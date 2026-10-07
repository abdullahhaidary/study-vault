import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'chart_block.dart';
import 'chart_spec.dart';
import 'notation_block.dart';
import 'notation_spec.dart';

/// Renders fenced ```chart blocks as charts; other code blocks keep the
/// default flutter_markdown look.
///
/// Usage: `MarkdownBody(builders: chartMarkdownBuilders(styleSheet), ...)`.
Map<String, MarkdownElementBuilder> chartMarkdownBuilders(
  MarkdownStyleSheet styleSheet,
) => {
  'pre': ChartCodeBlockBuilder(styleSheet),
  'notation': NotationElementBuilder(),
};

class ChartCodeBlockBuilder extends MarkdownElementBuilder {
  ChartCodeBlockBuilder(this.styleSheet);

  final MarkdownStyleSheet styleSheet;

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

    if (language == ChartSpec.language) {
      final spec = ChartSpec.tryParse(source);
      if (spec != null) return ChartBlock(spec: spec);
    }
    final notation = NotationSpec.tryParse(source, language: language);
    if (notation != null) return NotationBlock(spec: notation);
    return _defaultCodeBlock(source, language: language);
  }

  /// `language-xyz` class → `xyz`.
  static String? languageOf(md.Element? code) {
    final cls = code?.attributes['class'];
    if (cls == null) return null;
    const prefix = 'language-';
    return cls.startsWith(prefix) ? cls.substring(prefix.length).trim() : cls;
  }

  Widget _defaultCodeBlock(String source, {String? language}) {
    final text = source.endsWith('\n')
        ? source.substring(0, source.length - 1)
        : source;
    final lang = language?.trim();
    final padding =
        styleSheet.codeblockPadding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    final decoration =
        styleSheet.codeblockDecoration ??
        BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        );
    final codeStyle =
        styleSheet.code ??
        const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lang != null && lang.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                lang,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: codeStyle.color?.withValues(alpha: 0.7),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          _HorizontalScroll(
            padding: padding,
            child: Text(text, style: codeStyle),
          ),
        ],
      ),
    );
  }
}

class _HorizontalScroll extends StatefulWidget {
  const _HorizontalScroll({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  State<_HorizontalScroll> createState() => _HorizontalScrollState();
}

class _HorizontalScrollState extends State<_HorizontalScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}
