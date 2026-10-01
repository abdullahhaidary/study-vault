import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/database/database_provider.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/domain/study_note_codec.dart';

const _uuid = Uuid();

final flashcardsForLessonProvider =
    StreamProvider.family<List<Flashcard>, String>((ref, lessonId) {
      final db = ref.watch(databaseProvider);
      return db.watchFlashcardsForLesson(lessonId);
    });

final flashcardsForSubjectProvider =
    StreamProvider.family<List<Flashcard>, String>((ref, subjectId) {
      final db = ref.watch(databaseProvider);
      return db.watchFlashcardsForSubject(subjectId);
    });

final allFlashcardsProvider = StreamProvider<List<Flashcard>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllFlashcards();
});

final flashcardByIdProvider = StreamProvider.family<Flashcard?, String>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return db.watchFlashcardById(id);
});

final flashcardBySourcePinProvider = StreamProvider.family<Flashcard?, String>((
  ref,
  pinId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchFlashcardBySourcePinId(pinId);
});

final flashcardCountForLessonProvider = FutureProvider.family<int, String>((
  ref,
  lessonId,
) async {
  final db = ref.watch(databaseProvider);
  return db.countFlashcardsForLesson(lessonId);
});

/// Default front/back mapping when converting a Study Pin.
({String front, String back}) defaultsFromStudyPin(StudyPin pin) {
  final isQuestion = pin.categoryId == BuiltInPinCategories.question;
  final full = pin.fullExplanation ?? '';
  final back = StudyNoteCodec.hasContent(full)
      ? full
      : StudyNoteCodec.encode(StudyNoteCodec.decode(null));

  if (isQuestion) {
    return (front: pin.shortText.trim(), back: back);
  }

  if (pin.type == StudyPinType.text) {
    final selected = pin.selectedText?.trim() ?? '';
    final front = selected.isNotEmpty ? selected : pin.shortText.trim();
    return (front: front, back: back);
  }

  return (front: pin.shortText.trim(), back: back);
}

Future<Flashcard> createFlashcardFromPin(
  WidgetRef ref, {
  required StudyPin pin,
  required String front,
  required String back,
}) async {
  final db = ref.read(databaseProvider);
  final existing = await db.getFlashcardBySourcePinId(pin.id);
  if (existing != null) {
    throw StateError('A flashcard already exists for this Study Pin');
  }

  final material = await db.getMaterialById(pin.resourceId);
  if (material == null) {
    throw StateError('Material not found for Study Pin');
  }
  final lesson = await db.getLessonById(material.lessonId);
  if (lesson == null) {
    throw StateError('Lesson not found for Study Pin');
  }

  final now = DateTime.now();
  final id = _uuid.v4();
  final plain = StudyNoteCodec.plainTextPreview(back);

  await db.insertFlashcard(
    FlashcardsCompanion.insert(
      id: id,
      subjectId: Value(lesson.subjectId),
      lessonId: Value(lesson.id),
      sourceStudyPinId: Value(pin.id),
      front: front.trim(),
      back: back,
      backPlainText: Value(plain.isEmpty ? null : plain),
      createdAt: now,
      updatedAt: now,
    ),
  );

  return (await db.getFlashcardById(id))!;
}

Future<Flashcard> createFlashcard(
  WidgetRef ref, {
  String? subjectId,
  String? lessonId,
  required String front,
  required String back,
}) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final id = _uuid.v4();
  final plain = StudyNoteCodec.plainTextPreview(back);

  String? resolvedSubject = subjectId;
  if (resolvedSubject == null && lessonId != null) {
    final lesson = await db.getLessonById(lessonId);
    resolvedSubject = lesson?.subjectId;
  }

  await db.insertFlashcard(
    FlashcardsCompanion.insert(
      id: id,
      subjectId: Value(resolvedSubject),
      lessonId: Value(lessonId),
      front: front.trim(),
      back: back,
      backPlainText: Value(plain.isEmpty ? null : plain),
      createdAt: now,
      updatedAt: now,
    ),
  );

  return (await db.getFlashcardById(id))!;
}

Future<void> updateFlashcardContent(
  WidgetRef ref, {
  required Flashcard card,
  required String front,
  required String back,
}) async {
  final db = ref.read(databaseProvider);
  final plain = StudyNoteCodec.plainTextPreview(back);
  await db.updateFlashcard(
    card.copyWith(
      front: front.trim(),
      back: back,
      backPlainText: Value(plain.isEmpty ? null : plain),
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> deleteFlashcard(WidgetRef ref, {required String id}) async {
  final db = ref.read(databaseProvider);
  await db.deleteFlashcard(id);
}
