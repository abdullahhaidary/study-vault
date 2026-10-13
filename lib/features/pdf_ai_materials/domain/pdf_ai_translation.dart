import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Which text the reader shows for an AI study material.
enum PdfAiLanguage {
  original,
  persian;

  /// `pdf_ai_material_translations.language` value.
  String get storageValue => switch (this) {
    PdfAiLanguage.original => 'original',
    PdfAiLanguage.persian => 'fa',
  };

  String get shortLabel => switch (this) {
    PdfAiLanguage.original => 'EN',
    PdfAiLanguage.persian => 'فا',
  };
}

/// Text with code, chart and slide blocks swapped for placeholders so the
/// AI translator cannot alter them.
class PdfAiProtectedText {
  const PdfAiProtectedText(this.text, this.blocks);

  final String text;
  final List<String> blocks;

  /// Puts the protected blocks back. Throws [FormatException] when the
  /// translation lost or duplicated a placeholder.
  String restore(String translated) {
    var result = translated;
    for (var i = 0; i < blocks.length; i++) {
      final token = PdfAiTranslation.placeholder(i);
      if (token.allMatches(result).length != 1) {
        throw FormatException('Translation lost protected block $i.');
      }
      result = result.replaceFirst(token, blocks[i]);
    }
    if (RegExp(r'⟦SV\d+⟧').hasMatch(result)) {
      throw const FormatException('Translation invented a placeholder.');
    }
    return result;
  }
}

/// Section-aligned translation of AI study materials.
///
/// The reader renders a material as [segments]; a translation is stored as
/// the same number of segments joined by [_marker], so section N of the
/// original always corresponds to section N of the translation. That keeps
/// the reading position when toggling languages.
abstract final class PdfAiTranslation {
  static const targetCharacters = 3500;
  static const segmentMaxOutputTokens = 8192;
  static const _marker = '<!-- sv-segment -->';
  static final _markerLine = RegExp(
    r'^[ \t]*<!--[ \t]*sv-segment[ \t]*-->[ \t]*\n?',
    multiLine: true,
  );

  /// Reading sections: split on blank lines once [targetCharacters] is
  /// reached, never inside a fenced code block.
  static List<String> segments(String content) {
    final chunks = <String>[];
    final buffer = StringBuffer();
    var insideCodeFence = false;
    for (final line in content.split('\n')) {
      if (line.trimLeft().startsWith('```')) insideCodeFence = !insideCodeFence;
      buffer.writeln(line);
      if (!insideCodeFence &&
          buffer.length >= targetCharacters &&
          line.trim().isEmpty) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());
    return List.unmodifiable(chunks);
  }

  /// Storage form of translated segments.
  static String join(List<String> segments) => [
    for (final segment in segments)
      segment.endsWith('\n') ? segment : '$segment\n',
  ].join('$_marker\n');

  /// Segments of a stored translation (one entry when it has no markers).
  static List<String> split(String stored) =>
      List.unmodifiable(stored.split(_markerLine));

  /// Readable Markdown of a stored translation, for copying or AI context.
  static String plain(String stored) => split(stored).join();

  /// Identity of the source text a translation was made from.
  static String sourceHash(String content) =>
      sha256.convert(utf8.encode(content)).toString();

  static RegExp placeholder(int index) => RegExp('⟦SV$index⟧');

  static final _protected = RegExp(
    r'^[ \t]*(`{3,}|~{3,})[^\n]*\n[\s\S]*?^[ \t]*\1[ \t]*$'
    r'|^[ \t]*\$\$[\s\S]*?\$\$[ \t]*$'
    r'|^[ \t]*<!--[ \t]*slide[ \t]*-->[ \t]*$',
    multiLine: true,
    caseSensitive: false,
  );

  static PdfAiProtectedText protect(String segment) {
    final blocks = <String>[];
    final text = segment.replaceAllMapped(_protected, (match) {
      blocks.add(match[0]!);
      return '⟦SV${blocks.length - 1}⟧';
    });
    return PdfAiProtectedText(text, List.unmodifiable(blocks));
  }

  static int headingCount(String markdown) {
    final withoutCode = protect(markdown).text;
    return RegExp(
      r'^[ \t]{0,3}#{1,6}[ \t]',
      multiLine: true,
    ).allMatches(withoutCode).length;
  }

  static const systemMessage =
      'You are a professional English → Persian (Farsi) translator for '
      'university study notes. You translate faithfully and never summarise, '
      'explain, or add content.';

  static List<Map<String, String>> messages(
    String protectedSegment, {
    bool strict = false,
  }) => [
    {'role': 'system', 'content': systemMessage},
    {
      'role': 'user',
      'content':
          'Translate this Markdown study material into natural, fluent '
          'Persian (Farsi) for a university student.\n'
          'Rules:\n'
          '- Keep the Markdown structure identical: the same headings and '
          'heading levels, the same order, the same number of bullets, '
          'numbered items, table rows and columns, bold/italic emphasis and '
          'blank lines.\n'
          '- Translate every sentence. Do not add, remove, shorten, or '
          'explain anything.\n'
          '- Copy every token like ⟦SV0⟧ exactly once, unchanged, in the same '
          'place. They stand for code, formulas, or charts.\n'
          '- Keep formulas, LaTeX, numbers, units, URLs, inline code and '
          'variable names unchanged.\n'
          '- For a technical term, write the Persian term followed by the '
          'English term in parentheses the first time it appears; keep the '
          'English term alone when there is no established Persian one.\n'
          '- Reply with the translated Markdown only.'
          '${strict ? '\n- Your previous answer changed the structure. Keep exactly the same headings and every ⟦SV…⟧ token.' : ''}'
          '\n\nMARKDOWN:\n$protectedSegment',
    },
  ];
}
