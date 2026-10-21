import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/ai_endpoint_profile.dart';
import '../domain/ai_model_ref.dart';
import '../domain/ai_provider.dart';
import 'ai_credential_store.dart';
import 'ai_settings_store.dart';

/// Device-local JSON for profile metadata. Keys stay in secure storage.
abstract class AiEndpointCatalogStore {
  Future<String?> read();
  Future<void> write(String json);
}

class MemoryAiEndpointCatalogStore implements AiEndpointCatalogStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;
}

class SharedPreferencesAiEndpointCatalogStore
    implements AiEndpointCatalogStore {
  SharedPreferencesAiEndpointCatalogStore({SharedPreferences? prefs})
    : _prefsOverride = prefs;

  static const storageKey = 'ai_endpoint_profiles_v1';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _cached;

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ??
        (_cached ??= await SharedPreferences.getInstance());
  }

  @override
  Future<String?> read() async => (await _prefs()).getString(storageKey);

  @override
  Future<void> write(String json) async {
    await (await _prefs()).setString(storageKey, json);
  }
}

/// Resolved New API connection for one profile. The key lives only here,
/// long enough to build a request, and is never written back to metadata.
class AiEndpointConnection {
  const AiEndpointConnection({
    required this.profile,
    required this.messagesUri,
    required this.modelsUri,
    required this.apiKey,
  });

  final AiEndpointProfile profile;
  final Uri messagesUri;
  final Uri modelsUri;
  final String apiKey;
}

