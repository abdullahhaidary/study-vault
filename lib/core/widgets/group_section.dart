import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.only(top: 8, bottom: 4),
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
                    letterSpacing: 0.2,
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
                  const PopupMenuItem(
                    value: _GroupAction.delete,
                    child: Text('Delete group'),
                  ),
              ],
              child: Icon(Icons.more_horiz, color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }
}

enum _GroupAction { edit, delete }

/// Compact list tile for items under a group heading.
class GroupedItemTile extends StatelessWidget {
  const GroupedItemTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onEdit ?? onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ),
              if (onEdit == null && onDelete == null)
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
