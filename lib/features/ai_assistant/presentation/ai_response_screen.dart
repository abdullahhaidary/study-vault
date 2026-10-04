import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/database/app_database.dart';
import '../../../core/widgets/auto_direction_text_field.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../ai_questions/domain/question_source.dart';
import '../../ai_questions/presentation/generate_questions_sheet.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../data/ai_providers.dart';
import '../domain/ai_execution_selection.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_models.dart';
import '../domain/ai_token_usage.dart';
import '../domain/annotation_ai_context.dart';
import '../domain/annotation_ai_history.dart';
import '../services/ai_prompt_builder.dart';
import '../services/markdown_to_quill.dart';
import 'ai_assistant_controller.dart';
import 'widgets/ai_model_picker.dart';
import 'ai_flashcards_preview.dart';
import 'widgets/ai_usage_indicator.dart';
import 'widgets/voice_input_button.dart';

/// Result of the annotation AI response screen.
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
  AiTextResult? result,
  required AiStudyAction action,
  required AiStudyRequest request,
  AnnotationAiContext? annotationContext,
  AnnotationAiGeneration? initialGeneration,
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
        initialGeneration: initialGeneration,
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
    this.initialResult,
    required this.action,
    required this.request,
    this.annotationContext,
    this.initialGeneration,
    this.questionsLaunch,
    this.onFlashcardsCreate,
    this.onCreateNote,
    this.onGoToSource,
  });

  final AiTextResult? initialResult;
  final AiStudyAction action;
  final AiStudyRequest request;
  final AnnotationAiContext? annotationContext;
  final AnnotationAiGeneration? initialGeneration;
  final GenerateQuestionsLaunch? questionsLaunch;
  final Future<void> Function(List<AiFlashcardDraft> cards)? onFlashcardsCreate;
  final Future<void> Function(String markdown)? onCreateNote;
  final VoidCallback? onGoToSource;

  @override
  ConsumerState<AiResponseScreen> createState() => _AiResponseScreenState();
}

class _AiResponseScreenState extends ConsumerState<AiResponseScreen> {
  final List<AiConversationTurn> _conversation = [];
  final _followUpController = TextEditingController();
  var _busy = false;
  var _generatingLabel = '';
  List<AnnotationAiGeneration> _generations = [];
  AnnotationAiGeneration? _selected;
  var _historyReady = false;

  /// Transient follow-up answer; does not mutate immutable history rows.
  String? _followUpOverride;

  /// Frozen first answer used as the seed assistant turn for multi-turn asks.
  String? _seedAssistantMarkdown;

  AnnotationAiContext get _context {
    return widget.annotationContext ??
        AnnotationAiContext(
          selectedText: widget.request.sourceText,
          materialId: widget.request.materialId,
          lessonId: widget.request.lessonId,
          pageNumber: widget.request.pageNumber,
          annotationId: widget.request.annotationId,
          surroundingText: widget.request.surroundingText,
          shortDescription: widget.request.shortDescription,
          language: widget.request.language,
        );
  }

  String get _fingerprint =>
      AnnotationAiSourceFingerprint.fromContext(_context);

  String get _markdown =>
      _followUpOverride ??
      _selected?.responseText ??
      widget.initialResult?.markdown ??
      '';

  AiTokenUsage? get _usageForDisplay {
    final selected = _selected;
    if (selected != null) {
      return aiTokenUsageFromColumns(
        promptTokens: selected.promptTokens,
        completionTokens: selected.completionTokens,
        totalTokens: selected.totalTokens,
        cacheHitTokens: selected.cacheHitTokens,
        cacheMissTokens: selected.cacheMissTokens,
        model: selected.modelName,
        provider: selected.provider,
        durationMs: selected.requestDurationMs,
      );
    }
    return widget.initialResult?.usage;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final history = ref.read(annotationAiHistoryServiceProvider);
    var gens = await history.getGenerations(
      sourceFingerprint: _fingerprint,
      action: widget.action,
    );

    // Persist the just-generated result if it is not already in history.
    final incoming = widget.initialResult?.markdown.trim();
    if (incoming != null && incoming.isNotEmpty) {
      final already = gens.any((g) => g.responseText.trim() == incoming);
      if (!already) {
        final saved = await history.persistCompleted(
          context: _context,
          action: widget.action,
          responseText: widget.initialResult!.markdown,
          rephraseMode: widget.request.rephraseMode,
          organizeMode: widget.request.organizeMode,
          summarizeMode: widget.request.summarizeMode,
          translateTarget: widget.request.translateTarget,
          customPrompt: widget.request.customPrompt,
          modelName:
              widget.initialResult?.usage?.model ??
              widget.request.selection.resolvedModelId,
          provider:
              widget.initialResult?.usage?.provider ??
              widget.request.selection.providerStorage,
          usage: widget.initialResult!.usage,
        );
        gens = [...gens, saved];
      }
    }

    if (!mounted) return;
    setState(() {
      _generations = gens;
      _selected =
          widget.initialGeneration ?? (gens.isNotEmpty ? gens.last : null);
      _followUpOverride = null;
      _historyReady = true;
    });
    _invalidateCounts();
  }

