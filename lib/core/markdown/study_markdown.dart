import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/app_spacing.dart';
import 'chart_markdown_builder.dart';
import 'notation_spec.dart';

/// Study-note markdown: charts, UML/ASCII diagrams, and cleaner tables.
class StudyMarkdown extends StatelessWidget {
  const StudyMarkdown({
    super.key,
    required this.data,
    this.styleSheet,
    this.selectable = false,
    this.onTapLink,
  });

  final String data;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final style = studyMarkdownStyle(context, base: styleSheet);
    return MarkdownBody(
      data: data,
      selectable: selectable,
      styleSheet: style,
      builders: chartMarkdownBuilders(style),
      blockSyntaxes: const [RelationshipBlockSyntax()],
      onTapLink: onTapLink,
    );
  }
}

MarkdownStyleSheet studyMarkdownStyle(
  BuildContext context, {
  MarkdownStyleSheet? base,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final codeBg = scheme.surfaceContainerHigh;
  return (base ?? MarkdownStyleSheet.fromTheme(theme)).copyWith(
    tableBorder: TableBorder.all(color: scheme.outlineVariant),
    tableHead: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    tableBody: theme.textTheme.bodyMedium,
    tableHeadAlign: TextAlign.center,
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    tableCellsDecoration: BoxDecoration(color: scheme.surface),
    blockSpacing: 12,
    code: theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: scheme.primary,
      backgroundColor: scheme.primary.withValues(alpha: 0.08),
      height: 1.4,
    ),
    codeblockPadding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    codeblockDecoration: BoxDecoration(
      color: codeBg,
      borderRadius: AppRadii.mdAll,
      border: Border.all(color: scheme.outlineVariant),
    ),
  );
}

class RelationshipBlockSyntax extends md.BlockSyntax {
  const RelationshipBlockSyntax();

  @override
  RegExp get pattern => RelationshipNotation.connector;

  @override
  bool canParse(md.BlockParser parser) {
    return RelationshipNotation.looksLikeLine(parser.current.content);
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[];
    while (!parser.isDone &&
        RelationshipNotation.looksLikeLine(parser.current.content)) {
      lines.add(parser.current.content);
      parser.advance();
    }
    return md.Element.text('notation', lines.join('\n'));
  }
}
