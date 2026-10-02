import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A lightweight section heading with optional overflow actions.
///
/// Used for subject groups and lesson groups — not a large card.
class GroupSectionHeader extends StatelessWidget {
  const GroupSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActions = onEdit != null || onDelete != null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasActions)
            PopupMenuButton<_GroupAction>(
              tooltip: 'Group options',
              onSelected: (action) {
                switch (action) {
                  case _GroupAction.edit:
                    onEdit?.call();
                  case _GroupAction.delete:
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: _GroupAction.edit,
                    child: Text('Edit group'),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: _GroupAction.delete,
                    child: Text(
                      'Delete group',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
              icon: Icon(Icons.more_vert, color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }
}

enum _GroupAction { edit, delete }

/// Compact list tile for items under a group heading.
///
/// Shows icon, title, subtitle, and either a chevron or a single overflow menu.
class GroupedItemTile extends StatelessWidget {
  const GroupedItemTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.editLabel = 'Edit',
    this.deleteLabel = 'Delete',
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String editLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMenu = onEdit != null || onDelete != null;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouch.min),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasMenu)
                  PopupMenuButton<_ItemAction>(
                    tooltip: 'Options',
                    onSelected: (action) {
                      switch (action) {
                        case _ItemAction.edit:
                          onEdit?.call();
                        case _ItemAction.delete:
                          onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        PopupMenuItem(
                          value: _ItemAction.edit,
                          child: Text(editLabel),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: _ItemAction.delete,
                          child: Text(
                            deleteLabel,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                    ],
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.outline,
                    ),
                  )
                else
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ItemAction { edit, delete }
