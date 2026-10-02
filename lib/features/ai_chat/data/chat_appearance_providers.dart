import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/chat_appearance.dart';

abstract class ChatAppearanceStore {
  Future<ChatAppearance> load();
  Future<void> save(ChatAppearance appearance);
}

class SharedPreferencesChatAppearanceStore implements ChatAppearanceStore {
  SharedPreferencesChatAppearanceStore([this._preferences]);

  static const _key = 'ai_chat_appearance_v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() => _preferences == null
      ? SharedPreferences.getInstance()
      : Future.value(_preferences);

  @override
  Future<ChatAppearance> load() async {
    final raw = (await _prefs()).getString(_key);
    if (raw == null) return ChatAppearance.defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return ChatAppearance.defaults;
      return ChatAppearance.fromJson(decoded);
    } on Object {
      return ChatAppearance.defaults;
    }
  }

  @override
  Future<void> save(ChatAppearance appearance) async {
    await (await _prefs()).setString(_key, jsonEncode(appearance.toJson()));
  }
}

abstract class ChatBackgroundImageStore {
  Future<String?> pickAndPersist();
  Future<void> remove(String? imagePath);
}

class LocalChatBackgroundImageStore implements ChatBackgroundImageStore {
  static const _baseName = 'ai_chat_background';

  @override
  Future<String?> pickAndPersist() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return null;

    final directory = await getApplicationSupportDirectory();
    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension =
        {'.jpg', '.jpeg', '.png', '.webp', '.gif'}.contains(extension)
        ? extension
        : '.jpg';
    final destination = p.join(directory.path, '$_baseName$safeExtension');
    if (p.equals(sourcePath, destination)) return destination;

    for (final candidate in directory.listSync().whereType<File>()) {
      if (p.basename(candidate.path).startsWith(_baseName)) {
        await candidate.delete();
      }
    }
    await File(sourcePath).copy(destination);
    return destination;
  }

  @override
  Future<void> remove(String? imagePath) async {
    if (imagePath == null) return;
    final file = File(imagePath);
    if (await file.exists()) await file.delete();
  }
}

final chatAppearanceStoreProvider = Provider<ChatAppearanceStore>((ref) {
  return SharedPreferencesChatAppearanceStore();
});

final chatBackgroundImageStoreProvider = Provider<ChatBackgroundImageStore>((
  ref,
) {
  return LocalChatBackgroundImageStore();
});

final chatAppearanceProvider =
    StateNotifierProvider<ChatAppearanceController, AsyncValue<ChatAppearance>>(
      (ref) {
        return ChatAppearanceController(
          ref.watch(chatAppearanceStoreProvider),
          ref.watch(chatBackgroundImageStoreProvider),
        );
      },
    );

class ChatAppearanceController
    extends StateNotifier<AsyncValue<ChatAppearance>> {
  ChatAppearanceController(this._store, this._imageStore)
    : super(const AsyncLoading()) {
    _load();
  }

  final ChatAppearanceStore _store;
  final ChatBackgroundImageStore _imageStore;
  int _revision = 0;

  Future<void> _load() async {
    final revision = _revision;
    final loaded = await AsyncValue.guard(_store.load);
    if (revision == _revision) state = loaded;
  }

  Future<void> update(ChatAppearance appearance) async {
    _revision++;
    state = AsyncData(appearance);
    await _store.save(appearance);
  }

  Future<void> applyPreset(ChatAppearancePreset preset) =>
      update(ChatAppearance.fromPreset(preset));

  Future<bool> chooseBackgroundImage() async {
    final current = state.valueOrNull ?? ChatAppearance.defaults;
    final path = await _imageStore.pickAndPersist();
    if (path == null) return false;
    await update(
      current.copyWith(
        backgroundKind: ChatBackgroundKind.image,
        backgroundImagePath: path,
      ),
    );
    return true;
  }

  Future<void> clearBackgroundImage() async {
    final current = state.valueOrNull ?? ChatAppearance.defaults;
    await _imageStore.remove(current.backgroundImagePath);
    await update(
      current.copyWith(
        backgroundKind: ChatBackgroundKind.theme,
        clearBackgroundImage: true,
      ),
    );
  }

  Future<void> reset() async {
    final current = state.valueOrNull;
    await _imageStore.remove(current?.backgroundImagePath);
    await update(ChatAppearance.defaults);
  }
}
