import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'backup_manifest.dart';
import 'backup_service.dart';

/// Must stay in sync with [AppDatabase.schemaVersion].
const kStudyVaultSchemaVersion = 7;

final studyBackupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(currentSchemaVersion: kStudyVaultSchemaVersion);
});

final lastBackupInfoProvider = FutureProvider<LastBackupInfo?>((ref) async {
  return ref.watch(studyBackupServiceProvider).loadLastBackupInfo();
});

class BackupUiController extends StateNotifier<BackupProgress> {
  BackupUiController(this._ref) : super(BackupProgress.idle);

  final Ref _ref;
  File? _pendingRestoreFile;
  BackupManifest? _pendingManifest;

  BackupService get _service => _ref.read(studyBackupServiceProvider);

  File? get pendingRestoreFile => _pendingRestoreFile;
  BackupManifest? get pendingManifest => _pendingManifest;

  void reset() {
    _pendingRestoreFile = null;
    _pendingManifest = null;
    state = BackupProgress.idle;
  }

  Future<void> createAndExportBackup() async {
    if (_isBusy) return;

    try {
      final db = _ref.read(databaseProvider);
      final built = await _service.buildBackup(
        db: db,
        onProgress: (p) => state = p,
      );

      final exported = await _service.exportBuiltBackup(
        built,
        onProgress: (p) => state = p,
      );

      if (exported == null) {
        state = const BackupProgress(
          phase: BackupPhase.idle,
          message: 'Backup cancelled.',
        );
        return;
      }

      final info = LastBackupInfo(
        fileName: built.suggestedFileName,
        createdAt: built.manifest.createdAt.toLocal(),
        sizeBytes: exported.sizeBytes,
        materialFileCount: built.manifest.materialFileCount,
      );
      await _service.saveLastBackupInfo(info);
      _ref.invalidate(lastBackupInfoProvider);

      state = BackupProgress(
        phase: BackupPhase.success,
        message: 'Backup created successfully.',
        resultFileName: built.suggestedFileName,
        resultSizeBytes: exported.sizeBytes,
        materialsDone: built.manifest.materialFileCount,
        materialsTotal: built.manifest.materialFileCount,
      );
    } catch (e) {
      state = BackupProgress(
        phase: BackupPhase.error,
        errorMessage: e.toString(),
        message: 'Backup failed.',
      );
    }
  }

  /// Pick a backup and validate it. Stores path for a later confirmed restore.
  Future<BackupManifest?> pickAndValidateBackup() async {
    if (_isBusy) return null;

    try {
      final file = await _service.pickBackupFile();
      if (file == null) return null;

      state = const BackupProgress(
        phase: BackupPhase.validating,
        message: 'Validating backup…',
      );

      final manifest = await _service.inspectBackup(file);
      _pendingRestoreFile = file;
      _pendingManifest = manifest;
      state = BackupProgress.idle;
      return manifest;
    } catch (e) {
      _pendingRestoreFile = null;
      _pendingManifest = null;
      state = BackupProgress(
        phase: BackupPhase.error,
        errorMessage: e.toString(),
        message: 'Invalid backup.',
      );
      return null;
    }
  }

  Future<bool> confirmRestorePending() async {
    final file = _pendingRestoreFile;
    if (file == null) return false;
    if (_isBusy) return false;

    state = const BackupProgress(
      phase: BackupPhase.restoring,
      message: 'Restoring Study Vault…',
    );

    try {
      final manifest = await _service.restoreBackup(
        archive: file,
        closeDatabase: () async {
          await _ref.read(databaseProvider).close();
        },
        reopenDatabase: () async {
          _ref.invalidate(databaseProvider);
          // Force a new connection so migrations run immediately.
          _ref.read(databaseProvider);
        },
        onProgress: (p) => state = p,
      );

      _pendingRestoreFile = null;
      _pendingManifest = null;

      state = BackupProgress(
        phase: BackupPhase.success,
        message: 'Study Vault restored successfully.',
        resultFileName: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : file.path,
        materialsDone: manifest.materialFileCount,
        materialsTotal: manifest.materialFileCount,
      );
      return true;
    } catch (e) {
      state = BackupProgress(
        phase: BackupPhase.error,
        errorMessage: e.toString(),
        message: 'Restore failed.',
      );
      return false;
    }
  }

  bool get _isBusy {
    switch (state.phase) {
      case BackupPhase.preparingDatabase:
      case BackupPhase.collectingFiles:
      case BackupPhase.packaging:
      case BackupPhase.exporting:
      case BackupPhase.validating:
      case BackupPhase.restoring:
        return true;
      case BackupPhase.idle:
      case BackupPhase.success:
      case BackupPhase.error:
        return false;
    }
  }
}

final backupUiControllerProvider =
    StateNotifierProvider<BackupUiController, BackupProgress>((ref) {
      return BackupUiController(ref);
    });
