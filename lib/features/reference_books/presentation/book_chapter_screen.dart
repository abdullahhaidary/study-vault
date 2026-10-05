import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../../ai_questions/presentation/quiz_session_screen.dart';
import '../data/book_providers.dart';
import '../data/book_repository.dart';
import '../domain/book_prompts.dart';
import '../services/book_ai_service.dart';
import 'book_actions.dart';
import 'book_markdown.dart';

/// One chapter: read it, its pre-reading brief, post-reading summary, page
/// explanations and quizzes.
class BookChapterScreen extends ConsumerStatefulWidget {
  const BookChapterScreen({
    super.key,
    required this.bookId,
    required this.chapterId,
  });

  final String bookId;
  final String chapterId;

  @override
  ConsumerState<BookChapterScreen> createState() => _BookChapterScreenState();
}

class _BookChapterScreenState extends ConsumerState<BookChapterScreen> {
  String? _busy;

  BookRepository get _repository => ref.read(bookRepositoryProvider);

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = label);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(aiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _generate(
    ReferenceBook book,
    ReferenceBookChapter chapter,
    BookAiKind kind,
  ) async {
    final selection = await pickAiModel(
      context,
      ref,
      title: 'Write the ${kind.label.toLowerCase()} with',
    );
    if (selection == null || !mounted) return;
    await _run(
      'Writing the ${kind.label.toLowerCase()}…',
      () => ref
          .read(bookAiServiceProvider)
          .generateChapterItem(
            book: book,
            chapter: chapter,
            kind: kind,
            selection: selection,
          ),
    );
  }

  Future<void> _copyForAi(
    ReferenceBook book,
    ReferenceBookChapter chapter,
    BookAiKind kind,
  ) async {
    final pages = await _repository.pages(
      book.id,
      start: chapter.startPage,
      end: chapter.endPage,
    );
    if (pages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wait for indexing to finish first.')),
        );
      }
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: BookPrompts.external(
          kind,
          bookTitle: book.title,
          chapterTitle: chapter.title,
          pages: pages,
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied the ${kind.label.toLowerCase()} request with '
            '${pages.length} pages. Paste the AI\'s answer back with '
            '"Paste result".',
          ),
        ),
      );
    }
  }

  Future<void> _paste(
    ReferenceBook book,
    ReferenceBookChapter chapter,
    BookAiKind kind,
  ) async {
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted) return;
    final controller = TextEditingController(text: clip);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Paste ${kind.label.toLowerCase()}'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 18,
            decoration: const InputDecoration(
              hintText: 'Markdown from Gemini, ChatGPT, Cursor or Devin',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (save != true || text.isEmpty) return;
    await _repository.addAiItem(
      bookId: book.id,
      chapterId: chapter.id,
      kind: kind,
      scopeKey: chapter.id,
      startPage: chapter.startPage,
      endPage: chapter.endPage,
      content: text,
      provider: 'manual',
      model: 'manual_entry',
    );
  }

  Future<void> _explainRange(
    ReferenceBook book,
    ReferenceBookChapter chapter,
  ) async {
    final start = TextEditingController(text: '${chapter.startPage}');
    final end = TextEditingController(
      text:
          '${(chapter.startPage + 4).clamp(chapter.startPage, chapter.endPage)}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Explain pages'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: start,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'From page'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: end,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'To page'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Explain'),
          ),
        ],
      ),
    );
    final s = int.tryParse(start.text.trim());
    final e = int.tryParse(end.text.trim());
    start.dispose();
    end.dispose();
    if (ok != true || s == null || e == null || !mounted) return;
    final selection = await pickAiModel(context, ref, title: 'Explain with');
    if (selection == null || !mounted) return;
    await _run(
      'Explaining pages $s–$e…',
      () => ref
          .read(bookAiServiceProvider)
          .explainPages(
            book: book,
            startPage: s,
            endPage: e,
            selection: selection,
            chapterId: chapter.id,
          ),
    );
  }

  Future<void> _quiz(ReferenceBook book, ReferenceBookChapter chapter) async {
    var count = 10.0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Chapter quiz'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${count.round()} mixed questions'),
              Slider(
                value: count,
                min: 5,
                max: 30,
                divisions: 25,
                onChanged: (v) => setDialog(() => count = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final selection = await pickAiModel(
      context,
      ref,
      title: 'Create quiz with',
    );
    if (selection == null || !mounted) return;
    await _run(
      'Creating the quiz…',
      () => ref
          .read(bookAiServiceProvider)
          .generateQuiz(
            book: book,
            chapter: chapter,
            count: count.round(),
            selection: selection,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(bookProvider(widget.bookId)).valueOrNull;
    final chapters =
        ref.watch(bookChaptersProvider(widget.bookId)).valueOrNull ?? const [];
    final chapter = chapters.where((c) => c.id == widget.chapterId).firstOrNull;
    if (book == null || chapter == null) {
      return const Scaffold(body: AppLoading());
    }
    final items =
        ref.watch(bookAiItemsProvider(book.id)).valueOrNull ?? const [];
    ReferenceBookAiItem? latest(BookAiKind kind) => items
        .where((i) => i.kind == kind.storageValue && i.scopeKey == chapter.id)
        .firstOrNull;
    final explanations = [
      for (final i in items)
        if (i.kind == BookAiKind.explanation.storageValue &&
            i.startPage >= chapter.startPage &&
            i.endPage <= chapter.endPage)
          i,
    ];
    final status = ChapterStatus.fromStorage(chapter.status);
    void open(int page) => openBookReader(context, book, page: page);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(chapter.title, overflow: TextOverflow.ellipsis),
              Text(
                '${book.title} · pp. ${chapter.startPage}–${chapter.endPage}',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            FilledButton.tonalIcon(
              onPressed: () async {
                if (status == ChapterStatus.notStarted) {
                  await _repository.setChapterStatus(
                    chapter,
                    ChapterStatus.reading,
                  );
                }
                if (context.mounted) open(chapter.startPage);
              },
              icon: const Icon(Icons.chrome_reader_mode_outlined),
              label: const Text('Read'),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Brief'),
              Tab(text: 'Summary'),
              Tab(text: 'Explanations'),
              Tab(text: 'Quiz'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: SegmentedButton<ChapterStatus>(
                segments: [
                  for (final s in ChapterStatus.values)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {status},
                onSelectionChanged: (s) =>
                    _repository.setChapterStatus(chapter, s.first),
              ),
            ),
            if (_busy != null) ...[
              const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Text(_busy!),
              ),
            ],
            Expanded(
              child: TabBarView(
                children: [
                  for (final kind in const [
                    BookAiKind.brief,
                    BookAiKind.summary,
                  ])
                    _itemTab(book, chapter, kind, latest(kind), open),
                  _explanationsTab(book, chapter, explanations, open),
                  _quizTab(book, chapter),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(
    ReferenceBook book,
    ReferenceBookChapter chapter,
    BookAiKind kind,
    bool exists,
  ) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      FilledButton.icon(
        onPressed: _busy != null ? null : () => _generate(book, chapter, kind),
        icon: const Icon(Icons.auto_awesome),
        label: Text(exists ? 'Regenerate' : 'Generate'),
      ),
      OutlinedButton.icon(
        onPressed: () => _copyForAi(book, chapter, kind),
        icon: const Icon(Icons.copy_all_outlined),
        label: const Text('Copy for external AI'),
      ),
      OutlinedButton.icon(
        onPressed: () => _paste(book, chapter, kind),
        icon: const Icon(Icons.content_paste),
        label: const Text('Paste result'),
      ),
    ],
  );

  Widget _itemTab(
    ReferenceBook book,
    ReferenceBookChapter chapter,
    BookAiKind kind,
    ReferenceBookAiItem? item,
    ValueChanged<int> open,
  ) {
    final theme = Theme.of(context);
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            kind == BookAiKind.brief
                ? 'Read this first: a map of the chapter, key terms, and what to '
                      'read closely vs. skim.'
                : 'After reading: a complete revision summary with page '
                      'references.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _actions(book, chapter, kind, item != null),
          const Divider(height: AppSpacing.xl),
          if (item == null)
            Text('No ${kind.label.toLowerCase()} yet.')
          else ...[
            Text(
              'v${item.version}${item.provider == 'manual' ? ' · pasted' : ''}',
              style: theme.textTheme.labelSmall,
            ),
            BookMarkdown(data: item.content, onOpenPage: open),
          ],
        ],
      ),
    );
  }

  Widget _explanationsTab(
    ReferenceBook book,
    ReferenceBookChapter chapter,
    List<ReferenceBookAiItem> items,
    ValueChanged<int> open,
  ) {
    final latest = <String, ReferenceBookAiItem>{};
    for (final i in items) {
      latest.putIfAbsent(i.scopeKey, () => i);
    }
    final list = latest.values.toList()
      ..sort((a, b) => a.startPage.compareTo(b.startPage));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        FilledButton.icon(
          onPressed: _busy != null ? null : () => _explainRange(book, chapter),
          icon: const Icon(Icons.auto_awesome),
          label: Text('Explain pages (up to ${BookAiService.maxExplainPages})'),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in list)
          Card(
            child: ExpansionTile(
              title: Text(
                item.startPage == item.endPage
                    ? 'Page ${item.startPage}'
                    : 'Pages ${item.startPage}–${item.endPage}',
              ),
              childrenPadding: const EdgeInsets.all(AppSpacing.md),
              children: [
                SelectionArea(
                  child: BookMarkdown(data: item.content, onOpenPage: open),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _quizTab(ReferenceBook book, ReferenceBookChapter chapter) {
    final quizzes =
        ref.watch(chapterQuizzesProvider(chapter.id)).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        FilledButton.icon(
          onPressed: _busy != null ? null : () => _quiz(book, chapter),
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('Create chapter quiz'),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final q in quizzes)
          Card(
            child: ListTile(
              leading: const Icon(Icons.quiz),
              title: Text(q.title),
              subtitle: Text('${q.questionCount} questions'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuizSessionScreen(questionSetId: q.id),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
