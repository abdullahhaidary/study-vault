import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/ai_token_usage.dart';

/// Compact, low-emphasis usage chip under an assistant answer.
class AiUsageIndicator extends StatelessWidget {
  const AiUsageIndicator({super.key, required this.usage});

  final AiTokenUsage usage;

  @override
  Widget build(BuildContext context) {
    if (!usage.hasAnyMetric) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final label = usage.compactLabel;

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => showAiUsageDetailsDialog(context, usage),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.75,
                  ),
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showAiUsageDetailsDialog(
  BuildContext context,
  AiTokenUsage usage,
) {
  final theme = Theme.of(context);
  final rows = <(String, String)>[
    if (usage.provider != null) ('Provider', _providerLabel(usage.provider!)),
    if (usage.model != null) ('Model', usage.model!),
    if (usage.promptTokens != null)
      ('Prompt tokens', AiTokenUsage.formatExactTokens(usage.promptTokens!)),
    if (usage.cacheHitTokens != null)
      ('Cache hit', AiTokenUsage.formatExactTokens(usage.cacheHitTokens!)),
    if (usage.cacheMissTokens != null)
      ('Cache miss', AiTokenUsage.formatExactTokens(usage.cacheMissTokens!)),
    if (usage.cacheHitRatio != null)
      ('Cache hit ratio', '${usage.cacheHitRatio!.toStringAsFixed(1)}%'),
    if (usage.completionTokens != null)
      (
        'Completion tokens',
        AiTokenUsage.formatExactTokens(usage.completionTokens!),
      ),
    if (usage.totalTokens != null)
      ('Total tokens', AiTokenUsage.formatExactTokens(usage.totalTokens!)),
    if (usage.durationMs != null)
      ('Request duration', AiTokenUsage.formatDuration(usage.durationMs)),
  ];

  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('AI Usage'),
        content: SizedBox(
          width: 360,
          child: rows.isEmpty
              ? Text(
                  'No usage details available.',
                  style: theme.textTheme.bodyMedium,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              rows[i].$1,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              rows[i].$2,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

String _providerLabel(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('deepseek')) return 'DeepSeek';
  if (lower.contains('gemini')) return 'Gemini';
  return raw;
}

/// Builds [AiTokenUsage] from nullable DB columns.
AiTokenUsage? aiTokenUsageFromColumns({
  int? promptTokens,
  int? completionTokens,
  int? totalTokens,
  int? cacheHitTokens,
  int? cacheMissTokens,
  String? model,
  String? provider,
  int? durationMs,
}) {
  final usage = AiTokenUsage(
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    totalTokens: totalTokens,
    cacheHitTokens: cacheHitTokens,
    cacheMissTokens: cacheMissTokens,
    model: model,
    provider: provider,
    durationMs: durationMs,
  );
  return usage.hasAnyMetric ? usage : null;
}
