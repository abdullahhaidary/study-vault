import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/services/chat_history_policy.dart';
import '../domain/book_ai_input.dart';
import 'book_pdf_source.dart';
import '../../../core/database/app_database.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_questions/domain/question_source.dart';
import '../../ai_questions/domain/quiz_models.dart';
import '../../ai_questions/services/pdf_text_extractor.dart';
import '../../ai_questions/services/quiz_generation_service.dart';
import '../../course_review/domain/course_review_models.dart';
import '../../lessons/data/materials_providers.dart' show materialAbsolutePath;
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';
import '../../pdf_ai_materials/services/pdf_ai_material_service.dart';
import '../data/book_repository.dart';
import '../domain/book_prompts.dart';
import '../domain/book_text_index.dart';
import '../domain/reading_plan.dart';
import 'book_search_service.dart';

/// Book AI uses retrieved/chapter text by default. Native PDF input is an
/// explicit choice and keeps the selected provider/profile for the request.
class BookAiService {
  BookAiService(
    this._repository,
    this._search,
    this._client, {
    this.quizzes,
    BookPdfSource? pdfSource,
    Future<String> Function(LessonMaterial)? resolveLecturePath,
  }) : _pdfSource = pdfSource ?? LocalBookPdfSource(),
       _resolveLecturePath = resolveLecturePath ?? materialAbsolutePath;

  final BookRepository _repository;
  final BookSearchService _search;
  final PdfAiCompletionClient _client;
  final QuizGenerationService? quizzes;
  final BookPdfSource _pdfSource;
  final Future<String> Function(LessonMaterial) _resolveLecturePath;

  static const askPageLimit = 14;
  static const askCharBudget = 60000;
  static const maxExplainPages = 30;
  static const _safeCharacters =
      PdfAiMaterialService.singleRequestSafeCharacters;

  Future<void> _requireIndex(ReferenceBook book) async {
    final state = await _repository.localState(book.id);
    if (!state.isIndexed(book)) {
      throw StateError(
        'This book is still being indexed on this device. Wait for indexing '
        'to finish, then try again.',
      );
    }
  }

  String Function(int) _chapterLookup(List<ReferenceBookChapter> chapters) {
    final top = chapters.where((c) => c.level == 0).toList();
    return (page) {
      for (final c in top.reversed) {
        if (page >= c.startPage && page <= c.endPage) return c.title;
      }
      return '';
    };
  }

  // ── Ask the book ─────────────────────────────────────────

