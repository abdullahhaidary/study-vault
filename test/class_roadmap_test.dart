import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/class_roadmap/data/class_roadmap_repository.dart';

void main() {
  late AppDatabase db;
  late ClassRoadmapRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ClassRoadmapRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seed() async {
    final t = DateTime(2026, 3, 1);
    await db.insertClass(
      ClassesCompanion.insert(id: 'c1', name: 'Banking', createdAt: t, updatedAt: t),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's1',
        classId: 'c1',
        name: 'Credit',
        createdAt: t,
        updatedAt: t,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's2',
        classId: 'c1',
        name: 'Risk',
        createdAt: t,
        updatedAt: t,
      ),
    );
    for (final entry in [
      ('l1', 's1', 'Intro'),
      ('l2', 's1', 'Loans'),
      ('l3', 's2', 'VaR'),
    ]) {
      await db.insertLesson(
        LessonsCompanion.insert(
          id: entry.$1,
          subjectId: entry.$2,
          name: entry.$3,
          createdAt: t,
          updatedAt: t,
        ),
      );
    }
  }

  test('adds lessons once, in order, and skips duplicates', () async {
    await seed();

    expect(await repo.addLesson('c1', 'l2'), isTrue);
    expect(await repo.addLesson('c1', 'l1'), isTrue);
    expect(await repo.addLesson('c1', 'l2'), isFalse);

    final steps = await repo.steps('c1');
    expect(steps.map((s) => s.lessonId), ['l2', 'l1']);
    expect(steps.map((s) => s.lessonName), ['Loans', 'Intro']);
    expect(steps.map((s) => s.subjectName), ['Credit', 'Credit']);
  });

  test('available lessons exclude those already on the roadmap', () async {
    await seed();
    await repo.addLesson('c1', 'l1');

    final available = await repo.availableLessons('c1');
    expect(available.map((c) => c.lessonId).toSet(), {'l2', 'l3'});
  });

  test('move up/down and remove reorder the syllabus', () async {
    await seed();
    await repo.addLessons('c1', ['l1', 'l2', 'l3']);

    var steps = await repo.steps('c1');
    await repo.moveDown('c1', steps[0].id);
    steps = await repo.steps('c1');
    expect(steps.map((s) => s.lessonId), ['l2', 'l1', 'l3']);

    await repo.moveUp('c1', steps[2].id);
    steps = await repo.steps('c1');
    expect(steps.map((s) => s.lessonId), ['l2', 'l3', 'l1']);

    await repo.removeEntry(steps[1].id);
    steps = await repo.steps('c1');
    expect(steps.map((s) => s.lessonId), ['l2', 'l1']);
  });

  test('current step skips reviewed/mastered lessons', () async {
    await seed();
    await repo.addLessons('c1', ['l1', 'l2', 'l3']);
    await db.updateLessonProgress(lessonId: 'l1', progressStatus: 'reviewed');

    final steps = await repo.steps('c1');
    expect(repo.currentStep(steps)?.lessonId, 'l2');

    await db.updateLessonProgress(lessonId: 'l2', progressStatus: 'mastered');
    await db.updateLessonProgress(lessonId: 'l3', progressStatus: 'reviewed');
    expect(repo.currentStep(await repo.steps('c1')), isNull);
  });

  test('deleting a lesson removes its roadmap entry', () async {
    await seed();
    await repo.addLessons('c1', ['l1', 'l2']);
    await db.deleteLesson('l1');
    expect((await repo.steps('c1')).map((s) => s.lessonId), ['l2']);
  });
}
