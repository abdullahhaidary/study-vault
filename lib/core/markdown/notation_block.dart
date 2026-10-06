import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/app_spacing.dart';
import 'notation_spec.dart';

/// Professional card layout for ASCII / mermaid study notations.
class NotationBlock extends StatelessWidget {
  const NotationBlock({super.key, required this.spec});

  final NotationSpec spec;

  @override
  Widget build(BuildContext context) {
    return switch (spec) {
      MappingNotation(:final pairs) => _MappingView(pairs: pairs),
      TreeNotation(:final root, :final subtitle, :final branches) => _TreeView(
        root: root,
        subtitle: subtitle,
        branches: branches,
      ),
      ClassBoxNotation(:final className, :final compartments) => _ClassBoxView(
        className: className,
        compartments: compartments,
      ),
      PipelineNotation(:final steps) => _PipelineView(steps: steps),
      StackFlowNotation(:final title, :final items) => _StackFlowView(
        title: title,
        items: items,
      ),
      RelationshipNotation(:final items) => _RelationshipView(items: items),
      TableNotation(:final caption, :final headers, :final rows) => _TableView(
        caption: caption,
        headers: headers,
        rows: rows,
      ),
    };
  }
}

class _MappingView extends StatelessWidget {
  const _MappingView({required this.pairs});

  final List<NotationPair> pairs;

  @override
  Widget build(BuildContext context) {
    return _Figure(
      child: Column(
        children: [
          for (var i = 0; i < pairs.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _MappingRow(pair: pairs[i]),
          ],
        ],
      ),
    );
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({required this.pair});

  final NotationPair pair;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 560;
        final arrow = Icon(
          stacked ? Icons.south_rounded : Icons.east_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        );
        if (stacked) {
          return Column(
            children: [
              _TermCard(text: pair.from, emphasis: true),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: arrow,
              ),
              _TermCard(text: pair.to, emphasis: false),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _TermCard(text: pair.from, emphasis: true)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: arrow,
            ),
            Expanded(child: _TermCard(text: pair.to, emphasis: false)),
          ],
        );
      },
    );
  }
}

class _TreeView extends StatelessWidget {
  const _TreeView({
    required this.root,
    required this.subtitle,
    required this.branches,
  });

