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
    final text = _normalizePaste(raw);
    if (text.isEmpty) {
      throw FormatException('Paste JSON for this ${type.shortName}.');
    }

    final decoded = _tryDecode(text);
    if (decoded != null) {
      return _markdownFromDecoded(decoded, type);
    }

    final recovered = _recoverBrokenStringField(text, type);
    if (recovered != null) return recovered;

    throw const FormatException(
      'Could not parse JSON. Copy the instruction, generate it with ChatGPT, '
      'then paste the JSON here.',
    );
  }

  static String _normalizePaste(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return text;

    // Prefer the complete object before looking for a fence. Broken Markdown
    // strings may themselves contain fenced code blocks.
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return text.substring(start, end + 1).trim();
    }

    // Also accept a fenced JSON string payload when no object is present.
    final fences = RegExp(
      r'```(?:json)?\s*\n(.*?)```',
      dotAll: true,
    ).allMatches(text);
    for (final fence in fences) {
      final body = fence.group(1)!.trim();
      if (body.startsWith('"')) return body;
    }
    return text;
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      final repaired = _stripTrailingObjectComma(text);
      if (repaired == text) return null;
      try {
        return jsonDecode(repaired);
      } on FormatException {
        return null;
      }
    }
  }

  static String _stripTrailingObjectComma(String text) {
    final closingBrace = text.lastIndexOf('}');
    if (closingBrace < 0) return text;
    var index = closingBrace - 1;
    while (index >= 0 && text[index].trim().isEmpty) {
      index--;
    }
    if (index < 0 || text[index] != ',') return text;
    return text.substring(0, index) + text.substring(index + 1);
  }

  static String _markdownFromDecoded(Object decoded, PdfAiMaterialType type) {
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

  /// Best-effort recovery when models leave raw `"` inside a markdown string.
  ///
  /// Does not convert nested JSON objects into markdown.
  static String? _recoverBrokenStringField(
    String text,
    PdfAiMaterialType type,
  ) {
    final keys = <String>[
      'content',
      'markdown',
      'text',
      type.storageValue,
      type.name,
    ];
    for (final key in keys) {
      final value = _extractBrokenJsonStringValue(text, key);
      if (value != null) return value;
    }

    final studyKey = RegExp(r'"study_materials"\s*:\s*\{').firstMatch(text);
    if (studyKey != null) {
      final fromStudy = text.substring(studyKey.end - 1);
      for (final key in [type.storageValue, type.name]) {
        final value = _extractBrokenJsonStringValue(fromStudy, key);
        if (value != null) return value;
      }
    }
    return null;
  }

  static String? _extractBrokenJsonStringValue(String text, String key) {
    final keyMatch = RegExp(
      '"${RegExp.escape(key)}"\\s*:\\s*',
    ).firstMatch(text);
    if (keyMatch == null) return null;

    final afterKey = text.substring(keyMatch.end).trimLeft();
    if (!afterKey.startsWith('"')) {
      // Nested object/array — leave rejection to the normal path.
      return null;
    }

    final bodyAndRest = afterKey.substring(1);

    // Prefer a well-formed JSON string only when its closer is a real field
    // terminator (not a raw quote mid-markdown).
    final scanned = _scanJsonStringField(afterKey);
    if (scanned != null) return scanned;

    // Typical AI payload: markdown field is last → ...raw"\n}
    final endOfObject = RegExp(r'"\s*,?\s*\}\s*$').firstMatch(bodyAndRest);
    if (endOfObject != null) {
      final body = bodyAndRest.substring(0, endOfObject.start);
      final unescaped = _unescapeJsonStringBody(body).trim();
      return unescaped.isEmpty ? null : unescaped;
    }

    // Field is followed by another key: ...raw" , "nextKey":
    final nextKey = RegExp(
      r'"\s*,\s*"[A-Za-z_][A-Za-z0-9_]*"\s*:',
    ).allMatches(bodyAndRest);
    if (nextKey.isNotEmpty) {
      final match = nextKey.last;
      final body = bodyAndRest.substring(0, match.start);
      final unescaped = _unescapeJsonStringBody(body).trim();
      return unescaped.isEmpty ? null : unescaped;
    }
    return null;
  }

  /// Decodes a JSON string field when escaping is valid and the value is
  /// followed by `,` / `}` / `]`.
  static String? _scanJsonStringField(String quoted) {
    if (!quoted.startsWith('"')) return null;
    final buffer = StringBuffer();
    for (var i = 1; i < quoted.length; i++) {
      final char = quoted[i];
      if (char == '"') {
        final rest = quoted.substring(i + 1).trimLeft();
        if (rest.isEmpty ||
            rest.startsWith(',') ||
            rest.startsWith('}') ||
            rest.startsWith(']')) {
          final value = buffer.toString().trim();
          return value.isEmpty ? null : value;
        }
        // Quote was mid-value (broken escaping); let loose recovery handle it.
        return null;
      }
      if (char != r'\') {
        buffer.write(char);
        continue;
      }
      if (i + 1 >= quoted.length) return null;
      i++;
      final escape = quoted[i];
      switch (escape) {
        case '"':
        case r'\':
        case '/':
          buffer.write(escape);
        case 'b':
          buffer.write('\b');
        case 'f':
          buffer.write('\f');
        case 'n':
          buffer.write('\n');
        case 'r':
          buffer.write('\r');
        case 't':
          buffer.write('\t');
        case 'u':
          if (i + 4 >= quoted.length) return null;
          final hex = quoted.substring(i + 1, i + 5);
          final code = int.tryParse(hex, radix: 16);
          if (code == null) return null;
          buffer.writeCharCode(code);
          i += 4;
        default:
          return null;
      }
    }
    return null;
  }

  static String _unescapeJsonStringBody(String body) {
    final buffer = StringBuffer();
    for (var i = 0; i < body.length; i++) {
      final char = body[i];
      if (char != r'\') {
        buffer.write(char);
        continue;
      }
      if (i + 1 >= body.length) {
        buffer.write(r'\');
        break;
      }
      i++;
      final escape = body[i];
      switch (escape) {
        case '"':
        case r'\':
        case '/':
          buffer.write(escape);
        case 'b':
        case 'f':
        case 'r':
        case 't':
          // In malformed AI output these are commonly the beginning of LaTeX
          // commands such as \beta, \frac, or \theta, not control escapes.
          buffer
            ..write(r'\')
            ..write(escape);
        case 'n':
          buffer.write('\n');
        case 'u':
          if (i + 4 < body.length) {
            final hex = body.substring(i + 1, i + 5);
            final code = int.tryParse(hex, radix: 16);
            if (code != null) {
              buffer.writeCharCode(code);
              i += 4;
              break;
            }
          }
          buffer
            ..write(r'\')
            ..write(escape);
        default:
          buffer
            ..write(r'\')
            ..write(escape);
      }
    }
    return buffer.toString();
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
