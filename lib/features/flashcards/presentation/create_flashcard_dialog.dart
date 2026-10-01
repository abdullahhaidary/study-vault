import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../../study_pins/presentation/full_explanation_screen.dart';
import '../data/flashcards_providers.dart';

class CreateFlashcardDialog extends ConsumerStatefulWidget {
  const CreateFlashcardDialog({super.key, required this.pin});

  final StudyPin pin;

  static Future<void> show(BuildContext context, {required StudyPin pin}) {
    return showDialog<void>(
      context: context,
      builder: (_) => CreateFlashcardDialog(pin: pin),
    );
  }

  @override
  ConsumerState<CreateFlashcardDialog> createState() =>
      _CreateFlashcardDialogState();
}

class _CreateFlashcardDialogState extends ConsumerState<CreateFlashcardDialog> {
  late final TextEditingController _front;
  late String _back;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    final defaults = defaultsFromStudyPin(widget.pin);
    _front = TextEditingController(text: defaults.front);
    _back = defaults.back;
  }

  @override
  void dispose() {
    _front.dispose();
    super.dispose();
  }

  Future<void> _editBack() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            FullExplanationScreen(initialText: _back, title: 'Flashcard back'),
      ),
    );
    if (value != null && mounted) setState(() => _back = value);
  }

  Future<void> _create() async {
    if (_front.text.trim().isEmpty) return;
    setState(() => _creating = true);
    try {
      final card = await createFlashcardFromPin(
        ref,
        pin: widget.pin,
        front: _front.text,
        back: _back,
      );
      if (mounted) Navigator.of(context).pop(card.id);
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Flashcard'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _front,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Front'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Back'),
              subtitle: Text(
                StudyNoteCodec.plainTextPreview(_back).isEmpty
                    ? 'No answer yet'
                    : StudyNoteCodec.plainTextPreview(_back),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _editBack,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _creating ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