  /// Saves the question and the cited answer to the book's conversation.
  Future<void> ask({
    required ReferenceBook book,
    required String question,
    required AiExecutionSelection selection,
    ReferenceBookChapter? chapter,
    BookAiInputMode inputMode = BookAiInputMode.extractedText,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;
    if (inputMode == BookAiInputMode.pdfAttachment) {
      await _askPdf(
        book: book,
        question: trimmed,
        selection: selection,
        chapter: chapter,
      );
      return;
    }
    await _requireIndex(book);
    final history = await _repository.messages(book.id);
    await _repository.addMessage(
      bookId: book.id,
      role: 'user',
      content: chapter == null
          ? trimmed
          : '$trimmed\n\n_(in: ${chapter.title})_',
    );

    var query = trimmed;
    final state = await _repository.localState(book.id);
    final useSemantic = selection.provider == AiProviderId.gemini;
    if (!useSemantic || state.vectorsModel != _search.embeddings.model) {
      try {
        final keywords = await _client.complete(
          messages: [
            {'role': 'user', 'content': BookPrompts.keywordsRequest(trimmed)},
          ],
          maxOutputTokens: 256,
          selection: selection,
        );
        _requireComplete(keywords);
        query = '$trimmed ${keywords.markdown}';
      } on Object {
        // Keyword expansion is only a recall boost.
      }
    }
    final within = chapter == null
        ? null
        : (start: chapter.startPage, end: chapter.endPage);
    final hits = await _search.search(
      book.id,
      query,
      limit: askPageLimit,
      within: within,
      useSemantic: useSemantic,
    );
    if (hits.isEmpty) {
      await _repository.addMessage(
        bookId: book.id,
        role: 'assistant',
        content:
            'I could not find pages in this book matching that question. '
            'Try different words or the exact term the book uses.',
        sourcePages: const [],
      );
      return;
    }
    final index = await _search.index(book.id);
    final selected = <BookPage>[];
    var used = 0;
    for (final hit in hits) {
      final text = index.textOf(hit.page) ?? '';
      if (used + text.length > askCharBudget && selected.isNotEmpty) break;
      selected.add(BookPage(hit.page, text));
      used += text.length;
    }
    selected.sort((a, b) => a.page.compareTo(b.page));
    final chapters = await _repository.chapters(book.id);
    final context =
        'SOURCE PAGES:\n${BookPrompts.pagesDocument(selected, chapterOf: _chapterLookup(chapters))}';
    final historyTurns = ChatHistoryPolicy.compact([
      AiChatTurn(role: 'user', content: context, pinForCache: true),
      for (final m in history) AiChatTurn(role: m.role, content: m.content),
      AiChatTurn(role: 'user', content: BookPrompts.askRequest(trimmed)),
    ]);
    final completion = await _client.complete(
      messages: [
        {'role': 'system', 'content': BookPrompts.system(book.title)},
        for (final m in historyTurns) {'role': m.role, 'content': m.content},
      ],
      maxOutputTokens: 4096,
      selection: selection,
    );
    _requireComplete(completion);
    final answer = completion.markdown.trim();
    if (answer.isEmpty) throw StateError('The AI returned an empty answer.');
    await _repository.addMessage(
      bookId: book.id,
      role: 'assistant',
      content: answer,
      sourcePages: [for (final p in selected) p.page],
      provider: completion.provider,
      model: completion.model,
    );
  }

  // ── Chapter briefs, summaries, explanations ──────────────

  Future<ReferenceBookAiItem> generateChapterItem({
    required ReferenceBook book,
    required ReferenceBookChapter chapter,
    required BookAiKind kind,
    required AiExecutionSelection selection,
    BookAiInputMode inputMode = BookAiInputMode.extractedText,
  }) async {
    if (chapter.bookId != book.id) {
      throw StateError('This chapter belongs to another book.');
    }
    if (inputMode == BookAiInputMode.extractedText) await _requireIndex(book);
    final pages = inputMode == BookAiInputMode.pdfAttachment
        ? await _pdfPageReferences(
            book,
            chapter.startPage,
            chapter.endPage,
            selection,
          )
        : await _repository.pages(
            book.id,
            start: chapter.startPage,
            end: chapter.endPage,
          );
    final completion = await _completeOverPages(
      book: book,
      pages: pages,
      inputMode: inputMode,
      request: BookPrompts.chapterRequest(kind, chapter.title),
      title: chapter.title,
      selection: selection,
    );
    return _repository.addAiItem(
      bookId: book.id,
      chapterId: chapter.id,
      kind: kind,
      scopeKey: chapter.id,
      startPage: chapter.startPage,
      endPage: chapter.endPage,
      content: completion.markdown,
      provider: completion.provider,
      model: completion.model,
    );
  }

  Future<ReferenceBookAiItem> explainPages({
    required ReferenceBook book,
    required int startPage,
    required int endPage,
    required AiExecutionSelection selection,
    BookAiInputMode inputMode = BookAiInputMode.extractedText,
    String? chapterId,
  }) async {
    if (startPage < 1 ||
        endPage > book.pageCount ||
        endPage < startPage ||
        endPage - startPage + 1 > maxExplainPages) {
      throw StateError('Choose at most $maxExplainPages pages to explain.');
    }
    if (inputMode == BookAiInputMode.extractedText) await _requireIndex(book);
    final pages = inputMode == BookAiInputMode.pdfAttachment
        ? await _pdfPageReferences(book, startPage, endPage, selection)
        : await _repository.pages(book.id, start: startPage, end: endPage);
    final completion = await _completeOverPages(
      book: book,
      pages: pages,
      inputMode: inputMode,
      request: BookPrompts.chapterRequest(BookAiKind.explanation, ''),
      title: 'pages $startPage–$endPage',
      selection: selection,
    );
    return _repository.addAiItem(
      bookId: book.id,
      chapterId: chapterId,
      kind: BookAiKind.explanation,
      scopeKey: pageScope(startPage, endPage),
      startPage: startPage,
      endPage: endPage,
      content: completion.markdown,
      provider: completion.provider,
      model: completion.model,
    );
  }

  static String pageScope(int start, int end) => 'pages:$start-$end';

  /// Long chapters are digested chunk by chunk first, like large PDFs.
  Future<PdfAiCompletion> _completeOverPages({
    required ReferenceBook book,
    required List<BookPage> pages,
    required String request,
    required String title,
    required AiExecutionSelection selection,
    BookAiInputMode inputMode = BookAiInputMode.extractedText,
  }) async {
    if (inputMode == BookAiInputMode.pdfAttachment) {
      final client = _fileClient;
      final limit = await client.pdfPageLimit(selection);
      final document = await _pdfSource.prepare(
        book,
        pages: [for (final p in pages) p.page],
        maxPages: limit,
      );
      final result = await client.completeWithPdf(
        document: document,
        messages: [
          {'role': 'system', 'content': BookPrompts.system(book.title)},
          {'role': 'user', 'content': document.pageMap},
          {'role': 'user', 'content': request},
        ],
        maxOutputTokens: 12000,
        selection: selection,
      );
      _requireComplete(result);
      return result;
    }
    if (pages.every((p) => p.text.trim().isEmpty)) {
      throw StateError('These pages have no extractable text.');
    }
    var document = BookPrompts.pagesDocument(pages, maxCharsPerPage: 1 << 20);
    if (document.length > _safeCharacters) {
      final chunks = _chunks(document, PdfAiMaterialService.chunkCharacters);
      final digests = <String>[];
      for (var i = 0; i < chunks.length; i++) {
        final digest = await _client.complete(
          messages: PdfAiPromptBuilder.chunkDigestMessages(
            documentChunk: chunks[i],
            chunkNumber: i + 1,
            chunkCount: chunks.length,
          ),
          maxOutputTokens: PdfAiMaterialService.chunkDigestMaxOutputTokens,
          selection: selection,
        );
        _requireComplete(digest);
        digests.add(digest.markdown.trim());
      }
      document = PdfAiPromptBuilder.synthesisDocument(
        title: title,
        chunkDigests: digests,
      );
    }
    final completion = await _client.complete(
      messages: [
        {'role': 'system', 'content': BookPrompts.system(book.title)},
        {'role': 'user', 'content': 'SOURCE PAGES:\n$document'},
        {'role': 'user', 'content': request},
      ],
      maxOutputTokens: 12000,
      selection: selection,
    );
    _requireComplete(completion);
    if (completion.markdown.trim().isEmpty) {
      throw StateError('The AI returned an empty response.');
    }
    return completion;
  }

  Future<List<BookPage>> _pdfPageReferences(
    ReferenceBook book,
    int start,
    int end,
    AiExecutionSelection selection,
  ) async {
    final limit = await _fileClient.pdfPageLimit(selection);
    if (start < 1 ||
        end < start ||
        end > book.pageCount ||
        end - start + 1 > limit) {
      throw AiMalformedOutputException(
        'Choose a valid range of at most $limit pages for this endpoint, or use extracted text.',
      );
    }
    return [for (var p = start; p <= end; p++) BookPage(p, '')];
  }

  PdfAiFileCompletionClient get _fileClient {
    final client = _client;
    if (client is! PdfAiFileCompletionClient) {
      throw const AiUnsupportedModelException(
        'PDF attachments are unavailable. Use extracted text for this model.',
      );
    }
    return client as PdfAiFileCompletionClient;
  }

  static void _requireComplete(PdfAiCompletion completion) {
    if (completion.isPartial) {
      throw const AiConnectionInterruptedException(
        'The book response was interrupted. It was not saved as a completed answer. Try again.',
      );
    }
    if (completion.markdown.trim().isEmpty) {
      throw const AiEmptyResultException();
    }
  }

  Future<void> _askPdf({
    required ReferenceBook book,
    required String question,
    required AiExecutionSelection selection,
    ReferenceBookChapter? chapter,
  }) async {
    final client = _fileClient;
    final limit = await client.pdfPageLimit(selection);
    final references = chapter == null
        ? null
        : await _pdfPageReferences(
            book,
            chapter.startPage,
            chapter.endPage,
            selection,
          );
    final document = await _pdfSource.prepare(
      book,
      pages: references == null ? null : [for (final p in references) p.page],
      maxPages: limit,
    );
    final history = await _repository.messages(book.id);
    final messages = ChatHistoryPolicy.compact([
      AiChatTurn(role: 'user', content: document.pageMap, pinForCache: true),
      for (final m in history) AiChatTurn(role: m.role, content: m.content),
      AiChatTurn(role: 'user', content: BookPrompts.askRequest(question)),
    ]);
    await _repository.addMessage(
      bookId: book.id,
      role: 'user',
      content: question,
    );
    final completion = await client.completeWithPdf(
      document: document,
      messages: [
        {'role': 'system', 'content': BookPrompts.system(book.title)},
        for (final m in messages) {'role': m.role, 'content': m.content},
      ],
      maxOutputTokens: 4096,
      selection: selection,
    );
    _requireComplete(completion);
    final permitted = document.sourcePages.toSet();
    final cited = BookPrompts.citedPages(
      completion.markdown,
    ).where(permitted.contains).toList();
    await _repository.addMessage(
      bookId: book.id,
      role: 'assistant',
      content: completion.markdown.trim(),
      sourcePages: cited,
      provider: completion.provider,
      model: completion.model,
    );
  }

  static List<String> _chunks(String text, int size) {
    final result = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = start + size;
      if (end >= text.length) {
        end = text.length;
      } else {
        final cut = text.lastIndexOf('\n--- Page ', end);
        if (cut > start + size ~/ 2) end = cut;
      }
      result.add(text.substring(start, end));
      start = end;
    }
    return result;
  }

