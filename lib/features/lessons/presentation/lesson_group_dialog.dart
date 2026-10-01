import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/lesson_groups_providers.dart';

/// Create or edit a lesson group.
class LessonGroupDialog extends ConsumerStatefulWidget {
  const LessonGroupDialog({super.key, required this.subjectId, this.existing});

  final String subjectId;
  final LessonGroup? existing;

  static Future<void> show(
    BuildContext context, {
    required String subjectId,
    LessonGroup? existing,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          LessonGroupDialog(subjectId: subjectId, existing: existing),
    );
  }

  @override
  ConsumerState<LessonGroupDialog> createState() => _LessonGroupDialogState();
}

class _LessonGroupDialogState extends ConsumerState<LessonGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await updateLessonGroupDetails(
          ref,
          group: widget.existing!,
          name: _nameController.text,
          description: _descriptionController.text,
        );
      } else {
        await createLessonGroup(
          ref,
          subjectId: widget.subjectId,
          name: _nameController.text,
          description: _descriptionController.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Lesson Group' : 'Add Lesson Group'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g. Unit 1 - Fundamentals',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'A short note about this group',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
