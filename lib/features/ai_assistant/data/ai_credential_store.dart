import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ai_provider.dart';

/// Secure per-provider API key storage. Never logs or returns keys to UI lists.
abstract class AiCredentialStore {
  Future<bool> hasApiKeyFor(AiProviderId provider);
  Future<String?> readApiKeyFor(AiProviderId provider);
  Future<List<String>> readApiKeysFor(AiProviderId provider);
  Future<List<String>> readApiKeySuffixesFor(AiProviderId provider);
  Future<void> saveApiKeyFor(AiProviderId provider, String key);
  Future<void> addApiKeyFor(AiProviderId provider, String key);
  Future<void> replaceApiKeyFor(AiProviderId provider, String key);
  Future<void> removeApiKeyFor(AiProviderId provider);
  Future<void> removeApiKeyAt(AiProviderId provider, int index);
}

/// Android Keystore / Linux libsecret via flutter_secure_storage.
class SecureAiCredentialStore implements AiCredentialStore {
  SecureAiCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _geminiKeyName = 'study_vault_gemini_api_key';
  static const _geminiKeysName = 'study_vault_gemini_api_keys';
  static const _deepseekKeyName = 'study_vault_deepseek_api_key';
  static const _newApiKeyName = 'study_vault_newapi_api_key';

  final FlutterSecureStorage _storage;

  String _keyName(AiProviderId provider) => switch (provider) {
    AiProviderId.gemini => _geminiKeyName,
    AiProviderId.deepseek => _deepseekKeyName,
    AiProviderId.newApi => _newApiKeyName,
  };

  @override
  Future<bool> hasApiKeyFor(AiProviderId provider) async {
    return (await readApiKeysFor(provider)).isNotEmpty;
  }

  @override
  Future<String?> readApiKeyFor(AiProviderId provider) async {
    final keys = await readApiKeysFor(provider);
    return keys.isEmpty ? null : keys.first;
  }

  @override
  Future<List<String>> readApiKeysFor(AiProviderId provider) async {
    if (provider != AiProviderId.gemini) {
      return _singleList(await _storage.read(key: _keyName(provider)));
    }
    final packed = await _storage.read(key: _geminiKeysName);
    final fromList = GeminiApiKeys.parse(packed);
    if (fromList.isNotEmpty) return fromList;
    return _singleList(await _storage.read(key: _geminiKeyName));
  }

  @override
  Future<List<String>> readApiKeySuffixesFor(AiProviderId provider) async {
    return [
      for (final key in await readApiKeysFor(provider))
        GeminiApiKeys.suffix(key),
    ];
  }

  @override
  Future<void> saveApiKeyFor(AiProviderId provider, String key) =>
      replaceApiKeyFor(provider, key);

  @override
  Future<void> addApiKeyFor(AiProviderId provider, String key) async {
    final incoming = GeminiApiKeys.split(key);
    if (incoming.isEmpty) return;
    if (provider != AiProviderId.gemini) {
      await replaceApiKeyFor(provider, incoming.first);
      return;
    }
    final keys = [...await readApiKeysFor(provider)];
    for (final item in incoming) {
      if (!keys.contains(item)) keys.add(item);
    }
    await _writeGeminiKeys(keys);
  }

  @override
  Future<void> replaceApiKeyFor(AiProviderId provider, String key) async {
    final incoming = GeminiApiKeys.split(key);
    if (incoming.isEmpty) {
      await removeApiKeyFor(provider);
      return;
    }
    if (provider != AiProviderId.gemini) {
      await _storage.write(key: _keyName(provider), value: incoming.first);
      return;
    }
    await _writeGeminiKeys(incoming);
  }

  @override
  Future<void> removeApiKeyFor(AiProviderId provider) async {
    if (provider == AiProviderId.gemini) {
      await _writeGeminiKeys(const []);
      return;
    }
    await _storage.delete(key: _keyName(provider));
  }

