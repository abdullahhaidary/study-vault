import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/failed_ai_requests_provider.dart';
import 'ai_assistant_controller.dart';

/// Screen showing failed study AI requests that can be retried or removed.
class FailedAiRequestsScreen extends ConsumerWidget {
  const FailedAiRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(failedAiRequestsProvider);
    final timeFmt = DateFormat.jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Failed AI Requests'),
        actions: [
          if (failed.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () {
                ref.read(failedAiRequestsProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: failed.isEmpty
          ? const Center(child: Text('No failed AI requests.'))
          : ListView.builder(
              itemCount: failed.length,
              itemBuilder: (context, index) {
                final item = failed[index];
                return _FailedRequestTile(
                  item: item,
                  timeFmt: timeFmt,
                );
              },
            ),
    );
  }
}

class _FailedRequestTile extends ConsumerWidget {
  const _FailedRequestTile({required this.item, required this.timeFmt});

  final FailedAiRequest item;
  final DateFormat timeFmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(item.actionLabel),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Text(
                  timeFmt.format(item.failedAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.sourcePreview),
            if (item.errorMessage != null && item.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(failedAiRequestsProvider.notifier)
                        .remove(item.id);
                  },
                  child: const Text('Remove'),
                ),
                FilledButton(
                  onPressed: () => AiAssistantController.retry(context, ref, item),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the failed requests screen.
void showFailedAiRequestsScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const FailedAiRequestsScreen()),
  );
}
