import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/auto_direction_text_field.dart';
import '../../../core/widgets/system_bottom_inset.dart';
import '../../ai_questions/presentation/generate_questions_sheet.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../data/ai_providers.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_execution_selection.dart';
import '../domain/ai_models.dart';
import '../domain/annotation_ai_context.dart';
import '../domain/inline_ai_models.dart';
import '../services/inline_ai_annotation_saver.dart';
import '../services/markdown_to_quill.dart';
import 'ai_assistant_controller.dart';
import 'widgets/ai_model_picker.dart';
import 'ai_flashcards_preview.dart';
import 'ai_response_screen.dart';
import 'inline_ai_controller.dart';
import 'widgets/ai_usage_indicator.dart';
import 'widgets/voice_input_button.dart';

/// Callbacks the PDF study screen provides for persistence side-effects.
class InlineAiHostCallbacks {
  const InlineAiHostCallbacks({
    required this.onDismiss,
    this.onCreateNote,
    this.onFlashcardsCreate,
    this.questionsLaunch,
    this.onGoToSource,
    this.onAnnotationSaved,
    this.resourceId,
    this.rangeInputs = const [],
  });

  final VoidCallback onDismiss;
  final Future<void> Function(String markdown)? onCreateNote;
  final Future<void> Function(List<AiFlashcardDraft> cards)? onFlashcardsCreate;
  final GenerateQuestionsLaunch? questionsLaunch;
  final VoidCallback? onGoToSource;
  final Future<void> Function(StudyPin pin)? onAnnotationSaved;
  final String? resourceId;
  final List<TextRangeInput> rangeInputs;
}

/// Floating / docked inline AI panel over the PDF viewer.
class InlineAiOverlay extends ConsumerStatefulWidget {
  const InlineAiOverlay({
    super.key,
    required this.mode,
    required this.aiContext,
    required this.callbacks,
    this.existingPin,
    this.anchorGlobal,
    this.useBottomSheetLayout = false,
  });

  final InlineAiSourceMode mode;
  final AnnotationAiContext aiContext;
  final InlineAiHostCallbacks callbacks;
  final StudyPin? existingPin;
  final Offset? anchorGlobal;
  final bool useBottomSheetLayout;

  @override
  ConsumerState<InlineAiOverlay> createState() => _InlineAiOverlayState();
}

