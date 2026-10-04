import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/markdown/chart_spec.dart';
import '../../study_pins/domain/study_note_codec.dart';

/// Converts a Quill document back into markdown — the inverse of
/// [MarkdownToQuill], covering the same pragmatic subset (headings, lists,
/// quotes, code fences, dividers, bold/italic/code/links).
///
/// Code blocks whose body is a valid chart spec are re-tagged ```chart so
/// charts survive a round trip through the rich editor.
abstract final class QuillToMarkdown {
  static String fromStored(String? storedValue) =>
      fromDocument(StudyNoteCodec.decode(storedValue));

  static String fromDocument(Document document) {
    final lines = _lines(document);
    final blocks = <String>[];
    final ordered = <int, int>{}; // indent → running number

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final kind = line.kind;

      if (kind == _Kind.code) {
        final buffer = <String>[];
        while (i < lines.length && lines[i].kind == _Kind.code) {
          buffer.add(lines[i].text);
          i++;
        }
        final body = buffer.join('\n');
        final lang = ChartSpec.tryParse(body) != null ? ChartSpec.language : '';
        blocks.add('```$lang\n$body\n```');
        ordered.clear();
        continue;
      }

      if (kind == _Kind.bullet || kind == _Kind.ordered) {
        final buffer = <String>[];
        while (i < lines.length &&
            (lines[i].kind == _Kind.bullet || lines[i].kind == _Kind.ordered)) {
          final l = lines[i];
          final pad = '  ' * l.indent;
          if (l.kind == _Kind.bullet) {
            buffer.add('$pad- ${l.text}');
          } else {
            final n = (ordered[l.indent] ?? 0) + 1;
            ordered[l.indent] = n;
            buffer.add('$pad$n. ${l.text}');
          }
          i++;
        }
        blocks.add(buffer.join('\n'));
        ordered.clear();
        continue;
      }

      ordered.clear();
      if (kind == _Kind.quote) {
        final buffer = <String>[];
        while (i < lines.length && lines[i].kind == _Kind.quote) {
          buffer.add('> ${lines[i].text}');
          i++;
        }
        blocks.add(buffer.join('\n'));
        continue;
      }

      i++;
      switch (kind) {
        case _Kind.divider:
          blocks.add('---');
        case _Kind.header:
          blocks.add('${'#' * line.level} ${line.text}');
        case _Kind.paragraph:
          if (line.text.trim().isNotEmpty) blocks.add(line.text);
        case _Kind.code:
        case _Kind.bullet:
        case _Kind.ordered:
        case _Kind.quote:
          break;
      }
    }
    return blocks.join('\n\n').trim();
  }

  /// Splits the delta into logical lines with their block attributes.
  static List<_Line> _lines(Document document) {
    final lines = <_Line>[];
    var inline = StringBuffer();
    var hasDivider = false;

    void finish(Map<String, dynamic>? lineAttrs) {
      lines.add(_Line.from(inline.toString(), lineAttrs, divider: hasDivider));
      inline = StringBuffer();
      hasDivider = false;
    }

    for (final op in document.toDelta().toList()) {
      final data = op.data;
      final attrs = op.attributes;
      if (data is Map) {
        if (data.containsKey('divider')) hasDivider = true;
        continue;
      }
      final text = data as String;
      if (text == '\n' || RegExp(r'^\n+$').hasMatch(text)) {
        for (var k = 0; k < text.length; k++) {
          finish(attrs);
        }
        continue;
      }
      final parts = text.split('\n');
      for (var p = 0; p < parts.length; p++) {
        if (parts[p].isNotEmpty) inline.write(_inline(parts[p], attrs));
        if (p < parts.length - 1) finish(null);
      }
    }
    if (inline.isNotEmpty || hasDivider) finish(null);
    return lines;
  }

  static String _inline(String text, Map<String, dynamic>? attrs) {
    if (attrs == null || attrs.isEmpty) return text;
    // Keep surrounding whitespace outside the markers so `** x**` can't occur.
    final lead = RegExp(r'^\s*').firstMatch(text)!.group(0)!;
    final trail = RegExp(r'\s*$').firstMatch(text)!.group(0)!;
    var core = text.substring(lead.length, text.length - trail.length);
    if (core.isEmpty) return text;

    if (attrs['code'] == true) {
      core = '`$core`';
    } else {
      final bold = attrs['bold'] == true;
      final italic = attrs['italic'] == true;
      if (bold && italic) {
        core = '***$core***';
      } else if (bold) {
        core = '**$core**';
      } else if (italic) {
        core = '*$core*';
      }
      if (attrs['strike'] == true) core = '~~$core~~';
    }
    final link = attrs['link'];
    if (link is String && link.isNotEmpty) core = '[$core]($link)';
    return '$lead$core$trail';
  }
}

enum _Kind { paragraph, header, bullet, ordered, quote, code, divider }

class _Line {
  const _Line(this.kind, this.text, {this.level = 1, this.indent = 0});

  final _Kind kind;
  final String text;
  final int level;
  final int indent;

  factory _Line.from(
    String text,
    Map<String, dynamic>? attrs, {
    required bool divider,
  }) {
    if (divider && text.trim().isEmpty) return const _Line(_Kind.divider, '');
    final a = attrs ?? const <String, dynamic>{};
    final indent = (a['indent'] as num?)?.toInt() ?? 0;
    if (a['header'] != null) {
      return _Line(_Kind.header, text, level: (a['header'] as num).toInt());
    }
    if (a['code-block'] != null && a['code-block'] != false) {
      return _Line(_Kind.code, text);
    }
    if (a['blockquote'] == true) return _Line(_Kind.quote, text);
    return switch (a['list']) {
      'bullet' ||
      'unchecked' ||
      'checked' => _Line(_Kind.bullet, text, indent: indent),
      'ordered' => _Line(_Kind.ordered, text, indent: indent),
      _ => _Line(_Kind.paragraph, text),
    };
  }
}