class AiEndpointProfileRepository {
  AiEndpointProfileRepository({
    required this.store,
    required this.settings,
    required this.credentials,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final AiEndpointCatalogStore store;
  final AiSettingsStore settings;
  final AiCredentialStore credentials;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<void>? _migrating;

  Future<void> ensureMigrated() {
    final pending = _migrating;
    if (pending != null) return pending;
    final run = _migrate();
    _migrating = run;
    return run.whenComplete(() {
      if (identical(_migrating, run)) _migrating = null;
    });
  }

  Future<List<AiEndpointProfile>> list() async {
    await ensureMigrated();
    return List.unmodifiable((await _read()).profiles);
  }

  Future<AiEndpointProfile?> find(String id) async {
    await ensureMigrated();
    for (final profile in (await _read()).profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Future<String?> legacyProfileId() async {
    await ensureMigrated();
    return (await _read()).legacyProfileId;
  }

  Future<bool> isAvailable(AiModelRef ref) async {
    await ensureMigrated();
    if (ref is EndpointAiModelRef) {
      final profile = await find(ref.profileId);
      return profile != null && profile.enabled;
    }
    if (ref is LegacyNewApiModelRef) {
      final id = await legacyProfileId();
      if (id == null) return false;
      final profile = await find(id);
      return profile != null && profile.enabled;
    }
    return true;
  }

  /// Binds a legacy `newapi:` ref to the migrated profile when it still exists.
  Future<AiModelRef> bindLegacy(AiModelRef ref) async {
    if (ref is! LegacyNewApiModelRef || ref.bareModelId.isEmpty) return ref;
    final id = await legacyProfileId();
    if (id == null) return ref;
    final profile = await find(id);
    if (profile == null) return ref;
    return EndpointAiModelRef(profileId: id, modelId: ref.bareModelId);
  }

  Future<AiEndpointProfile> create({
    required String name,
    required String baseUrl,
    required String apiKey,
    String? defaultModelId,
    bool makeGlobalDefault = false,
  }) async {
    await ensureMigrated();
    final cleanedName = _uniqueName(name, existing: await _read());
    final url = normalizeNewApiBaseUrl(baseUrl);
    if (url.isEmpty) {
      throw const FormatException('Enter the server base URL.');
    }
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const FormatException('Enter an API key for this profile.');
    }
    final model = (defaultModelId ?? '').trim();
    final now = _clock();
    final profile = AiEndpointProfile(
      id: _newId(),
      name: cleanedName,
      protocol: AiEndpointProtocol.newApiAnthropic,
      baseUrl: url,
      defaultModelId: model,
      cachedModelIds: const [],
      modelsRefreshedAt: null,
      createdAt: now,
      updatedAt: now,
      enabled: true,
      connectionStatus: AiEndpointConnectionStatus.unknown,
      connectionDetail: null,
      keySuffix: GeminiApiKeys.suffix(key),
    );
    await credentials.writeEndpointKey(profile.id, key);
    final catalog = await _read();
    await _write(catalog.copyWith(profiles: [...catalog.profiles, profile]));
    if (makeGlobalDefault && model.isNotEmpty) {
      await settings.setGlobalModelRef(
        EndpointAiModelRef(profileId: profile.id, modelId: model),
      );
    } else if (await settings.getActiveEndpointProfileId() == null) {
      await settings.setActiveEndpointProfileId(profile.id);
    }
    return profile;
  }

  Future<AiEndpointProfile> update({
    required String id,
    String? name,
    String? baseUrl,
    String? replacementApiKey,
    String? defaultModelId,
    bool? enabled,
  }) async {
    await ensureMigrated();
    final catalog = await _read();
    final index = catalog.profiles.indexWhere((profile) => profile.id == id);
    if (index < 0) {
      throw const FormatException('API profile unavailable.');
    }
    final current = catalog.profiles[index];
    final nextName = name == null
        ? current.name
        : _uniqueName(name, existing: catalog, exceptId: id);
    final nextUrl = baseUrl == null
        ? current.baseUrl
        : normalizeNewApiBaseUrl(baseUrl);
    if (nextUrl.isEmpty) {
      throw const FormatException('Enter the server base URL.');
    }
    final nextModel = defaultModelId == null
        ? current.defaultModelId
        : defaultModelId.trim();
    if (defaultModelId != null && nextModel.isEmpty) {
      throw const FormatException('Enter a model ID.');
    }
    final replacement = replacementApiKey?.trim();
    var suffix = current.keySuffix;
    if (replacement != null && replacement.isNotEmpty) {
      await credentials.writeEndpointKey(id, replacement);
      suffix = GeminiApiKeys.suffix(replacement);
    }
    final next = current.copyWith(
      name: nextName,
      baseUrl: nextUrl,
      defaultModelId: nextModel,
      enabled: enabled,
      keySuffix: suffix,
      updatedAt: _clock(),
    );
    final profiles = [...catalog.profiles];
    profiles[index] = next;
    await _write(catalog.copyWith(profiles: profiles));
    return next;
  }

  Future<void> delete(String id, {AiModelRef? replacementDefault}) async {
    await ensureMigrated();
    final catalog = await _read();
    final global = await settings.getGlobalModelRef();
    final wasGlobal =
        global is EndpointAiModelRef && global.profileId == id ||
        (global is LegacyNewApiModelRef && catalog.legacyProfileId == id);
    if (wasGlobal) {
      final replacement =
          replacementDefault ??
          BuiltinGeminiModelRef(
            await settings.getModelIdFor(AiProviderId.gemini),
          );
      if (replacement is EndpointAiModelRef && replacement.profileId == id) {
        throw const FormatException(
          'Choose a different default before deleting this profile.',
        );
      }
      await settings.setGlobalModelRef(replacement);
    }
    if (await settings.getActiveEndpointProfileId() == id) {
      final remaining = catalog.profiles.where((profile) => profile.id != id);
      await settings.setActiveEndpointProfileId(
        remaining.isEmpty ? null : remaining.first.id,
      );
    }
    await _write(
      catalog.copyWith(
        profiles: [
          for (final profile in catalog.profiles)
            if (profile.id != id) profile,
        ],
        clearLegacyProfileId: catalog.legacyProfileId == id,
      ),
    );
    await credentials.deleteEndpointKey(id);
  }

  Future<AiEndpointProfile> cacheModels({
    required String id,
    required List<String> modelIds,
  }) async {
    final unique = <String>{};
    final models = <String>[
      for (final id in modelIds)
        if (id.trim().isNotEmpty && unique.add(id.trim())) id.trim(),
    ]..sort();
    return _replace(id, (profile) {
      return profile.copyWith(
        cachedModelIds: models,
        modelsRefreshedAt: _clock(),
        updatedAt: _clock(),
      );
    });
  }

  Future<AiEndpointProfile> setConnection({
    required String id,
    required AiEndpointConnectionStatus status,
    String? detail,
  }) {
    final message = _publicDetail(detail);
    return _replace(id, (profile) {
      return profile.copyWith(
        connectionStatus: status,
        connectionDetail: message,
        clearConnectionDetail: message == null,
        updatedAt: _clock(),
      );
    });
  }

  Future<AiEndpointConnection> resolve(String profileId) async {
    await ensureMigrated();
    final profile = await find(profileId);
    if (profile == null) {
      throw const FormatException('API profile unavailable.');
    }
    if (!profile.enabled) {
      throw const FormatException('This API profile is turned off.');
    }
    if (profile.protocol != AiEndpointProtocol.newApiAnthropic) {
      throw FormatException(
        'Protocol ${profile.protocol.storageValue} is not supported.',
      );
    }
    final key = await credentials.readEndpointKey(profileId);
    if (key == null || key.isEmpty || profile.baseUrl.isEmpty) {
      throw const FormatException(
        'Add an API key and server URL for this profile in Settings.',
      );
    }
    return AiEndpointConnection(
      profile: profile,
      messagesUri: aiEndpointMessagesUri(profile.baseUrl),
      modelsUri: aiEndpointModelsUri(profile.baseUrl),
      apiKey: key,
    );
  }

  Future<String> metadataJson() async {
    await ensureMigrated();
    return jsonEncode((await _read()).toJson());
  }

  Future<AiEndpointProfile> _replace(
    String id,
    AiEndpointProfile Function(AiEndpointProfile profile) update,
  ) async {
    await ensureMigrated();
    final catalog = await _read();
    final index = catalog.profiles.indexWhere((profile) => profile.id == id);
    if (index < 0) {
      throw const FormatException('API profile unavailable.');
    }
    final profiles = [...catalog.profiles];
    final next = update(profiles[index]);
    profiles[index] = next;
    await _write(catalog.copyWith(profiles: profiles));
    return next;
  }

  Future<void> _migrate() async {
    final catalog = await _read();
    if (catalog.migrated) return;
    final url = await settings.getNewApiBaseUrl();
    final key = await credentials.readApiKeyFor(AiProviderId.newApi);
    final storedModel = await settings.getModelIdFor(AiProviderId.newApi);
    final bare = newApiBareModelId(storedModel);
    final hasKey = key != null && key.trim().isNotEmpty;
    if (url.trim().isEmpty && !hasKey) {
      await _write(catalog.copyWith(migrated: true));
      return;
    }
    String normalized = '';
    if (url.trim().isNotEmpty) {
      try {
        normalized = normalizeNewApiBaseUrl(url);
      } on FormatException {
        return;
      }
    }
    final now = _clock();
    final id = _newId();
    final profile = AiEndpointProfile(
      id: id,
      name: _availableName('New API', catalog),
      protocol: AiEndpointProtocol.newApiAnthropic,
      baseUrl: normalized,
      defaultModelId: bare,
      cachedModelIds: const [],
      modelsRefreshedAt: null,
      createdAt: now,
      updatedAt: now,
      enabled: true,
      connectionStatus: AiEndpointConnectionStatus.unknown,
      connectionDetail: null,
      keySuffix: hasKey ? GeminiApiKeys.suffix(key) : '',
    );
    if (hasKey) {
      await credentials.writeEndpointKey(id, key.trim());
    }
    await _write(
      catalog.copyWith(
        migrated: true,
        legacyProfileId: id,
        profiles: [...catalog.profiles, profile],
      ),
    );
    await settings.setActiveEndpointProfileId(id);
    if (hasKey) {
      await credentials.removeApiKeyFor(AiProviderId.newApi);
    }
    if (await settings.getProvider() == AiProviderId.newApi &&
        bare.isNotEmpty) {
      await settings.setGlobalModelRef(
        EndpointAiModelRef(profileId: id, modelId: bare),
      );
    }
  }

  Future<AiEndpointCatalog> _read() async {
    final raw = await store.read();
    if (raw == null || raw.trim().isEmpty) return AiEndpointCatalog.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AiEndpointCatalog.empty;
      return AiEndpointCatalog.fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      return AiEndpointCatalog.empty;
    }
  }

  Future<void> _write(AiEndpointCatalog catalog) {
    return store.write(jsonEncode(catalog.toJson()));
  }

  String _uniqueName(
    String name, {
    required AiEndpointCatalog existing,
    String? exceptId,
  }) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) {
      throw const FormatException('Enter a name for this API profile.');
    }
    final lower = cleaned.toLowerCase();
    for (final profile in existing.profiles) {
      if (profile.id == exceptId) continue;
      if (profile.name.toLowerCase() == lower) {
        throw FormatException(
          'An API profile named "$cleaned" already exists.',
        );
      }
    }
    return cleaned;
  }

  String _availableName(String base, AiEndpointCatalog catalog) {
    final names = {
      for (final profile in catalog.profiles) profile.name.toLowerCase(),
    };
    if (!names.contains(base.toLowerCase())) return base;
    var index = 2;
    while (names.contains('$base $index'.toLowerCase())) {
      index++;
    }
    return '$base $index';
  }

  String? _publicDetail(String? detail) {
    final trimmed = detail?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.length > 180 ? '${trimmed.substring(0, 180)}…' : trimmed;
  }
}

Uri aiEndpointMessagesUri(String baseUrl) {
  final root = _withV1(baseUrl);
  return Uri.parse('$root/messages');
}

Uri aiEndpointModelsUri(String baseUrl) {
  final root = _withV1(baseUrl);
  return Uri.parse('$root/models');
}

String _withV1(String baseUrl) {
  final base = normalizeNewApiBaseUrl(baseUrl);
  return base.endsWith('/v1') ? base : '$base/v1';
}
