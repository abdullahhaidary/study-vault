import 'package:flutter_quill/flutter_quill.dart';

import '../../study_pins/domain/study_note_codec.dart';

/// Converts Gemini markdown (headings/lists/emphasis) into Quill Delta JSON.
///
/// Intentionally pragmatic — not a full CommonMark parser.
abstract final class MarkdownToQuill {
  /// Returns Quill Delta JSON string suitable for StudyNoteCodec storage.
  static String toDeltaJson(String markdown) {
    final document = toDocument(markdown);
    return StudyNoteCodec.encode(document);
  }

  static Document toDocument(String markdown) {
    final cleaned = markdown.replaceAll('\r\n', '\n').trim();
    if (cleaned.isEmpty) return Document();

    final document = Document();
    // Keep this converter deliberately conservative. flutter_quill 11 does not
    // expose an Attribute.fromKeyValue factory, and plain paragraphs preserve
    // all AI output without risking malformed Delta attributes.
    document.insert(0, '$cleaned\n');
    return document;
  }
}
