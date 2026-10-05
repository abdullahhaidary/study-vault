import 'dart:convert';
import 'dart:io';

String cloudCanonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${cloudCanonical(value[key])}').join(',')}}';
  }
  if (value is List) return '[${value.map(cloudCanonical).join(',')}]';
  if (value is double &&
      value.isFinite &&
      value.abs() <= 9007199254740991 &&
      value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return jsonEncode(value);
}

bool cloudEqual(Object? a, Object? b) => cloudCanonical(a) == cloudCanonical(b);
String cloudKey(String table, String id) => '$table/$id';
String cloudTable(String key) => key.substring(0, key.indexOf('/'));
String cloudId(String key) => key.substring(key.indexOf('/') + 1);
typedef CloudRows = Map<String, Map<String, dynamic>>;

CloudRows cloudRowsFromJson(Object? json) => {
  for (final entry in (json as Map<String, dynamic>).entries)
    entry.key: Map<String, dynamic>.from(entry.value as Map),
};

class CloudSnapshot {
  const CloudSnapshot({
    required this.head,
    required this.rows,
    required this.revisions,
  });
  final int head;
  final CloudRows rows;
  final Map<String, int> revisions;

  factory CloudSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 16 ||
        json['head'] is! int ||
        (json['head'] as int) < 0 ||
        json['records'] is! List) {
      throw const FormatException('Unsupported sync response.');
    }
    final rows = <String, Map<String, dynamic>>{};
    final revisions = <String, int>{};
    for (final record in json['records'] as List) {
      if (record is! Map ||
          record['table'] is! String ||
          record['id'] is! String ||
          record['revision'] is! int ||
          (record['revision'] as int) <= 0 ||
          (record['revision'] as int) > (json['head'] as int)) {
        throw const FormatException('Invalid sync record.');
      }
      final key = cloudKey(record['table'] as String, record['id'] as String);
      if (revisions.containsKey(key)) {
        throw const FormatException('Duplicate sync record.');
      }
      revisions[key] = record['revision'] as int;
      if (record['data'] != null) {
        rows[key] = Map<String, dynamic>.from(record['data'] as Map);
      }
    }
    return CloudSnapshot(
      head: json['head'] as int,
      rows: rows,
      revisions: revisions,
    );
  }
}

abstract interface class CloudSyncRemote {
  Future<CloudSnapshot> snapshot(String token);
  Future<void> commit(String token, Map<String, dynamic> body);
  Future<bool> hasFile(String token, String digest);
  Future<void> uploadFile(String token, String digest, File file);
  Future<void> downloadFile(
    String token,
    String digest,
    int bytes,
    File target,
  );
}

enum CloudConflictChoice { device, server }

class CloudConflict {
  const CloudConflict({
    required this.key,
    required this.reason,
    this.device,
    this.server,
  });
  final String key;
  final String reason;
  final Map<String, dynamic>? device;
  final Map<String, dynamic>? server;
  String get label {
    final row = device ?? server ?? {};
    return '${row['title'] ?? row['name'] ?? row['front'] ?? row['short_text'] ?? cloudId(key)}';
  }
}

class CloudSyncOutcome {
  const CloudSyncOutcome({
    this.conflicts = const [],
    this.resolutionToken,
    this.lastSync,
    this.backupPath,
    this.message = '',
  });
  final List<CloudConflict> conflicts;
  final String? resolutionToken;
  final DateTime? lastSync;
  final String? backupPath;
  final String message;
}

class CloudSyncFailure implements Exception {
  const CloudSyncFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
