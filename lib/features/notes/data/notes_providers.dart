import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../study_pins/domain/study_note_codec.dart';

const _uuid = Uuid();

final notesForSubjectProvider = StreamProvider.family<List<StudyNote>, String>((
  ref,
  subjectId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchNotesForSubject(subjectId);
});

final notesForLessonProvider = StreamProvider.family<List<StudyNote>, String>((
  ref,
  lessonId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchNotesForLesson(lessonId);
});

final studyNoteByIdProvider = StreamProvider.family<StudyNote?, String>((
  ref,
  noteId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchStudyNoteById(noteId);
});

Future<StudyNote> createStudyNote(
  WidgetRef ref, {
  String? subjectId,
  String? lessonId,
  required String title,
  String? content,
}) async {
  assert(
    (subjectId != null) ^ (lessonId != null),
    'Exactly one of subjectId or lessonId must be set',
  );
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final id = _uuid.v4();
  final stored = content ?? StudyNoteCodec.encode(StudyNoteCodec.decode(null));
  final plain = StudyNoteCodec.plainTextPreview(stored);
  final sortOrder = await db.nextNoteSortOrder(
    subjectId: subjectId,
    lessonId: lessonId,
  );

  await db.insertStudyNote(
    StudyNotesCompanion.insert(
      id: id,
      subjectId: Value(subjectId),
      lessonId: Value(lessonId),
      title: title.trim(),
      content: stored,
      plainTextContent: Value(plain.isEmpty ? null : plain),
      sortOrder: Value(sortOrder),
      createdAt: now,
      updatedAt: now,
    ),
  );

  final note = await db.getStudyNoteById(id);
  return note!;
}

Future<void> updateStudyNoteContent(
  WidgetRef ref, {
  required StudyNote note,
  required String title,
  required String content,
}) async {
  final db = ref.read(databaseProvider);
  final plain = StudyNoteCodec.plainTextPreview(content);
  await db.updateStudyNote(
    note.copyWith(
      title: title.trim(),
      content: content,
      plainTextContent: Value(plain.isEmpty ? null : plain),
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> deleteStudyNote(WidgetRef ref, {required String noteId}) async {
  final db = ref.read(databaseProvider);
  await db.deleteStudyNote(noteId);
}
