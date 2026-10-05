import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/manual_entry_plan.dart';
import 'manual_entry_import_screen.dart' show manualEntryKindIcon;
import 'manual_entry_item_reader.dart';

/// A virtual copy of the lesson page showing exactly what Save will produce.
///
/// Pops `true` when the user taps Save here.
class ManualEntryPreviewScreen extends StatefulWidget {
  const ManualEntryPreviewScreen({super.key, required this.plan});

  final ManualEntryPlan plan;

  @override
  State<ManualEntryPreviewScreen> createState() =>
      _ManualEntryPreviewScreenState();
}

class _ManualEntryPreviewScreenState extends State<ManualEntryPreviewScreen> {
  bool _showExisting = true;

  ManualEntryPlan get plan => widget.plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final replaced = plan.replacedIds;

    return DetailScaffold(
      title: plan.target.displayName,
      description: 'Preview — nothing is saved yet.',
      actions: [
        IconButton(
          tooltip: _showExisting
              ? 'Hide existing items'
              : 'Show existing items',
          icon: Icon(
            _showExisting ? Icons.layers_outlined : Icons.layers_clear_outlined,
          ),
          onPressed: () => setState(() => _showExisting = !_showExisting),
        ),
      ],
      floatingActionButton: !plan.canSave
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_outlined),
              label: Text('Save ${plan.writeCount}'),
            ),
      bodySlivers: [
        SliverToBoxAdapter(
          child: DetailContent(
            bottom: AppSpacing.md,
            child: _SummaryBanner(plan: plan),
          ),
        ),
        if (plan.target.materialTitle != null ||
            plan.ofKind(ManualEntryKind.studyMaterial).isNotEmpty ||
            plan.ofKind(ManualEntryKind.annotation).isNotEmpty)
          SliverToBoxAdapter(
            child: DetailContent(
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(title: 'Materials'),
                  _PdfCard(
                    plan: plan,
                    replaced: replaced,
                    showExisting: _showExisting,
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: DetailContent(
            bottom: AppSpacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Study tools'),
                for (final kind in const [
                  ManualEntryKind.flashcard,
                  ManualEntryKind.quiz,
                  ManualEntryKind.note,
                  ManualEntryKind.courseReview,
                ])
                  if (kind != ManualEntryKind.courseReview ||
                      plan.ofKind(kind).isNotEmpty) ...[
                    _ToolSection(
                      kind: kind,
                      plan: plan,
                      replaced: replaced,
                      showExisting: _showExisting,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                if (plan.missingPdf)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      title: Text(
                        'Study materials and annotations need a PDF',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      subtitle: Text(
                        'Go back and choose a PDF, or untick those items.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.plan});
  final ManualEntryPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final after = plan.after;
    final replacing = plan.items.where((i) => i.replaces).length;
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'After saving',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                for (final kind in ManualEntryKind.values)
                  if (plan.ofKind(kind).isNotEmpty ||
                      plan.before.forKind(kind) > 0)
                    _CountDelta(
                      icon: manualEntryKindIcon(kind),
                      label: kind == ManualEntryKind.studyMaterial
                          ? 'AI material versions'
                          : kind.label,
                      before: plan.before.forKind(kind),
                      after: after.forKind(kind),
                    ),
              ],
            ),
            if (replacing > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$replacing existing item(s) will be overwritten.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                _Legend(color: theme.colorScheme.primary, label: 'New'),
                const SizedBox(width: AppSpacing.md),
                _Legend(color: theme.colorScheme.error, label: 'Replaced'),
                const SizedBox(width: AppSpacing.md),
                _Legend(color: theme.colorScheme.outline, label: 'Unchanged'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _CountDelta extends StatelessWidget {
  const _CountDelta({
    required this.icon,
    required this.label,
    required this.before,
    required this.after,
  });

  final IconData icon;
  final String label;
  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changed = before != after;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xxs),
        Text('$label: ', style: theme.textTheme.bodySmall),
        Text(
          changed ? '$before → $after' : '$before',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: changed ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class _PdfCard extends StatelessWidget {
  const _PdfCard({
    required this.plan,
    required this.replaced,
    required this.showExisting,
  });

  final ManualEntryPlan plan;
  final Set<String> replaced;
  final bool showExisting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materials = plan.ofKind(ManualEntryKind.studyMaterial).toList();
    final annotations = plan.ofKind(ManualEntryKind.annotation).toList()
      ..sort((a, b) => (a.page ?? 0).compareTo(b.page ?? 0));
    final existingMaterials = plan.existing
        .where((e) => e.kind == ManualEntryKind.studyMaterial)
        .toList();
    final existingPins = plan.existing
        .where((e) => e.kind == ManualEntryKind.annotation)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.picture_as_pdf_outlined,
                color: plan.target.materialTitle == null
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              title: Text(plan.target.materialTitle ?? 'No PDF chosen'),
              subtitle: const Text('PDF'),
            ),
            if (materials.isNotEmpty || existingMaterials.isNotEmpty) ...[
              _SubHeader(
                icon: manualEntryKindIcon(ManualEntryKind.studyMaterial),
                title: 'AI Study Materials',
              ),
              if (showExisting)
                for (final e in existingMaterials)
                  _ExistingRow(item: e, replaced: replaced.contains(e.id)),
              for (final item in materials) _NewRow(item: item),
            ],
            if (annotations.isNotEmpty || existingPins.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _SubHeader(
                icon: manualEntryKindIcon(ManualEntryKind.annotation),
                title: 'Annotations',
              ),
              if (showExisting)
                for (final e in existingPins)
                  _ExistingRow(item: e, replaced: replaced.contains(e.id)),
              for (final item in annotations) _NewRow(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolSection extends StatelessWidget {
  const _ToolSection({
    required this.kind,
    required this.plan,
    required this.replaced,
    required this.showExisting,
  });

  final ManualEntryKind kind;
  final ManualEntryPlan plan;
  final Set<String> replaced;
  final bool showExisting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = plan.ofKind(kind).toList();
    final existing = plan.existing.where((e) => e.kind == kind).toList();
    final before = plan.before.forKind(kind);
    final after = plan.after.forKind(kind);
    final unit = switch (kind) {
      ManualEntryKind.flashcard => 'card',
      ManualEntryKind.quiz => 'quiz',
      ManualEntryKind.courseReview => 'part',
      _ => 'note',
    };

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(
          color: items.isEmpty
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  manualEntryKindIcon(kind),
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind == ManualEntryKind.quiz
                            ? 'AI Questions'
                            : kind.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        before == after
                            ? '$after $unit${after == 1 ? '' : 's'}'
                            : '$before → $after $unit${after == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: before == after
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (items.isNotEmpty || (showExisting && existing.isNotEmpty))
              const Divider(height: AppSpacing.md),
            if (showExisting)
              for (final e in existing)
                _ExistingRow(item: e, replaced: replaced.contains(e.id)),
            for (final item in items) _NewRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingRow extends StatelessWidget {
  const _ExistingRow({required this.item, required this.replaced});
  final ManualEntryExistingItem item;
  final bool replaced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = replaced
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        replaced ? Icons.remove_circle_outline : Icons.circle_outlined,
        size: 18,
        color: color,
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
          decoration: replaced ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: item.detail == null
          ? null
          : Text(
              item.detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
      trailing: replaced
          ? Text(
              'Replaced',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            )
          : null,
    );
  }
}

class _NewRow extends StatelessWidget {
  const _NewRow({required this.item});
  final ManualEntryPlanItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!item.willWrite) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.block, size: 18, color: theme.colorScheme.outline),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        trailing: Text(
          'Skipped',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        onTap: () => ManualEntryItemReader.open(context, item),
      );
    }
    final color = theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        leading: Icon(
          item.replaces ? Icons.swap_horiz : Icons.add_circle_outline,
          size: 18,
          color: color,
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          [
            if (item.detail != null) item.detail!,
            if (item.preview.isNotEmpty && item.preview != item.title)
              item.preview,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            item.replaces
                ? 'Replaces'
                : item.kind.isVersioned && item.hasConflict
                ? 'New version'
                : 'New',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        onTap: () => ManualEntryItemReader.open(context, item),
      ),
    );
  }
}
