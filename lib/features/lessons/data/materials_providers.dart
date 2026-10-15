import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/storage/material_storage.dart';
import '../domain/material_language_variant.dart';
import 'material_mime.dart';

export 'material_mime.dart';

const _uuid = Uuid();

final materialsForLessonProvider =
    StreamProvider.family<List<LessonMaterial>, String>((ref, lessonId) {
      final db = ref.watch(databaseProvider);
      return db.watchMaterialsForLesson(lessonId);
    });

final materialByIdProvider = StreamProvider.family<LessonMaterial?, String>((
  ref,
  materialId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchMaterialById(materialId);
});

/// Persian companion PDF for a primary material, if one has been attached.
final materialPersianVariantProvider =
    StreamProvider.family<LessonMaterial?, String>((ref, originalId) {
      final db = ref.watch(databaseProvider);
      return db.watchMaterialVariant(
        originalId,
        MaterialLanguageVariant.persian,
      );
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

/// Attaches a Persian translation PDF as a language companion of [original].
///
/// The companion is hidden from the lesson material list and shown via the
/// EN | فا switch in the PDF reader. [pageOffset] maps
/// `persianPage = originalPage + pageOffset`.
Future<LessonMaterial?> attachPersianPdfToMaterial(
  WidgetRef ref, {
  required LessonMaterial original,
  int pageOffset = 0,
}) async {
  if (!isPdfMimeType(original.mimeType)) {
    throw StateError('Only PDF materials can have a Persian companion.');
  }
  if (original.variantOfId != null) {
    throw StateError('A language variant cannot itself have a companion.');
  }
  final db = ref.read(databaseProvider);
  final existing = await db.getMaterialVariant(
    original.id,
    MaterialLanguageVariant.persian,
  );
  if (existing != null) {
    throw StateError('This PDF already has a Persian companion.');
  }

  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    withData: false,
    dialogTitle: 'Attach Persian PDF',
  );
  return _importPickedFile(
    ref,
    lessonId: original.lessonId,
    result: result,
    language: MaterialLanguageVariant.persian,
    variantOfId: original.id,
    pageOffset: pageOffset,
    sortOrder: original.sortOrder,
    titlePrefix: 'فارسی · ',
  );
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
  String? language,
  String? variantOfId,
  int pageOffset = 0,
  int? sortOrder,
  String titlePrefix = '',
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
  if (language != null && !isPdfMimeType(mimeType)) {
    throw StateError('Language companions must be PDF files.');
  }
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final order = sortOrder ?? await db.nextMaterialSortOrder(lessonId);
  final id = _uuid.v4();
  final title = '$titlePrefix$originalName';

  await MaterialStorage.importFile(
    lessonId: lessonId,
    sourcePath: sourcePath,
    storedFileName: storedFileName,
  );

  final companion = LessonMaterialsCompanion.insert(
    id: id,
    lessonId: lessonId,
    title: title,
    originalFileName: originalName,
    storedFileName: storedFileName,
    mimeType: Value(mimeType),
    sortOrder: Value(order),
    language: Value(language),
    variantOfId: Value(variantOfId),
    pageOffset: Value(pageOffset),
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
  final variants = await db.getMaterialVariants(material.id);
  for (final variant in [...variants, material]) {
    await MaterialStorage.deleteFile(
      lessonId: variant.lessonId,
      storedFileName: variant.storedFileName,
    );
  }
  await db.deleteLessonMaterial(material.id);
}

/// Removes only the Persian companion PDF, leaving the original intact.
Future<void> deletePersianVariant(
  WidgetRef ref, {
  required LessonMaterial original,
}) async {
  final db = ref.read(databaseProvider);
  final persian = await db.getMaterialVariant(
    original.id,
    MaterialLanguageVariant.persian,
  );
  if (persian == null) return;
  await MaterialStorage.deleteFile(
    lessonId: persian.lessonId,
    storedFileName: persian.storedFileName,
  );
  await db.deleteLessonMaterial(persian.id);
}

Future<String> materialAbsolutePath(LessonMaterial material) {
  return MaterialStorage.absolutePath(
    lessonId: material.lessonId,
    storedFileName: material.storedFileName,
  );
}
