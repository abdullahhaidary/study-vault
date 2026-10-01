import 'package:flutter/material.dart';

import '../domain/pin_type.dart';
import 'full_explanation_screen.dart';

/// Result returned when the user saves (or deletes) from the annotation editor.
sealed class StudyPinEditorResult {
  const StudyPinEditorResult();
}

class StudyPinEditorSaved extends StudyPinEditorResult {
  const StudyPinEditorSaved({required this.shortText, this.fullExplanation});

  final String shortText;
  final String? fullExplanation;
}

class StudyPinEditorDeleted extends StudyPinEditorResult {
  const StudyPinEditorDeleted();
}

/// Dialog / bottom sheet to create or edit Study Pin annotations.
class AddEditStudyPinSheet extends StatefulWidget {
  const AddEditStudyPinSheet({
    super.key,
    this.initialShortText = '',
    this.initialFullExplanation,
    this.selectedText,
    this.pinType = StudyPinType.point,
    this.isEditing = false,
    this.allowDelete = false,
  });

  final String initialShortText;
  final String? initialFullExplanation;
  final String? selectedText;
  final StudyPinType pinType;
  final bool isEditing;
  final bool allowDelete;

  static Future<StudyPinEditorResult?> show(
    BuildContext context, {
    String initialShortText = '',
    String? initialFullExplanation,
    String? selectedText,
    StudyPinType pinType = StudyPinType.point,
    bool isEditing = false,
    bool allowDelete = false,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final child = AddEditStudyPinSheet(
      initialShortText: initialShortText,
      initialFullExplanation: initialFullExplanation,
      selectedText: selectedText,
      pinType: pinType,
      isEditing: isEditing,
      allowDelete: allowDelete,
    );

    if (isWide) {
      return showDialog<StudyPinEditorResult>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
            child: Padding(padding: const EdgeInsets.all(8), child: child),
          ),
        ),
      );
    }

    return showModalBottomSheet<StudyPinEditorResult>(
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
        builder: (_) =>
            FullExplanationScreen(initialText: _fullExplanation ?? ''),
      ),
    );
    if (result != null && mounted) {
      setState(() => _fullExplanation = result.trim().isEmpty ? null : result);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this annotation?'),
        content: const Text(
          'The annotation will be removed. The PDF or image is not affected.',
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
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const StudyPinEditorDeleted());
    }
  }

  void _save() {
    final short = _shortController.text.trim();
    if (short.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Short description is required.')),
      );
      return;
    }
    Navigator.of(context).pop(
      StudyPinEditorSaved(shortText: short, fullExplanation: _fullExplanation),
    );
  }

  String get _title {
    if (widget.isEditing) {
      return widget.pinType == StudyPinType.text
          ? 'Edit Text Annotation'
          : 'Edit Point Annotation';
    }
    return widget.pinType == StudyPinType.text
        ? 'Add Text Annotation'
        : 'Add Point Annotation';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFull = _fullExplanation != null && _fullExplanation!.isNotEmpty;
    final selected = widget.selectedText?.trim();
    final showSelected =
        widget.pinType == StudyPinType.text &&
        selected != null &&
        selected.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_title, style: theme.textTheme.titleLarge),
            if (showSelected) ...[
              const SizedBox(height: 16),
              Text(
                'Selected text',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    selected,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _shortController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Short description',
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
              children: [
                if (widget.allowDelete)
                  TextButton(
                    onPressed: _confirmDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Delete'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
