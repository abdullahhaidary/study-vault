import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../lessons/data/materials_providers.dart' show materialAbsolutePath;
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';
import '../../pdf_ai_materials/services/pdf_ai_material_service.dart';
import '../data/course_review_repository.dart';
import '../domain/course_review_models.dart';
import '../domain/course_review_prompts.dart';

/// Generates Course Review content one PDF per AI request.
class CourseReviewService {
  CourseReviewService(
    this._db,
    this._client,
    this._pdf, {
    Future<String> Function(LessonMaterial)? resolvePath,
    Uuid? uuid,
  }) : _resolvePath = resolvePath ?? materialAbsolutePath,
       _uuid = uuid ?? const Uuid(),
       repository = CourseReviewRepository(_db);

  final AppDatabase _db;
  final PdfAiCompletionClient _client;
  final PdfAiMaterialService _pdf;
  final Future<String> Function(LessonMaterial) _resolvePath;
  final Uuid _uuid;
  final CourseReviewRepository repository;

  static const sectionMaxOutputTokens = 12000;
  static const overviewMaxOutputTokens = 8192;
  static const _safeCharacters =
      PdfAiMaterialService.singleRequestSafeCharacters;

  /// Saves summary, explanation and deep parts only if all three parsed.
  Future<void> generateSection({
    required CourseReviewSource source,
    required AiExecutionSelection selection,
  }) async {
    final input = await _sectionInput(source, selection);
    final completion = await _client.complete(
      messages: [
        {'role': 'system', 'content': CourseReviewPrompts.system},
        {'role': 'user', 'content': input},
        {
          'role': 'user',
          'content': CourseReviewPrompts.sectionRequest(
            lessonName: source.lesson.name,
            pdfTitle: source.material.title,
          ),
        },
      ],
      maxOutputTokens: sectionMaxOutputTokens,
      selection: selection,
    );
    final parts = CourseReviewPrompts.parse(
      completion.markdown,
      CourseReviewPart.sectionParts,
    );
    await _db.transaction(() async {
      for (final part in CourseReviewPart.sectionParts) {
        await _db.insertCourseReviewVersion(
          id: _uuid.v4(),
          subjectId: source.lesson.subjectId,
          materialId: source.material.id,
          part: part.storageValue,
          content: parts[part]!,
          sourceFingerprint: source.currentFingerprint,
          provider: completion.provider,
          model: completion.model,
        );
      }
    });
  }

  /// Builds the big picture and the course-wide examples from the compact
  /// sections, so input stays small however many lectures exist.
  Future<void> generateOverview({
    required CourseReviewState state,
    required int exampleCount,
    required AiExecutionSelection selection,
  }) async {
    if (state.withSections.isEmpty) {
      throw StateError('Add at least one lecture section first.');
    }
    var document = CourseReviewPrompts.sectionsDocument(state);
    if (document.length > _safeCharacters) {
      document = CourseReviewPrompts.sectionsDocument(
        state,
        summariesOnly: true,
      );
    }
    if (document.length > _safeCharacters) {
      throw StateError(
        'The review is too large for one request. Exclude some PDFs, or '
        'create the examples externally and import them.',
      );
    }
    final completion = await _client.complete(
      messages: [
        {'role': 'system', 'content': CourseReviewPrompts.system},
        {'role': 'user', 'content': document},
        {
          'role': 'user',
          'content': CourseReviewPrompts.overviewRequest(
            subjectName: state.subject.name,
            exampleCount: exampleCount,
          ),
        },
      ],
      maxOutputTokens: overviewMaxOutputTokens,
      selection: selection,
    );
    final parts = CourseReviewPrompts.parse(
      completion.markdown,
      CourseReviewPart.overviewParts,
    );
    await _db.transaction(() async {
      for (final part in CourseReviewPart.overviewParts) {
        await _db.insertCourseReviewVersion(
          id: _uuid.v4(),
          subjectId: state.subject.id,
          materialId: null,
          part: part.storageValue,
          content: parts[part]!,
          sourceFingerprint: state.overviewFingerprint,
          provider: completion.provider,
          model: completion.model,
        );
      }
    });
  }

  Future<void> saveEdit({
    required CourseReviewEntry entry,
    required String content,
  }) {
    return _db.insertCourseReviewVersion(
      id: _uuid.v4(),
      subjectId: entry.subjectId,
      materialId: entry.materialId,
      part: entry.part,
      content: content,
      sourceFingerprint: entry.sourceFingerprint,
      provider: entry.provider,
      model: entry.model,
    );
  }

  Future<void> setExcluded(CourseReviewSource source, bool excluded) {
    return _db.setCourseReviewExcluded(
      id: _uuid.v4(),
      subjectId: source.lesson.subjectId,
      materialId: source.material.id,
      excluded: excluded,
    );
  }

  /// Existing lesson materials first; otherwise the PDF text, digested in
  /// chunks when it is too large for one request.
  Future<String> _sectionInput(
    CourseReviewSource source,
    AiExecutionSelection selection,
  ) async {
    final header =
        'LECTURE: ${source.material.title}\nLESSON: ${source.lesson.name}\n';
    if (source.usesLessonMaterials) {
      return [
        header,
        'SOURCE: the study materials the student already used for this lecture.',
        if (source.lessonSummary != null)
          '\n=== LECTURE SUMMARY ===\n${source.lessonSummary!.content}',
        if (source.lessonExplanation != null)
          '\n=== LECTURE EXPLANATION ===\n${source.lessonExplanation!.content}',
      ].join('\n');
    }
    final document = await _pdf.prepareDocument(
      title: source.material.title,
      filePath: await _resolvePath(source.material),
    );
    if (document.stableDocument.length <= _safeCharacters) {
      return '$header\n${document.stableDocument}';
    }
    final digests = <String>[];
    final chunks = document.chunks(
      maxCharacters: PdfAiMaterialService.chunkCharacters,
    );
    for (var i = 0; i < chunks.length; i++) {
      final completion = await _client.complete(
        messages: PdfAiPromptBuilder.chunkDigestMessages(
          documentChunk: chunks[i],
          chunkNumber: i + 1,
          chunkCount: chunks.length,
        ),
        maxOutputTokens: PdfAiMaterialService.chunkDigestMaxOutputTokens,
        selection: selection,
      );
      digests.add(completion.markdown.trim());
    }
    final synthesis = PdfAiPromptBuilder.synthesisDocument(
      title: document.title,
      chunkDigests: digests,
    );
    if (synthesis.length > _safeCharacters) {
      throw StateError(
        'This PDF is too large. Generate its lesson Summary first, then '
        'create the review section from it.',
      );
    }
    return '$header\n$synthesis';
  }
}
