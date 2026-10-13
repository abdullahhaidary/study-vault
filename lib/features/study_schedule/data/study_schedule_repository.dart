import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../lessons/data/material_mime.dart';
import '../../lessons/domain/lesson_progress.dart';
import '../../study_review/domain/review_models.dart';
import '../domain/review_scheduler.dart';
import '../domain/schedule_day.dart';
import '../domain/schedule_models.dart';

const _uuid = Uuid();

/// A lesson summary shown after the blank-page recall step.
typedef LessonSummary = ({String title, String markdown});

/// Reads and writes the Study Schedule.
class StudyScheduleRepository {
  StudyScheduleRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  DateTime get _today => ScheduleDay.of(_clock());

  static const _latestEvent =
      'SELECT id FROM study_schedule_events x WHERE x.lesson_id = s.lesson_id '
      'ORDER BY x.sequence_number DESC, x.created_at DESC, x.id DESC LIMIT 1';

  Selectable<QueryRow> _entriesQuery() => _db.customSelect(
    'SELECT s.lesson_id, s.paused, l.name AS lesson_name, l.subject_id, '
    'sub.name AS subject_name, sub.exam_date, e.due_on, e.event_on, '
    '(SELECT x.event_on FROM study_schedule_events x '
    "WHERE x.lesson_id = s.lesson_id AND x.kind != 'reschedule' "
    'ORDER BY x.sequence_number DESC, x.created_at DESC, x.id DESC LIMIT 1) '
    'AS studied_on, '
    '(SELECT COUNT(*) FROM study_schedule_events x '
    "WHERE x.lesson_id = s.lesson_id AND x.kind = 'review') AS review_count "
    'FROM study_schedules s '
    'JOIN lessons l ON l.id = s.lesson_id '
    'JOIN subjects sub ON sub.id = l.subject_id '
    'LEFT JOIN study_schedule_events e ON e.id = ($_latestEvent)',
    readsFrom: {
      _db.studySchedules,
      _db.studyScheduleEvents,
      _db.lessons,
      _db.subjects,
    },
  );

  List<ScheduleEntry> _map(List<QueryRow> rows) {
    final today = _today;
    return [
      for (final row in rows)
        () {
          final due = ScheduleDay.tryParse(row.readNullable<String>('due_on'));
          final studied =
              ScheduleDay.tryParse(row.readNullable<String>('studied_on')) ??
              ScheduleDay.tryParse(row.readNullable<String>('event_on')) ??
              today;
          final dueOn = due ?? today;
          return ScheduleEntry(
            lessonId: row.read<String>('lesson_id'),
            lessonName: row.read<String>('lesson_name'),
            subjectId: row.read<String>('subject_id'),
            subjectName: row.read<String>('subject_name'),
            examOn: ScheduleDay.tryParse(row.readNullable<String>('exam_date')),
            paused: row.read<bool>('paused'),
            dueOn: dueOn,
            intervalDays: max(1, ScheduleDay.between(studied, dueOn)),
            lastOn: studied,
            reviewCount: row.read<int>('review_count'),
          );
        }(),
    ];
  }

  Stream<List<ScheduleEntry>> watchEntries() =>
      _entriesQuery().watch().map(_map);

  Future<List<ScheduleEntry>> entries() async => _map(await _entriesQuery().get());

  Future<ScheduleEntry?> entryFor(String lessonId) async {
    for (final entry in await entries()) {
      if (entry.lessonId == lessonId) return entry;
    }
    return null;
  }

  /// Adds a lesson; returns false when it is already scheduled.
  Future<bool> enroll(String lessonId, {bool mastered = false}) {
    return _db.transaction(() async {
      if (await _scheduleRow(lessonId) != null) return false;
      final decision = ReviewScheduler.start(
        today: _today,
        mastered: mastered,
        examOn: await _examFor(lessonId),
      );
      await _insertSchedule(lessonId, decision);
      return true;
    });
  }

