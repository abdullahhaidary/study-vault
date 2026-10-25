import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/navigation/library_reorder.dart';
import 'package:study_vault/core/widgets/group_section.dart';

void main() {
  test('reorderIds supports each destination', () {
    const ids = ['a', 'b', 'c', 'd'];

    expect(
      reorderIds(ids: ids, itemId: 'c', destination: ReorderDestination.start),
      ['c', 'a', 'b', 'd'],
    );
    expect(
      reorderIds(
        ids: ids,
        itemId: 'c',
        destination: ReorderDestination.previous,
      ),
      ['a', 'c', 'b', 'd'],
    );
    expect(
      reorderIds(ids: ids, itemId: 'b', destination: ReorderDestination.next),
      ['a', 'c', 'b', 'd'],
    );
    expect(
      reorderIds(ids: ids, itemId: 'b', destination: ReorderDestination.end),
      ['a', 'c', 'd', 'b'],
    );
  });

  testWidgets('item menu exposes each available move action', (tester) async {
    var movedToEnd = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupedItemTile(
            title: 'Lesson',
            icon: Icons.book_outlined,
            onTap: () {},
            onMoveToStart: () {},
            onMoveUp: () {},
            onMoveDown: () {},
            onMoveToEnd: () => movedToEnd = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Move to top'), findsOneWidget);
    expect(find.text('Move up'), findsOneWidget);
    expect(find.text('Move down'), findsOneWidget);
    expect(find.text('Move to bottom'), findsOneWidget);

    await tester.tap(find.text('Move to bottom'));
    await tester.pumpAndSettle();
    expect(movedToEnd, isTrue);
  });

  test('class, subject, lesson, group, and material order persists', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026);

    for (final (index, id) in ['c1', 'c2'].indexed) {
      await db.insertClass(
        ClassesCompanion.insert(
          id: id,
          name: id,
          sortOrder: Value(index),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    expect(await db.firstClassSortOrder(), -1);
    await db.reorderClasses(['c2', 'c1']);
    expect((await db.watchAllClasses().first).map((item) => item.id), [
      'c2',
      'c1',
    ]);

    for (final (index, id) in ['sg1', 'sg2'].indexed) {
      await db.insertSubjectGroup(
        SubjectGroupsCompanion.insert(
          id: id,
          classId: 'c1',
          name: id,
          sortOrder: Value(index),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.reorderSubjectGroups(['sg2', 'sg1']);
    expect(
      (await db.watchSubjectGroupsForClass('c1').first).map((item) => item.id),
      ['sg2', 'sg1'],
    );

    for (final (index, id) in ['s1', 's2', 's3'].indexed) {
      await db.insertSubject(
        SubjectsCompanion.insert(
          id: id,
          classId: 'c1',
          name: id,
          sortOrder: Value(index),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.reorderSubjects(['s3', 's1']);
    expect(
      (await db.watchSubjectsForClass('c1').first).map((item) => item.id),
      ['s3', 's2', 's1'],
    );

    for (final (index, id) in ['lg1', 'lg2'].indexed) {
      await db.insertLessonGroup(
        LessonGroupsCompanion.insert(
          id: id,
          subjectId: 's1',
          name: id,
          sortOrder: Value(index),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.reorderLessonGroups(['lg2', 'lg1']);
    expect(
      (await db.watchLessonGroupsForSubject('s1').first).map((item) => item.id),
      ['lg2', 'lg1'],
    );

    for (final (index, id) in ['l1', 'l2', 'l3'].indexed) {
      await db.insertLesson(
        LessonsCompanion.insert(
          id: id,
          subjectId: 's1',
          name: id,
          sortOrder: Value(index),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.reorderLessons(['l3', 'l1']);
    expect(
      (await db.watchLessonsForSubject('s1').first).map((item) => item.id),
      ['l3', 'l2', 'l1'],
    );

    for (final (index, id) in ['m1', 'm2', 'm3'].indexed) {
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: id,
          lessonId: 'l1',
          title: id,
          originalFileName: '$id.pdf',
          storedFileName: '$id.pdf',
          mimeType: Value(id == 'm2' ? 'image/png' : 'application/pdf'),
          sortOrder: Value(index),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.reorderLessonMaterials(['m3', 'm1']);
    expect(
      (await db.watchMaterialsForLesson('l1').first).map((item) => item.id),
      ['m3', 'm2', 'm1'],
    );
  });
}
