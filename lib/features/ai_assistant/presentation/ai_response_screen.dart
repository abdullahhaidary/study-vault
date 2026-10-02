import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/auto_direction_text_field.dart';
import '../../ai_questions/domain/question_source.dart';
import '../../ai_questions/presentation/generate_questions_sheet.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_models.dart';
import '../domain/annotation_ai_context.dart';
import '../services/markdown_to_quill.dart';
import 'ai_assistant_controller.dart';
import 'ai_flashcards_preview.dart';

/// Result of the annotation AI response screen (ephemeral unless user saves).
class AiResponseScreenResult {
  const AiResponseScreenResult({
    required this.markdown,
    this.createNote = false,
  });

  final String markdown;
  final bool createNote;
}

/// Reusable AI response UI for annotation / PDF selection flows.
Future<AiResponseScreenResult?> showAiResponseScreen(
  BuildContext context,
  WidgetRef ref, {
  required AiTextResult result,
  required AiStudyAction action,
  required AiStudyRequest request,
  AnnotationAiContext? annotationContext,
  GenerateQuestionsLaunch? questionsLaunch,
  Future<void> Function(List<AiFlashcardDraft> cards)? onFlashcardsCreate,
  Future<void> Function(String markdown)? onCreateNote,
  VoidCallback? onGoToSource,
}) {
  return Navigator.of(context).push<AiResponseScreenResult>(
    MaterialPageRoute(
      builder: (_) => AiResponseScreen(
        initialResult: result,
        action: action,
        request: request,
        annotationContext: annotationContext,
        questionsLaunch: questionsLaunch,
        onFlashcardsCreate: onFlashcardsCreate,
        onCreateNote: onCreateNote,
        onGoToSource: onGoToSource,
      ),
    ),
  );
}

class AiResponseScreen extends ConsumerStatefulWidget {
  const AiResponseScreen({
    super.key,
    required this.initialResult,
    required this.action,
    required this.request,
    this.annotationContext,
    this.questionsLaunch,
    this.onFlashcardsCreate,
    this.onCreateNote,
    this.onGoToSource,
  });

  final AiTextResult initialResult;
  final AiStudyAction action;
  final AiStudyRequest request;
  final AnnotationAiContext? annotationContext;
  final GenerateQuestionsLaunch? questionsLaunch;
  final Future<void> Function(List<AiFlashcardDraft> cards)? onFlashcardsCreate;
  final Future<void> Function(String markdown)? onCreateNote;
  final VoidCallback? onGoToSource;

  @override
  ConsumerState<AiResponseScreen> createState() => _AiResponseScreenState();
}

class _AiResponseScreenState extends ConsumerState<AiResponseScreen> {
  late String _markdown;
  final List<AiConversationTurn> _conversation = [];
  final _followUpController = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _markdown = widget.initialResult.markdown;
  }

  @override
  void dispose() {
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await AiAssistantController.runWithLoading(
      context,
      ref,
      request: widget.request,
      annotationContext: widget.annotationContext,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is AiTextResult) {
      setState(() {
        _markdown = result.markdown;
        _conversation.clear();
      });
    }
  }

  Future<void> _sendFollowUp() async {
    final question = _followUpController.text.trim();
    if (question.isEmpty || _busy) return;
    final ctx = widget.annotationContext;
    if (ctx == null) return;

    setState(() => _busy = true);
    final prior = List<AiConversationTurn>.from(_conversation);
    final result = await AiAssistantController.runWithLoading(
      context,
      ref,
      request: ctx.toStudyRequest(
        action: AiStudyAction.askAi,
        customPrompt: question,
        conversation: [
          ...prior,
          AiConversationTurn(
            userMessage: 'Previous answer context',
            assistantMarkdown: _markdown,
          ),
        ],
      ),
      annotationContext: ctx,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is AiTextResult) {
      setState(() {
        _conversation.add(
          AiConversationTurn(
            userMessage: question,
            assistantMarkdown: _markdown,
          ),
        );
        _markdown = result.markdown;
        _followUpController.clear();
      });
    }
  }

  Future<void> _createFlashcards() async {
    final ctx = widget.annotationContext;
    final source = ctx?.primaryText ?? widget.request.sourceText;
    final count = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('How many flashcards?')),
            for (final n in _flashcardCountOptions(source))
              ListTile(
                title: Text('$n'),
                onTap: () => Navigator.pop(context, n),
              ),
          ],
        ),
      ),
    );
    if (count == null || !mounted) return;

    final localCtx = ctx ?? AnnotationAiContext(selectedText: source);
    final result = await AiAssistantController.runWithLoading(
      context,
      ref,
      request: localCtx.toStudyRequest(
        action: AiStudyAction.generateFlashcards,
        flashcardCount: count,
      ),
      annotationContext: ctx,
    );
    if (result is! AiFlashcardsResult || !mounted) return;
    await showAiFlashcardsPreview(
      context,
      cards: result.cards,
      onCreate: widget.onFlashcardsCreate,
    );
  }

  Future<void> _generateQuestions() async {
    final launch =
        widget.questionsLaunch ??
        GenerateQuestionsLaunch(
          availableSources: const [QuestionSourceType.selectedText],
          initialSource: QuestionSourceType.selectedText,
          resolveSource: (type) async {
            return QuestionSourceBuilder.fromSelectedText(
              text: widget.request.sourceText,
              materialId: widget.request.materialId,
              lessonId: widget.request.lessonId,
              pageNumber: widget.request.pageNumber,
            );
          },
        );
    await showGenerateQuestionsSheet(context, ref, launch: launch);
  }

  @override
  Widget build(BuildContext context) {
    final stored = MarkdownToQuill.toDeltaJson(_markdown);
    final page =
        widget.request.pageNumber ?? widget.annotationContext?.pageNumber;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Response'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _markdown));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              }
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (page != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text('Source: Page $page'),
              trailing: widget.onGoToSource == null
                  ? null
                  : TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onGoToSource!();
                      },
                      child: const Text('Go to Source'),
                    ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.action.menuLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      Expanded(
                        child: SingleChildScrollView(
                          child: StudyRichTextViewer(storedValue: stored),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.annotationContext != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AutoDirectionTextField(
                      controller: _followUpController,
                      decoration: const InputDecoration(
                        hintText: 'Ask a follow-up…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendFollowUp(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _sendFollowUp,
                    icon: const Icon(Icons.send),
                    tooltip: 'Ask follow-up',
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _retry,
                  child: const Text('Retry'),
                ),
                if (widget.onCreateNote != null)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await widget.onCreateNote!(_markdown);
                            if (context.mounted) {
                              Navigator.pop(
                                context,
                                AiResponseScreenResult(
                                  markdown: _markdown,
                                  createNote: true,
                                ),
                              );
                            }
                          },
                    child: const Text('Create Note'),
                  ),
                if (widget.onFlashcardsCreate != null)
                  OutlinedButton(
                    onPressed: _busy ? null : _createFlashcards,
                    child: const Text('Create Flashcards'),
                  ),
                OutlinedButton(
                  onPressed: _busy ? null : _generateQuestions,
                  child: const Text('Generate Questions'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    AiResponseScreenResult(markdown: _markdown),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<int> _flashcardCountOptions(String source) {
  final len = source.trim().length;
  if (len < 120) return const [3, 5];
  if (len < 400) return const [5, 10];
  return const [5, 10, 20];
}