  void _invalidateCounts() {
    ref.invalidate(annotationAiGenerationCountsProvider(_fingerprint));
  }

  @override
  void dispose() {
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _newVersion({
    String? regenerateInstruction,
    AnnotationAiGeneration? parent,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _generatingLabel = 'Generating V${_generations.length + 1}…';
    });

    final history = ref.read(annotationAiHistoryServiceProvider);
    final parentGen = parent ?? _selected;
    var selection =
        parentGen != null && (parentGen.modelName?.trim().isNotEmpty ?? false)
        ? AiExecutionSelection.fromStored(
            provider: AiProviderIdX.fromStorage(parentGen.provider),
            modelId: parentGen.modelName!,
            action: widget.action,
          )
        : widget.request.selection;
    if (!mounted) return;
    selection =
        await showAiModelSelector(
          context,
          selected: selection,
          action: widget.action,
          title: 'Regenerate with',
        ) ??
        selection;

    try {
      if (!mounted) return;
      if (!await AiAssistantController.ensureReady(context, ref)) {
        if (mounted) {
          setState(() {
            _busy = false;
            _generatingLabel = '';
          });
        }
        return;
      }
      if (!mounted) return;

      final saved = await history.regenerate(
        context: _context,
        action: widget.action,
        selection: selection,
        parent: parentGen,
        rephraseMode: widget.request.rephraseMode,
        organizeMode: widget.request.organizeMode,
        summarizeMode: widget.request.summarizeMode,
        translateTarget: widget.request.translateTarget,
        customPrompt: widget.request.customPrompt,
        regenerateInstruction: regenerateInstruction,
      );

      if (!mounted) return;
      setState(() {
        _generations = [..._generations, saved];
        _selected = saved;
        _conversation.clear();
        _followUpOverride = null;
        _busy = false;
        _generatingLabel = '';
      });
      _invalidateCounts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _generatingLabel = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('AiException')
                ? e.toString()
                : 'AI request failed. Previous versions were kept.',
          ),
        ),
      );
    }
  }

  Future<void> _regenerateWithInstruction() async {
    final instruction = await showAiPromptDialog(
      context,
      title: 'Regenerate with instruction',
      hint: 'Make it shorter / use a banking example…',
      confirmLabel: 'Regenerate',
    );
    if (instruction == null || instruction.isEmpty || !mounted) return;
    await _newVersion(regenerateInstruction: instruction, parent: _selected);
  }

  Future<void> _editSelected() async {
    final current = _selected;
    if (current == null || _busy) return;
    final controller = TextEditingController(text: current.responseText);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit V${current.generationNumber}'),
        content: SizedBox(
          width: 650,
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: TextField(
            controller: controller,
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, value.text.trim()),
              child: const Text('Save as new version'),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null || edited == current.responseText.trim() || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await ref
          .read(annotationAiHistoryServiceProvider)
          .editGeneration(original: current, responseText: edited);
      if (!mounted) return;
      setState(() {
        _generations = [..._generations, saved];
        _selected = saved;
        _conversation.clear();
        _followUpOverride = null;
        _seedAssistantMarkdown = null;
      });
      _invalidateCounts();
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your changes.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected() async {
    final current = _selected;
    if (current == null || _busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete V${current.generationNumber}?'),
        content: const Text(
          'This removes only this AI generation. The annotation and other '
          'versions stay intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final history = ref.read(annotationAiHistoryServiceProvider);
    await history.deleteGeneration(current.id);

    final remaining = _generations.where((g) => g.id != current.id).toList();
    AnnotationAiGeneration? next;
    if (remaining.isNotEmpty) {
      // Prefer nearest lower number, else nearest higher.
      final lower = remaining
          .where((g) => g.generationNumber < current.generationNumber)
          .toList();
      next = lower.isNotEmpty ? lower.last : remaining.first;
    }

    if (!mounted) return;
    setState(() {
      _generations = remaining;
      _selected = next;
      _conversation.clear();
      _followUpOverride = null;
    });
    _invalidateCounts();
  }

  Future<void> _deleteAll() async {
    if (_generations.isEmpty || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete all ${widget.action.menuLabel}?'),
        content: Text(
          'Remove all ${_generations.length} saved '
          '${widget.action.menuLabel.toLowerCase()} generations for this '
          'source? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref
        .read(annotationAiHistoryServiceProvider)
        .deleteAllForAction(
          sourceFingerprint: _fingerprint,
          action: widget.action,
        );
    if (!mounted) return;
    setState(() {
      _generations = [];
      _selected = null;
      _conversation.clear();
      _followUpOverride = null;
    });
    _invalidateCounts();
  }

  Future<void> _sendFollowUp() async {
    final question = _followUpController.text.trim();
    if (question.isEmpty || _busy) return;
    final ctx = widget.annotationContext;
    if (ctx == null) return;

    setState(() => _busy = true);
    _seedAssistantMarkdown ??= _markdown;
    final seedUser = AiPromptBuilder.deepSeekLatestUserContent(
      widget.request.copyWith(conversation: const []),
    );
    final conversation = <AiConversationTurn>[
      AiConversationTurn(
        userMessage: seedUser.isNotEmpty
            ? seedUser
            : 'Please help with the selected study material.',
        assistantMarkdown: _seedAssistantMarkdown!,
      ),
      ..._conversation,
    ];
    final result = await AiAssistantController.runWithLoading(
      context,
      ref,
      request: ctx.toStudyRequest(
        action: AiStudyAction.askAi,
        selection: widget.request.selection,
        customPrompt: question,
        conversation: conversation,
      ),
      annotationContext: ctx,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is AiTextResult) {
      final history = ref.read(annotationAiHistoryServiceProvider);
      final saved = await history.persistCompleted(
        context: ctx,
        action: AiStudyAction.askAi,
        responseText: result.markdown,
        customPrompt: question,
        parentGenerationId: _selected?.id,
        modelName:
            result.usage?.model ?? widget.request.selection.resolvedModelId,
        provider:
            result.usage?.provider ?? widget.request.selection.providerStorage,
        usage: result.usage,
      );
      ref.invalidate(
        annotationAiGenerationCountsProvider(
          AnnotationAiSourceFingerprint.fromContext(ctx),
        ),
      );
      if (!mounted) return;
      setState(() {
        _conversation.add(
          AiConversationTurn(
            userMessage: question,
            assistantMarkdown: result.markdown,
          ),
        );
        _followUpOverride = result.markdown;
        _selected = saved;
        _generations = [..._generations, saved];
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
        selection: widget.request.selection,
        flashcardCount: count,
      ),
      annotationContext: ctx,
    );
    if (result is! AiFlashcardsResult || !mounted) return;

    final history = ref.read(annotationAiHistoryServiceProvider);
    await history.persistCompleted(
      context: localCtx,
      action: AiStudyAction.generateFlashcards,
      responseText: result.cards
          .map((c) => 'Q: ${c.front}\nA: ${c.back}')
          .join('\n\n---\n\n'),
      responseKind: 'flashcards',
      parentGenerationId: _selected?.id,
      modelName:
          result.usage?.model ?? widget.request.selection.resolvedModelId,
      provider:
          result.usage?.provider ?? widget.request.selection.providerStorage,
      usage: result.usage,
    );
    ref.invalidate(
      annotationAiGenerationCountsProvider(
        AnnotationAiSourceFingerprint.fromContext(localCtx),
      ),
    );

    if (!mounted) return;
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
    final timeFmt = DateFormat.jm();
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.action.menuLabel),
        actions: [
          if (_generations.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete_all') await _deleteAll();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete_all',
                  child: Text('Delete all versions'),
                ),
              ],
            ),
        ],
      ),
      body: ScrollEdgeArrows(
        child: Column(
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
            if (_historyReady && _generations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.action.menuLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        _CountChip(count: _generations.length),
                        const Spacer(),
                        if (selected != null)
                          Text(
                            'V${selected.generationNumber} · '
                            '${timeFmt.format(selected.createdAt.toLocal())}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Directionality(
                      // Keep version chronology LTR even in RTL locales.
                      textDirection: TextDirection.ltr,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final g in _generations)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 6,
                                ),
                                child: ChoiceChip(
                                  label: Text('V${g.generationNumber}'),
                                  selected: selected?.id == g.id,
                                  onSelected: _busy
                                      ? null
                                      : (_) {
                                          setState(() {
                                            _selected = g;
                                            _conversation.clear();
                                            _followUpOverride = null;
                                            _seedAssistantMarkdown = null;
                                          });
                                        },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (selected?.modelName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Model: ${AiModels.displayBadge(provider: selected!.provider, modelName: selected.modelName)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            if (_busy && _generatingLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(_generatingLabel),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: !_historyReady
                        ? const Center(child: CircularProgressIndicator())
                        : _markdown.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No generations yet',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: _busy ? null : () => _newVersion(),
                                  child: const Text('Generate'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                StudyRichTextViewer(storedValue: stored),
                                if (_usageForDisplay != null) ...[
                                  const SizedBox(height: 8),
                                  AiUsageIndicator(usage: _usageForDisplay!),
                                ],
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: _markdown),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Copied'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.copy_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Copy response'),
                                  ),
                                ),
                              ],
                            ),
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
                    VoiceInputButton(
                      controller: _followUpController,
                      enabled: !_busy,
                      compact: true,
                    ),
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
                  OutlinedButton.icon(
                    onPressed: _busy || _selected == null
                        ? null
                        : _editSelected,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _newVersion(),
                    child: const Text('New Version'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _selected == null
                        ? null
                        : () => _newVersion(parent: _selected),
                    child: const Text('Regenerate'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _selected == null
                        ? null
                        : _regenerateWithInstruction,
                    child: const Text('Regenerate with instruction'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _selected == null
                        ? null
                        : _deleteSelected,
                    child: const Text('Delete'),
                  ),
                  if (widget.onCreateNote != null)
                    OutlinedButton(
                      onPressed: _busy || _markdown.isEmpty
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
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
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
