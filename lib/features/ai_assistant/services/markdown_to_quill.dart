import 'package:flutter_quill/flutter_quill.dart';

import '../../study_pins/domain/study_note_codec.dart';

/// Converts Gemini markdown (headings/lists/emphasis) into Quill Delta JSON.
///
/// Pragmatic subset of CommonMark — enough for study notes, not a full parser.
abstract final class MarkdownToQuill {
  /// Returns Quill Delta JSON string suitable for StudyNoteCodec storage.
  static String toDeltaJson(String markdown) {
    final document = toDocument(markdown);
    return StudyNoteCodec.encode(document);
  }

  static Document toDocument(String markdown) {
    var cleaned = markdown.replaceAll('\r\n', '\n').trim();
    cleaned = _stripOuterFence(cleaned);
    if (cleaned.isEmpty) return Document();

    final ops = <Map<String, dynamic>>[];
    final lines = cleaned.split('\n');
    var inCodeBlock = false;

    for (final line in lines) {
      final trimmedStart = line.trimLeft();

      if (trimmedStart.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        if (!inCodeBlock) {
          // Closing fence — ensure a trailing break after the block.
          if (ops.isEmpty ||
              !(ops.last['insert'] is String &&
                  (ops.last['insert'] as String).endsWith('\n'))) {
            ops.add({'insert': '\n'});
          }
        }
        continue;
      }

      if (inCodeBlock) {
        ops.add({'insert': line});
        ops.add({
          'insert': '\n',
          'attributes': {'code-block': true},
        });
        continue;
      }

      if (line.trim().isEmpty) {
        ops.add({'insert': '\n'});
        continue;
      }

      // Horizontal rule: `--`, `---`, `***`, `___` (alone on a line).
      if (_isHorizontalRule(line)) {
        ops.add({
          'insert': {'divider': 'hr'},
        });
        ops.add({'insert': '\n'});
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length.clamp(1, 6);
        _appendInline(ops, heading.group(2)!.trimRight());
        ops.add({
          'insert': '\n',
          'attributes': {'header': level},
        });
        continue;
      }

      final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (quote != null) {
        _appendInline(ops, quote.group(1)!);
        ops.add({
          'insert': '\n',
          'attributes': {'blockquote': true},
        });
        continue;
      }

      final ul = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
      if (ul != null) {
        _appendInline(ops, ul.group(2)!);
        final attrs = <String, dynamic>{'list': 'bullet'};
        final indent = _indentLevel(ul.group(1)!);
        if (indent > 0) attrs['indent'] = indent;
        ops.add({'insert': '\n', 'attributes': attrs});
        continue;
      }

      final ol = RegExp(r'^(\s*)\d+\.\s+(.*)$').firstMatch(line);
      if (ol != null) {
        _appendInline(ops, ol.group(2)!);
        final attrs = <String, dynamic>{'list': 'ordered'};
        final indent = _indentLevel(ol.group(1)!);
        if (indent > 0) attrs['indent'] = indent;
        ops.add({'insert': '\n', 'attributes': attrs});
        continue;
      }

      _appendInline(ops, line);
      ops.add({'insert': '\n'});
    }

    if (ops.isEmpty) {
      ops.add({'insert': '\n'});
    } else {
      final last = ops.last['insert'];
      if (last is! String || !last.endsWith('\n')) {
        ops.add({'insert': '\n'});
      }
    }

    try {
      return Document.fromJson(ops);
    } on Object {
      // Fall back to plain paragraph if Delta is rejected.
      final document = Document();
      document.insert(0, '$cleaned\n');
      return document;
    }
  }

  /// True when [plain] looks like structured markdown from AI (not casual text).
  static bool looksLikeMarkdown(String plain) {
    final text = plain.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'^#{1,6}\s+\S', multiLine: true).hasMatch(text)) return true;
    if (RegExp(r'^[-*+]\s+\S', multiLine: true).hasMatch(text)) return true;
    if (RegExp(r'^\d+\.\s+\S', multiLine: true).hasMatch(text)) return true;
    if (RegExp(r'^>\s+\S', multiLine: true).hasMatch(text)) return true;
    if (RegExp(
      r'^(?:-{2,}|_{3,}|\*{3,})\s*$',
      multiLine: true,
    ).hasMatch(text)) {
      return true;
    }
    if (text.contains('```')) return true;
    // Require paired emphasis markers so stray asterisks don't trigger.
    if (RegExp(r'\*\*[^*\n]+\*\*').hasMatch(text)) return true;
    if (RegExp(r'__[^_\n]+__').hasMatch(text)) return true;
    return false;
  }

  /// Markdown thematic break / horizontal rule on its own line.
  ///
  /// Accepts `--` and longer dash runs, plus CommonMark `***` / `___`.
  static bool _isHorizontalRule(String line) {
    return RegExp(r'^(?:-{2,}|_{3,}|\*{3,})\s*$').hasMatch(line.trim());
  }

  static String _stripOuterFence(String text) {
    final match = RegExp(
      r'^```(?:markdown|md)?\s*\n([\s\S]*?)\n```$',
      caseSensitive: false,
    ).firstMatch(text.trim());
    return match?.group(1)?.trim() ?? text;
  }

  static int _indentLevel(String leadingWhitespace) {
    final spaces = leadingWhitespace.replaceAll('\t', '  ').length;
    return (spaces ~/ 2).clamp(0, 3);
  }

  static void _appendInline(List<Map<String, dynamic>> ops, String text) {
    if (text.isEmpty) return;

    final pattern = RegExp(
      r'(`[^`\n]+`)'
      r'|(\*\*\*[^*\n]+?\*\*\*)'
      r'|(___[^_\n]+?___)'
      r'|(\*\*[^*\n]+?\*\*)'
      r'|(__[^_\n]+?__)'
      r'|(\*[^*\n]+?\*)'
      r'|(_[^_\n]+?_)'
      r'|(\[[^\]]+\]\([^)]+\))',
    );

    var start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        ops.add({'insert': text.substring(start, match.start)});
      }
      final token = match.group(0)!;
      if (token.startsWith('`') && token.endsWith('`')) {
        final inner = token.substring(1, token.length - 1);
        ops.add({
          'insert': inner,
          'attributes': {'code': true},
        });
      } else if (token.startsWith('***') || token.startsWith('___')) {
        final inner = token.substring(3, token.length - 3);
        ops.add({
          'insert': inner,
          'attributes': {'bold': true, 'italic': true},
        });
      } else if (token.startsWith('**') || token.startsWith('__')) {
        final inner = token.substring(2, token.length - 2);
        ops.add({
          'insert': inner,
          'attributes': {'bold': true},
        });
      } else if (token.startsWith('*') || token.startsWith('_')) {
        final inner = token.substring(1, token.length - 1);
        ops.add({
          'insert': inner,
          'attributes': {'italic': true},
        });
      } else if (token.startsWith('[')) {
        final link = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(token);
        if (link != null) {
          ops.add({
            'insert': link.group(1)!,
            'attributes': {'link': link.group(2)!},
          });
        } else {
          ops.add({'insert': token});
        }
      } else {
        ops.add({'insert': token});
      }
      start = match.end;
    }
    if (start < text.length) {
      ops.add({'insert': text.substring(start)});
    }
  }
}
