import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../ai_questions/domain/quiz_models.dart';
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/manual_entry_models.dart';
import '../domain/manual_entry_plan.dart';

/// Builds a reviewable plan from a parsed bundle and applies it atomically.
class ManualEntryImportService {
  ManualEntryImportService(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  static const provider = 'manual';
  static const sourceType = 'manual_entry';

  Future<ManualEntryPlan> buildPlan({
    required ManualEntryBundle bundle,
    required ManualEntryTarget target,
    ManualEntryPlan? previous,
  }) async {
    final notes = await _db.getStudyNotesForLesson(target.lessonId);
    final flashcards = await _db
        .watchFlashcardsForLesson(target.lessonId)
        .first;
    final quizzes = await _db.watchQuestionSetsForLesson(target.lessonId).first;
    final materials = target.materialId == null
        ? const <PdfAiMaterial>[]
        : await _db.watchPdfAiMaterials(target.materialId!).first;
    final pins = target.materialId == null
        ? const <StudyPin>[]
        : await _db.getStudyPinsForResource(target.materialId!);

    final items = <ManualEntryPlanItem>[];
    for (final material in bundle.studyMaterials) {
      final latest = materials
          .where((m) => m.type == material.type.storageValue)
          .fold<PdfAiMaterial?>(
            null,
            (best, m) => best == null || m.version > best.version ? m : best,
          );
      items.add(
        ManualEntryPlanItem(
          id: 'sm:${material.type.storageValue}',
          kind: ManualEntryKind.studyMaterial,
          title: material.type.displayName,
          preview: _firstLine(material.markdown),
          markdown: material.markdown,
          detail:
              '${_chars(material.markdown)} chars'
              '${latest == null ? '' : ' · will be v${latest.version + 1}'}',
          existing: latest == null
              ? null
              : ExistingMatch(
                  id: latest.id,
                  description:
                      '${material.type.shortName} v${latest.version} · '
                      '${_chars(latest.content)} chars',
                ),
        ),
      );
    }
    for (var i = 0; i < bundle.notes.length; i++) {
      final note = bundle.notes[i];
      final match = notes.where((n) => _same(n.title, note.title)).firstOrNull;
      items.add(
        ManualEntryPlanItem(
          id: 'note:$i',
          kind: ManualEntryKind.note,
          title: note.title,
          preview: _firstLine(note.markdown),
          markdown: note.markdown,
          existing: match == null
              ? null
              : ExistingMatch(
                  id: match.id,
                  description: 'Note "${match.title}"',
                ),
        ),
      );
    }
    for (var i = 0; i < bundle.annotations.length; i++) {
      final annotation = bundle.annotations[i];
      final match = pins
          .where(
            (p) =>
                p.pageNumber == annotation.page &&
                _same(p.shortText, annotation.shortText),
          )
          .firstOrNull;
      items.add(
        ManualEntryPlanItem(
          id: 'pin:$i',
          kind: ManualEntryKind.annotation,
          title: annotation.shortText,
          preview: annotation.fullNoteMarkdown == null
              ? 'Label only'
              : _firstLine(annotation.fullNoteMarkdown!),
          markdown: annotation.fullNoteMarkdown ?? annotation.shortText,
          page: annotation.page,
          detail: annotation.categoryKey == null
              ? 'Page ${annotation.page}'
              : 'Page ${annotation.page} · ${_categoryLabel(annotation.categoryKey!)}',
          existing: match == null
              ? null
              : ExistingMatch(
                  id: match.id,
                  description:
                      'Pin on page ${match.pageNumber}: "${match.shortText}"',
                ),
        ),
      );
    }
    for (var i = 0; i < bundle.flashcards.length; i++) {
      final card = bundle.flashcards[i];
      final match = flashcards
          .where((f) => _same(f.front, card.front))
          .firstOrNull;
      items.add(
        ManualEntryPlanItem(
          id: 'card:$i',
          kind: ManualEntryKind.flashcard,
          title: card.front,
          preview: _firstLine(card.backMarkdown),
          markdown:
              '**Front**\n\n${card.front}\n\n**Back**\n\n${card.backMarkdown}',
          existing: match == null
              ? null
              : ExistingMatch(
                  id: match.id,
                  description: 'Card "${match.front}"',
                ),
        ),
      );
    }
    for (var i = 0; i < bundle.quizzes.length; i++) {
      final quiz = bundle.quizzes[i];
      final match = quizzes
          .where((q) => _same(q.title, quiz.title))
          .firstOrNull;
      items.add(
        ManualEntryPlanItem(
          id: 'quiz:$i',
          kind: ManualEntryKind.quiz,
          title: quiz.title,
          preview: quiz.questions.first.question,
          markdown: _quizMarkdown(quiz),
          detail:
              '${quiz.questions.length} questions · ${quiz.questionType.label} · ${quiz.difficulty.label}',
          existing: match == null
              ? null
              : ExistingMatch(
                  id: match.id,
                  description:
                      'Quiz "${match.title}" · ${match.questionCount} questions',
                ),
        ),
      );
    }

    if (previous != null) {
      final old = {for (final item in previous.items) item.id: item};
      for (final item in items) {
        final prior = old[item.id];
        if (prior == null) continue;
        item.included = prior.included;
        if (item.hasConflict || prior.resolution == ConflictResolution.skip) {
          item.resolution = prior.resolution;
        }
      }
    }

    return ManualEntryPlan(
      bundle: bundle,
      target: target,
      items: items,
      existing: [
        for (final m in materials)
          ManualEntryExistingItem(
            id: m.id,
            kind: ManualEntryKind.studyMaterial,
            title:
                PdfAiMaterialTypeX.fromStorage(m.type)?.displayName ?? m.type,
            detail: 'v${m.version} · ${_chars(m.content)} chars',
          ),
        for (final n in notes)
          ManualEntryExistingItem(
            id: n.id,
            kind: ManualEntryKind.note,
            title: n.title,
            detail: n.plainTextContent == null
                ? null
                : _firstLine(n.plainTextContent!),
          ),
        for (final p in pins)
          ManualEntryExistingItem(
            id: p.id,
            kind: ManualEntryKind.annotation,
            title: p.shortText,
            detail: 'Page ${p.pageNumber ?? '?'}',
            page: p.pageNumber,
          ),
        for (final f in flashcards)
          ManualEntryExistingItem(
            id: f.id,
            kind: ManualEntryKind.flashcard,
            title: f.front,
            detail: f.backPlainText == null
                ? null
                : _firstLine(f.backPlainText!),
          ),
        for (final q in quizzes)
          ManualEntryExistingItem(
            id: q.id,
            kind: ManualEntryKind.quiz,
            title: q.title,
            detail:
                '${q.questionCount} questions · ${QuizDifficultyX.fromStorage(q.difficulty).label}',
          ),
      ],
      before: ManualEntryCounts(
        studyMaterialVersions: materials.length,
        notes: notes.length,
        annotations: pins.length,
        flashcards: flashcards.length,
        quizzes: quizzes.length,
      ),
    );
  }

  /// Writes every included, non-skipped item in a single transaction.
  Future<ManualEntryImportResult> apply(ManualEntryPlan plan) async {
    if (plan.missingPdf) {
      throw StateError('Choose a PDF for study materials and annotations.');
    }
    var added = 0;
    var replaced = 0;
    final skipped = plan.items.where((i) => !i.willWrite).length;
    final now = DateTime.now();

    await _db.transaction(() async {
      final pinsPerPage = <int, int>{};
      for (final item in plan.items.where((i) => i.willWrite)) {
        if (item.replaces) {
          replaced++;
        } else {
          added++;
        }
        switch (item.kind) {
          case ManualEntryKind.studyMaterial:
            await _writeStudyMaterial(plan, item, now);
          case ManualEntryKind.note:
            await _writeNote(plan, item, now);
          case ManualEntryKind.annotation:
            await _writeAnnotation(plan, item, now, pinsPerPage);
          case ManualEntryKind.flashcard:
            await _writeFlashcard(plan, item, now);
          case ManualEntryKind.quiz:
            await _writeQuiz(plan, item, now);
        }
      }
    });
    return ManualEntryImportResult(
      added: added,
      replaced: replaced,
      skipped: skipped,
    );
  }

  Future<void> _writeStudyMaterial(
    ManualEntryPlan plan,
    ManualEntryPlanItem item,
    DateTime now,
  ) async {
    final material = plan.bundle.studyMaterials.firstWhere(
      (m) => 'sm:${m.type.storageValue}' == item.id,
    );
    if (item.replaces) await _db.deletePdfAiMaterial(item.existing!.id);
    final content = material.markdown.trim();
    await _db.insertPdfAiMaterialVersion(
      materialId: plan.target.materialId!,
      type: material.type.storageValue,
      builder: (version) => PdfAiMaterialsCompanion.insert(
        id: _uuid.v4(),
        materialId: plan.target.materialId!,
        type: material.type.storageValue,
        content: content,
        version: version,
        generatedAt: now,
        provider: const Value(provider),
        model: const Value(sourceType),
        sourceFingerprint: sha256.convert(utf8.encode(content)).toString(),
      ),
    );
  }

  Future<void> _writeNote(
    ManualEntryPlan plan,
    ManualEntryPlanItem item,
    DateTime now,
  ) async {
    final note = plan.bundle.notes[_index(item.id)];
    final rich = MarkdownToQuill.toDeltaJson(note.markdown);
    final plain = StudyNoteCodec.plainTextPreview(rich);
    if (item.replaces) {
      final existing = await _db.getStudyNoteById(item.existing!.id);
      if (existing != null) {
        await _db.updateStudyNote(
          existing.copyWith(
            title: note.title,
            content: rich,
            plainTextContent: Value(plain.isEmpty ? null : plain),
            updatedAt: now,
          ),
        );
        return;
      }
    }
    await _db.insertStudyNote(
      StudyNotesCompanion.insert(
        id: _uuid.v4(),
        lessonId: Value(plan.target.lessonId),
        title: note.title,
        content: rich,
        plainTextContent: Value(plain.isEmpty ? null : plain),
        sortOrder: Value(
          await _db.nextNoteSortOrder(lessonId: plan.target.lessonId),
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _writeAnnotation(
    ManualEntryPlan plan,
    ManualEntryPlanItem item,
    DateTime now,
    Map<int, int> pinsPerPage,
  ) async {
    final annotation = plan.bundle.annotations[_index(item.id)];
    final rich = annotation.fullNoteMarkdown == null
        ? null
        : MarkdownToQuill.toDeltaJson(annotation.fullNoteMarkdown!);
    final plain = rich == null ? null : StudyNoteCodec.plainTextPreview(rich);
    final categoryId = annotation.categoryKey == null
        ? null
        : 'cat_${annotation.categoryKey}';
    if (item.replaces) {
      final existing = await _db.getStudyPinById(item.existing!.id);
      if (existing != null) {
        await _db.updateStudyPin(
          existing.copyWith(
            shortText: annotation.shortText,
            fullExplanation: Value(rich),
            fullExplanationPlainText: Value(
              plain?.isEmpty ?? true ? null : plain,
            ),
            categoryId: Value(categoryId ?? existing.categoryId),
            updatedAt: now,
          ),
        );
        return;
      }
    }
    // ChatGPT cannot know page coordinates: stack imported pins down the
    // left margin so each is visible and draggable.
    final slot = pinsPerPage.update(
      annotation.page,
      (v) => v + 1,
      ifAbsent: () => 0,
    );
    await _db.insertStudyPin(
      StudyPinsCompanion.insert(
        id: _uuid.v4(),
        resourceId: plan.target.materialId!,
        pinType: Value(StudyPinType.point.dbValue),
        categoryId: Value(categoryId),
        pageNumber: Value(annotation.page),
        xRatio: 0.08,
        yRatio: (0.12 + slot * 0.08).clamp(0.05, 0.92),
        shortText: annotation.shortText,
        fullExplanation: Value(rich),
        fullExplanationPlainText: Value(plain?.isEmpty ?? true ? null : plain),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _writeFlashcard(
    ManualEntryPlan plan,
    ManualEntryPlanItem item,
    DateTime now,
  ) async {
    final card = plan.bundle.flashcards[_index(item.id)];
    final rich = MarkdownToQuill.toDeltaJson(card.backMarkdown);
    final plain = StudyNoteCodec.plainTextPreview(rich);
    if (item.replaces) {
      final existing = await _db.getFlashcardById(item.existing!.id);
      if (existing != null) {
        await _db.updateFlashcard(
          existing.copyWith(
            front: card.front,
            back: rich,
            backPlainText: Value(plain.isEmpty ? null : plain),
            updatedAt: now,
          ),
        );
        return;
      }
    }
    await _db.insertFlashcard(
      FlashcardsCompanion.insert(
        id: _uuid.v4(),
        subjectId: Value(plan.target.subjectId),
        lessonId: Value(plan.target.lessonId),
        front: card.front,
        back: rich,
        backPlainText: Value(plain.isEmpty ? null : plain),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _writeQuiz(
    ManualEntryPlan plan,
    ManualEntryPlanItem item,
    DateTime now,
  ) async {
    final quiz = plan.bundle.quizzes[_index(item.id)];
    if (item.replaces) await _db.deleteQuestionSet(item.existing!.id);
    final setId = _uuid.v4();
    final questions = <QuizQuestionsCompanion>[];
    final options = <QuizQuestionOptionsCompanion>[];
    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      final qId = _uuid.v4();
      questions.add(
        QuizQuestionsCompanion.insert(
          id: qId,
          questionSetId: setId,
          type: q.type.storageValue,
          question: q.question,
          correctAnswer: q.correctAnswerStorage,
          explanation: Value(q.explanation.isEmpty ? null : q.explanation),
          difficulty: Value(q.difficulty.storageValue),
          sourcePage: Value(q.sourcePage),
          position: i,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final labels = q.isMcq
          ? q.options
          : (q.isTrueFalse ? const ['True', 'False'] : const <String>[]);
      for (var oi = 0; oi < labels.length; oi++) {
        options.add(
          QuizQuestionOptionsCompanion.insert(
            id: _uuid.v4(),
            questionId: qId,
            optionText: labels[oi],
            isCorrect: q.isMcq
                ? oi == q.correctAnswer
                : (q.correctAnswer == true) == (oi == 0),
            position: oi,
          ),
        );
      }
    }
    await _db.persistGeneratedQuiz(
      setEntry: QuestionSetsCompanion.insert(
        id: setId,
        materialId: Value(plan.target.materialId),
        lessonId: Value(plan.target.lessonId),
        subjectId: Value(plan.target.subjectId),
        title: quiz.title,
        sourceType: sourceType,
        questionCount: quiz.questions.length,
        questionType: quiz.questionType.storageValue,
        difficulty: quiz.difficulty.storageValue,
        aiProvider: const Value(provider),
        createdAt: now,
        updatedAt: now,
      ),
      questions: questions,
      options: options,
    );
  }

  static int _index(String id) => int.parse(id.split(':').last);

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  static String _firstLine(String markdown) {
    final line = markdown
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[#>\-*\s]+'), '').trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return line.length > 140 ? '${line.substring(0, 140)}…' : line;
  }

  static String _chars(String text) {
    final digits = text.length.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String _categoryLabel(String key) {
    final seed = BuiltInPinCategories.seeds
        .where((s) => s.id == 'cat_$key')
        .firstOrNull;
    return seed?.name ?? key;
  }

  static String _quizMarkdown(ManualQuiz quiz) {
    final buffer = StringBuffer('# ${quiz.title}\n\n');
    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      buffer.writeln('**${i + 1}. ${q.question}**  ');
      buffer.writeln('_${q.type.label} · ${q.difficulty.label}_\n');
      if (q.isMcq) {
        for (var oi = 0; oi < q.options.length; oi++) {
          final marker = oi == q.correctAnswer ? '✅' : '•';
          buffer.writeln('$marker ${'ABCD'[oi]}. ${q.options[oi]}');
        }
      } else {
        buffer.writeln('Answer: **${q.correctAnswerStorage}**');
      }
      if (q.explanation.isNotEmpty) buffer.writeln('\n> ${q.explanation}');
      buffer.writeln();
    }
    return buffer.toString();
  }
}
