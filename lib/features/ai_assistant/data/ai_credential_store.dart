import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ai_provider.dart';

/// Secure per-provider API key storage. Never logs or returns keys to UI lists.
abstract class AiCredentialStore {
  Future<bool> hasApiKeyFor(AiProviderId provider);
  Future<String?> readApiKeyFor(AiProviderId provider);
  Future<void> saveApiKeyFor(AiProviderId provider, String key);
  Future<void> replaceApiKeyFor(AiProviderId provider, String key);
  Future<void> removeApiKeyFor(AiProviderId provider);
}

/// Android Keystore / Linux libsecret via flutter_secure_storage.
class SecureAiCredentialStore implements AiCredentialStore {
  SecureAiCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _geminiKeyName = 'study_vault_gemini_api_key';
  static const _deepseekKeyName = 'study_vault_deepseek_api_key';

  final FlutterSecureStorage _storage;

  String _keyName(AiProviderId provider) => switch (provider) {
    AiProviderId.gemini => _geminiKeyName,
    AiProviderId.deepseek => _deepseekKeyName,
  };

  @override
  Future<bool> hasApiKeyFor(AiProviderId provider) async {
    final value = await _storage.read(key: _keyName(provider));
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Future<String?> readApiKeyFor(AiProviderId provider) async {
    final value = await _storage.read(key: _keyName(provider));
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> saveApiKeyFor(AiProviderId provider, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await removeApiKeyFor(provider);
      return;
    }
    await _storage.write(key: _keyName(provider), value: trimmed);
  }

  @override
  Future<void> replaceApiKeyFor(AiProviderId provider, String key) =>
      saveApiKeyFor(provider, key);

  @override
  Future<void> removeApiKeyFor(AiProviderId provider) async {
    await _storage.delete(key: _keyName(provider));
  }
}

/// In-memory stub for unit tests.
class MemoryAiCredentialStore implements AiCredentialStore {
  final Map<AiProviderId, String> _keys = {};

  @override
  Future<bool> hasApiKeyFor(AiProviderId provider) async {
    final value = _keys[provider];
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> readApiKeyFor(AiProviderId provider) async => _keys[provider];

  @override
  Future<void> saveApiKeyFor(AiProviderId provider, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      _keys.remove(provider);
    } else {
      _keys[provider] = trimmed;
    }
  }

  @override
  Future<void> replaceApiKeyFor(AiProviderId provider, String key) =>
      saveApiKeyFor(provider, key);

  @override
  Future<void> removeApiKeyFor(AiProviderId provider) async {
    _keys.remove(provider);
  }
}
