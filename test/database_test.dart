import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert and watch a class', () async {
    final now = DateTime.now();
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'class-1',
        name: 'Biology 101',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final classes = await db.watchAllClasses().first;
    expect(classes, hasLength(1));
    expect(classes.first.name, 'Biology 101');
  });

  test('can insert a subject under a class', () async {
    final now = DateTime.now();
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'class-1',
        name: 'Biology 101',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 'subject-1',
        classId: 'class-1',
        name: 'Cell Structure',
        sortOrder: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final subjects = await db.watchSubjectsForClass('class-1').first;
    expect(subjects, hasLength(1));
    expect(subjects.first.name, 'Cell Structure');
    expect(subjects.first.subjectGroupId, isNull);
    expect(await db.countSubjectsForClass('class-1'), 1);
  });

  test('subject groups organize subjects without nesting', () async {
    final now = DateTime.now();
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'class-1',
        name: "Master's Semester 1",
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubjectGroup(
      SubjectGroupsCompanion.insert(
        id: 'sg-1',
        classId: 'class-1',
        name: 'Core Subjects',
        sortOrder: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 'subject-1',
        classId: 'class-1',
        subjectGroupId: const Value('sg-1'),
        name: 'Machine Learning',
        sortOrder: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 'subject-2',
        classId: 'class-1',
        name: 'Elective Seminar',
        sortOrder: const Value(1),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final groups = await db.watchSubjectGroupsForClass('class-1').first;
    final subjects = await db.watchSubjectsForClass('class-1').first;

    expect(groups, hasLength(1));
    expect(subjects.where((s) => s.subjectGroupId == 'sg-1'), hasLength(1));
    expect(subjects.where((s) => s.subjectGroupId == null), hasLength(1));
  });

  test('deleting a subject group unassigns subjects', () async {
    final now = DateTime.now();
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'class-1',
        name: 'Class',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubjectGroup(
      SubjectGroupsCompanion.insert(
        id: 'sg-1',
        classId: 'class-1',
        name: 'Core',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 'subject-1',
        classId: 'class-1',
        subjectGroupId: const Value('sg-1'),
        name: 'ML',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.deleteSubjectGroup('sg-1');

    final groups = await db.watchSubjectGroupsForClass('class-1').first;
    final subjects = await db.watchSubjectsForClass('class-1').first;
    expect(groups, isEmpty);
    expect(subjects, hasLength(1));
    expect(subjects.first.subjectGroupId, isNull);
  });

  test('lesson groups organize lessons without deleting on group remove',
      () async {
    final now = DateTime.now();
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'class-1',
        name: 'Class',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 'subject-1',
        classId: 'class-1',
        name: 'ML',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLessonGroup(
      LessonGroupsCompanion.insert(
        id: 'lg-1',
        subjectId: 'subject-1',
        name: 'Unit 1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'lesson-1',
        subjectId: 'subject-1',
        lessonGroupId: const Value('lg-1'),
        name: 'Introduction',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.deleteLessonGroup('lg-1');

    final groups = await db.watchLessonGroupsForSubject('subject-1').first;
    final lessons = await db.watchLessonsForSubject('subject-1').first;
    expect(groups, isEmpty);
    expect(lessons, hasLength(1));
    expect(lessons.first.lessonGroupId, isNull);
  });

  test('lesson materials can be attached to a lesson', () async {
    final now = DateTime.now();
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'class-1',
        name: 'Class',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 'subject-1',
        classId: 'class-1',
        name: 'ML',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'lesson-1',
        subjectId: 'subject-1',
        name: 'Linear Regression',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'mat-1',
        lessonId: 'lesson-1',
        title: 'ML-L4-MSIS.pdf',
        originalFileName: 'ML-L4-MSIS.pdf',
        storedFileName: 'uuid.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final materials = await db.watchMaterialsForLesson('lesson-1').first;
    expect(materials, hasLength(1));
    expect(materials.first.title, 'ML-L4-MSIS.pdf');
  });
}
