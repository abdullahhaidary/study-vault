import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/question_source.dart';
import '../services/pdf_text_extractor.dart';
import 'generate_questions_sheet.dart';

/// Shared launch builders for PDF / note / pin contexts.
abstract final class QuestionSourceLaunches {
  static GenerateQuestionsLaunch forPdfSelection({
    required WidgetRef ref,
    required String selectedText,
    required String materialId,
    required String filePath,
    int? pageNumber,
    int? currentPage,
    Set<int>? selectedPages,
    String? surroundingText,
  }) {
    final enrichedSelection = _withSurrounding(
      selectedText: selectedText,
      surroundingText: surroundingText,
      pageNumber: pageNumber,
    );
    return GenerateQuestionsLaunch(
      availableSources: const [
        QuestionSourceType.selectedText,
        QuestionSourceType.page,
        QuestionSourceType.pages,
        QuestionSourceType.material,
        QuestionSourceType.annotations,
        QuestionSourceType.notes,
        QuestionSourceType.annotationsAndNotes,
      ],
      initialSource: QuestionSourceType.selectedText,
      resolveSource: (type) => _resolvePdfSource(
        ref: ref,
        type: type,
        materialId: materialId,
        filePath: filePath,
        selectedText: enrichedSelection,
        pageNumber: pageNumber,
        currentPage: currentPage,
        selectedPages: selectedPages,
      ),
    );
  }

  static String _withSurrounding({
    required String selectedText,
    String? surroundingText,
    int? pageNumber,
  }) {
    final selected = selectedText.trim();
    final surrounding = surroundingText?.trim();
    if (surrounding == null || surrounding.isEmpty) return selected;
    final buffer = StringBuffer();
    if (pageNumber != null) buffer.writeln('--- Page $pageNumber ---');
    buffer.writeln('SELECTED TEXT:');
    buffer.writeln(selected);
    buffer.writeln();
    buffer.writeln('SURROUNDING CONTEXT:');
    buffer.writeln(surrounding);
    return buffer.toString().trim();
  }

  static GenerateQuestionsLaunch forPdfMaterial({
    required WidgetRef ref,
    required String materialId,
    required String filePath,
    int? currentPage,
    Set<int>? selectedPages,
  }) {
    return GenerateQuestionsLaunch(
      availableSources: const [
        QuestionSourceType.page,
        QuestionSourceType.pages,
        QuestionSourceType.material,
        QuestionSourceType.annotations,
        QuestionSourceType.notes,
        QuestionSourceType.annotationsAndNotes,
      ],
      initialSource: currentPage != null
          ? QuestionSourceType.page
          : QuestionSourceType.material,
      resolveSource: (type) => _resolvePdfSource(
        ref: ref,
        type: type,
        materialId: materialId,
        filePath: filePath,
        currentPage: currentPage,
        selectedPages: selectedPages,
      ),
    );
  }

  static GenerateQuestionsLaunch forNoteText({
    required WidgetRef ref,
    required String noteText,
    String? lessonId,
    String? subjectId,
    String? noteId,
    String? noteTitle,
  }) {
    return GenerateQuestionsLaunch(
      availableSources: const [
        QuestionSourceType.selectedText,
        QuestionSourceType.notes,
      ],
      initialSource: QuestionSourceType.selectedText,
      resolveSource: (type) async {
        final db = ref.read(databaseProvider);
        if (type == QuestionSourceType.notes) {
          final notes = <NoteSourceItem>[];
          if (noteId != null) {
            notes.add(
              NoteSourceItem(
                id: noteId,
                title: noteTitle ?? 'Note',
                plainText: noteText,
              ),
            );
          } else if (lessonId != null) {
            final rows = await db.getStudyNotesForLesson(lessonId);
            for (final n in rows) {
              notes.add(
                NoteSourceItem(
                  id: n.id,
                  title: n.title,
                  plainText: n.plainTextContent ?? '',
                ),
              );
            }
          }
          return QuestionSourceBuilder.fromNotes(
            notes: notes,
            lessonId: lessonId,
            subjectId: subjectId,
          );
        }
        return QuestionSourceBuilder.fromSelectedText(
          text: noteText,
          lessonId: lessonId,
          subjectId: subjectId,
        );
      },
    );
  }