class _InlineAiOverlayState extends ConsumerState<InlineAiOverlay> {
  late final InlineAiController _controller;
  final _askController = TextEditingController();
  final _askFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = InlineAiController(
      ref: ref,
      mode: widget.mode,
      context: widget.aiContext,
      existingPin: widget.existingPin,
    );
    _controller.addListener(_onChanged);
    _controller.bootstrap();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    if (_controller.state.focusAskField) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _askController.dispose();
    _askFocus.dispose();
    super.dispose();
  }

  Future<bool> _ensureReady() => AiAssistantController.ensureReady(
    context,
    ref,
    requireGemini: _controller.state.pageSendMode == AiPageSendMode.image,
  );

  Future<void> _run(AiStudyAction action) async {
    if (action == AiStudyAction.generateQuestions) {
      final launch = widget.callbacks.questionsLaunch;
      if (launch != null) {
        await showGenerateQuestionsSheet(context, ref, launch: launch);
      }
      return;
    }
    if (action == AiStudyAction.generateFlashcards) {
      await _createFlashcards();
      return;
    }
    if (action == AiStudyAction.translate) {
      final target = await _pickTranslateTarget();
      if (target == null || !mounted) return;
      await _controller.runAction(
        action,
        translateTarget: target,
        ensureReady: _ensureReady,
      );
      return;
    }
    if (action == AiStudyAction.customPrompt) {
      final prompt = await _promptDialog(
        title: 'Custom prompt',
        hint: 'Explain this using a real-world banking example.',
      );
      if (prompt == null || prompt.isEmpty || !mounted) return;
      await _controller.runAction(
        action,
        customPrompt: prompt,
        ensureReady: _ensureReady,
      );
      return;
    }
    if (action == AiStudyAction.rephrase) {
      await _controller.runAction(
        action,
        rephraseMode: AiRephraseMode.clearer,
        ensureReady: _ensureReady,
      );
      return;
    }
    if (action == AiStudyAction.summarize) {
      await _controller.runAction(
        action,
        summarizeMode: AiSummarizeMode.keyPoints,
        ensureReady: _ensureReady,
      );
      return;
    }
    await _controller.runAction(action, ensureReady: _ensureReady);
  }

  Future<void> _submitAsk() async {
    final text = _askController.text;
    await _controller.ask(text, ensureReady: _ensureReady);
    if (mounted) {
      _askController.clear();
      _askFocus.unfocus();
    }
  }

  Future<void> _expand() async {
    final state = _controller.state;
    final action = state.action ?? AiStudyAction.explain;
    final selection =
        state.selection ??
        await AiExecutionSelection.fromGlobal(
          ref.read(aiSettingsStoreProvider),
          action: action,
        );
    if (!mounted) return;
    final request = _controller.buildStudyRequest(selection);
    final result = state.hasResponse
        ? AiTextResult(markdown: state.markdown)
        : null;

    await showAiResponseScreen(
      context,
      ref,
      result: result,
      action: action,
      request: request,
      annotationContext: state.context,
      initialGeneration: state.selected,
      questionsLaunch: widget.callbacks.questionsLaunch,
      onFlashcardsCreate: widget.callbacks.onFlashcardsCreate,
      onCreateNote: widget.callbacks.onCreateNote,
      onGoToSource: widget.callbacks.onGoToSource,
    );

    // Refresh after returning from full view.
    if (!mounted) return;
    if (state.action != null) {
      await _controller.runAction(
        state.action!,
        customPrompt: state.customPrompt,
        summarizeMode: state.summarizeMode,
        rephraseMode: state.rephraseMode,
        translateTarget: state.translateTarget,
        ensureReady: () async => true,
      );
    } else {
      await _controller.bootstrap();
    }
  }

  Future<void> _addToAnnotation() async {
    final state = _controller.state;
    if (!state.hasResponse) return;

    final target = await showModalBottomSheet<InlineAiAnnotationTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Add AI response as'),
              subtitle: Text('Choose where to save this answer'),
            ),
            ListTile(
              leading: const Icon(Icons.short_text),
              title: const Text('Short description'),
              onTap: () => Navigator.pop(
                context,
                InlineAiAnnotationTarget.shortDescription,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Full explanation'),
              subtitle:
                  _controller.existingPin != null &&
                      (_controller.existingPin!.fullExplanation ?? '')
                          .trim()
                          .isNotEmpty
                  ? const Text('Replaces the current full note')
                  : null,
              onTap: () => Navigator.pop(
                context,
                InlineAiAnnotationTarget.fullExplanation,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Append to explanation'),
              onTap: () => Navigator.pop(
                context,
                InlineAiAnnotationTarget.appendToExplanation,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;

    final resourceId = widget.callbacks.resourceId;
    if (resourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save annotation here.')),
      );
      return;
    }

    if (_controller.existingPin == null &&
        widget.callbacks.rangeInputs.isEmpty &&
        state.mode == InlineAiSourceMode.selection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selection ranges are unavailable.')),
      );
      return;
    }

    // Page mode without pin: use short/full on a point-less text pin requires
    // ranges — only allow when selection ranges exist.
    if (_controller.existingPin == null &&
        widget.callbacks.rangeInputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select text to create an annotation, or open an existing pin.',
          ),
        ),
      );
      return;
    }

    try {
      final pin = await InlineAiAnnotationSaver.save(
        ref: ref,
        target: target,
        markdown: state.markdown,
        action: state.action,
        resourceId: resourceId,
        selectedText: state.context.selectedText,
        ranges: widget.callbacks.rangeInputs,
        existingPin: _controller.existingPin,
      );
      _controller.bindExistingPin(pin);
      await widget.callbacks.onAnnotationSaved?.call(pin);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to annotation')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save annotation.')),
      );
    }
  }

  Future<void> _createFlashcards() async {
    final state = _controller.state;
    final source = state.context.primaryText;
    final count = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('How many flashcards?')),
            for (final n in _flashcardCounts(source))
              ListTile(
                title: Text('$n'),
                onTap: () => Navigator.pop(context, n),
              ),
          ],
        ),
      ),
    );
    if (count == null || !mounted) return;

    final result = await AiAssistantController.runWithLoading(
      context,
      ref,
      request: state.context.toStudyRequest(
        action: AiStudyAction.generateFlashcards,
        selection:
            state.selection ??
            await AiExecutionSelection.fromGlobal(
              ref.read(aiSettingsStoreProvider),
              action: AiStudyAction.generateFlashcards,
            ),
        flashcardCount: count,
        pageSendMode: state.pageSendMode,
      ),
      annotationContext: state.context,
    );
    if (result is! AiFlashcardsResult || !mounted) return;
    await showAiFlashcardsPreview(
      context,
      cards: result.cards,
      onCreate: widget.callbacks.onFlashcardsCreate,
    );
  }

  Future<void> _moreMenu() async {
    final state = _controller.state;
    final more = state.mode == InlineAiSourceMode.page
        ? InlineAiQuickActions.pageMore
        : InlineAiQuickActions.selectionMore;

    final chosen = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('More AI actions')),
            for (final action in more)
              ListTile(
                title: Text(action.menuLabel),
                trailing: _countBadge(context, state.counts[action] ?? 0),
                onTap: () => Navigator.pop(context, action),
              ),
            if (state.hasResponse) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Regenerate with instruction'),
                onTap: () => Navigator.pop(context, 'regen_instruction'),
              ),
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('Create note'),
                onTap: () => Navigator.pop(context, 'create_note'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_full),
                title: const Text('Open full history'),
                onTap: () => Navigator.pop(context, 'expand'),
              ),
              if (state.selected != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('Delete this generation'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
            ],
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;

    if (chosen is AiStudyAction) {
      await _run(chosen);
      return;
    }
    switch (chosen) {
      case 'regen_instruction':
        final instruction = await _promptDialog(
          title: 'Regenerate with instruction',
          hint: 'Make it shorter / use a banking example…',
        );
        if (instruction == null || instruction.isEmpty || !mounted) return;
        await _controller.regenerate(
          ensureReady: _ensureReady,
          instruction: instruction,
        );
      case 'create_note':
        await widget.callbacks.onCreateNote?.call(state.markdown);
      case 'expand':
        await _expand();
      case 'delete':
        await _controller.deleteSelected();
    }
  }

  Future<AiLanguage?> _pickTranslateTarget() {
    return showModalBottomSheet<AiLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in const [
              AiLanguage.english,
              AiLanguage.persianDari,
            ])
              ListTile(
                title: Text(lang.label),
                onTap: () => Navigator.pop(context, lang),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptDialog({required String title, required String hint}) {
    return showAiPromptDialog(
      context,
      title: title,
      hint: hint,
      confirmLabel: 'OK',
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final narrow = media.size.width < 720 || widget.useBottomSheetLayout;
    final panel = _InlineAiPanelCard(
      state: _controller.state,
      askController: _askController,
      askFocus: _askFocus,
      onRun: _run,
      onAskFocusChip: () {
        _controller.requestAskFocus();
        _askFocus.requestFocus();
      },
      onSubmitAsk: _submitAsk,
      onIgnore: widget.callbacks.onDismiss,
      onAddToAnnotation: _addToAnnotation,
      onCopy: () async {
        final md = _controller.state.markdown;
        if (md.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: md));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Copied')));
        }
      },
      onRegenerate: () => _controller.regenerate(ensureReady: _ensureReady),
      onExpand: _expand,
      onMore: _moreMenu,
      onRetry: () {
        final action = _controller.state.action;
        if (action == null) {
          _controller.clearErrorAndReady();
          return;
        }
        _run(action);
      },
      onSelectGeneration: _controller.selectGeneration,
      onPageSendMode: widget.mode == InlineAiSourceMode.page
          ? _controller.setPageSendMode
          : null,
      onSelectionChanged: _controller.setSelection,
      showAddToAnnotation:
          widget.mode == InlineAiSourceMode.selection ||
          _controller.existingPin != null,
    );

    if (narrow) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: SystemBottomInset.of(context, extra: 12),
          ),
          child: panel,
        ),
      );
    }

    final anchor = widget.anchorGlobal;
    final size = media.size;
    double left = 24;
    double top = 72;
    if (anchor != null) {
      left = (anchor.dx - 160).clamp(12.0, size.width - 380);
      top = (anchor.dy + 12).clamp(56.0, size.height - 420);
    }

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: 360,
          child: Padding(
            padding: EdgeInsets.only(bottom: SystemBottomInset.of(context)),
            child: panel,
          ),
        ),
      ],
    );
  }
}

