import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/subject_groups_providers.dart';
import '../data/subjects_providers.dart';

/// Dialog for creating or editing a Subject.
class CreateSubjectDialog extends ConsumerStatefulWidget {
  const CreateSubjectDialog({
    super.key,
    required this.classId,
    this.existing,
    this.initialGroupId,
  });

  final String classId;
  final Subject? existing;
  final String? initialGroupId;

  static Future<void> show(
    BuildContext context, {
    required String classId,
    Subject? existing,
    String? initialGroupId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => CreateSubjectDialog(
        classId: classId,
        existing: existing,
        initialGroupId: initialGroupId,
      ),
    );
  }

  @override
  ConsumerState<CreateSubjectDialog> createState() =>
      _CreateSubjectDialogState();
}

class _CreateSubjectDialogState extends ConsumerState<CreateSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _selectedGroupId;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _selectedGroupId = widget.existing?.subjectGroupId ?? widget.initialGroupId;
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
        await updateSubjectDetails(
          ref,
          subject: widget.existing!,
          name: _nameController.text,
          description: _descriptionController.text,
          subjectGroupId: _selectedGroupId,
        );
      } else {
        await createSubject(
          ref,
          classId: widget.classId,
          name: _nameController.text,
          description: _descriptionController.text,
          subjectGroupId: _selectedGroupId,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(
      subjectGroupsForClassProvider(widget.classId),
    );

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Subject' : 'Add Subject'),
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
                  labelText: 'Subject Name',
                  hintText: 'e.g. Machine Learning',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject name';
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
                  hintText: 'A short note about this subject',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              groupsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (groups) {
                  return DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: _selectedGroupId,
                    decoration: const InputDecoration(labelText: 'Group'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      for (final group in groups)
                        DropdownMenuItem<String?>(
                          value: group.id,
                          child: Text(group.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedGroupId = value);
                    },
                  );
                },
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
