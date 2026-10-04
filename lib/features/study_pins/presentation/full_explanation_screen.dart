import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_assistant/presentation/ai_actions_sheet.dart';
import '../../ai_assistant/presentation/ai_preview_screen.dart';
import '../../selection_ai/presentation/quill_selection_apply.dart';
import '../domain/study_note_codec.dart';
import 'widgets/study_rich_text_editor.dart';

/// Full-screen / route-level Full Note editor (and optional read-only view).
///
/// Returns the serialized Quill Delta JSON string on Save, or `null` on Cancel.
/// An empty note returns an empty string so the caller can clear the field.
class FullExplanationScreen extends StatefulWidget {
  const FullExplanationScreen({
    super.key,
    this.initialText = '',
    this.readOnly = false,
    this.title = 'Full Note',
  });

  /// Stored DB value: Quill Delta JSON or legacy plain text.
  final String initialText;
  final bool readOnly;
  final String title;

  @override
  State<FullExplanationScreen> createState() => _FullExplanationScreenState();
}

class _FullExplanationScreenState extends State<FullExplanationScreen> {
  late final QuillController _controller;
  late final String _initialEncoded;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final document = StudyNoteCodec.decode(
      widget.initialText.isEmpty ? null : widget.initialText,
    );
    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: widget.readOnly,
    );
    _initialEncoded = StudyNoteCodec.encode(document);
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final encoded = StudyNoteCodec.encode(_controller.document);
    final dirty = encoded != _initialEncoded;
    if (dirty != _dirty && mounted) {
      setState(() => _dirty = dirty);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || widget.readOnly) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Your Full Note edits will be lost if you leave without saving.',
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

  void _save() {
    final encoded = StudyNoteCodec.encodeOrNull(_controller.document);
    Navigator.of(context).pop(encoded ?? '');
  }

  Future<void> _openAiActions(WidgetRef ref) async {
    final selection = _controller.selection;
    final hadSelection = !selection.isCollapsed;
    final sourceText = hadSelection
        ? _controller.getPlainText().trim()
        : _controller.document.toPlainText().trim();
    if (sourceText.isEmpty) return;

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
        applyPreviewToQuill(_controller, preview, hadSelection: hadSelection);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_dirty || widget.readOnly,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscard();
        if (!shouldDiscard || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        // Let Scaffold shrink for the IME; do not also pad by viewInsets
        // or the Quill editor can get zero height on Android.
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              if (!widget.readOnly)
                TextButton(onPressed: _onCancel, child: const Text('Cancel'))
              else
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              Expanded(
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (!widget.readOnly)
                Consumer(
                  builder: (context, ref, _) => IconButton(
                    tooltip: 'AI Actions',
                    onPressed: () => _openAiActions(ref),
                    icon: const Icon(Icons.auto_awesome),
                  ),
                ),
              if (!widget.readOnly)
                TextButton(onPressed: _save, child: const Text('Save'))
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
        body: SafeArea(
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerLowest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: StudyRichTextEditor(
                    controller: _controller,
                    readOnly: widget.readOnly,
                    autofocus: !widget.readOnly,
                    showToolbar: !widget.readOnly,
                    expands: true,
                    selectionAiHost: () => QuillSelectionApply.host(
                      _controller,
                      title: widget.title,
                      readOnly: widget.readOnly,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