  final String root;
  final String? subtitle;
  final List<TreeBranch> branches;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Figure(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _TermCard(
              text: root,
              caption: subtitle,
              emphasis: true,
              center: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Icon(Icons.south_rounded, size: 20, color: scheme.primary),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520 || branches.length > 3;
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < branches.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      _BranchCard(branch: branches[i]),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < branches.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _BranchCard(branch: branches[i])),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch});

  final TreeBranch branch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TermCard(
      text: branch.title,
      caption: branch.details.isEmpty ? null : branch.details.join('\n'),
      emphasis: false,
      center: true,
      captionStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({
    required this.text,
    required this.emphasis,
    this.caption,
    this.center = false,
    this.captionStyle,
  });

  final String text;
  final String? caption;
  final bool emphasis;
  final bool center;
  final TextStyle? captionStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final align = center ? TextAlign.center : TextAlign.start;
    return Material(
      color: emphasis ? scheme.primaryContainer : scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(
          color: emphasis
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              textAlign: align,
              style: theme.textTheme.titleSmall?.copyWith(
                color: emphasis ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (caption != null && caption!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                caption!,
                textAlign: align,
                style:
                    captionStyle ??
                    theme.textTheme.bodySmall?.copyWith(
                      color: emphasis
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

class _ClassBoxView extends StatelessWidget {
  const _ClassBoxView({required this.className, required this.compartments});

  final String className;
  final List<ClassCompartment> compartments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _Figure(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: scheme.outline, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: scheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    className,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                for (final compartment in compartments) ...[
                  Divider(height: 1, color: scheme.outline),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compartment.label != null) ...[
                          Text(
                            compartment.label!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                        ],
                        for (final line in compartment.lines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              line,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PipelineView extends StatelessWidget {
  const _PipelineView({required this.steps});

  final List<PipelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Figure(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Icon(
                  Icons.south_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
            _PipelineStepRow(step: steps[i]),
          ],
        ],
      ),
    );
  }
}

class _PipelineStepRow extends StatelessWidget {
  const _PipelineStepRow({required this.step});

  final PipelineStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = step.left;
    final right = step.right;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 640;
        final box = _TermCard(text: step.title, emphasis: true, center: true);
        if (stacked) {
          return Column(
            children: [
              if (left != null)
                Text(
                  left,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: AppSpacing.xs),
              box,
              if (right != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  right,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: left == null
                  ? const SizedBox.shrink()
                  : Text(left, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: box),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : Text(
                      right,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StackFlowView extends StatelessWidget {
  const _StackFlowView({required this.title, required this.items});

  final String? title;
  final List<StackFlowItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _Figure(
      child: Column(
        children: [
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Icon(
                  Icons.south_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _TermCard(
                text: items[i].title,
                caption: items[i].detail,
                emphasis: true,
                center: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RelationshipView extends StatelessWidget {
  const _RelationshipView({required this.items});

  final List<UmlRelationship> items;

  @override
  Widget build(BuildContext context) {
    return _Figure(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _RelationshipRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({required this.item});

  final UmlRelationship item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 560;
            final edge = _UmlEdge(item: item);
            if (stacked) {
              return Column(
                children: [
                  _TermCard(text: item.left, emphasis: true, center: true),
                  edge,
                  _TermCard(text: item.right, emphasis: false, center: true),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _TermCard(
                    text: item.left,
                    emphasis: true,
                    center: true,
                  ),
                ),
                edge,
                Expanded(
                  child: _TermCard(
                    text: item.right,
                    emphasis: false,
                    center: true,
                  ),
                ),
              ],
            );
          },
        ),
        if (item.note != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.note!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _UmlEdge extends StatelessWidget {
  const _UmlEdge({required this.item});

  final UmlRelationship item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        width: 120,
        child: Column(
          children: [
            if (item.label != null)
              Text(
                item.label!,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            SizedBox(
              height: 22,
              width: 120,
              child: CustomPaint(
                painter: _UmlEdgePainter(
                  color: scheme.primary,
                  kind: item.kind,
                ),
              ),
            ),
            if (item.leftMultiplicity != null || item.rightMultiplicity != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.leftMultiplicity ?? '',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.rightMultiplicity ?? '',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UmlEdgePainter extends CustomPainter {
  const _UmlEdgePainter({required this.color, required this.kind});

  final Color color;
  final UmlConnectorKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    const diamond = 10.0;
    const head = 10.0;
    var start = 4.0;
    var end = size.width - 4;
    if (kind == UmlConnectorKind.aggregation ||
        kind == UmlConnectorKind.composition) {
      start = 4 + diamond * 2;
      final path = Path()
        ..moveTo(4, y)
        ..lineTo(4 + diamond, y - 6)
        ..lineTo(4 + diamond * 2, y)
        ..lineTo(4 + diamond, y + 6)
        ..close();
      if (kind == UmlConnectorKind.composition) {
        canvas.drawPath(path, Paint()..color = color);
      } else {
        canvas.drawPath(path, paint);
      }
    }
    canvas.drawLine(Offset(start, y), Offset(end - head, y), paint);
    if (kind == UmlConnectorKind.generalization) {
      final path = Path()
        ..moveTo(end, y)
        ..lineTo(end - head, y - 6)
        ..lineTo(end - head, y + 6)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    } else if (kind == UmlConnectorKind.directed) {
      canvas.drawLine(Offset(end, y), Offset(end - head, y - 5), paint);
      canvas.drawLine(Offset(end, y), Offset(end - head, y + 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _UmlEdgePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.kind != kind;
}

class _TableView extends StatelessWidget {
  const _TableView({
    required this.caption,
    required this.headers,
    required this.rows,
  });

  final String? caption;
  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _Figure(
      child: Column(
        children: [
          if (caption != null) ...[
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Table(
            border: TableBorder.all(color: scheme.outlineVariant),
            children: [
              TableRow(
                decoration: BoxDecoration(color: scheme.primaryContainer),
                children: [
                  for (final header in headers)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(
                        header,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              for (final row in rows)
                TableRow(
                  decoration: BoxDecoration(color: scheme.surface),
                  children: [
                    for (final cell in row)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Text(cell, style: theme.textTheme.bodyMedium),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotationElementBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

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
    final spec = NotationSpec.tryParse(element.textContent);
    if (spec == null) return Text(element.textContent);
    return NotationBlock(spec: spec);
  }
}
