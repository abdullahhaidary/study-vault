import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../data/ai_providers.dart';
import '../domain/ai_provider.dart';

Future<void> showAiMissingKeyDialog(
  BuildContext context, {
  WidgetRef? ref,
  AiProviderId? requireProvider,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, consumerRef, _) {
          final state = consumerRef.watch(aiSettingsStateProvider);
          final name =
              requireProvider?.displayName ??
              state.maybeWhen(
                data: (s) => s.provider.displayName,
                orElse: () => 'AI',
              );
          return AlertDialog(
            title: Text('$name API key required'),
            content: Text(
              requireProvider == AiProviderId.gemini
                  ? 'Sending a page as an image uses Gemini vision. Add a Gemini API key in Settings.'
                  : 'Add your $name API key in Settings to use AI features.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.settings, arguments: {'section': 'ai'});
                },
                child: const Text('Add API Key'),
              ),
            ],
          );
        },
      );
    },
  );
}
