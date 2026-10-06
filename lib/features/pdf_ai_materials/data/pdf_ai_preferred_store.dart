import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pdf_ai_material_models.dart';

class PdfAiPreferredKey {
  const PdfAiPreferredKey({required this.materialId, required this.type});

  final String materialId;
  final PdfAiMaterialType type;

  @override
  bool operator ==(Object other) =>
      other is PdfAiPreferredKey &&
      other.materialId == materialId &&
      other.type == type;

  @override
  int get hashCode => Object.hash(materialId, type);
}

abstract class PdfAiPreferredStore {
  Future<String?> read(PdfAiPreferredKey key);
  Future<void> write(PdfAiPreferredKey key, String generationId);
  Future<void> clear(PdfAiPreferredKey key);
}

class SharedPreferencesPdfAiPreferredStore implements PdfAiPreferredStore {
  SharedPreferencesPdfAiPreferredStore({this._prefs});

  SharedPreferences? _prefs;

  static String storageKey(PdfAiPreferredKey key) =>
      'pdf_ai_preferred_version/${key.materialId}/${key.type.storageValue}';

  Future<SharedPreferences> _ready() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> read(PdfAiPreferredKey key) async {
    final value = (await _ready()).getString(storageKey(key))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> write(PdfAiPreferredKey key, String generationId) async {
    final id = generationId.trim();
    if (id.isEmpty) {
      await clear(key);
      return;
    }
    await (await _ready()).setString(storageKey(key), id);
  }

  @override
  Future<void> clear(PdfAiPreferredKey key) async {
    await (await _ready()).remove(storageKey(key));
  }
}

class MemoryPdfAiPreferredStore implements PdfAiPreferredStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(PdfAiPreferredKey key) async {
    return _values[SharedPreferencesPdfAiPreferredStore.storageKey(key)];
  }

  @override
  Future<void> write(PdfAiPreferredKey key, String generationId) async {
    final id = generationId.trim();
    if (id.isEmpty) {
      await clear(key);
      return;
    }
    _values[SharedPreferencesPdfAiPreferredStore.storageKey(key)] = id;
  }

  @override
  Future<void> clear(PdfAiPreferredKey key) async {
    _values.remove(SharedPreferencesPdfAiPreferredStore.storageKey(key));
  }
}
