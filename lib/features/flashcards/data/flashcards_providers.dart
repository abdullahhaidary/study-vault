import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/domain/ai_models.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_schedule/domain/review_scheduler.dart';
import '../../study_schedule/domain/schedule_day.dart';

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

final flashcardReviewEventsProvider =
    StreamProvider<List<FlashcardReviewEvent>>((ref) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.flashcardReviewEvents)..orderBy([
            (t) => OrderingTerm.desc(t.sequenceNumber),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
          .watch();
    });

final flashcardReviewRepositoryProvider = Provider<FlashcardReviewRepository>(
  (ref) => FlashcardReviewRepository(ref.watch(databaseProvider)),
);

class FlashcardReviewRepository {
  FlashcardReviewRepository(this._db);

  final AppDatabase _db;

  Future<void> rate(String cardId, ReviewRating rating, {DateTime? now}) async {
    final time = now ?? DateTime.now();
    final today = ScheduleDay.of(time);
    await _db.transaction(() async {
      final card = await _db.getFlashcardById(cardId);
      if (card == null || card.deletedAt != null) {
        throw StateError('Flashcard not found.');
      }
      final previous =
          await (_db.select(_db.flashcardReviewEvents)
                ..where((t) => t.flashcardId.equals(cardId))
                ..orderBy([
                  (t) => OrderingTerm.desc(t.sequenceNumber),
                  (t) => OrderingTerm.desc(t.createdAt),
                  (t) => OrderingTerm.desc(t.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      final decision = previous == null
          ? ReviewScheduler.review(
              today: today,
              lastOn: ScheduleDay.add(today, -1),
              dueOn: today,
              intervalDays: 1,
              rating: rating,
            )
          : ReviewScheduler.review(
              today: today,
              lastOn: ScheduleDay.parse(previous.reviewedOn),
              dueOn: ScheduleDay.parse(previous.dueOn),
              intervalDays: previous.intervalDays,
              rating: rating,
            );
      await _db
          .into(_db.flashcardReviewEvents)
          .insert(
            FlashcardReviewEventsCompanion.insert(
              id: _uuid.v4(),
              flashcardId: cardId,
              rating: rating.storageValue,
              reviewedOn: ScheduleDay.format(today),
              dueOn: ScheduleDay.format(decision.dueOn),
              intervalDays: decision.intervalDays,
              sequenceNumber: (previous?.sequenceNumber ?? 0) + 1,
              createdAt: time,
            ),
          );
    });
  }
}

Map<String, FlashcardReviewEvent> latestFlashcardReviews(
  List<FlashcardReviewEvent> events,
) {
  final sorted = [...events]
    ..sort((a, b) {
      final sequence = b.sequenceNumber.compareTo(a.sequenceNumber);
      if (sequence != 0) return sequence;
      final created = b.createdAt.compareTo(a.createdAt);
      return created != 0 ? created : b.id.compareTo(a.id);
    });
  return {for (final event in sorted.reversed) event.flashcardId: event};
}

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

Future<void> createAiFlashcards(
  WidgetRef ref, {
  required List<AiFlashcardDraft> cards,
  String? subjectId,
  String? lessonId,
}) async {
  if (cards.isEmpty) return;
  final db = ref.read(databaseProvider);
  await db.transaction(() async {
    for (final card in cards) {
      if (card.front.trim().isEmpty || card.back.trim().isEmpty) {
        throw ArgumentError('Flashcards need a front and back.');
      }
      await createFlashcard(
        ref,
        subjectId: subjectId,
        lessonId: lessonId,
        front: card.front,
        back: MarkdownToQuill.toDeltaJson(card.back),
      );
    }
  });
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
