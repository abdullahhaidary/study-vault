import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../data/ai_chat_providers.dart';

/// Conversation history for Study AI.
class AiChatHistoryScreen extends ConsumerStatefulWidget {
  const AiChatHistoryScreen({super.key});

  @override
  ConsumerState<AiChatHistoryScreen> createState() =>
      _AiChatHistoryScreenState();
}

class _AiChatHistoryScreenState extends ConsumerState<AiChatHistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _newChat() async {
    ref.read(activeAiChatIdProvider.notifier).state = null;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _open(AiChat chat) async {
    ref.read(activeAiChatIdProvider.notifier).state = chat.id;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _rename(AiChat chat) async {
    final controller = TextEditingController(text: chat.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    await ref.read(aiChatServiceProvider).renameChat(chat.id, title);
  }

  Future<void> _delete(AiChat chat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text(
          'This conversation will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final active = ref.read(activeAiChatIdProvider);
    await ref.read(aiChatServiceProvider).deleteChat(chat.id);
    if (active == chat.id) {
      ref.read(activeAiChatIdProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(aiChatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _newChat,
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.pageInsets(
              context,
            ).copyWith(top: AppSpacing.xs, bottom: AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: chatsAsync.when(
              loading: () => const AppLoading(),
              error: (_, _) =>
                  const AppErrorState(message: 'Could not load chats.'),
              data: (chats) {
                final filtered = _query.isEmpty
                    ? chats
                    : chats
                          .where((c) => c.title.toLowerCase().contains(_query))
                          .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: chats.isEmpty ? 'No chats yet' : 'No matches',
                    message: chats.isEmpty
                        ? 'Start a conversation from Study AI.'
                        : 'Try a different search.',
                    action: chats.isEmpty
                        ? FilledButton(
                            onPressed: _newChat,
                            child: const Text('New chat'),
                          )
                        : null,
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageInsets(context).left,
                    0,
                    AppSpacing.pageInsets(context).right,
                    AppSpacing.xl,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final chat = filtered[index];
                    return _ChatHistoryTile(
                      chat: chat,
                      onOpen: () => _open(chat),
                      onRename: () => _rename(chat),
                      onDelete: () => _delete(chat),
                      theme: theme,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatHistoryTile extends ConsumerWidget {
  const _ChatHistoryTile({
    required this.chat,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.theme,
  });

  final AiChat chat;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(aiChatLastMessageProvider(chat.id));
    final preview = previewAsync.whenOrNull(
      data: (last) {
        if (last == null) return 'No messages yet';
        final text = last.content.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.length <= 80) return text;
        return '${text.substring(0, 80)}…';
      },
    );

    final when = chat.lastMessageAt ?? chat.updatedAt;
    final dateLabel = _friendlyDate(when);
    final modelLabel = GeminiModelRegistry.displayName(chat.modelId);
    final modelKnown = GeminiModelRegistry.isKnown(chat.modelId);

    return ListTile(
      tileColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      title: Text(
        chat.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        '${preview ?? '…'}\n$dateLabel · ${modelKnown ? modelLabel : 'Previous model unavailable'}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'rename') onRename();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(
            value: 'delete',
            child: Text(
              'Delete',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
      onTap: onOpen,
    );
  }

  String _friendlyDate(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat.yMMMd().format(local);
  }
}