  // ── Quizzes ──────────────────────────────────────────────

  Future<QuestionSet> generateQuiz({
    required ReferenceBook book,
    required ReferenceBookChapter chapter,
    required int count,
    required AiExecutionSelection selection,
  }) async {
    final quizzes = this.quizzes;
    if (quizzes == null) throw StateError('Quizzes are unavailable.');
    await _requireIndex(book);
    final pages = await _repository.pages(
      book.id,
      start: chapter.startPage,
      end: chapter.endPage,
    );
    final subjects = await _repository.subjectsForBook(book.id);
    final set = await quizzes.generateAndPersist(
      source: QuestionSourceBuilder.fromPages(
        pages: [
          for (final p in pages)
            SourcePageText(pageNumber: p.page, text: p.text),
        ],
        subjectId: subjects.firstOrNull?.id,
      ),
      count: count,
      type: QuizQuestionType.mixed,
      difficulty: QuizDifficulty.mixed,
      selection: selection,
    );
    final title = 'Book · ${chapter.title}';
    await _repository.db.customStatement(
      'UPDATE question_sets SET title = ? WHERE id = ?',
      [title.length > 200 ? title.substring(0, 200) : title, set.id],
    );
    await _repository.linkQuiz(
      bookId: book.id,
      chapterId: chapter.id,
      questionSetId: set.id,
    );
    return set;
  }

