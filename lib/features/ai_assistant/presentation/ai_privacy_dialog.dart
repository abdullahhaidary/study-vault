import 'package:flutter/material.dart';

Future<bool?> showAiPrivacyNotice(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('AI Privacy Notice'),
      content: const Text(
        'Study Vault normally keeps your study data on this device.\n\n'
        'When you use a Gemini AI action, only the text/note needed for that '
        'action is sent to the Gemini API.\n\n'
        'Nothing is sent automatically.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('I Understand'),
        ),
      ],
    ),
  );
}
