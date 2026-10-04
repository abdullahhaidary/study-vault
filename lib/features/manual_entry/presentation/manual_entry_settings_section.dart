import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../data/manual_entry_providers.dart';

/// Settings → Manual Entry: copy the AI instruction and open the importer.
class ManualEntrySettingsSection extends ConsumerWidget {
  const ManualEntrySettingsSection({super.key});

  Future<void> _copy(
    BuildContext context,
    WidgetRef ref, {
    required bool full,
  }) async {
    final markdown = await ref.read(manualEntryInstructionProvider.future);
    await Clipboard.setData(
      ClipboardData(
        text: full ? markdown : manualEntryPromptFromInstruction(markdown),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          full ? 'Full format guide copied.' : 'AI instruction copied.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Manual Entry'),
        Text(
          'Generate study content with any AI (ChatGPT, Claude, Gemini) using '
          'the Study Vault JSON format, then import it with a full preview. '
          'Works without an API key.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How it works',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const _Step(
                  n: 1,
                  text:
                      'Copy the AI instruction and paste it into ChatGPT '
                      'together with your slides or PDF text.',
                ),
                const _Step(
                  n: 2,
                  text:
                      'Ask for exactly what you need: a summary, deep '
                      'explanation, flashcards, a quiz, notes, annotations — '
                      'or all of them.',
                ),
                const _Step(
                  n: 3,
                  text:
                      'Paste the JSON answer into Manual Entry, pick the '
                      'lesson, preview the result, and save.',
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.manualEntry),
                      icon: const Icon(Icons.data_object),
                      label: const Text('Open Manual Entry'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copy(context, ref, full: false),
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copy AI instruction'),
                    ),
                    TextButton(
                      onPressed: () => _copy(context, ref, full: true),
                      child: const Text('Copy full format guide'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The full guide is also in the project as '
                  'manual_entry_instruction.md.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '$n',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
