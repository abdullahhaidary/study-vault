import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/interactive_html_repository.dart';
import '../domain/html_bundle.dart';

/// Picks an `.html` page or `.zip` bundle and adds it to [lessonId].
Future<LessonMaterial?> importInteractiveHtmlFile(
  WidgetRef ref, {
  required String lessonId,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['html', 'htm', 'zip'],
    withData: false,
    dialogTitle: 'Import interactive HTML',
  );
  if (result == null || result.files.isEmpty) return null;
  final picked = result.files.single;
  final path = picked.path;
  if (path == null) {
    throw const InteractiveHtmlException('Could not read the selected file.');
  }
  return ref
      .read(interactiveHtmlRepositoryProvider)
      .importFile(
        lessonId: lessonId,
        sourcePath: path,
        originalName: picked.name,
      );
}

/// Lets the user paste a page (for example from ChatGPT) and saves it.
Future<LessonMaterial?> showPasteHtmlDialog(
  BuildContext context, {
  required String lessonId,
}) {
  return showDialog<LessonMaterial>(
    context: context,
    builder: (_) => _PasteHtmlDialog(lessonId: lessonId),
  );
}

class _PasteHtmlDialog extends ConsumerStatefulWidget {
  const _PasteHtmlDialog({required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<_PasteHtmlDialog> createState() => _PasteHtmlDialogState();
}

class _PasteHtmlDialogState extends ConsumerState<_PasteHtmlDialog> {
  final _title = TextEditingController();
  final _html = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _html.dispose();
    super.dispose();
  }

  bool get _ready =>
      _title.text.trim().isNotEmpty && _html.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final material = await ref
          .read(interactiveHtmlRepositoryProvider)
          .createFromText(
            lessonId: widget.lessonId,
            title: _title.text,
            html: _html.text,
          );
      if (mounted) Navigator.of(context).pop(material);
    } on InteractiveHtmlException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Paste interactive HTML'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: TextField(
                controller: _html,
                minLines: 8,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'HTML',
                  hintText: '<!DOCTYPE html>\n<html>…</html>',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scripts and styles inside the page run as written. A code '
              'fence copied from a chat answer is removed. For pages with '
              'image files, import a .zip instead.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || !_ready ? null : _save,
          child: const Text('Save page'),
        ),
      ],
    );
  }
}
