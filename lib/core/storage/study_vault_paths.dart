import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Canonical Study Vault on-disk locations.
///
/// The active library account decides the library root: the default account
/// uses the app documents directory, every other account its own folder.
abstract final class StudyVaultPaths {
  static const databaseFileName = 'study_vault.sqlite';
  static const materialsDirName = 'study_vault_files';
  static const lastBackupMetaFileName = 'study_vault_last_backup.json';
  static const syncRecoveryDirName = 'study_vault_sync_recovery';

  static Directory? _libraryRoot;

  /// Points every library path at [root]; `null` restores the documents root.
  /// Only switch while no database connection for the old root is opening.
  static void useLibraryRoot(Directory? root) => _libraryRoot = root;

  static Future<Directory> documentsDirectory() =>
      getApplicationDocumentsDirectory();

  /// Root holding the active account's database, files, and backups.
  static Future<Directory> libraryDirectory() async =>
      _libraryRoot ?? await documentsDirectory();

  static Future<File> databaseFile() async {
    final root = await libraryDirectory();
    return File(p.join(root.path, databaseFileName));
  }

  static Future<Directory> materialsDirectory() async {
    final root = await libraryDirectory();
    return Directory(p.join(root.path, materialsDirName));
  }

  static Future<Directory> syncRecoveryDirectory() async {
    final root = await libraryDirectory();
    return Directory(p.join(root.path, syncRecoveryDirName));
  }

  static Future<File> lastBackupMetaFile() async {
    final root = await libraryDirectory();
    return File(p.join(root.path, lastBackupMetaFileName));
  }

  /// Sidecar files SQLite may create alongside the main DB.
  static Future<List<File>> databaseSidecarFiles() async {
    final db = await databaseFile();
    return [File('${db.path}-wal'), File('${db.path}-shm')];
  }
}
