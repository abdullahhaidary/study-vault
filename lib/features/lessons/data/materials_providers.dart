import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/storage/material_storage.dart';
import 'material_mime.dart';

export 'material_mime.dart';

const _uuid = Uuid();

final materialsForLessonProvider =
    StreamProvider.family<List<LessonMaterial>, String>((ref, lessonId) {
      final db = ref.watch(databaseProvider);
      return db.watchMaterialsForLesson(lessonId);
    });

final materialByIdProvider = FutureProvider.family<LessonMaterial?, String>((
  ref,
  materialId,
) async {
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
    dialogTitle: 'Attach PDF',
  );
  return _importPickedFile(ref, lessonId: lessonId, result: result);
}

/// Opens the gallery / image picker, copies into app storage, and records metadata.
///
/// Intended for lesson review images (often a single AI-generated overview).
Future<LessonMaterial?> attachImageToLesson(
  WidgetRef ref, {
  required String lessonId,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: false,
    dialogTitle: 'Add image from gallery',
  );
  return _importPickedFile(
    ref,
    lessonId: lessonId,
    result: result,
    forceImageMime: true,
  );
}

/// Creates a markdown/text lesson attachment from pasted (or typed) content.
///
/// Stored as a `.md` file under the lesson materials folder and treated like a
/// PDF for AI Study Materials, Course Review, and chat context.
Future<LessonMaterial> attachMarkdownToLesson(
  WidgetRef ref, {
  required String lessonId,
  required String title,
  required String markdown,
}) async {
  final trimmedTitle = title.trim();
  final body = markdown.trimRight();
  if (trimmedTitle.isEmpty) {
    throw ArgumentError.value(title, 'title', 'Title is required.');
  }
  if (body.trim().isEmpty) {
    throw ArgumentError.value(markdown, 'markdown', 'Content is required.');
  }

  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final sortOrder = await db.nextMaterialSortOrder(lessonId);
  final id = _uuid.v4();
  final storedFileName = '$id.md';
  final originalName = trimmedTitle.toLowerCase().endsWith('.md')
      ? trimmedTitle
      : '$trimmedTitle.md';

  await MaterialStorage.writeText(
    lessonId: lessonId,
    storedFileName: storedFileName,
    contents: body.endsWith('\n') ? body : '$body\n',
  );

  await db.insertLessonMaterial(
    LessonMaterialsCompanion.insert(
      id: id,
      lessonId: lessonId,
      title: trimmedTitle,
      originalFileName: originalName,
      storedFileName: storedFileName,
      mimeType: const Value(kMarkdownMimeType),
      sortOrder: Value(sortOrder),
      createdAt: now,
      updatedAt: now,
    ),
  );
  final created = await db.getMaterialById(id);
  if (created == null) {
    throw StateError('Failed to create markdown attachment.');
  }
  return created;
}

/// Overwrites the on-disk contents of a text/markdown material.
Future<void> updateMarkdownMaterialContent(
  WidgetRef ref, {
  required LessonMaterial material,
  required String markdown,
}) async {
  if (!isTextDocumentMimeType(material.mimeType)) {
    throw StateError('Only text documents can be edited as markdown.');
  }
  final body = markdown.trimRight();
  await MaterialStorage.writeText(
    lessonId: material.lessonId,
    storedFileName: material.storedFileName,
    contents: body.endsWith('\n') ? body : '$body\n',
  );
  await ref.read(databaseProvider).touchLessonMaterial(material.id);
}

Future<LessonMaterial?> _importPickedFile(
  WidgetRef ref, {
  required String lessonId,
  required FilePickerResult? result,
  bool forceImageMime = false,
}) async {
  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.single;
  final sourcePath = picked.path;
  if (sourcePath == null) {
    throw StateError('Could not read the selected file path.');
  }

  final originalName = picked.name;
  final ext = p.extension(originalName).toLowerCase();
  final storedFileName = '${_uuid.v4()}$ext';
  var mimeType = guessMimeType(originalName);
  if (forceImageMime && !isImageMimeType(mimeType)) {
    mimeType = switch (ext) {
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }
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
