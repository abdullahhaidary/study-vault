import 'package:flutter/material.dart';

import 'full_explanation_screen.dart';

/// Dialog / bottom sheet to create or edit short + full explanation fields.
class AddEditStudyPinSheet extends StatefulWidget {
  const AddEditStudyPinSheet({
    super.key,
    this.initialShortText = '',
    this.initialFullExplanation,
    this.isEditing = false,
  });

  final String initialShortText;
  final String? initialFullExplanation;
  final bool isEditing;

  static Future<({String shortText, String? fullExplanation})?> show(
    BuildContext context, {
    String initialShortText = '',
    String? initialFullExplanation,
    bool isEditing = false,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final child = AddEditStudyPinSheet(
      initialShortText: initialShortText,
      initialFullExplanation: initialFullExplanation,
      isEditing: isEditing,
    );

    if (isWide) {
      return showDialog<({String shortText, String? fullExplanation})>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: child,
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<({String shortText, String? fullExplanation})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: child,
      ),
    );
  }

  @override
  State<AddEditStudyPinSheet> createState() => _AddEditStudyPinSheetState();
}

class _AddEditStudyPinSheetState extends State<AddEditStudyPinSheet> {
  late final TextEditingController _shortController;
  late String? _fullExplanation;

  @override
  void initState() {
    super.initState();
    _shortController = TextEditingController(text: widget.initialShortText);
    _fullExplanation = widget.initialFullExplanation;
  }

  @override
  void dispose() {
    _shortController.dispose();
    super.dispose();
  }

  Future<void> _editFullExplanation() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FullExplanationScreen(initialText: _fullExplanation ?? ''),
      ),
    );
    if (result != null && mounted) {
      setState(() => _fullExplanation = result.trim().isEmpty ? null : result);
    }
  }

  void _save() {
    final short = _shortController.text.trim();
    if (short.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Short explanation is required.')),
      );
      return;
    }
    Navigator.of(context).pop((
      shortText: short,
      fullExplanation: _fullExplanation,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFull = _fullExplanation != null && _fullExplanation!.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isEditing ? 'Edit Study Pin' : 'Add Study Pin',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shortController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Short explanation',
                helperText: 'Keep this short, ideally 5–7 words.',
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _editFullExplanation,
              icon: Icon(
                hasFull ? Icons.notes_outlined : Icons.note_add_outlined,
              ),
              label: Text(
                hasFull
                    ? 'Edit Full Explanation'
                    : 'Open / Edit Full Explanation',
              ),
            ),
            if (hasFull) ...[
              const SizedBox(height: 8),
              Text(
                _fullExplanation!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
