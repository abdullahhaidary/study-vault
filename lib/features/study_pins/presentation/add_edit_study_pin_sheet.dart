import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/auto_direction_text_field.dart';
import '../../ai_assistant/presentation/ai_actions_sheet.dart';
import '../../ai_assistant/presentation/ai_preview_screen.dart';
import '../data/pin_categories_providers.dart';
import '../domain/pin_type.dart';
import '../domain/study_note_codec.dart';
import 'widgets/study_rich_text_editor.dart';

/// Result returned when the user saves (or deletes) from the annotation editor.
sealed class StudyPinEditorResult {
  const StudyPinEditorResult();
}

class StudyPinEditorSaved extends StudyPinEditorResult {
  const StudyPinEditorSaved({
    required this.shortText,
    this.fullExplanation,
    this.categoryId,
  });

  final String shortText;

  /// Stored Full Note value (Quill Delta JSON) or `null` when empty.
  final String? fullExplanation;

  /// Null means General / no category.
  final String? categoryId;
}

class StudyPinEditorDeleted extends StudyPinEditorResult {
  const StudyPinEditorDeleted();
}

/// Dialog / bottom sheet to create or edit Study Pin annotations.
class AddEditStudyPinSheet extends ConsumerStatefulWidget {
  const AddEditStudyPinSheet({
    super.key,
    this.initialShortText = '',
    this.initialFullExplanation,
    this.initialCategoryId,
    this.selectedText,
    this.pinType = StudyPinType.point,
    this.isEditing = false,
    this.allowDelete = false,
  });

  final String initialShortText;
  final String? initialFullExplanation;
  final String? initialCategoryId;
  final String? selectedText;
  final StudyPinType pinType;
  final bool isEditing;
  final bool allowDelete;

  static Future<StudyPinEditorResult?> show(
    BuildContext context, {
    String initialShortText = '',
    String? initialFullExplanation,
    String? initialCategoryId,
    String? selectedText,
    StudyPinType pinType = StudyPinType.point,
    bool isEditing = false,
    bool allowDelete = false,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final child = AddEditStudyPinSheet(
      initialShortText: initialShortText,
      initialFullExplanation: initialFullExplanation,
      initialCategoryId: initialCategoryId,
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
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 780),
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
  ConsumerState<AddEditStudyPinSheet> createState() =>
      _AddEditStudyPinSheetState();
}

class _AddEditStudyPinSheetState extends ConsumerState<AddEditStudyPinSheet> {
  late final TextEditingController _shortController;
  late final QuillController _fullController;
  late final String _initialFullEncoded;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _shortController = TextEditingController(text: widget.initialShortText);
    _categoryId = widget.initialCategoryId;

    final document = StudyNoteCodec.decode(
      widget.initialFullExplanation?.isEmpty ?? true
          ? null
          : widget.initialFullExplanation,
    );
    _fullController = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _initialFullEncoded = StudyNoteCodec.encode(document);
    _fullController.addListener(_onFullChanged);
  }

  void _onFullChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shortController.dispose();
    _fullController
      ..removeListener(_onFullChanged)
      ..dispose();
    super.dispose();
  }

  bool get _fullDirty =>
      StudyNoteCodec.encode(_fullController.document) != _initialFullEncoded;

  bool get _isDirty {
    final shortChanged =
        _shortController.text.trim() != widget.initialShortText.trim();
    final categoryChanged = _categoryId != widget.initialCategoryId;
    return shortChanged || _fullDirty || categoryChanged;
  }

  String? get _encodedFullNote =>
      StudyNoteCodec.encodeOrNull(_fullController.document);

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Your annotation edits will be lost if you leave without saving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _onCancel() async {
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    Navigator.of(context).pop();
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
      StudyPinEditorSaved(
        shortText: short,
        fullExplanation: _encodedFullNote,
        categoryId: _categoryId,
      ),
    );
  }

  Future<void> _openAiActions() async {
    final selection = _fullController.selection;
    final hadSelection = !selection.isCollapsed;
    final sourceText = hadSelection
        ? _fullController.getPlainText().trim()
        : _fullController.document.toPlainText().trim();
    if (sourceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write some note text first.')),
      );
      return;
    }

    if (!hadSelection) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use the whole note?'),
          content: const Text(
            'No text is selected. AI will use the entire note as its source.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await showAiActionsSheet(
      context,
      ref,
      sourceText: sourceText,
      selectedText: hadSelection ? sourceText : null,
      actionContext: AiActionContext.noteEditor,
      onTextPreviewApplied: (preview) {
        applyPreviewToQuill(
          _fullController,
          preview,
          hadSelection: hadSelection,
        );
      },
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
    final mediaHeight = MediaQuery.sizeOf(context).height;
    // Cap the embedded editor to about 35% of the screen (less than half).
    final editorHeight = (mediaHeight * 0.35).clamp(160.0, 280.0);
    final selected = widget.selectedText?.trim();
    final showSelected =
        widget.pinType == StudyPinType.text &&
        selected != null &&
        selected.isNotEmpty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.92),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(_title, style: theme.textTheme.titleLarge),
                    if (showSelected) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Selected text',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadii.mdAll,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: AutoDirectionSelectableText(
                            selected,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AutoDirectionTextField(
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
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Category',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ref
                        .watch(studyPinCategoriesProvider)
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) =>
                              const Text('Could not load categories'),
                          data: (categories) {
                            return DropdownButtonFormField<String?>(
                              // ignore: deprecated_member_use
                              value: _categoryId,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('General'),
                                ),
                                for (final cat in categories)
                                  DropdownMenuItem<String?>(
                                    value: cat.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Color(cat.colorValue),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(cat.name),
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _categoryId = value),
                            );
                          },
                        ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Full Note',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'AI Actions',
                          visualDensity: VisualDensity.compact,
                          onPressed: _openAiActions,
                          icon: const Icon(Icons.auto_awesome, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      height: editorHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: AppRadii.mdAll,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadii.mdAll,
                          child: StudyRichTextEditor(
                            controller: _fullController,
                            autofocus: false,
                            showToolbar: true,
                            expands: true,
                            scrollable: true,
                            placeholder: 'Write a detailed study note…',
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
                  TextButton(onPressed: _onCancel, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
