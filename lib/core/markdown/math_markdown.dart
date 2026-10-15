import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Parses display equations delimited by `$$` on one or more lines.
class MathBlockSyntax extends md.BlockSyntax {
  const MathBlockSyntax();

  @override
  RegExp get pattern => RegExp(r'^\s*\$\$');

  @override
  md.Node parse(md.BlockParser parser) {
    final source = StringBuffer();
    var line = parser.current.content.trimLeft();
    var remainder = line.substring(2);

    final sameLineEnd = remainder.indexOf(r'$$');
    if (sameLineEnd >= 0) {
      source.write(remainder.substring(0, sameLineEnd));
      parser.advance();
      return md.Element.text('math-block', source.toString().trim());
    }

    if (remainder.trim().isNotEmpty) {
      source.writeln(remainder);
    }
    parser.advance();

    while (!parser.isDone) {
      line = parser.current.content;
      final end = line.indexOf(r'$$');
      if (end >= 0) {
        source.write(line.substring(0, end));
        parser.advance();
        break;
      }
      source.writeln(line);
      parser.advance();
    }

    return md.Element.text('math-block', source.toString().trim());
  }
}

/// Parses inline equations such as `$x^2 + y^2$`.
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax()
    : super(
        r'\$(?!\$)((?:\\.|[^$\n])+?)\$(?!\$)',
        startCharacter: r'$'.codeUnitAt(0),
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final expression = match[1]!.replaceAll(r'\$', r'$').trim();
    parser.addNode(md.Element.text('math-inline', expression));
    return true;
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  MathElementBuilder({required this.display});

  final bool display;

  @override
  bool isBlockElement() => display;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) =>
      const SizedBox.shrink();

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final expression = element.textContent.trim();
    final math = Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        expression,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: preferredStyle,
        onErrorFallback: (_) => Text(
          display ? r'$$' + expression + r'$$' : r'$' + expression + r'$',
          style: preferredStyle,
        ),
      ),
    );

    if (!display) return math;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: math,
      ),
    );
  }
}
