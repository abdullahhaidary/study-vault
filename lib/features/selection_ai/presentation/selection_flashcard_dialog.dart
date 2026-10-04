import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/auto_direction_text_field.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../flashcards/data/flashcards_providers.dart';

/// Minimal "front / back" dialog used by the selection toolbar.
class SelectionFlashcardDialog extends ConsumerStatefulWidget {
  const SelectionFlashcardDialog({
    super.key,
    required this.front,
    this.back = '',
    this.lessonId,
  });

  final String front;
  final String back;
  final String? lessonId;

  static Future<bool> show(
    BuildContext context, {
    required String front,
    String back = '',
    String? lessonId,
  }) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => SelectionFlashcardDialog(
        front: front,
        back: back,
        lessonId: lessonId,
      ),
    );
    return created ?? false;
  }

  @override
  ConsumerState<SelectionFlashcardDialog> createState() =>
      _SelectionFlashcardDialogState();
}

class _SelectionFlashcardDialogState
    extends ConsumerState<SelectionFlashcardDialog> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _front = TextEditingController(text: widget.front.trim());
    _back = TextEditingController(text: widget.back.trim());
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final front = _front.text.trim();
    final back = _back.text.trim();
    if (front.isEmpty || back.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await createFlashcard(
        ref,
        lessonId: widget.lessonId,
        front: front,
        back: MarkdownToQuill.toDeltaJson(back),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the flashcard.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New flashcard'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AutoDirectionTextField(
              controller: _front,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Front',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AutoDirectionTextField(
              controller: _back,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Back (answer)',
                hintText: 'Markdown is supported',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([_front, _back]),
          builder: (context, _) => FilledButton(
            onPressed:
                _saving ||
                    _front.text.trim().isEmpty ||
                    _back.text.trim().isEmpty
                ? null
                : _create,
            child: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ),
      ],
    );
  }
}
