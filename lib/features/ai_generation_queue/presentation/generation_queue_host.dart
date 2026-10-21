import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/desktop_frame.dart';
import '../data/ai_generation_providers.dart';
import '../domain/ai_generation_models.dart';
import '../services/ai_generation_notification_service.dart';
import 'generation_queue_indicator.dart';

/// Stays above the navigator so queue status survives route changes.
class GenerationQueueHost extends ConsumerWidget {
  const GenerationQueueHost({super.key, required this.child});

  final Widget child;

  static const bridge = AiGenerationNotificationBridge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(aiGenerationNoticesProvider, (previous, next) {
      final notice = next.valueOrNull;
      if (notice == null) return;
      if (bridge.appIsBackgrounded) {
        debugPrint(bridge.limitation);
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(notice.title),
          action: SnackBarAction(
            label: switch (notice.action) {
              AiGenerationNoticeAction.open => 'Open',
              AiGenerationNoticeAction.continuePartial => 'Continue',
              AiGenerationNoticeAction.retryTranslation => 'Retry translation',
              AiGenerationNoticeAction.details => 'View details',
            },
            onPressed: () {
              appNavigatorKey.currentState?.pushNamed(
                AppRoutes.generationCenter,
                arguments: notice.jobId,
              );
            },
          ),
        ),
      );
    });
    return Stack(
      children: [
        child,
        const Positioned(
          right: 16,
          bottom: 96,
          child: GenerationQueueIndicator(),
        ),
      ],
    );
  }
}
