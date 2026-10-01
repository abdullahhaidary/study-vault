import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Canonical Study Vault on-disk locations under the app documents directory.
abstract final class StudyVaultPaths {
  static const databaseFileName = 'study_vault.sqlite';
  static const materialsDirName = 'study_vault_files';
  static const lastBackupMetaFileName = 'study_vault_last_backup.json';

  static Future<Directory> documentsDirectory() =>
      getApplicationDocumentsDirectory();

  static Future<File> databaseFile() async {
    final docs = await documentsDirectory();
    return File(p.join(docs.path, databaseFileName));
  }

  static Future<Directory> materialsDirectory() async {
    final docs = await documentsDirectory();
    return Directory(p.join(docs.path, materialsDirName));
  }

  static Future<File> lastBackupMetaFile() async {
    final docs = await documentsDirectory();
    return File(p.join(docs.path, lastBackupMetaFileName));
  }

  /// Sidecar files SQLite may create alongside the main DB.
  static Future<List<File>> databaseSidecarFiles() async {
    final db = await databaseFile();
    return [File('${db.path}-wal'), File('${db.path}-shm')];
  }
}
