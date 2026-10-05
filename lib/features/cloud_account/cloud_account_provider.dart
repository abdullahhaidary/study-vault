import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../../../core/backup/backup_io.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/storage/study_vault_paths.dart';
import 'cloud_api.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_service.dart';

abstract interface class CloudSessionStore {
  Future<CloudSession?> read();
  Future<void> write(CloudSession session);
  Future<void> clear();
}

class SecureCloudSessionStore implements CloudSessionStore {
  static const _key = 'study_vault_cloud_session_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<CloudSession?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    final session = CloudSession.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
    if (!session.expiresAt.isAfter(DateTime.now())) {
      await clear();
      return null;
    }
    return session;
  }

  @override
  Future<void> write(CloudSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class CloudAccountState {
  const CloudAccountState({
    this.username,
    this.busy = false,
    this.message,
    this.syncEnabled = false,
    this.lastSync,
    this.backupPath,
    this.conflicts = const [],
    this.resolutionToken,
  });
  final String? username;
  final bool busy;
  final String? message;
  final bool syncEnabled;
  final DateTime? lastSync;
  final String? backupPath;
  final List<CloudConflict> conflicts;
  final String? resolutionToken;
}

final cloudSyncServiceProvider = FutureProvider<CloudSyncService>((ref) async {
  final db = ref.watch(databaseProvider);
  final docs = await StudyVaultPaths.documentsDirectory();
  final files = await StudyVaultPaths.materialsDirectory();
  final api = CloudApi();
  ref.onDispose(api.close);
  return CloudSyncService(
    db: db,
    remote: api,
    filesRoot: files,
    recoveryRoot: Directory(p.join(docs.path, 'study_vault_sync_recovery')),
    serverId: CloudApi.origin.toString(),
  );
});

final cloudAccountProvider =
    StateNotifierProvider<CloudAccountController, CloudAccountState>((ref) {
      final api = CloudApi();
      ref.onDispose(api.close);
      return CloudAccountController(
        api,
        SecureCloudSessionStore(),
        syncService: () => ref.read(cloudSyncServiceProvider.future),
      );
    });

class CloudAccountController extends StateNotifier<CloudAccountState> {
  CloudAccountController(this._api, this._store, {this.syncService})
    : super(const CloudAccountState(busy: true)) {
    _restore();
  }

  final CloudApi _api;
  final CloudSessionStore _store;
  CloudSession? _session;
  final Future<CloudSyncService> Function()? syncService;
  bool _syncEnabled = false;
  CloudSyncOutcome _sync = const CloudSyncOutcome();

  Future<void> _loadSyncInfo() async {
    if (syncService == null || _session == null) return;
    final service = await syncService!();
    final info = await service.info();
    _syncEnabled =
        info['account'] == '${service.serverId}|${_session!.accountId}';
    _sync = CloudSyncOutcome(
      lastSync: DateTime.tryParse('${info['last_sync']}'),
      backupPath: info['backup_path'] as String?,
    );
  }

  void _show({bool busy = false, String? message}) {
    if (mounted) {
      state = CloudAccountState(
        username: _session?.username,
        busy: busy,
        message: message,
        syncEnabled: _syncEnabled,
        lastSync: _sync.lastSync,
        backupPath: _sync.backupPath,
        conflicts: _sync.conflicts,
        resolutionToken: _sync.resolutionToken,
      );
    }
  }

  Future<void> _restore() async {
    try {
      _session = await _store.read();
      await _loadSyncInfo();
      _show();
    } catch (_) {
      _show(
        message:
            'Could not read secure account storage. Check that your device keyring is unlocked.',
      );
    }
  }

  Future<bool> signIn(String username, String password) async {
    if (state.busy) return false;
    _show(busy: true);
    try {
      final session = await _api.login(
        username: username,
        password: password,
        deviceName: 'Study Vault ${Platform.operatingSystem}',
      );
      try {
        await _store.write(session);
      } catch (_) {
        await _api.logout(session).catchError((_) {});
        _show(
          message:
              'Could not save the session securely. Unlock your device keyring and retry.',
        );
        return false;
      }
      _session = session;
      await _loadSyncInfo();
      _show(
        message:
            'Signed in securely. Use Sync now to synchronize your library.',
      );
      return true;
    } on CloudApiException catch (error) {
      _show(message: error.message);
      return false;
    } catch (_) {
      _show(message: 'Sign-in failed. Your local study data is unchanged.');
      return false;
    }
  }

  Future<void> syncNow({
    bool consent = false,
    CloudConflictChoice? choice,
    String? resolutionToken,
  }) async {
    final session = _session;
    if (state.busy || session == null || syncService == null) return;
    _show(busy: true, message: 'Connecting securely…');
    try {
      await _api.verify(session);
      final service = await syncService!();
      final result = await service.sync(
        token: session.token,
        accountId: session.accountId,
        consent: consent,
        choice: choice,
        resolutionToken: resolutionToken,
        onProgress: (message) => _show(busy: true, message: message),
      );
      await _loadSyncInfo();
      _sync = CloudSyncOutcome(
        conflicts: result.conflicts,
        resolutionToken: result.resolutionToken,
        lastSync: result.lastSync ?? _sync.lastSync,
        backupPath: result.backupPath ?? _sync.backupPath,
      );
      _show(message: result.message);
    } catch (error) {
      await _loadSyncInfo().catchError((_) {});
      if (error is CloudApiException && error.status == 401) {
        try {
          await _store.clear();
          _session = null;
          _syncEnabled = false;
        } catch (_) {}
      }
      _show(
        message: error is CloudApiException
            ? error.message
            : error is CloudSyncFailure
            ? error.message
            : 'Sync was interrupted. Your recovery copies were kept. Check your connection and storage, then tap Sync now to retry.',
      );
    }
  }

  Future<void> exportRecovery() async {
    final path = state.backupPath;
    if (state.busy || path == null) return;
    _show(busy: true, message: 'Preparing recovery backup export…');
    Directory? temporary;
    try {
      final file = File(path);
      final backups = BackupService();
      final manifest = await backups.inspectBackup(file);
      temporary = await Directory.systemTemp.createTemp('sv_recovery_export_');
      final copy = File(
        p.join(temporary.path, 'StudyVault-before-sync.svbackup'),
      );
      await copyFileStreaming(file, copy);
      await backups.exportBuiltBackup(
        BuiltBackup(
          archiveFile: copy,
          manifest: manifest,
          suggestedFileName: 'StudyVault-before-sync.svbackup',
          workDir: temporary,
        ),
      );
      _show(
        message:
            'Recovery backup export finished. The original recovery copy was kept.',
      );
    } catch (_) {
      _show(
        message:
            'Could not export the backup. The original recovery copy was kept.',
      );
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  Future<void> checkConnection() async {
    final session = _session;
    if (state.busy || session == null) return;
    _show(busy: true);
    try {
      await _api.verify(session);
      _show(message: 'Connected securely to your private server.');
    } on CloudApiException catch (error) {
      if (error.status == 401) {
        try {
          await _store.clear();
          _session = null;
        } catch (_) {
          _show(
            message:
                'Session expired. Unlock secure storage and sign out before retrying.',
          );
          return;
        }
      }
      _show(message: error.message);
    } catch (_) {
      _show(
        message:
            'Could not verify the connection. Your local study data is unchanged.',
      );
    }
  }

  Future<void> signOut() async {
    final session = _session;
    if (state.busy || session == null) return;
    _show(busy: true);
    try {
      await _store.clear();
    } catch (_) {
      _show(
        message:
            'Could not clear secure storage. Unlock your device keyring and retry.',
      );
      return;
    }
    _session = null;
    _syncEnabled = false;
    _sync = const CloudSyncOutcome();
    try {
      await _api.logout(session);
      _show(message: 'Signed out. Local study data was kept.');
    } catch (_) {
      _show(
        message:
            'Signed out locally. Server session revocation failed; it remains valid until expiry or password reset.',
      );
    }
  }
}