  @override
  Future<void> removeApiKeyAt(AiProviderId provider, int index) async {
    final keys = [...await readApiKeysFor(provider)];
    if (index < 0 || index >= keys.length) return;
    keys.removeAt(index);
    if (provider != AiProviderId.gemini) {
      if (keys.isEmpty) {
        await removeApiKeyFor(provider);
      } else {
        await replaceApiKeyFor(provider, keys.first);
      }
      return;
    }
    await _writeGeminiKeys(keys);
  }

  Future<void> _writeGeminiKeys(List<String> keys) async {
    if (keys.isEmpty) {
      await _storage.delete(key: _geminiKeysName);
      await _storage.delete(key: _geminiKeyName);
      return;
    }
    await _storage.write(key: _geminiKeysName, value: jsonEncode(keys));
    await _storage.write(key: _geminiKeyName, value: keys.first);
  }

  static List<String> _singleList(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? const [] : [trimmed];
  }
}

/// In-memory stub for unit tests.
class MemoryAiCredentialStore implements AiCredentialStore {
  final Map<AiProviderId, List<String>> _keys = {};

  @override
  Future<bool> hasApiKeyFor(AiProviderId provider) async {
    return (_keys[provider] ?? const []).isNotEmpty;
  }

  @override
  Future<String?> readApiKeyFor(AiProviderId provider) async {
    final keys = _keys[provider];
    if (keys == null || keys.isEmpty) return null;
    return keys.first;
  }

  @override
  Future<List<String>> readApiKeysFor(AiProviderId provider) async {
    return List.unmodifiable(_keys[provider] ?? const []);
  }

  @override
  Future<List<String>> readApiKeySuffixesFor(AiProviderId provider) async {
    return [
      for (final key in await readApiKeysFor(provider))
        GeminiApiKeys.suffix(key),
    ];
  }

  @override
  Future<void> saveApiKeyFor(AiProviderId provider, String key) =>
      replaceApiKeyFor(provider, key);

  @override
  Future<void> addApiKeyFor(AiProviderId provider, String key) async {
    final incoming = GeminiApiKeys.split(key);
    if (incoming.isEmpty) return;
    if (provider != AiProviderId.gemini) {
      await replaceApiKeyFor(provider, incoming.first);
      return;
    }
    final keys = [...(_keys[provider] ?? const <String>[])];
    for (final item in incoming) {
      if (!keys.contains(item)) keys.add(item);
    }
    _keys[provider] = keys;
  }

  @override
  Future<void> replaceApiKeyFor(AiProviderId provider, String key) async {
    final incoming = GeminiApiKeys.split(key);
    if (incoming.isEmpty) {
      _keys.remove(provider);
      return;
    }
    _keys[provider] = provider == AiProviderId.gemini
        ? incoming
        : [incoming.first];
  }

  @override
  Future<void> removeApiKeyFor(AiProviderId provider) async {
    _keys.remove(provider);
  }

  @override
  Future<void> removeApiKeyAt(AiProviderId provider, int index) async {
    final keys = [...(_keys[provider] ?? const <String>[])];
    if (index < 0 || index >= keys.length) return;
    keys.removeAt(index);
    if (keys.isEmpty) {
      _keys.remove(provider);
    } else {
      _keys[provider] = keys;
    }
  }
}

abstract final class GeminiApiKeys {
  static List<String> split(String raw) {
    final seen = <String>{};
    final keys = <String>[];
    for (final part in raw.split(RegExp(r'[\n,;]+'))) {
      final trimmed = part.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      keys.add(trimmed);
    }
    return keys;
  }

  static List<String> parse(String? packed) {
    if (packed == null || packed.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(packed);
      if (decoded is! List) return const [];
      final keys = <String>[];
      final seen = <String>{};
      for (final item in decoded) {
        final trimmed = item.toString().trim();
        if (trimmed.isEmpty || seen.contains(trimmed)) continue;
        seen.add(trimmed);
        keys.add(trimmed);
      }
      return keys;
    } on FormatException {
      return const [];
    }
  }

  static String suffix(String key) {
    final trimmed = key.trim();
    if (trimmed.length <= 4) return '••••';
    return trimmed.substring(trimmed.length - 4);
  }
}
