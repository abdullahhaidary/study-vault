import 'package:shared_preferences/shared_preferences.dart';

/// Device-local map from a Study Vault chat id to a Pocket browser chat id.
///
/// These ids stay off the synced database. A Study Vault chat keeps using
/// the same browser conversation until the link is cleared or replaced.
abstract class PocketChatLinks {
  Future<String?> pocketIdFor(String studyChatId);

  Future<void> bind(String studyChatId, String pocketChatId);

  Future<void> clear(String studyChatId);
}

class SharedPreferencesPocketChatLinks implements PocketChatLinks {
  SharedPreferencesPocketChatLinks({SharedPreferences? prefs})
    : _prefsOverride = prefs;

  static const _key = 'ai_pocket_chat_links_v1';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _cached;

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ??
        (_cached ??= await SharedPreferences.getInstance());
  }

  @override
  Future<String?> pocketIdFor(String studyChatId) async {
    final map = await _read();
    final id = map[studyChatId];
    if (id == null || id.isEmpty) return null;
    return id;
  }

  @override
  Future<void> bind(String studyChatId, String pocketChatId) async {
    final studyId = studyChatId.trim();
    final pocketId = pocketChatId.trim();
    if (studyId.isEmpty || pocketId.isEmpty) return;
    final map = await _read();
    if (map[studyId] == pocketId) return;
    map[studyId] = pocketId;
    await _write(map);
  }

  @override
  Future<void> clear(String studyChatId) async {
    final map = await _read();
    if (map.remove(studyChatId) == null) return;
    await _write(map);
  }

  Future<Map<String, String>> _read() async {
    final raw = (await _prefs()).getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = _decode(raw);
    return decoded;
  }

  Future<void> _write(Map<String, String> map) async {
    await (await _prefs()).setString(_key, _encode(map));
  }
}

class MemoryPocketChatLinks implements PocketChatLinks {
  final Map<String, String> _links = {};

  @override
  Future<String?> pocketIdFor(String studyChatId) async => _links[studyChatId];

  @override
  Future<void> bind(String studyChatId, String pocketChatId) async {
    final studyId = studyChatId.trim();
    final pocketId = pocketChatId.trim();
    if (studyId.isEmpty || pocketId.isEmpty) return;
    _links[studyId] = pocketId;
  }

  @override
  Future<void> clear(String studyChatId) async {
    _links.remove(studyChatId);
  }
}

Map<String, String> _decode(String raw) {
  final pairs = raw.split('\n');
  final map = <String, String>{};
  for (final pair in pairs) {
    final split = pair.indexOf('\t');
    if (split <= 0) continue;
    final studyId = pair.substring(0, split).trim();
    final pocketId = pair.substring(split + 1).trim();
    if (studyId.isEmpty || pocketId.isEmpty) continue;
    map[studyId] = pocketId;
  }
  return map;
}

String _encode(Map<String, String> map) {
  return [
    for (final entry in map.entries) '${entry.key}\t${entry.value}',
  ].join('\n');
}
