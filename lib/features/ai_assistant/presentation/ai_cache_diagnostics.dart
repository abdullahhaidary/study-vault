import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_providers.dart';
import '../domain/ai_model_ref.dart';
import '../domain/ai_token_usage.dart';

class AiCacheDiagnostics extends ConsumerWidget {
  const AiCacheDiagnostics({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(aiRequestMetricsProvider).valueOrNull ?? const [];
    final profiles =
        ref.watch(aiEndpointProfilesProvider).valueOrNull ?? const [];
    String modelLabel(String id) {
      final model = AiModelRef.parse(id);
      final profile = profiles
          .where((p) => p.id == model.endpointProfileId)
          .firstOrNull;
      return profile == null
          ? model.bareModelId
          : '${profile.name} · ${model.bareModelId}';
    }

    String count(int? value) =>
        value == null ? 'Not reported' : AiTokenUsage.formatExactTokens(value);
    return ExpansionTile(
      title: const Text('AI cache diagnostics'),
      subtitle: Text(
        '${rows.length} recent chat requests · stored on this device',
      ),
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Reads reuse cached input. Writes create cache entries. Uncached input is processed normally. '
            'Unavailable metrics appear as “Not reported”. First-token time is measured for streamed replies. '
            'Title requests are recorded separately.',
          ),
        ),
        if (rows.isEmpty)
          const ListTile(
            title: Text('Send a chat message to collect measurements.'),
          ),
        for (final row in rows.take(10))
          ListTile(
            title: Text(
              '${modelLabel(row.modelId)} · ${row.succeeded ? 'Completed' : 'Interrupted'}',
            ),
            subtitle: Text(
              '${row.at.toLocal()}\n'
              'Input: ${count(row.usage.promptTokens)} · Cache reads: ${count(row.usage.cacheHitTokens)}\n'
              'Cache writes: ${count(row.usage.cacheWriteTokens)} · Uncached: ${count(row.usage.uncachedInputTokens)}\n'
              'First token: ${row.usage.timeToFirstTokenMs == null ? 'Not reported' : '${row.usage.timeToFirstTokenMs} ms'} · '
              'Total: ${row.usage.durationMs ?? 0} ms',
            ),
          ),
      ],
    );
  }
}
