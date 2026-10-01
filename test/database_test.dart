import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  Future<void> seedMaterial() async {
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
        title: 'notes.pdf',
        originalFileName: 'notes.pdf',
        storedFileName: 'uuid.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

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

  test(
    'lesson groups organize lessons without deleting on group remove',
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
    },
  );

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

  test(
    'point study pins persist normalized coordinates on a resource',
    () async {
      await seedMaterial();
      final now = DateTime.now();

      await db.insertStudyPin(
        StudyPinsCompanion.insert(
          id: 'pin-1',
          resourceId: 'mat-1',
          pinType: const Value('point'),
          pageNumber: const Value(2),
          xRatio: 0.42,
          yRatio: 0.33,
          shortText: 'Controls gradient step size',
          fullExplanation: const Value('Learning rate scales each update.'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final pins = await db.watchStudyPinsForResource('mat-1').first;
      expect(pins, hasLength(1));
      expect(pins.first.pinType, 'point');
      expect(pins.first.pageNumber, 2);
      expect(pins.first.xRatio, closeTo(0.42, 0.0001));
      expect(pins.first.yRatio, closeTo(0.33, 0.0001));
      expect(pins.first.shortText, 'Controls gradient step size');

      await db.deleteLessonMaterial('mat-1');
      final afterDelete = await db.watchStudyPinsForResource('mat-1').first;
      expect(afterDelete, isEmpty);
    },
  );

  test('text study pins store multiple range rectangles atomically', () async {
    await seedMaterial();
    final now = DateTime.now();

    await db.insertTextStudyPin(
      pin: StudyPinsCompanion.insert(
        id: 'text-pin-1',
        resourceId: 'mat-1',
        pinType: const Value('text'),
        pageNumber: const Value(1),
        xRatio: 0.2,
        yRatio: 0.3,
        shortText: 'Key definition',
        fullExplanation: const Value('Longer note about the selection.'),
        selectedText: const Value('supervised learning'),
        createdAt: now,
        updatedAt: now,
      ),
      ranges: [
        StudyPinTextRangesCompanion.insert(
          id: 'range-1',
          studyPinId: 'text-pin-1',
          pageNumber: 1,
          xRatio: 0.10,
          yRatio: 0.20,
          widthRatio: 0.40,
          heightRatio: 0.03,
          sortOrder: const Value(0),
        ),
        StudyPinTextRangesCompanion.insert(
          id: 'range-2',
          studyPinId: 'text-pin-1',
          pageNumber: 1,
          xRatio: 0.10,
          yRatio: 0.24,
          widthRatio: 0.25,
          heightRatio: 0.03,
          sortOrder: const Value(1),
        ),
      ],
    );

    final pins = await db.watchStudyPinsForResource('mat-1').first;
    expect(pins, hasLength(1));
    expect(pins.first.pinType, 'text');
    expect(pins.first.selectedText, 'supervised learning');

    final ranges = await db.getTextRangesForPin('text-pin-1');
    expect(ranges, hasLength(2));
    expect(ranges.first.widthRatio, closeTo(0.40, 0.0001));
    expect(ranges.last.yRatio, closeTo(0.24, 0.0001));

    final watched = await db.watchTextRangesForResource('mat-1').first;
    expect(watched, hasLength(2));
  });

  test('deleting a text pin removes its ranges', () async {
    await seedMaterial();
    final now = DateTime.now();

    await db.insertTextStudyPin(
      pin: StudyPinsCompanion.insert(
        id: 'text-pin-1',
        resourceId: 'mat-1',
        pinType: const Value('text'),
        pageNumber: const Value(1),
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Note',
        selectedText: const Value('hello'),
        createdAt: now,
        updatedAt: now,
      ),
      ranges: [
        StudyPinTextRangesCompanion.insert(
          id: 'range-1',
          studyPinId: 'text-pin-1',
          pageNumber: 1,
          xRatio: 0.1,
          yRatio: 0.1,
          widthRatio: 0.2,
          heightRatio: 0.02,
        ),
      ],
    );

    await db.deleteStudyPin('text-pin-1');

    expect(await db.getStudyPinById('text-pin-1'), isNull);
    expect(await db.getTextRangesForPin('text-pin-1'), isEmpty);
  });

  test('updating study pin texts keeps type and ranges', () async {
    await seedMaterial();
    final now = DateTime.now();

    await db.insertTextStudyPin(
      pin: StudyPinsCompanion.insert(
        id: 'text-pin-1',
        resourceId: 'mat-1',
        pinType: const Value('text'),
        pageNumber: const Value(1),
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Old',
        selectedText: const Value('source'),
        createdAt: now,
        updatedAt: now,
      ),
      ranges: [
        StudyPinTextRangesCompanion.insert(
          id: 'range-1',
          studyPinId: 'text-pin-1',
          pageNumber: 1,
          xRatio: 0.1,
          yRatio: 0.1,
          widthRatio: 0.2,
          heightRatio: 0.02,
        ),
      ],
    );

    final pin = await db.getStudyPinById('text-pin-1');
    expect(pin, isNotNull);

    await db.updateStudyPin(
      pin!.copyWith(
        shortText: 'New title',
        fullExplanation: const Value('Updated explanation'),
        updatedAt: DateTime.now(),
      ),
    );

    final updated = await db.getStudyPinById('text-pin-1');
    expect(updated!.shortText, 'New title');
    expect(updated.fullExplanation, 'Updated explanation');
    expect(updated.pinType, 'text');
    expect(updated.selectedText, 'source');
    expect(await db.getTextRangesForPin('text-pin-1'), hasLength(1));
  });

  test('deleting a material cascades pins and text ranges', () async {
    await seedMaterial();
    final now = DateTime.now();

    await db.insertTextStudyPin(
      pin: StudyPinsCompanion.insert(
        id: 'text-pin-1',
        resourceId: 'mat-1',
        pinType: const Value('text'),
        pageNumber: const Value(1),
        xRatio: 0.1,
        yRatio: 0.1,
        shortText: 'Note',
        selectedText: const Value('hello'),
        createdAt: now,
        updatedAt: now,
      ),
      ranges: [
        StudyPinTextRangesCompanion.insert(
          id: 'range-1',
          studyPinId: 'text-pin-1',
          pageNumber: 1,
          xRatio: 0.1,
          yRatio: 0.1,
          widthRatio: 0.2,
          heightRatio: 0.02,
        ),
      ],
    );

    await db.deleteLessonMaterial('mat-1');
    expect(await db.getTextRangesForPin('text-pin-1'), isEmpty);
    expect(await db.watchStudyPinsForResource('mat-1').first, isEmpty);
  });
}
