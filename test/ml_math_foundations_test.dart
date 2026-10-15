import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/classes/services/ml_math_foundations_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('installs the complete ML mathematics class and roadmap', () async {
    final written = <String, String>{};
    final service = MlMathFoundationsService(
      db,
      writeMarkdown:
          ({
            required lessonId,
            required storedFileName,
            required contents,
          }) async {
            written['$lessonId/$storedFileName'] = contents;
          },
      cleanupLessonFiles: (_) async {},
    );

    final classId = await service.create();
    final studyClass = await db.getClassById(classId);
    final subjects = await db.watchSubjectsForClass(classId).first;
    final lessons = await db.select(db.lessons).get();
    final materials = await db.select(db.lessonMaterials).get();
    final roadmap = await db.select(db.classRoadmapEntries).get();

    expect(studyClass?.name, 'Mathematics for Machine Learning');
    expect(
      subjects.map((subject) => subject.name),
      containsAllInOrder([
        'Foundations and Mathematical Language',
        'Linear Algebra',
        'Calculus and Backpropagation',
        'Probability, Statistics, and Information',
        'Optimization and Generalization',
      ]),
    );
    expect(lessons, hasLength(26));
    expect(materials, hasLength(26));
    expect(roadmap, hasLength(26));
    expect(written, hasLength(26));
    expect(
      written.values,
      contains(contains(r'\frac{\partial L}{\partial \mathbf{w}}')),
    );
    expect(
      written.values.every(
        (document) =>
            document.contains('## Machine-learning connection') &&
            document.contains('## Check your understanding'),
      ),
      isTrue,
    );
  });

  test('does not persist partial curriculum when a file write fails', () async {
    var writes = 0;
    final cleaned = <String>[];
    final service = MlMathFoundationsService(
      db,
      writeMarkdown:
          ({
            required lessonId,
            required storedFileName,
            required contents,
          }) async {
            writes++;
            if (writes == 2) throw StateError('disk full');
          },
      cleanupLessonFiles: (lessonId) async => cleaned.add(lessonId),
    );

    await expectLater(service.create(), throwsStateError);

    expect(await db.select(db.classes).get(), isEmpty);
    expect(await db.select(db.subjects).get(), isEmpty);
    expect(await db.select(db.lessons).get(), isEmpty);
    expect(cleaned, hasLength(26));
  });
}
