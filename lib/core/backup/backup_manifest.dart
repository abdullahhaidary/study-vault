import 'dart:convert';

/// Manifest stored inside every `.svbackup` archive as `backup/manifest.json`.
class BackupManifest {
  const BackupManifest({
    required this.backupFormatVersion,
    required this.appVersion,
    required this.databaseSchemaVersion,
    required this.createdAt,
    required this.platform,
    required this.databaseSha256,
    required this.filesIndexSha256,
    required this.materialFileCount,
    required this.materialTotalBytes,
    this.format = 'study-vault-backup',
  });

  static const currentFormatVersion = 1;
  static const formatId = 'study-vault-backup';

  final String format;
  final int backupFormatVersion;
  final String appVersion;
  final int databaseSchemaVersion;
  final DateTime createdAt;
  final String platform;
  final String databaseSha256;
  final String filesIndexSha256;
  final int materialFileCount;
  final int materialTotalBytes;

  Map<String, Object?> toJson() => {
    'format': format,
    'backupFormatVersion': backupFormatVersion,
    'backupVersion': backupFormatVersion, // alias for older docs / tooling
    'appVersion': appVersion,
    'databaseSchemaVersion': databaseSchemaVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'platform': platform,
    'materialFileCount': materialFileCount,
    'materialTotalBytes': materialTotalBytes,
    'checksums': {
      'databaseSha256': databaseSha256,
      'filesIndexSha256': filesIndexSha256,
    },
  };

  String encodePretty() => const JsonEncoder.withIndent('  ').convert(toJson());

  static BackupManifest fromJson(Map<String, dynamic> json) {
    final checksums =
        (json['checksums'] as Map?)?.cast<String, dynamic>() ?? {};
    final formatVersion =
        (json['backupFormatVersion'] as num?)?.toInt() ??
        (json['backupVersion'] as num?)?.toInt() ??
        0;

    return BackupManifest(
      format: json['format'] as String? ?? '',
      backupFormatVersion: formatVersion,
      appVersion: json['appVersion'] as String? ?? 'unknown',
      databaseSchemaVersion:
          (json['databaseSchemaVersion'] as num?)?.toInt() ?? -1,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      platform: json['platform'] as String? ?? 'unknown',
      databaseSha256: checksums['databaseSha256'] as String? ?? '',
      filesIndexSha256: checksums['filesIndexSha256'] as String? ?? '',
      materialFileCount: (json['materialFileCount'] as num?)?.toInt() ?? 0,
      materialTotalBytes: (json['materialTotalBytes'] as num?)?.toInt() ?? 0,
    );
  }

  static BackupManifest decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manifest root must be a JSON object.');
    }
    return fromJson(decoded);
  }
}

/// Local metadata about the last successful export from this install.
class LastBackupInfo {
  const LastBackupInfo({
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
    this.materialFileCount,
  });

  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
  final int? materialFileCount;

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'sizeBytes': sizeBytes,
    'materialFileCount': materialFileCount,
  };

  static LastBackupInfo fromJson(Map<String, dynamic> json) {
    return LastBackupInfo(
      fileName: json['fileName'] as String? ?? 'backup.svbackup',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      materialFileCount: (json['materialFileCount'] as num?)?.toInt(),
    );
  }

  static LastBackupInfo? tryDecode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return null;
      return fromJson(decoded);
    } on Object {
      return null;
    }
  }
}
