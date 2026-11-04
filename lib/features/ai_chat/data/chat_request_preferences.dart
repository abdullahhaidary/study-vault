import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local style snapshots. Existing chats keep their system prefix when
/// Settings changes. No credentials or source text are stored here.
abstract class ChatRequestPreferences {
  Future<String> capture(
    String chatId,
    String modelId,
    Future<String?> Function() load,
  );
  Future<void> remove(String chatId);
  Future<void> clear();
}

class MemoryChatRequestPreferences implements ChatRequestPreferences {
  final Map<String, Map<String, String>> values = {};
  @override
  Future<String> capture(
    String chatId,
    String modelId,
    Future<String?> Function() load,
  ) async {
    final models = values.putIfAbsent(chatId, () => {});
    return models[modelId] ??= await load() ?? '';
  }

  @override
  Future<void> remove(String chatId) async {
    values.remove(chatId);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}

class LocalChatRequestPreferences implements ChatRequestPreferences {
  static const _prefix = 'ai_chat_request_preferences_v1_';
  Future<void> _writes = Future.value();
  Future<T> _serial<T>(Future<T> Function() work) {
    final run = _writes.then((_) => work());
    _writes = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  @override
  Future<String> capture(
    String chatId,
    String modelId,
    Future<String?> Function() load,
  ) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$chatId');
    Map<String, dynamic> models;
    try {
      models = raw == null
          ? {}
          : (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on Object {
      models = {};
    }
    if (models[modelId] is String) return models[modelId] as String;
    final style = await load() ?? '';
    models[modelId] = style;
    await prefs.setString('$_prefix$chatId', jsonEncode(models));
    return style;
  });
  @override
  Future<void> remove(String chatId) => _serial(() async {
    await (await SharedPreferences.getInstance()).remove('$_prefix$chatId');
  });
  @override
  Future<void> clear() => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  });
}
