import 'package:flutter/material.dart';

import '../../domain/deepseek_pricing_period.dart';

/// How much detail to show for the DeepSeek peak warning.
enum DeepSeekPricingBannerStyle {
  /// Settings / selector: label, short hint, and Afghanistan hours.
  full,

  /// Inline strip under a chat header or model row.
  compact,

  /// Tiny chip next to a model name / picker.
  chip,
}

/// Peak-only DeepSeek pricing warning.
///
/// Renders nothing outside peak hours, and nothing unless [visible] (caller is
/// using DeepSeek). Off-peak is intentionally silent.
class DeepSeekPricingBanner extends StatelessWidget {
  const DeepSeekPricingBanner({
    super.key,
    this.visible = true,
    this.style = DeepSeekPricingBannerStyle.compact,
    this.clock,
  });

  /// When false, renders nothing (caller is not using DeepSeek).
  final bool visible;

  final DeepSeekPricingBannerStyle style;

  /// Test clock; defaults to wall clock UTC via [DeepSeekPricingSchedule.now].
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final period = DeepSeekPricingSchedule.now(clock);
    if (period != DeepSeekPricingPeriod.peak) {
      return const SizedBox.shrink();
    }

    return switch (style) {
      DeepSeekPricingBannerStyle.chip => const _Chip(),
      DeepSeekPricingBannerStyle.compact => const _Compact(),
      DeepSeekPricingBannerStyle.full => const _Full(),
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.tertiary;
    return Tooltip(
      message:
          '${DeepSeekPricingPeriod.peak.shortHint}. '
          '${DeepSeekPricingSchedule.afghanistanPeakHint}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: accent),
            const SizedBox(width: 4),
            Text(
              'DeepSeek Peak',
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Compact extends StatelessWidget {
  const _Compact();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.tertiary;
    return Material(
      color: accent.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'DeepSeek peak pricing — ${DeepSeekPricingPeriod.peak.shortHint}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Full extends StatelessWidget {
  const _Full();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = scheme.tertiary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DeepSeek peak pricing',
                    style: theme.textTheme.titleSmall?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              DeepSeekPricingPeriod.peak.shortHint,
              style: theme.textTheme.labelMedium?.copyWith(color: accent),
            ),
            const SizedBox(height: 6),
            Text(
              DeepSeekPricingSchedule.afghanistanPeakHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
