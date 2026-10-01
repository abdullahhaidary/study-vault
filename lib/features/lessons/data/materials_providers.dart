import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/storage/material_storage.dart';

const _uuid = Uuid();

final materialsForLessonProvider =
    StreamProvider.family<List<LessonMaterial>, String>((ref, lessonId) {
  final db = ref.watch(databaseProvider);
  return db.watchMaterialsForLesson(lessonId);
});

final materialByIdProvider =
    FutureProvider.family<LessonMaterial?, String>((ref, materialId) async {
  final db = ref.watch(databaseProvider);
  return db.getMaterialById(materialId);
});

/// Picks a local PDF, copies it into app storage, and records metadata.
Future<LessonMaterial?> attachPdfToLesson(
  WidgetRef ref, {
  required String lessonId,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    withData: false,
  );

  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.single;
  final sourcePath = picked.path;
  if (sourcePath == null) {
    throw StateError('Could not read the selected file path.');
  }

  final originalName = picked.name;
  final storedFileName = '${_uuid.v4()}.pdf';
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final sortOrder = await db.nextMaterialSortOrder(lessonId);
  final id = _uuid.v4();

  await MaterialStorage.importPdf(
    lessonId: lessonId,
    sourcePath: sourcePath,
    storedFileName: storedFileName,
  );

  final companion = LessonMaterialsCompanion.insert(
    id: id,
    lessonId: lessonId,
    title: originalName,
    originalFileName: originalName,
    storedFileName: storedFileName,
    sortOrder: Value(sortOrder),
    createdAt: now,
    updatedAt: now,
  );

  await db.insertLessonMaterial(companion);
  return db.getMaterialById(id);
}

Future<void> deleteLessonMaterial(
  WidgetRef ref, {
  required LessonMaterial material,
}) async {
  final db = ref.read(databaseProvider);
  await MaterialStorage.deleteFile(
    lessonId: material.lessonId,
    storedFileName: material.storedFileName,
  );
  await db.deleteLessonMaterial(material.id);
}

Future<String> materialAbsolutePath(LessonMaterial material) {
  return MaterialStorage.absolutePath(
    lessonId: material.lessonId,
    storedFileName: material.storedFileName,
  );
}