  /// Lessons marked Reviewed or Mastered that are not scheduled yet.
  Future<List<Lesson>> unscheduledReviewedLessons() {
    return (_db.select(_db.lessons)
          ..where(
            (t) =>
                t.progressStatus.isIn([
                  LessonProgressStatus.storageReviewed,
                  LessonProgressStatus.storageMastered,
                ]) &
                t.id.isNotInQuery(
                  _db.selectOnly(_db.studySchedules)
                    ..addColumns([_db.studySchedules.lessonId]),
                ),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Schedules [lessons], spreading first reviews by [dailyLimit] per day.
  Future<int> enrollMany(List<Lesson> lessons, {required int dailyLimit}) {
    return _db.transaction(() async {
      var added = 0;
      final perDay = max(1, dailyLimit);
      for (final lesson in lessons) {
        if (await _scheduleRow(lesson.id) != null) continue;
        final exam = await _examFor(lesson.id);
        final first = ReviewScheduler.start(
          today: _today,
          mastered:
              lesson.progressStatus == LessonProgressStatus.storageMastered,
          examOn: exam,
        );
        var due = ScheduleDay.add(first.dueOn, added ~/ perDay);
        if (exam != null && !due.isBefore(exam) && first.dueOn.isBefore(exam)) {
          due = first.dueOn;
        }
        await _insertSchedule(lesson.id, (
          dueOn: due,
          intervalDays: ScheduleDay.between(_today, due),
        ));
        added++;
      }
      return added;
    });
  }

  /// Days until the next review for each rating (no load spreading).
  Future<Map<ReviewRating, ScheduleDecision>> previews(String lessonId) async {
    final entry = await entryFor(lessonId);
    if (entry == null) return const {};
    return {
      for (final rating in ReviewRating.values)
        rating: _decide(entry, rating),
    };
  }

  ScheduleDecision _decide(
    ScheduleEntry entry,
    ReviewRating rating, {
    DueCount? dueCount,
    int dailyLimit = 0,
  }) => ReviewScheduler.review(
    today: _today,
    lastOn: entry.lastOn,
    dueOn: entry.dueOn,
    intervalDays: entry.intervalDays,
    rating: rating,
    examOn: entry.examOn,
    dueCount: dueCount,
    dailyLimit: dailyLimit,
  );

  /// Records a review, schedules the next one and updates lesson progress.
  Future<ScheduleDecision> recordReview(
    String lessonId, {
    required ReviewRating rating,
    String? recallText,
    int dailyLimit = 0,
  }) {
    return _db.transaction(() async {
      final all = await entries();
      final entry = all.where((e) => e.lessonId == lessonId).firstOrNull;
      if (entry == null) {
        throw StateError('This lesson is not in the Study Schedule.');
      }
      final load = <DateTime, int>{};
      for (final other in all) {
        if (other.paused || other.lessonId == lessonId) continue;
        load[other.dueOn] = (load[other.dueOn] ?? 0) + 1;
      }
      final decision = _decide(
        entry,
        rating,
        dueCount: (day) => load[day] ?? 0,
        dailyLimit: dailyLimit,
      );
      final recall = recallText?.trim();
      await _addEvent(
        lessonId,
        kind: ScheduleEventKind.review,
        decision: decision,
        rating: rating,
        recallText: recall == null || recall.isEmpty ? null : recall,
      );
      await _syncLessonStatus(lessonId, rating, decision.intervalDays);
      return decision;
    });
  }

  /// The schedule owns Reviewed/Mastered: long successful gaps promote a
  /// lesson, forgetting it demotes it.
  Future<void> _syncLessonStatus(
    String lessonId,
    ReviewRating rating,
    int interval,
  ) async {
    final lesson = await _db.getLessonById(lessonId);
    if (lesson == null) return;
    final success =
        rating == ReviewRating.good || rating == ReviewRating.easy;
    final keepMastered =
        rating != ReviewRating.again &&
        lesson.progressStatus == LessonProgressStatus.storageMastered;
    final next =
        (success && interval >= ReviewScheduler.masteredIntervalDays) ||
            keepMastered
        ? LessonProgressStatus.storageMastered
        : LessonProgressStatus.storageReviewed;
    await _db.updateLessonProgress(
      lessonId: lessonId,
      progressStatus: next,
      touchLastStudied: true,
    );
  }

  Future<void> reschedule(String lessonId, DateTime day) async {
    final today = _today;
    final due = day.isBefore(today) ? today : ScheduleDay.of(day);
    await _db.transaction(() async {
      if (await _scheduleRow(lessonId) == null) return;
      await _addEvent(
        lessonId,
        kind: ScheduleEventKind.reschedule,
        decision: (dueOn: due, intervalDays: ScheduleDay.between(today, due)),
      );
    });
  }

  Future<void> setPaused(String lessonId, bool paused) {
    return (_db.update(
      _db.studySchedules,
    )..where((t) => t.lessonId.equals(lessonId))).write(
      StudySchedulesCompanion(
        paused: Value(paused),
        updatedAt: Value(_clock()),
      ),
    );
  }

  /// Removes the lesson from the list; its review history is kept.
  Future<void> remove(String lessonId) {
    return (_db.delete(
      _db.studySchedules,
    )..where((t) => t.lessonId.equals(lessonId))).go();
  }

  Future<void> setExamDate(String subjectId, DateTime? day) {
    return (_db.update(
      _db.subjects,
    )..where((t) => t.id.equals(subjectId))).write(
      SubjectsCompanion(
        examDate: Value(day == null ? null : ScheduleDay.format(day)),
        updatedAt: Value(_clock()),
      ),
    );
  }

  /// Latest AI or Course Review summary for each document in the lesson.
  Future<List<LessonSummary>> lessonSummaries(String lessonId) async {
    final materials =
        await (_db.select(_db.lessonMaterials)
              ..where((t) => t.lessonId.equals(lessonId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get();
    final result = <LessonSummary>[];
    for (final material in materials) {
      if (!isDocumentMimeType(material.mimeType)) continue;
      final ai =
          await (_db.select(_db.pdfAiMaterials)
                ..where(
                  (t) =>
                      t.materialId.equals(material.id) &
                      t.type.equals('summary'),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.version)])
                ..limit(1))
              .getSingleOrNull();
      final content =
          ai?.content ??
          (await (_db.select(_db.courseReviewEntries)
                    ..where(
                      (t) =>
                          t.materialId.equals(material.id) &
                          t.part.equals('summary'),
                    )
                    ..orderBy([(t) => OrderingTerm.desc(t.version)])
                    ..limit(1))
                  .getSingleOrNull())
              ?.content;
      if (content != null && content.trim().isNotEmpty) {
        result.add((title: material.title, markdown: content));
      }
    }
    return result;
  }

  Future<StudySchedule?> _scheduleRow(String lessonId) =>
      (_db.select(
        _db.studySchedules,
      )..where((t) => t.lessonId.equals(lessonId))).getSingleOrNull();

  Future<void> _insertSchedule(String lessonId, ScheduleDecision first) async {
    final now = _clock();
    await _db
        .into(_db.studySchedules)
        .insert(
          StudySchedulesCompanion.insert(
            id: _uuid.v4(),
            lessonId: lessonId,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _addEvent(
      lessonId,
      kind: ScheduleEventKind.start,
      decision: first,
    );
  }

  Future<DateTime?> _examFor(String lessonId) async {
    final row = await _db
        .customSelect(
          'SELECT sub.exam_date FROM lessons l '
          'JOIN subjects sub ON sub.id = l.subject_id WHERE l.id = ?',
          variables: [Variable.withString(lessonId)],
        )
        .getSingleOrNull();
    return ScheduleDay.tryParse(row?.readNullable<String>('exam_date'));
  }

  Future<void> _addEvent(
    String lessonId, {
    required String kind,
    required ScheduleDecision decision,
    ReviewRating? rating,
    String? recallText,
  }) async {
    final last = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sequence_number), 0) AS n '
          'FROM study_schedule_events WHERE lesson_id = ?',
          variables: [Variable.withString(lessonId)],
        )
        .getSingle();
    await _db
        .into(_db.studyScheduleEvents)
        .insert(
          StudyScheduleEventsCompanion.insert(
            id: _uuid.v4(),
            lessonId: lessonId,
            kind: kind,
            rating: Value(rating?.storageValue),
            recallText: Value(recallText),
            eventOn: ScheduleDay.format(_today),
            dueOn: ScheduleDay.format(decision.dueOn),
            intervalDays: decision.intervalDays,
            sequenceNumber: last.read<int>('n') + 1,
            createdAt: _clock(),
          ),
        );
  }
}
