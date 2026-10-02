import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/ai_chat_providers.dart';
import '../../domain/ai_chat_models.dart';
import '../../domain/referenced_ai_message.dart';
import '../../services/ai_chat_navigation.dart';

/// Compact reverse-reference section for Lesson / PDF / Note / Pin screens.
class AiDiscussionsSection extends ConsumerWidget {
  const AiDiscussionsSection({
    super.key,
    required this.kind,
    required this.id,
    this.title = 'AI Discussions',
    this.dense = false,
  });

  final AiContextKind kind;
  final String id;
  final String title;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (kind: kind, id: id);
    final countAsync = ref.watch(aiDiscussionsCountProvider(key));
    final count = countAsync.valueOrNull ?? 0;

    if (count == 0 && !countAsync.isLoading) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 16,
            vertical: dense ? 0 : 2,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            dense ? 8 : 12,
            0,
            dense ? 8 : 12,
            dense ? 8 : 12,
          ),
          leading: Icon(
            Icons.auto_awesome_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(title),
          subtitle: Text(
            countAsync.isLoading
                ? 'Loading…'
                : count == 1
                ? '1 referenced message'
                : '$count referenced messages',
          ),
          children: [AiDiscussionsList(kind: kind, id: id, dense: dense)],
        ),
      ),
    );
  }
}

/// Expanded list of reverse references (grouped by chat).
class AiDiscussionsList extends ConsumerWidget {
  const AiDiscussionsList({
    super.key,
    required this.kind,
    required this.id,
    this.dense = false,
  });

  final AiContextKind kind;
  final String id;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(
      aiDiscussionsGroupedProvider((kind: kind, id: id)),
    );
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();

    return groupsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          'Could not load AI discussions.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              'No AI discussions yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var g = 0; g < groups.length; g++) ...[
              if (g > 0) const SizedBox(height: AppSpacing.sm),
              _ChatGroupHeader(group: groups[g]),
              for (final message in groups[g].messages)
                _MessageTile(
                  message: message,
                  dateLabel: dateFormat.format(message.createdAt),
                  dense: dense,
                  onTap: () => AiChatNavigation.openAtMessage(
                    context,
                    ref,
                    chatId: message.chatId,
                    messageId: message.messageId,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ChatGroupHeader extends StatelessWidget {
  const _ChatGroupHeader({required this.group});

  final ReferencedAiChatGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countLabel = group.messageCount == 1
        ? '1 message'
        : '${group.messageCount} messages';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.chatTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            countLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.dateLabel,
    required this.onTap,
    this.dense = false,
  });

  final ReferencedAiMessage message;
  final String dateLabel;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        message.userMessage,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${message.chatTitle} · $dateLabel',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (message.assistantReplyPreview != null &&
              message.assistantReplyPreview!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              message.assistantReplyPreview!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.85,
                ),
              ),
            ),
          ],
        ],
      ),
      isThreeLine: message.assistantReplyPreview != null,
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