  static GenerateQuestionsLaunch forPin({
    required WidgetRef ref,
    required String pinText,
    required String materialId,
    String? lessonId,
    int? pageNumber,
  }) {
    return GenerateQuestionsLaunch(
      availableSources: const [
        QuestionSourceType.selectedText,
        QuestionSourceType.annotations,
      ],
      initialSource: QuestionSourceType.selectedText,
      resolveSource: (type) async {
        final db = ref.read(databaseProvider);
        if (type == QuestionSourceType.annotations) {
          final pins = await db.getStudyPinsForResource(materialId);
          return QuestionSourceBuilder.fromAnnotations(
            annotations: [for (final p in pins) _annotationItem(p)],
            materialId: materialId,
            lessonId: lessonId,
          );
        }
        return QuestionSourceBuilder.fromSelectedText(
          text: pinText,
          materialId: materialId,
          lessonId: lessonId,
          pageNumber: pageNumber,
        );
      },
    );
  }

  static AnnotationSourceItem _annotationItem(StudyPin p) {
    return AnnotationSourceItem(
      id: p.id,
      shortText: p.shortText,
      selectedText: p.selectedText,
      fullNotePlainText: p.fullExplanationPlainText,
      pageNumber: p.pageNumber,
    );
  }

  static Future<QuestionSource> _resolvePdfSource({
    required WidgetRef ref,
    required QuestionSourceType type,
    required String materialId,
    required String filePath,
    String? selectedText,
    int? pageNumber,
    int? currentPage,
    Set<int>? selectedPages,
  }) async {
    final db = ref.read(databaseProvider);
    final material = await db.getMaterialById(materialId);
    final lessonId = material?.lessonId;
    String? subjectId;
    if (lessonId != null) {
      final lesson = await db.getLessonById(lessonId);
      subjectId = lesson?.subjectId;
    }

    switch (type) {
      case QuestionSourceType.selectedText:
        return QuestionSourceBuilder.fromSelectedText(
          text: selectedText ?? '',
          materialId: materialId,
          lessonId: lessonId,
          subjectId: subjectId,
          pageNumber: pageNumber ?? currentPage,
          filePath: filePath,
        );
      case QuestionSourceType.page:
        final page = currentPage ?? pageNumber ?? 1;
        final pages = await PdfTextExtractor.extractPages(
          filePath: filePath,
          pageNumbers: {page},
        );
        return QuestionSourceBuilder.fromPage(
          pageNumber: page,
          pageText: pages.isEmpty ? '' : pages.first.text,
          materialId: materialId,
          lessonId: lessonId,
          subjectId: subjectId,
          filePath: filePath,
        );
      case QuestionSourceType.pages:
        var wanted = <int>{...?selectedPages};
        if (wanted.isEmpty) {
          // Caller should pass a BuildContext-aware picker; fall back to current.
          if (currentPage != null) wanted = {currentPage};
          if (pageNumber != null) wanted = {...wanted, pageNumber};
        }
        final pages = await PdfTextExtractor.extractPages(
          filePath: filePath,
          pageNumbers: wanted.isEmpty ? null : wanted,
        );
        return QuestionSourceBuilder.fromPages(
          pages: pages,
          materialId: materialId,
          lessonId: lessonId,
          subjectId: subjectId,
          filePath: filePath,
        );
      case QuestionSourceType.material:
        final pages = await PdfTextExtractor.extractPages(filePath: filePath);
        return QuestionSourceBuilder.fromMaterial(
          pages: pages,
          materialId: materialId,
          lessonId: lessonId,
          subjectId: subjectId,
          filePath: filePath,
        );
      case QuestionSourceType.annotations:
        final pins = await db.getStudyPinsForResource(materialId);
        return QuestionSourceBuilder.fromAnnotations(
          annotations: [for (final p in pins) _annotationItem(p)],
          materialId: materialId,
          lessonId: lessonId,
          subjectId: subjectId,
        );
      case QuestionSourceType.notes:
        final notes = lessonId == null
            ? const <NoteSourceItem>[]
            : [
                for (final n in await db.getStudyNotesForLesson(lessonId))
                  NoteSourceItem(
                    id: n.id,
                    title: n.title,
                    plainText: n.plainTextContent ?? '',
                  ),
              ];
        return QuestionSourceBuilder.fromNotes(
          notes: notes,
          materialId: materialId,
          lessonId: lessonId,
          subjectId: subjectId,
        );
      case QuestionSourceType.annotationsAndNotes:
        final pins = await db.getStudyPinsForResource(materialId);
        final notes = lessonId == null
            ? const <NoteSourceItem>[]
            : [
                for (final n in await db.getStudyNotesForLesson(lessonId))
                  NoteSourceItem(
                    id: n.id,
                    title: n.title,
                    plainText: n.plainTextContent ?? '',
                  ),
              ];
        return QuestionSourceBuilder.fromAnnotationsAndNotes(
          annotations: [for (final p in pins) _annotationItem(p)],
          notes: notes,
          materialId: materialId,
          lessonId: lessonId,
          subjectId: subjectId,
        );
    }
  }
}
