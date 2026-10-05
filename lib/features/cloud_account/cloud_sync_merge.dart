import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'cloud_sync_schema.dart';

class CloudMerge {
  CloudMerge({
    required this.rows,
    required this.conflicts,
    required this.token,
  });
  final CloudRows rows;
  final List<CloudConflict> conflicts;
  final String token;

  static CloudMerge plan({
    required CloudSyncSchema schema,
    required CloudRows base,
    required CloudRows device,
    required CloudRows server,
    CloudConflictChoice? choice,
  }) {
    final rows = <String, Map<String, dynamic>>{};
    final conflicts = <String, CloudConflict>{};
    final preferred = choice == CloudConflictChoice.device ? device : server;
    final keys = {...base.keys, ...device.keys, ...server.keys};
    void conflict(String key, String reason) {
      conflicts[key] = CloudConflict(
        key: key,
        reason: reason,
        device: device[key],
        server: server[key],
      );
    }

    for (final key in keys) {
      final local = device[key];
      final remote = server[key];
      Map<String, dynamic>? result;
      if (cloudEqual(local, remote) || cloudEqual(remote, base[key])) {
        result = local;
      } else if (cloudEqual(local, base[key])) {
        result = remote;
      } else if (cloudTable(key) == 'study_pin_categories' &&
          local?['is_system'] == 1 &&
          remote?['is_system'] == 1 &&
          cloudEqual(
            _without(local!, ['created_at', 'updated_at']),
            _without(remote!, ['created_at', 'updated_at']),
          )) {
        result = remote;
      } else {
        conflict(
          key,
          local == null || remote == null
              ? 'Deleted on one device and changed on another.'
              : 'Both devices changed this item.',
        );
        result = choice == null ? local : preferred[key];
      }
      if (result != null) rows[key] = Map.of(result);
    }
    for (final group in schema.duplicates(rows)) {
      final name = cloudTable(group.first);
      final ordered = [...group]
        ..sort((a, b) {
          final serverOrder = (server.containsKey(a) ? 0 : 1).compareTo(
            server.containsKey(b) ? 0 : 1,
          );
          return serverOrder != 0 ? serverOrder : a.compareTo(b);
        });
      final versioned = _versionedTables[name];
      if (versioned != null) {
        final (number, scope) = versioned;
        final sample = rows[ordered.first]!;
        var maximum = rows.entries
            .where(
              (e) =>
                  cloudTable(e.key) == name &&
                  scope.every((s) => e.value[s] == sample[s]),
            )
            .map((e) => e.value[number] as int)
            .fold<int>(0, (a, b) => a > b ? a : b);
        for (final key in ordered.skip(1)) {
          rows[key]![number] = ++maximum;
        }
      } else if (name == 'flashcards') {
        for (final key in ordered.skip(1)) {
          rows[key]!['source_study_pin_id'] = null;
        }
      } else {
        final equivalent = ordered.every(
          (key) => cloudEqual(
            _without(rows[key]!, ['id', 'created_at', 'updated_at']),
            _without(rows[ordered.first]!, ['id', 'created_at', 'updated_at']),
          ),
        );
        if (equivalent) {
          for (final key in ordered.skip(1)) {
            rows.remove(key);
          }
        } else {
          for (final key in ordered) {
            conflict(
              key,
              'Another device created a different item with the same unique reference.',
            );
          }
          if (choice != null) {
            for (final key in ordered) {
              if (preferred.containsKey(key)) {
                rows[key] = Map.of(preferred[key]!);
              } else {
                rows.remove(key);
              }
            }
          }
        }
      }
    }
    for (var iteration = 0; iteration < keys.length + 1; iteration++) {
      final missing = schema.missingParents(rows);
      if (missing.isEmpty) break;
      for (final link in missing) {
        conflict(
          link.child,
          'Its parent or material file was removed on another device.',
        );
        if (choice != null) {
          if (preferred.containsKey(link.parent)) {
            rows[link.parent] = Map.of(preferred[link.parent]!);
          } else if (preferred.containsKey(link.child) &&
              !cloudEqual(preferred[link.child], rows[link.child])) {
            rows[link.child] = Map.of(preferred[link.child]!);
          } else {
            rows.remove(link.child);
          }
        }
      }
      if (choice == null) break;
    }
    if (choice != null || conflicts.isEmpty) schema.validate(rows);
    final token = sha256
        .convert(utf8.encode(cloudCanonical([base, device, server])))
        .toString();
    return CloudMerge(
      rows: rows,
      conflicts: conflicts.values.toList(),
      token: token,
    );
  }

  /// Version column and scope of tables whose concurrent versions are
  /// renumbered instead of reported as conflicts.
  static const _versionedTables = {
    'pdf_ai_materials': ('version', ['material_id', 'type']),
    'annotation_ai_generations': (
      'generation_number',
      ['source_fingerprint', 'action_type'],
    ),
    'course_review_entries': ('version', ['subject_id', 'material_id', 'part']),
  };

  static Map<String, dynamic> _without(
    Map<String, dynamic> row,
    List<String> columns,
  ) => Map.of(row)..removeWhere((key, _) => columns.contains(key));
}
