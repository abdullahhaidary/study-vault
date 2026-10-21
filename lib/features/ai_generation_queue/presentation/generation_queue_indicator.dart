import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/desktop_frame.dart';
import '../data/ai_generation_providers.dart';

class GenerationQueueIndicator extends ConsumerWidget {
  const GenerationQueueIndicator({super.key, this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(generationQueueSnapshotProvider);
    if (!snapshot.visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final running = snapshot.running > 0;
    final label = running
        ? '${snapshot.running} generating'
        : snapshot.queued > 0
        ? '${snapshot.queued} queued'
        : snapshot.attention > 0
        ? '${snapshot.attention} need attention'
        : '${snapshot.completed} ready';
    final semantics =
        'Generation queue. ${snapshot.running} running, '
        '${snapshot.queued} queued, ${snapshot.completed} ready, '
        '${snapshot.attention} need attention.';
    return Semantics(
      button: true,
      label: semantics,
      child: Material(
        elevation: 6,
        color: theme.colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap:
              onOpen ??
              () => appNavigatorKey.currentState?.pushNamed(
                AppRoutes.generationCenter,
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (running)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    snapshot.attention > 0
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 18,
                    color: snapshot.attention > 0
                        ? theme.colorScheme.error
                        : Colors.greenAccent.shade100,
                  ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
                if (snapshot.queued > 0 && running) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${snapshot.queued} queued',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                    ),
                  ),
                ],
                if (snapshot.attention > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Badge(
                      label: Text('${snapshot.attention}'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
