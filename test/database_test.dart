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
        createdAt: now,
        updatedAt: now,
      ),
    );

    final subjects = await db.watchSubjectsForClass('class-1').first;
    expect(subjects, hasLength(1));
    expect(subjects.first.name, 'Cell Structure');
    expect(await db.countSubjectsForClass('class-1'), 1);
  });
}
