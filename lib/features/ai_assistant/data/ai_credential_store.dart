import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Gemini API key storage abstraction.
abstract class AiCredentialStore {
  Future<bool> get hasApiKey;
  Future<String?> readApiKey();
  Future<void> saveApiKey(String key);
  Future<void> replaceApiKey(String key);
  Future<void> removeApiKey();
}

/// Android Keystore / Linux libsecret via flutter_secure_storage.
class SecureAiCredentialStore implements AiCredentialStore {
  SecureAiCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'study_vault_gemini_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> get hasApiKey async {
    final value = await _storage.read(key: _keyName);
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Future<String?> readApiKey() async {
    final value = await _storage.read(key: _keyName);
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await removeApiKey();
      return;
    }
    await _storage.write(key: _keyName, value: trimmed);
  }

  @override
  Future<void> replaceApiKey(String key) => saveApiKey(key);

  @override
  Future<void> removeApiKey() async {
    await _storage.delete(key: _keyName);
  }
}

/// In-memory stub for unit tests.
class MemoryAiCredentialStore implements AiCredentialStore {
  String? _key;

  @override
  Future<bool> get hasApiKey async => _key != null && _key!.isNotEmpty;

  @override
  Future<String?> readApiKey() async => _key;

  @override
  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    _key = trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> replaceApiKey(String key) => saveApiKey(key);

  @override
  Future<void> removeApiKey() async {
    _key = null;
  }
}
