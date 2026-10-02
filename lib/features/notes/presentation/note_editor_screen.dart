import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/auto_direction_text_field.dart';
import '../../ai_assistant/presentation/ai_actions_sheet.dart';
import '../../ai_assistant/presentation/ai_preview_screen.dart';
import '../../ai_questions/presentation/question_source_launches.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../../study_pins/presentation/widgets/study_rich_text_editor.dart';
import '../data/notes_providers.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  QuillController? _editor;
  TextEditingController? _title;
  bool _saving = false;

  @override
  void dispose() {
    _editor?.dispose();
    _title?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = ref.read(studyNoteByIdProvider(widget.noteId)).valueOrNull;
    final editor = _editor;
    final title = _title;
    if (note == null ||
        editor == null ||
        title == null ||
        title.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    await updateStudyNoteContent(
      ref,
      note: note,
      title: title.text,
      content: StudyNoteCodec.encode(editor.document),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openAiActions() async {
    final editor = _editor;
    if (editor == null) return;
    final selection = editor.selection;
    final hadSelection = !selection.isCollapsed;
    final sourceText = hadSelection
        ? editor.getPlainText().trim()
        : editor.document.toPlainText().trim();
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

    final note = ref.read(studyNoteByIdProvider(widget.noteId)).valueOrNull;
    await showAiActionsSheet(
      context,
      ref,
      sourceText: sourceText,
      selectedText: hadSelection ? sourceText : null,
      actionContext: AiActionContext.noteEditor,
      questionsLaunch: QuestionSourceLaunches.forNoteText(
        ref: ref,
        noteText: sourceText,
        lessonId: note?.lessonId,
        subjectId: note?.subjectId,
        noteId: note?.id,
        noteTitle: note?.title,
      ),
      onTextPreviewApplied: (preview) {
        applyPreviewToQuill(editor, preview, hadSelection: hadSelection);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(studyNoteByIdProvider(widget.noteId));
    return note.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('Could not load note: $error'))),
      data: (item) {
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Note not found.')));
        }
        _title ??= TextEditingController(text: item.title);
        _editor ??= QuillController(
          document: StudyNoteCodec.decode(item.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
        return Scaffold(
          appBar: AppBar(
            leading: TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            leadingWidth: 76,
            title: const Text('Edit Note'),
            actions: [
              IconButton(
                tooltip: 'AI Actions',
                onPressed: _saving ? null : _openAiActions,
                icon: const Icon(Icons.auto_awesome),
              ),
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AutoDirectionTextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StudyRichTextEditor(
                    controller: _editor!,
                    autofocus: true,
                    expands: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
