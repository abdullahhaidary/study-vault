import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_providers.dart';
import '../domain/ai_provider.dart';

Future<bool?> showAiPrivacyNotice(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(aiSettingsStateProvider);
          final providerName = state.maybeWhen(
            data: (s) => s.provider.displayName,
            orElse: () => 'the selected AI provider',
          );
          final privacyLine = state.maybeWhen(
            data: (s) => s.provider.privacyLine,
            orElse: () =>
                'Study content used in AI requests is sent to the selected provider.',
          );
          return AlertDialog(
            title: const Text('AI Privacy Notice'),
            content: Text(
              'Study Vault normally keeps your study data on this device.\n\n'
              'When you use an AI action, only the text/note needed for that '
              'action is sent to $providerName.\n\n'
              '$privacyLine\n\n'
              'Nothing is sent automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('I Understand'),
              ),
            ],
          );
        },
      );
    },
  );
}
