import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/markdown/chart_markdown_builder.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/manual_entry_plan.dart';

/// Full-screen markdown reader for one item before it is saved.
class ManualEntryItemReader extends StatelessWidget {
  const ManualEntryItemReader({super.key, required this.item});

  final ManualEntryPlanItem item;

  static Future<void> open(BuildContext context, ManualEntryPlanItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ManualEntryItemReader(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme);
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Preview · ${item.kind.label}${item.detail == null ? '' : ' · ${item.detail}'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.contentMaxWidth,
          ),
          child: SelectionArea(
            child: Markdown(
              data: item.markdown,
              selectable: false,
              padding: AppSpacing.pageInsets(context),
              styleSheet: markdownStyle,
              builders: chartMarkdownBuilders(markdownStyle),
            ),
          ),
        ),
      ),
    );
  }
}
