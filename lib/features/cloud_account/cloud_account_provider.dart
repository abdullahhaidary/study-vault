import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cloud_api.dart';

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
  const CloudAccountState({this.username, this.busy = false, this.message});
  final String? username;
  final bool busy;
  final String? message;
}

final cloudAccountProvider =
    StateNotifierProvider<CloudAccountController, CloudAccountState>((ref) {
      final api = CloudApi();
      ref.onDispose(api.close);
      return CloudAccountController(api, SecureCloudSessionStore());
    });

class CloudAccountController extends StateNotifier<CloudAccountState> {
  CloudAccountController(this._api, this._store)
    : super(const CloudAccountState(busy: true)) {
    _restore();
  }

  final CloudApi _api;
  final CloudSessionStore _store;
  CloudSession? _session;

  void _show({bool busy = false, String? message}) {
    if (mounted) {
      state = CloudAccountState(
        username: _session?.username,
        busy: busy,
        message: message,
      );
    }
  }

  Future<void> _restore() async {
    try {
      _session = await _store.read();
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
      _show(
        message:
            'Signed in securely. Library synchronization is not enabled yet.',
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
