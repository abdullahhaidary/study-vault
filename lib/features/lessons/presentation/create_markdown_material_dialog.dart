import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/materials_providers.dart';

/// Paste or type markdown that becomes a lesson attachment (PDF-like source).
Future<LessonMaterial?> showCreateMarkdownMaterialDialog(
  BuildContext context, {
  required String lessonId,
}) {
  return showDialog<LessonMaterial>(
    context: context,
    builder: (_) => _CreateMarkdownMaterialDialog(lessonId: lessonId),
  );
}

class _CreateMarkdownMaterialDialog extends ConsumerStatefulWidget {
  const _CreateMarkdownMaterialDialog({required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<_CreateMarkdownMaterialDialog> createState() =>
      _CreateMarkdownMaterialDialogState();
}

class _CreateMarkdownMaterialDialogState
    extends ConsumerState<_CreateMarkdownMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final material = await attachMarkdownToLesson(
        ref,
        lessonId: widget.lessonId,
        title: _titleController.text,
        markdown: _bodyController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, material);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add text document'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Paste markdown (or plain text). It is stored with this '
                  'chapter like a PDF and works with AI Study Materials and '
                  'Course Review.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. HTML cheat sheet',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a title';
                    }
                    if (value.trim().length > 300) {
                      return 'Title is too long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bodyController,
                  minLines: 10,
                  maxLines: 18,
                  decoration: const InputDecoration(
                    labelText: 'Markdown / text',
                    alignLabelWithHint: true,
                    hintText: '# Heading\n\nPaste your notes or HTML notes here…',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Paste or type some content';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
