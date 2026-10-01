import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
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

bool isImageMimeType(String mimeType) {
  return mimeType.startsWith('image/');
}

bool isPdfMimeType(String mimeType) {
  return mimeType == 'application/pdf';
}

String guessMimeType(String fileName) {
  final ext = p.extension(fileName).toLowerCase();
  return switch (ext) {
    '.pdf' => 'application/pdf',
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.bmp' => 'image/bmp',
    _ => 'application/octet-stream',
  };
}

/// Picks a local PDF, copies it into app storage, and records metadata.
Future<LessonMaterial?> attachPdfToLesson(
  WidgetRef ref, {
  required String lessonId,
}) {
  return _attachFileToLesson(
    ref,
    lessonId: lessonId,
    dialogTitle: 'Attach PDF',
    allowedExtensions: const ['pdf'],
  );
}

/// Picks a local image, copies it into app storage, and records metadata.
Future<LessonMaterial?> attachImageToLesson(
  WidgetRef ref, {
  required String lessonId,
}) {
  return _attachFileToLesson(
    ref,
    lessonId: lessonId,
    dialogTitle: 'Attach image',
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
  );
}

Future<LessonMaterial?> _attachFileToLesson(
  WidgetRef ref, {
  required String lessonId,
  required String dialogTitle,
  required List<String> allowedExtensions,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    withData: false,
    dialogTitle: dialogTitle,
  );

  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.single;
  final sourcePath = picked.path;
  if (sourcePath == null) {
    throw StateError('Could not read the selected file path.');
  }

  final originalName = picked.name;
  final ext = p.extension(originalName).toLowerCase();
  final storedFileName = '${_uuid.v4()}$ext';
  final mimeType = guessMimeType(originalName);
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final sortOrder = await db.nextMaterialSortOrder(lessonId);
  final id = _uuid.v4();

  await MaterialStorage.importFile(
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
    mimeType: Value(mimeType),
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
