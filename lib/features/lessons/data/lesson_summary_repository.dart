import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/lesson_summary.dart';
import 'material_mime.dart';

const _aiSummaryType = 'summary';

class LessonSummaryRepository {
  const LessonSummaryRepository(this._db);

  final AppDatabase _db;

  Stream<StudyNote?> watch(String lessonId) =>
      _db.watchStudyNoteById(LessonSummary.noteIdFor(lessonId));

  /// Returns the lesson's summary, creating it on first use from the latest
  /// AI Summary of every document in the lesson.
  Future<StudyNote> ensure(String lessonId) {
    return _db.transaction(() async {
      final id = LessonSummary.noteIdFor(lessonId);
      final existing = await _db.getStudyNoteById(id);
      if (existing != null) return existing;

      String? content;
      for (final document in await _documentsFor(lessonId)) {
        final latest = await _db.listPdfAiMaterials(
          materialId: document.id,
          type: _aiSummaryType,
        );
        if (latest.isEmpty) continue;
        content = LessonSummary.append(
          content,
          latest.first.content,
          heading: document.title,
        );
      }
      final stored =
          content ?? StudyNoteCodec.encode(StudyNoteCodec.decode(null));
      final now = DateTime.now();
      await _db.insertStudyNote(
        StudyNotesCompanion.insert(
          id: id,
          lessonId: Value(lessonId),
          title: LessonSummary.title,
          content: stored,
          plainTextContent: Value(_plain(stored)),
          sortOrder: const Value(-1),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return (await _db.getStudyNoteById(id))!;
    });
  }

  Future<void> appendMarkdown({
    required String lessonId,
    required String markdown,
    String? heading,
  }) {
    return _db.transaction(() async {
      final note = await ensure(lessonId);
      await _write(
        note,
        LessonSummary.append(note.content, markdown, heading: heading),
      );
    });
  }

  /// Called after an AI Summary version is saved for [materialId]. A summary
  /// created here is already seeded with that version, so it is not repeated.
  Future<void> appendAiSummary({
    required String materialId,
    required String markdown,
  }) {
    return _db.transaction(() async {
      final material = await _db.getMaterialById(materialId);
      if (material == null) return;
      final id = LessonSummary.noteIdFor(material.lessonId);
      if (await _db.getStudyNoteById(id) == null) {
        await ensure(material.lessonId);
        return;
      }
      await appendMarkdown(
        lessonId: material.lessonId,
        markdown: markdown,
        heading: material.title,
      );
    });
  }

  Future<void> clear(String lessonId) async {
    final note = await ensure(lessonId);
    await _write(note, StudyNoteCodec.encode(StudyNoteCodec.decode(null)));
  }

  Future<void> _write(StudyNote note, String content) {
    return _db.updateStudyNote(
      note.copyWith(
        content: content,
        plainTextContent: Value(_plain(content)),
        updatedAt: DateTime.now(),
        deletedAt: const Value(null),
      ),
    );
  }

  Future<List<LessonMaterial>> _documentsFor(String lessonId) async {
    final materials =
        await (_db.select(_db.lessonMaterials)
              ..where(
                (t) => t.lessonId.equals(lessonId) & t.variantOfId.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return [
      for (final material in materials)
        if (isDocumentMimeType(material.mimeType)) material,
    ];
  }

  static String? _plain(String stored) {
    final plain = StudyNoteCodec.plainTextPreview(stored);
    return plain.isEmpty ? null : plain;
  }
}

final lessonSummaryRepositoryProvider = Provider<LessonSummaryRepository>(
  (ref) => LessonSummaryRepository(ref.watch(databaseProvider)),
);

final lessonSummaryProvider = StreamProvider.family<StudyNote?, String>(
  (ref, lessonId) => ref.watch(lessonSummaryRepositoryProvider).watch(lessonId),
);