class _InlineAiPanelCard extends StatelessWidget {
  const _InlineAiPanelCard({
    required this.state,
    required this.askController,
    required this.askFocus,
    required this.onRun,
    required this.onAskFocusChip,
    required this.onSubmitAsk,
    required this.onIgnore,
    required this.onAddToAnnotation,
    required this.onCopy,
    required this.onRegenerate,
    required this.onExpand,
    required this.onMore,
    required this.onRetry,
    required this.onSelectGeneration,
    this.onPageSendMode,
    this.onSelectionChanged,
    required this.showAddToAnnotation,
  });

  final InlineAiViewState state;
  final TextEditingController askController;
  final FocusNode askFocus;
  final Future<void> Function(AiStudyAction action) onRun;
  final VoidCallback onAskFocusChip;
  final Future<void> Function() onSubmitAsk;
  final VoidCallback onIgnore;
  final Future<void> Function() onAddToAnnotation;
  final Future<void> Function() onCopy;
  final Future<void> Function() onRegenerate;
  final Future<void> Function() onExpand;
  final Future<void> Function() onMore;
  final VoidCallback onRetry;
  final void Function(AnnotationAiGeneration g) onSelectGeneration;
  final void Function(AiPageSendMode mode)? onPageSendMode;
  final ValueChanged<AiExecutionSelection>? onSelectionChanged;
  final bool showAddToAnnotation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = state.phase == InlineAiPhase.loading;
    final chips = state.mode == InlineAiSourceMode.page
        ? InlineAiQuickActions.page
        : InlineAiQuickActions.selection;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420, maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.action?.menuLabel ?? 'AI',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (state.hasResponse)
                    IconButton(
                      tooltip: 'Expand',
                      visualDensity: VisualDensity.compact,
                      onPressed: busy ? null : onExpand,
                      icon: const Icon(Icons.open_in_full, size: 18),
                    ),
                  IconButton(
                    tooltip: 'Ignore',
                    visualDensity: VisualDensity.compact,
                    onPressed: onIgnore,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                state.contextLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onPageSendMode != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Send as',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    for (final mode in AiPageSendMode.values)
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: state.pageSendMode == mode,
                        onSelected: busy ? null : (_) => onPageSendMode!(mode),
                      ),
                  ],
                ),
              ),
            if (state.selection != null && onSelectionChanged != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AiModelPickerButton(
                    selection: state.selection!,
                    action: state.action,
                    compact: true,
                    constraints: state.pageSendMode == AiPageSendMode.image
                        ? AiExecutionConstraints.vision
                        : AiExecutionConstraints.none,
                    onChanged: busy ? (_) {} : onSelectionChanged!,
                  ),
                ),
              ),
            if (state.phase == InlineAiPhase.ready ||
                (state.phase == InlineAiPhase.error && !state.hasResponse))
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final action in chips)
                      ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(action.menuLabel),
                            if ((state.counts[action] ?? 0) > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${state.counts[action]}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        onPressed: busy ? null : () => onRun(action),
                      ),
                    ActionChip(
                      label: const Text('Ask…'),
                      onPressed: busy ? null : onAskFocusChip,
                    ),
                    ActionChip(
                      label: const Text('More'),
                      onPressed: busy ? null : onMore,
                    ),
                  ],
                ),
              ),
            if (state.generations.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final g in state.generations)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: ChoiceChip(
                              label: Text(
                                g.modelName == null || g.modelName!.isEmpty
                                    ? 'V${g.generationNumber}'
                                    : 'V${g.generationNumber} · ${AiModels.displayBadge(provider: g.provider, modelName: g.modelName)}',
                              ),
                              selected: state.selected?.id == g.id,
                              onSelected: busy
                                  ? null
                                  : (_) => onSelectGeneration(g),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Flexible(child: _buildBody(context, busy)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter): () {
                          if (!busy) onSubmitAsk();
                        },
                      },
                      child: AutoDirectionTextField(
                        controller: askController,
                        focusNode: askFocus,
                        enabled: !busy,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: busy ? null : (_) => onSubmitAsk(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: state.hasResponse
                              ? 'Ask a follow-up…'
                              : state.mode == InlineAiSourceMode.page
                              ? 'Ask about this page…'
                              : 'Ask about this selection…',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  VoiceInputButton(
                    controller: askController,
                    focusNode: askFocus,
                    enabled: !busy,
                    compact: true,
                  ),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: busy ? null : onSubmitAsk,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                ],
              ),
            ),
            if (state.hasResponse || state.phase == InlineAiPhase.loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: onIgnore,
                      child: const Text('Ignore'),
                    ),
                    if (showAddToAnnotation)
                      FilledButton(
                        onPressed: busy || !state.hasResponse
                            ? null
                            : onAddToAnnotation,
                        child: const Text('Add to annotation'),
                      ),
                    TextButton(
                      onPressed: busy || !state.hasResponse ? null : onCopy,
                      child: const Text('Copy'),
                    ),
                    TextButton(
                      onPressed: busy || state.action == null
                          ? null
                          : onRegenerate,
                      child: const Text('Regenerate'),
                    ),
                    TextButton(
                      onPressed: busy ? null : onMore,
                      child: const Text('More'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool busy) {
    final theme = Theme.of(context);

    if (busy) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                state.action?.loadingMessage ?? 'Working…',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (state.phase == InlineAiPhase.error && !state.hasResponse) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.errorMessage ?? 'Couldn’t generate a response.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
                const SizedBox(width: 8),
                TextButton(onPressed: onIgnore, child: const Text('Dismiss')),
              ],
            ),
          ],
        ),
      );
    }

    if (!state.hasResponse) {
      return const SizedBox.shrink();
    }

    final stored = MarkdownToQuill.toDeltaJson(state.markdown);
    final usage = state.selected == null
        ? null
        : aiTokenUsageFromColumns(
            promptTokens: state.selected!.promptTokens,
            completionTokens: state.selected!.completionTokens,
            totalTokens: state.selected!.totalTokens,
            cacheHitTokens: state.selected!.cacheHitTokens,
            cacheMissTokens: state.selected!.cacheMissTokens,
            model: state.selected!.modelName,
            provider: state.selected!.provider,
            durationMs: state.selected!.requestDurationMs,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudyRichTextViewer(storedValue: stored),
            if (usage != null) ...[
              const SizedBox(height: 8),
              AiUsageIndicator(usage: usage),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

Widget? _countBadge(BuildContext context, int count) {
  if (count <= 0) return null;
  final theme = Theme.of(context);
  return Text(
    '$count',
    style: theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

List<int> _flashcardCounts(String source) {
  final len = source.trim().length;
  if (len < 200) return const [3, 5];
  if (len < 800) return const [5, 8, 10];
  return const [5, 10, 15];
}
