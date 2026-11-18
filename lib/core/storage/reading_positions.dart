import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'study_vault_reading_position_v1_';

/// The file path includes the active library directory. Versions/languages use
/// separate parts, so their positions cannot overwrite one another.
String readingPositionKey(String filePath, String resourceId, String part) =>
    '$_prefix${sha256.convert(utf8.encode(jsonEncode([filePath, resourceId, part])))}';

final readingPositionsProvider = Provider<ReadingPositions>((ref) {
  final store = ReadingPositions();
  ref.onDispose(store.dispose);
  return store;
});

/// Small device-local numeric bookmarks, never study content or synced rows.
/// Memory is updated synchronously: switching away before the disk debounce
/// finishes still restores the latest position. Disk writes are serialized.
class ReadingPositions {
  final _positions = <String, Map<String, double>>{};
  final _pending = <String>{};
  Future<void>? _loading;
  Future<void> _writing = Future.value();
  Timer? _timer;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith(_prefix),
      )) {
        if (_positions.containsKey(key)) continue;
        try {
          final json = jsonDecode(prefs.getString(key) ?? '{}') as Map;
          final value = <String, double>{};
          for (final entry in json.entries) {
            if (entry.key is String &&
                entry.value is num &&
                (entry.value as num).isFinite) {
              value[entry.key as String] = (entry.value as num).toDouble();
            }
          }
          _positions.putIfAbsent(key, () => value);
        } on Object {
          // Ignore one malformed bookmark without preventing reading.
        }
      }
    } on Object {
      // In-memory retention still works if preferences are unavailable.
    }
  }

  Map<String, double> get(String key) => _positions[key] ?? const {};

  void save(String key, Map<String, double> position) {
    if (position.values.any((value) => !value.isFinite)) return;
    _positions[key] = Map.unmodifiable(position);
    _pending.add(key);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 250), flush);
  }

  Future<void> flush() {
    _timer?.cancel();
    final updates = {
      for (final key in _pending) key: jsonEncode(_positions[key]),
    };
    _pending.clear();
    _writing = _writing.then((_) async {
      if (updates.isEmpty) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final entry in updates.entries) {
          await prefs.setString(entry.key, entry.value);
        }
      } on Object {
        // A storage failure must not reset the in-memory reading position.
      }
    });
    return _writing;
  }

  void dispose() {
    _timer?.cancel();
    unawaited(flush());
  }
}

/// Supplies the saved offset before the first lazy-list layout, avoiding an
/// early jump clamped to the extent estimated from just the first sections.
class ReadingScrollController extends ScrollController {
  ReadingScrollController({
    required this.store,
    required this.positionKey,
    this.shouldSave,
  }) : super(keepScrollOffset: false) {
    addListener(_remember);
  }

  final ReadingPositions store;
  final String Function() positionKey;
  final bool Function()? shouldSave;

  @override
  double get initialScrollOffset =>
      (store.get(positionKey())['offset'] ?? 0).clamp(0, double.infinity);

  void _remember() {
    if (positions.length != 1 || shouldSave?.call() == false) return;
    final key = positionKey();
    store.save(key, {'offset': offset});
  }
}
