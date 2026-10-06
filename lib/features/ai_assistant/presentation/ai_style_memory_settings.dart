import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_providers.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_style_memory.dart';

class AiStyleMemorySettings extends ConsumerWidget {
  const AiStyleMemorySettings({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<AiStyleMemoryItem> items;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final block = AiStyleMemory.compact(items);
    final tokens = AiStyleMemory.estimateTokens(block ?? '');
    final cached = AiStyleMemory.cachedTokenBudget;
    final uncached = AiStyleMemory.uncachedTokenBudget;
    final overUncached = tokens > uncached;
    final overCached = tokens > cached;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Overall AI style history', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'This is not one chat’s transcript. It is the style you want across '
          'summaries, explanations, quizzes, and chat. Write 10–20 sentences '
          'per note (how you like answers, questions, and implementations). '
          'The text is sent hidden with every request until you edit or delete it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          overCached
              ? '$tokens / $cached tokens — over the send limit. Delete or '
                    'shorten notes or AI requests will fail.'
              : overUncached
              ? '$tokens / $cached cached tokens. Over the $uncached uncached '
                    'cap — a cache miss (or editing these notes) bills the full '
                    'hidden prefix.'
              : '$tokens / $cached cached tokens (uncached cap $uncached).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: overCached
                ? theme.colorScheme.error
                : overUncached
                ? theme.colorScheme.tertiary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: overCached ? FontWeight.w600 : null,
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No overall style history yet.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              isThreeLine: true,
              title: Text(
                item.text,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(context, ref, item),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, item),
                  ),
                ],
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _edit(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Add style history'),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AiStyleMemoryItem? existing,
  ) async {
    final controller = TextEditingController(text: existing?.text ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? 'Add overall style history' : 'Edit style history',
        ),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            maxLength: AiStyleMemory.maxItemChars,
            minLines: 10,
            maxLines: 20,
            decoration: const InputDecoration(
              hintText:
                  'Write 10–20 sentences about how you want answers, questions, '
                  'and implementations. This applies to every chat and study '
                  'material, not only this conversation.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || !context.mounted) return;
    final store = ref.read(aiSettingsStoreProvider);
    final next = [
      for (final item in items)
        if (item.id == existing?.id) item.copyWith(text: saved) else item,
      if (existing == null)
        AiStyleMemoryItem(
          id: 's${DateTime.now().microsecondsSinceEpoch}',
          text: saved,
        ),
    ];
    await _write(context, store, next);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AiStyleMemoryItem item,
  ) async {
    final store = ref.read(aiSettingsStoreProvider);
    await _write(context, store, [
      for (final current in items)
        if (current.id != item.id) current,
    ]);
  }

  Future<void> _write(
    BuildContext context,
    AiSettingsStore store,
    List<AiStyleMemoryItem> next,
  ) async {
    try {
      await store.setStyleMemoryItems(next);
      onChanged();
    } on AiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
