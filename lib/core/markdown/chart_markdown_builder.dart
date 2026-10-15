import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'chart_block.dart';
import 'chart_spec.dart';
import 'math_markdown.dart';
import 'notation_block.dart';
import 'notation_spec.dart';
import 'study_code_block.dart';

/// Renders fenced ```chart blocks as charts; other code blocks use the
/// ChatGPT-style highlighted [StudyCodeBlock].
///
/// Usage: `MarkdownBody(builders: chartMarkdownBuilders(styleSheet), ...)`.
Map<String, MarkdownElementBuilder> chartMarkdownBuilders([
  MarkdownStyleSheet? styleSheet,
]) => {
  'pre': ChartCodeBlockBuilder(),
  'notation': NotationElementBuilder(),
  'math-inline': MathElementBuilder(display: false),
  'math-block': MathElementBuilder(display: true),
};

class ChartCodeBlockBuilder extends MarkdownElementBuilder {
  ChartCodeBlockBuilder();

  @override
  bool isBlockElement() => true;

  // Text is read back from the element in [visitElementAfterWithContext].
  // A placeholder is returned (instead of null) so flutter_markdown closes
  // its inline scope; the block widget we return below replaces it anyway.
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) =>
      const SizedBox.shrink();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final language = languageOf(code);
    final source = element.textContent;
    final spec = language == ChartSpec.language
        ? ChartSpec.tryParse(source)
        : null;
    final notation = spec == null
        ? NotationSpec.tryParse(source, language: language)
        : null;
    // Code, charts and diagrams stay left-to-right inside RTL (Persian) text.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: spec != null
          ? ChartBlock(spec: spec)
          : notation != null
          ? NotationBlock(spec: notation)
          : StudyCodeBlock(source: source, language: language),
    );
  }

  /// `language-xyz` class → `xyz`.
  static String? languageOf(md.Element? code) {
    final cls = code?.attributes['class'];
    if (cls == null) return null;
    const prefix = 'language-';
    return cls.startsWith(prefix) ? cls.substring(prefix.length).trim() : cls;
  }
}
