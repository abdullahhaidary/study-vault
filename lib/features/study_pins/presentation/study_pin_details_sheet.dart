import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/study_pins_providers.dart';
import 'add_edit_study_pin_sheet.dart';
import 'full_explanation_screen.dart';

/// Details sheet for an existing Study Pin (view / edit / delete).
Future<void> showStudyPinDetails(
  BuildContext context,
  WidgetRef ref, {
  required StudyPin pin,
}) {
  final isWide = MediaQuery.sizeOf(context).width >= 720;
  final child = StudyPinDetailsContent(pinId: pin.id);

  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: child,
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        child: child,
      ),
    ),
  );
}

class StudyPinDetailsContent extends ConsumerWidget {
  const StudyPinDetailsContent({super.key, required this.pinId});

  final String pinId;

  Future<void> _edit(BuildContext context, WidgetRef ref, StudyPin pin) async {
    final result = await AddEditStudyPinSheet.show(
      context,
      initialShortText: pin.shortText,
      initialFullExplanation: pin.fullExplanation,
      isEditing: true,
    );
    if (result == null) return;
    await updateStudyPinTexts(
      ref,
      pin: pin,
      shortText: result.shortText,
      fullExplanation: result.fullExplanation,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    StudyPin pin,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this Study Pin?'),
        content: const Text(
          'The pin will be removed. The PDF or image is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteStudyPin(ref, pinId: pin.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _openFull(
    BuildContext context,
    WidgetRef ref,
    StudyPin pin, {
    required bool editable,
  }) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FullExplanationScreen(
          initialText: pin.fullExplanation ?? '',
          readOnly: !editable,
          title: editable ? 'Edit Full Explanation' : 'Full Explanation',
        ),
      ),
    );

    if (editable && result != null) {
      await updateStudyPinTexts(
        ref,
        pin: pin,
        shortText: pin.shortText,
        fullExplanation: result,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinAsync = ref.watch(studyPinByIdProvider(pinId));
    final theme = Theme.of(context);

    return pinAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $error'),
      ),
      data: (pin) {
        if (pin == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Study Pin not found.'),
          );
        }

        final hasFull =
            pin.fullExplanation != null && pin.fullExplanation!.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Study Pin', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                'Short Explanation',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(pin.shortText, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(
                'Full Explanation',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              if (hasFull)
                Text(
                  pin.fullExplanation!,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                )
              else
                Text(
                  'None yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (hasFull) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openFull(
                    context,
                    ref,
                    pin,
                    editable: false,
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open Full Explanation'),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _edit(context, ref, pin),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _delete(context, ref, pin),
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
