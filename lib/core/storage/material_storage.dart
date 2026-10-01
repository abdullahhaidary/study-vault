import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local file storage for lesson materials (PDFs and images).
///
/// Files live under:
/// `{documents}/study_vault_files/lessons/{lessonId}/{storedFileName}`
class MaterialStorage {
  MaterialStorage._();

  static Future<Directory> lessonDir(String lessonId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(docs.path, 'study_vault_files', 'lessons', lessonId),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> absolutePath({
    required String lessonId,
    required String storedFileName,
  }) async {
    final dir = await lessonDir(lessonId);
    return p.join(dir.path, storedFileName);
  }

  /// Copies [sourcePath] into the lesson folder as [storedFileName].
  static Future<File> importFile({
    required String lessonId,
    required String sourcePath,
    required String storedFileName,
  }) async {
    final targetPath = await absolutePath(
      lessonId: lessonId,
      storedFileName: storedFileName,
    );
    return File(sourcePath).copy(targetPath);
  }

  /// Legacy alias used by older call sites.
  static Future<File> importPdf({
    required String lessonId,
    required String sourcePath,
    required String storedFileName,
  }) {
    return importFile(
      lessonId: lessonId,
      sourcePath: sourcePath,
      storedFileName: storedFileName,
    );
  }

  static Future<void> deleteFile({
    required String lessonId,
    required String storedFileName,
  }) async {
    final path = await absolutePath(
      lessonId: lessonId,
      storedFileName: storedFileName,
    );
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
