import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Codec between stored [fullExplanation] TEXT values and Quill [Document]s.
///
/// Storage format: Quill Delta JSON array encoded as a string.
/// Legacy values that are plain text are promoted to a simple paragraph
/// document in memory (lazy — nothing is rewritten at app startup).
abstract final class StudyNoteCodec {
  /// Returns `true` when [storedValue] looks like a Quill Delta JSON document.
  static bool isRichDeltaJson(String? storedValue) {
    if (storedValue == null) return false;
    final trimmed = storedValue.trimLeft();
    if (!trimmed.startsWith('[')) return false;

    try {
      final decoded = jsonDecode(storedValue);
      if (decoded is! List || decoded.isEmpty) return false;

      var hasInsert = false;
      for (final op in decoded) {
        if (op is! Map) return false;
        final hasValidKey =
            op.containsKey('insert') ||
            op.containsKey('retain') ||
            op.containsKey('delete');
        if (!hasValidKey) return false;
        if (op.containsKey('insert')) hasInsert = true;
      }
      return hasInsert;
    } on Object {
      return false;
    }
  }

  /// Decode a stored DB value into a Quill [Document].
  ///
  /// - `null` / empty → empty document
  /// - valid Delta JSON → rich document
  /// - anything else → legacy plain text as a single paragraph
  static Document decode(String? storedValue) {
    if (storedValue == null || storedValue.isEmpty) {
      return Document();
    }

    if (isRichDeltaJson(storedValue)) {
      try {
        final data = jsonDecode(storedValue) as List<dynamic>;
        return Document.fromJson(data);
      } on Object {
        // Fall through to legacy plain text.
      }
    }

    return _documentFromPlainText(storedValue);
  }

  /// Serialize a Quill [Document] to Delta JSON for SQLite storage.
  static String encode(Document document) {
    return jsonEncode(document.toDelta().toJson());
  }

  /// Encode for persistence, returning `null` when the note has no real text.
  static String? encodeOrNull(Document document) {
    if (isEffectivelyEmpty(document)) return null;
    return encode(document);
  }

  /// Whether the document has no meaningful text content.
  static bool isEffectivelyEmpty(Document document) {
    return document.toPlainText().trim().isEmpty;
  }

  /// Whether a stored value has meaningful content (rich or legacy).
  static bool hasContent(String? storedValue) {
    if (storedValue == null || storedValue.isEmpty) return false;
    return plainTextPreview(storedValue).trim().isNotEmpty;
  }

  /// Extract plain text suitable for list previews, search indexing, etc.
  ///
  /// Collapses whitespace and optionally truncates with an ellipsis.
  static String plainTextPreview(String? storedValue, {int? maxLength}) {
    if (storedValue == null || storedValue.isEmpty) return '';

    final plain = decode(storedValue).toPlainText().replaceAll('\uFFFC', '');
    final collapsed = plain
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');

    if (maxLength == null || collapsed.length <= maxLength) {
      return collapsed;
    }
    if (maxLength <= 1) return '…';
    return '${collapsed.substring(0, maxLength - 1).trimRight()}…';
  }

  static Document _documentFromPlainText(String text) {
    final document = Document();
    if (text.isEmpty) return document;
    document.insert(0, text);
    return document;
  }
}
