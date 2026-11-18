/// Wire protocol for a custom AI endpoint.
///
/// [newApiAnthropic] is the Anthropic Messages shape used by New API and
/// Claude-compatible gateways. [openAiCompatible] is `/chat/completions`, used
/// by OpenAI-shaped gateways that do not speak Messages at all.
enum AiEndpointProtocol {
  newApiAnthropic,
  openAiCompatible;

  String get storageValue => name;

  String get label => switch (this) {
    newApiAnthropic => 'Anthropic Messages',
    openAiCompatible => 'OpenAI-compatible',
  };

  static AiEndpointProtocol parse(String? raw) {
    if (raw == null || raw.isEmpty) return newApiAnthropic;
    for (final protocol in values) {
      if (protocol.storageValue == raw) return protocol;
    }
    throw FormatException('Unsupported AI endpoint protocol: $raw.');
  }
}

enum AiEndpointConnectionStatus {
  unknown,
  ok,
  failed;

  String get storageValue => name;

  static AiEndpointConnectionStatus parse(String? raw) {
    for (final status in values) {
      if (status.storageValue == raw) return status;
    }
    return unknown;
  }

  String get label => switch (this) {
    unknown => 'Not tested',
    ok => 'Connected',
    failed => 'Connection failed',
  };
}

/// Non-secret metadata for one named custom API server.
///
/// The API key is never a field on this object. Only a short suffix is kept
/// so Settings can show which key is saved.
class AiEndpointProfile {
  const AiEndpointProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.defaultModelId,
    required this.cachedModelIds,
    required this.modelsRefreshedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.enabled,
    required this.connectionStatus,
    required this.connectionDetail,
    required this.keySuffix,
    this.connectionRevision = 0,
    this.promptCachingEnabled = false,
    this.pdfAttachmentsEnabled = false,
    this.pdfMaxPages = 100,
  });

  static const staleAfter = Duration(hours: 24);

  final String id;
  final String name;
  final AiEndpointProtocol protocol;
  final String baseUrl;
  final String defaultModelId;
  final List<String> cachedModelIds;
  final DateTime? modelsRefreshedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool enabled;
  final AiEndpointConnectionStatus connectionStatus;
  final String? connectionDetail;
  final String keySuffix;

  /// Changes whenever credentials or the server URL change. Never a key hash.
  final int connectionRevision;

  /// Opt in only when the gateway supports Anthropic cache_control.
  final bool promptCachingEnabled;

  /// Explicit capability for the server/model selected from this profile.
  final bool pdfAttachmentsEnabled;
  final int pdfMaxPages;

  String get host {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return baseUrl;
    return uri.host;
  }

  bool get warnsInsecureHttp => Uri.tryParse(baseUrl)?.scheme == 'http';

  bool get hasCachedModels => cachedModelIds.isNotEmpty;

  bool get modelsStale {
    final refreshed = modelsRefreshedAt;
    if (refreshed == null) return true;
    return DateTime.now().difference(refreshed) > staleAfter;
  }

  String get modelListLabel {
    if (modelsRefreshedAt == null) {
      return hasCachedModels ? 'Cached model list' : 'Model list not cached';
    }
    if (modelsStale) return 'Cached model list is stale';
    return 'Cached model list';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.storageValue,
    'baseUrl': baseUrl,
    'defaultModelId': defaultModelId,
    'cachedModelIds': cachedModelIds,
    'modelsRefreshedAt': modelsRefreshedAt?.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'enabled': enabled,
    'connectionStatus': connectionStatus.storageValue,
    'connectionDetail': connectionDetail,
    'keySuffix': keySuffix,
    'connectionRevision': connectionRevision,
    'promptCachingEnabled': promptCachingEnabled,
    'pdfAttachmentsEnabled': pdfAttachmentsEnabled,
    'pdfMaxPages': pdfMaxPages,
  };

  factory AiEndpointProfile.fromJson(Map<String, Object?> json) {
    final cached = json['cachedModelIds'];
    return AiEndpointProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      protocol: AiEndpointProtocol.parse(json['protocol'] as String?),
      baseUrl: json['baseUrl'] as String? ?? '',
      defaultModelId: json['defaultModelId'] as String? ?? '',
      cachedModelIds: cached is List
          ? [
              for (final id in cached)
                if (id is String && id.trim().isNotEmpty) id.trim(),
            ]
          : const [],
      modelsRefreshedAt: _time(json['modelsRefreshedAt']),
      createdAt:
          _time(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _time(json['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      enabled: json['enabled'] != false,
      connectionStatus: AiEndpointConnectionStatus.parse(
        json['connectionStatus'] as String?,
      ),
      connectionDetail: json['connectionDetail'] as String?,
      keySuffix: json['keySuffix'] as String? ?? '',
      connectionRevision: json['connectionRevision'] as int? ?? 0,
      promptCachingEnabled: json['promptCachingEnabled'] == true,
      pdfAttachmentsEnabled: json['pdfAttachmentsEnabled'] == true,
      pdfMaxPages: ((json['pdfMaxPages'] as int?) ?? 100).clamp(1, 600),
    );
  }

  AiEndpointProfile copyWith({
    String? name,
    AiEndpointProtocol? protocol,
    String? baseUrl,
    String? defaultModelId,
    List<String>? cachedModelIds,
    DateTime? modelsRefreshedAt,
    bool clearModelsRefreshedAt = false,
    DateTime? updatedAt,
    bool? enabled,
    AiEndpointConnectionStatus? connectionStatus,
    String? connectionDetail,
    bool clearConnectionDetail = false,
    String? keySuffix,
    int? connectionRevision,
    bool? promptCachingEnabled,
    bool? pdfAttachmentsEnabled,
    int? pdfMaxPages,
  }) {
    return AiEndpointProfile(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModelId: defaultModelId ?? this.defaultModelId,
      cachedModelIds: cachedModelIds ?? this.cachedModelIds,
      modelsRefreshedAt: clearModelsRefreshedAt
          ? null
          : modelsRefreshedAt ?? this.modelsRefreshedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      enabled: enabled ?? this.enabled,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionDetail: clearConnectionDetail
          ? null
          : connectionDetail ?? this.connectionDetail,
      keySuffix: keySuffix ?? this.keySuffix,
      connectionRevision: connectionRevision ?? this.connectionRevision,
      promptCachingEnabled: promptCachingEnabled ?? this.promptCachingEnabled,
      pdfAttachmentsEnabled:
          pdfAttachmentsEnabled ?? this.pdfAttachmentsEnabled,
      pdfMaxPages: pdfMaxPages ?? this.pdfMaxPages,
    );
  }

  static DateTime? _time(Object? raw) {
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }
}

class AiEndpointCatalog {
  const AiEndpointCatalog({
    required this.migrated,
    required this.legacyProfileId,
    required this.profiles,
  });

  static const empty = AiEndpointCatalog(
    migrated: false,
    legacyProfileId: null,
    profiles: [],
  );

  final bool migrated;
  final String? legacyProfileId;
  final List<AiEndpointProfile> profiles;

  Map<String, Object?> toJson() => {
    'v': 1,
    'migrated': migrated,
    'legacyProfileId': legacyProfileId,
    'profiles': [for (final profile in profiles) profile.toJson()],
  };

  factory AiEndpointCatalog.fromJson(Map<String, Object?> json) {
    final rawProfiles = json['profiles'];
    return AiEndpointCatalog(
      migrated: json['migrated'] == true,
      legacyProfileId: json['legacyProfileId'] as String?,
      profiles: rawProfiles is List
          ? [
              for (final item in rawProfiles)
                if (item is Map)
                  AiEndpointProfile.fromJson(item.cast<String, Object?>()),
            ]
          : const [],
    );
  }

  AiEndpointCatalog copyWith({
    bool? migrated,
    String? legacyProfileId,
    bool clearLegacyProfileId = false,
    List<AiEndpointProfile>? profiles,
  }) {
    return AiEndpointCatalog(
      migrated: migrated ?? this.migrated,
      legacyProfileId: clearLegacyProfileId
          ? null
          : legacyProfileId ?? this.legacyProfileId,
      profiles: profiles ?? this.profiles,
    );
  }
}