  // ── Lecture ↔ book matching ──────────────────────────────

  /// Finds and saves the book pages covering one lecture PDF.
  Future<int> mapLecture({
    required ReferenceBook book,
    required CourseReviewSource lecture,
    required AiExecutionSelection selection,
  }) async {
    await _requireIndex(book);
    final lectureText = await _lectureText(lecture);
    if (lectureText.trim().isEmpty) {
      throw StateError('This lecture has no text to match.');
    }
    final chapters = await _repository.chapters(book.id);
    final contents = [
      for (final c in chapters)
        '${'  ' * c.level}- [p. ${c.startPage}–${c.endPage}] ${c.title}',
    ].join('\n');
    final hits = await _search.search(
      book.id,
      lectureText.length > 3000 ? lectureText.substring(0, 3000) : lectureText,
      limit: 15,
      useSemantic: selection.provider == AiProviderId.gemini,
    );
    final lookup = _chapterLookup(chapters);
    final matching = [
      for (final h in hits) '- p. ${h.page} (${lookup(h.page)}): ${h.snippet}',
    ].join('\n');
    final completion = await _client.complete(
      messages: [
        {'role': 'system', 'content': BookPrompts.system(book.title)},
        {
          'role': 'user',
          'content':
              'LECTURE "${lecture.label}":\n$lectureText\n\n'
              'BOOK CONTENTS:\n$contents\n\nMATCHING PAGES:\n$matching',
        },
        {
          'role': 'user',
          'content': BookPrompts.lectureMapRequest(
            lectureTitle: lecture.label,
            pageCount: book.pageCount,
          ),
        },
      ],
      maxOutputTokens: 2048,
      selection: selection,
    );
    _requireComplete(completion);
    final ranges = BookPrompts.parseRanges(completion.markdown, book.pageCount);
    await _repository.replaceLinks(
      bookId: book.id,
      materialId: lecture.material.id,
      ranges: [
        for (final r in ranges)
          (
            start: r.start,
            end: r.end,
            priority: BookLinkPriority.fromStorage(r.priority),
            reason: r.reason,
          ),
      ],
    );
    return ranges.length;
  }

  Future<String> _lectureText(CourseReviewSource lecture) async {
    final parts = [
      lecture.lessonSummary?.content,
      lecture.latest[CourseReviewPart.summary]?.content,
      lecture.lessonExplanation?.content,
    ].whereType<String>().toList();
    if (parts.isNotEmpty) {
      final text = parts.join('\n\n');
      return text.length > 20000 ? text.substring(0, 20000) : text;
    }
    final pages = await PdfTextExtractor.extractPages(
      filePath: await _resolveLecturePath(lecture.material),
    );
    final text = pages.map((p) => p.text).join('\n');
    return text.length > 20000 ? text.substring(0, 20000) : text;
  }
}
