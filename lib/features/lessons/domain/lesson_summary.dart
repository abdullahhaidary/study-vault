import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:uuid/uuid.dart';

import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../study_pins/domain/study_note_codec.dart';

/// The single, editable summary of a lesson.
///
/// Stored as a lesson-owned `study_notes` row whose id is derived from the
/// lesson id, so two offline devices create the same row instead of two.
abstract final class LessonSummary {
  static const title = 'Lesson Summary';

  static String noteIdFor(String lessonId) => const Uuid().v5(
    Namespace.url.value,
    'study-vault:lesson-summary:$lessonId',
  );

  /// Appends [markdown] (optionally under a `## heading`) to the stored Quill
  /// value. An empty summary is replaced instead of appended to.
  static String append(String? stored, String markdown, {String? heading}) {
    final body = markdown.trim();
    final label = heading?.trim();
    final addition = label == null || label.isEmpty
        ? body
        : '## $label\n\n$body';
    final added = MarkdownToQuill.toDocument(addition);
    final existing = StudyNoteCodec.decode(stored);
    if (StudyNoteCodec.isEffectivelyEmpty(existing)) {
      return StudyNoteCodec.encode(added);
    }
    final ops = [
      ...existing.toDelta().toJson(),
      {'insert': '\n'},
      ...added.toDelta().toJson(),
    ];
    return StudyNoteCodec.encode(Document.fromJson(ops));
  }
}

/// Text pasted into "Add to summary": plain text/Markdown or JSON.
///
/// Accepted JSON: a string; an object with `content`, `summary`, `markdown`,
/// or `text` (plus optional `title`/`heading`); an object with a list under
/// `sections`, `items`, `summaries`, or `study_materials`; or a list of any of
/// these.
abstract final class LessonSummaryInput {
  static const _textKeys = ['content', 'summary', 'markdown', 'text'];
  static const _listKeys = [
    'sections',
    'items',
    'summaries',
    'study_materials',
  ];

  /// Returns the Markdown to append. Throws [FormatException] when nothing
  /// usable was supplied.
  static String parse(String raw) {
    final text = _stripJsonFence(raw.trim());
    if (text.isEmpty) throw const FormatException('Nothing to add.');
    if (!text.startsWith('{') &&
        !text.startsWith('[') &&
        !text.startsWith('"')) {
      return text;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return text;
    }
    final blocks = _blocks(decoded);
    if (blocks.isEmpty) {
      throw const FormatException(
        'The JSON has no "content", "summary", "markdown", or "text" field.',
      );
    }
    return blocks.join('\n\n');
  }

  static List<String> _blocks(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    if (value is List) return [for (final item in value) ..._blocks(item)];
    if (value is! Map) return const [];

    for (final key in _listKeys) {
      if (value[key] is List) return _blocks(value[key]);
    }
    for (final key in _textKeys) {
      final body = _blocks(value[key]);
      if (body.isEmpty) continue;
      final heading = value['title'] ?? value['heading'];
      if (heading is String && heading.trim().isNotEmpty) {
        return ['## ${heading.trim()}\n\n${body.join('\n\n')}'];
      }
      return body;
    }
    return const [];
  }

  static String _stripJsonFence(String text) {
    final match = RegExp(
      r'^```(?:json)?\s*\n([\s\S]*?)\n```$',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim() ?? text;
  }
}
