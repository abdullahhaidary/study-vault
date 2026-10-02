import 'package:flutter/material.dart';

import '../../../app/routes.dart';

Future<void> showAiMissingKeyDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Gemini is not configured yet'),
      content: const Text(
        'Add your Gemini API key in Settings to use AI features.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(
              context,
            ).pushNamed(AppRoutes.settings, arguments: {'section': 'ai'});
          },
          child: const Text('Open AI Settings'),
        ),
      ],
    ),
  );
}
