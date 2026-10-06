import 'dart:convert';

import '../../../core/database/app_database.dart';
import 'pdf_ai_material_models.dart';

abstract final class PdfAiVersionPicker {
  static PdfAiMaterial? pick({
    required List<PdfAiMaterial> materials,
    required PdfAiMaterialType type,
    String? selectedId,
    String? preferredId,
  }) {
    final history = [
      for (final item in materials)
        if (item.type == type.storageValue) item,
    ];
    if (history.isEmpty) return null;
    for (final id in [selectedId, preferredId]) {
      if (id == null || id.isEmpty) continue;
      for (final item in history) {
        if (item.id == id) return item;
      }
    }
    return history.first;
  }
}

abstract final class PdfAiManualJson {
  static const format = 'study-vault-pdf-ai';

  static String extractMarkdown(String raw, PdfAiMaterialType type) {
    var text = raw.trim();
    if (text.isEmpty) {
      throw FormatException('Paste JSON for this ${type.shortName}.');
    }
    final fenced = RegExp(
      r'^```(?:json)?\s*\n(.*)\n```$',
      dotAll: true,
    ).firstMatch(text);
    if (fenced != null) text = fenced.group(1)!.trim();

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException(
        'Could not parse JSON. Copy the instruction, generate it with ChatGPT, '
        'then paste the JSON here.',
      );
    }
    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
    if (decoded is! Map) {
      throw const FormatException(
        'JSON must be an object with a content field.',
      );
    }
    final study = decoded['study_materials'];
    if (study is Map) {
      final nested =
          _string(study[type.storageValue]) ?? _string(study[type.name]);
      if (nested != null) return nested;
    }
    final typed =
        _string(decoded[type.storageValue]) ?? _string(decoded[type.name]);
    if (typed != null) return typed;
    final content =
        _string(decoded['content']) ??
        _string(decoded['markdown']) ??
        _string(decoded['text']);
    if (content != null) return content;
    throw FormatException(
      'JSON has no ${type.shortName} content. Use "content" or '
      'study_materials.${type.storageValue}.',
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
