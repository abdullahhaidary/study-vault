import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/review_session_providers.dart';
import '../domain/review_models.dart';
import 'review_setup_screen.dart';

/// Compact Study Review entry for detail screens.
class ReviewEntryButton extends ConsumerWidget {
  const ReviewEntryButton({
    super.key,
    required this.scope,
    this.compact = false,
  });

  final ReviewScope scope;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(reviewableCountProvider(scope));
    final theme = Theme.of(context);

    return countAsync.when(
      loading: () =>
          compact ? const SizedBox.shrink() : const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
      data: (count) {
        if (compact) {
          return IconButton(
            tooltip: count == 0 ? 'No annotations to review' : 'Review Pins',
            onPressed: count == 0
                ? null
                : () => openReviewSetup(context, scope: scope),
            icon: const Icon(Icons.school_outlined),
          );
        }

        if (count == 0) {
          return Text(
            'No annotations to review yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => openReviewSetup(context, scope: scope),
            icon: const Icon(Icons.school_outlined),
            label: Text('Review $count Pins'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(AppTouch.min, AppTouch.min),
            ),
          ),
        );
      },
    );
  }
}
