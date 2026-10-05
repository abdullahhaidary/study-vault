import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/markdown/chart_markdown_builder.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../../ai_assistant/presentation/ai_assistant_controller.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import '../../ai_assistant/presentation/widgets/ai_usage_indicator.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../ai_assistant/services/quill_to_markdown.dart';
import '../../study_pins/presentation/full_explanation_screen.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/services/ai_chat_navigation.dart';
import '../../reference_books/presentation/lecture_book_links.dart';
import '../../selection_ai/domain/markdown_selection_editor.dart';
import '../../selection_ai/domain/selection_ai_host.dart';
import '../../selection_ai/presentation/selection_ai_area.dart';
import '../data/pdf_ai_material_providers.dart';
import '../domain/pdf_ai_material_models.dart';

class PdfAiMaterialReaderScreen extends ConsumerStatefulWidget {
  const PdfAiMaterialReaderScreen({
    super.key,
    required this.materialId,
    required this.pdfTitle,
    required this.filePath,
    required this.type,
    this.initialGenerationId,
    this.embedded = false,
  });

  final String materialId;
  final String pdfTitle;
  final String filePath;
  final PdfAiMaterialType type;
  final String? initialGenerationId;
  final bool embedded;

  @override
  ConsumerState<PdfAiMaterialReaderScreen> createState() =>
      _PdfAiMaterialReaderScreenState();
}

class _PdfAiMaterialReaderScreenState
    extends ConsumerState<PdfAiMaterialReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageController _slideController = PageController();
  String? _slideGenerationId;
  int _slideIndex = 0;
  String? _selectedId;
  bool _generating = false;
  bool _editing = false;
  bool _deleting = false;
  String? _restoredGenerationId;
  bool _restoringScroll = false;
  Timer? _scrollSaveTimer;
  double? _pendingScrollOffset;
  String? _chunkedGenerationId;
  List<String> _markdownChunks = const [];
  String? _lessonId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialGenerationId;
    _scrollController.addListener(_saveScrollOffset);
    ref.read(databaseProvider).getMaterialById(widget.materialId).then((m) {
      if (mounted && m != null) setState(() => _lessonId = m.lessonId);
    });
  }

  SelectionAiHost _selectionHost(PdfAiMaterial selected) {
    return SelectionAiHost(
      title: widget.type.shortName,
      materialId: widget.materialId,
      lessonId: _lessonId,
      filePath: widget.filePath,
      documentText: selected.content,
      loadSummary: widget.type == PdfAiMaterialType.summary
          ? null
          : () async {
              final all =
                  ref
                      .read(pdfAiMaterialsProvider(widget.materialId))
                      .valueOrNull ??
                  const <PdfAiMaterial>[];
              return all
                  .where(
                    (m) => m.type == PdfAiMaterialType.summary.storageValue,
                  )
                  .firstOrNull
                  ?.content;
            },
      onReplaceSelection: (sel, md) => _applyContentEdit(
        selected,
        MarkdownSelectionEditor.replace(selected.content, sel, md),
      ),
      onInsertBelow: (sel, md) => _applyContentEdit(
        selected,
        MarkdownSelectionEditor.insertBelow(selected.content, sel, md),
      ),
      onAppendToEnd: (_, md) => _applyContentEdit(
        selected,
        MarkdownSelectionEditor.append(selected.content, md),
      ),
    );
  }

  /// Lets the user decide between a new version and overwriting this one.
  Future<bool> _applyContentEdit(
    PdfAiMaterial selected,
    String? newContent,
  ) async {
    if (newContent == null) {
      _showError(
        'Could not find the selected text in the ${widget.type.shortName}. '
        'Use "Add at end" instead.',
      );
      return false;
    }
    if (newContent.trim() == selected.content.trim()) return false;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Apply to ${widget.type.shortName}'),
              subtitle: const Text('How should the change be saved?'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Save as new version'),
              subtitle: Text('Version ${selected.version} stays in History'),
              onTap: () => Navigator.pop(context, 'new'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('Overwrite version ${selected.version}'),
              subtitle: const Text('Changes this version in place'),
              onTap: () => Navigator.pop(context, 'overwrite'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return false;
    setState(() => _editing = true);
    try {
      final service = ref.read(pdfAiMaterialServiceProvider);
      final saved = choice == 'new'
          ? await service.editVersion(original: selected, content: newContent)
          : await service.overwriteVersion(
              original: selected,
              content: newContent,
            );
      if (mounted) {
        setState(() => _selectedId = saved.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              choice == 'new'
                  ? 'Saved as version ${saved.version}.'
                  : 'Version ${saved.version} updated.',
            ),
          ),
        );
      }
      return true;
    } on Object catch (_) {
      _showError('Could not save your changes. Please try again.');
      return false;
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  void dispose() {
    _scrollSaveTimer?.cancel();
    _persistScrollOffset();
    _scrollController.removeListener(_saveScrollOffset);
    _scrollController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  PdfAiMaterialScrollKey _scrollKey(String generationId) => (
    materialId: widget.materialId,
    type: widget.type,
    generationId: generationId,
  );

  void _saveScrollOffset() {
    final generationId = _restoredGenerationId;
    if (_restoringScroll ||
        generationId == null ||
        !_scrollController.hasClients) {
      return;
    }
    _pendingScrollOffset = _scrollController.offset;
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(
      const Duration(milliseconds: 250),
      _persistScrollOffset,
    );
  }

  void _persistScrollOffset() {
    final generationId = _restoredGenerationId;
    final offset = _pendingScrollOffset;
    if (generationId == null || offset == null) return;
    _pendingScrollOffset = null;
    ref
            .read(
              pdfAiMaterialScrollOffsetProvider(
                _scrollKey(generationId),
              ).notifier,
            )
            .state =
        offset;
  }

  void _restoreScrollOffset(String generationId) {
    if (_restoredGenerationId == generationId) return;
    _scrollSaveTimer?.cancel();
    _persistScrollOffset();
    _restoredGenerationId = generationId;
    _restoringScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _restoringScroll = false;
        return;
      }
      final position = _scrollController.position;
      final saved = ref.read(
        pdfAiMaterialScrollOffsetProvider(_scrollKey(generationId)),
      );
      _scrollController.jumpTo(
        saved
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      _restoringScroll = false;
    });
  }

  List<String> _chunksFor(PdfAiMaterial material) {
    if (_chunkedGenerationId == material.id) return _markdownChunks;
    _chunkedGenerationId = material.id;

    const targetCharacters = 3500;
    final chunks = <String>[];
    final buffer = StringBuffer();
    var insideCodeFence = false;
    for (final line in material.content.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        insideCodeFence = !insideCodeFence;
      }
      buffer.writeln(line);
      final paragraphEnded = line.trim().isEmpty;
      if (!insideCodeFence &&
          buffer.length >= targetCharacters &&
          paragraphEnded) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());
    _markdownChunks = List.unmodifiable(chunks);
    return _markdownChunks;
  }

  Future<void> _regenerate() async {
    if (_generating) return;
    final instruction = await _showRegenerationDialog();
    if (instruction == null || !mounted) return;

    if (!await AiAssistantController.ensureReady(context, ref)) return;
    if (!mounted) return;
    var selection = await AiExecutionSelection.fromGlobal(
      ref.read(aiSettingsStoreProvider),
      action: AiStudyAction.customPrompt,
    );
    if (!mounted) return;
    selection =
        await showAiModelSelector(
          context,
          selected: selection,
          action: AiStudyAction.customPrompt,
          title: 'Regenerate with',
        ) ??
        selection;

    setState(() => _generating = true);
    try {
      final generated = await ref
          .read(pdfAiMaterialServiceProvider)
          .generate(
            materialId: widget.materialId,
            title: widget.pdfTitle,
            filePath: widget.filePath,
            type: widget.type,
            selection: selection,
            customInstruction: instruction,
          );
      if (!mounted) return;
      setState(() => _selectedId = generated.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Version ${generated.version} generated.')),
      );
    } on AiException catch (error) {
      _showError(error.message);
    } on Object catch (error) {
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<String?> _showRegenerationDialog() async {
    final controller = TextEditingController();
    final instruction = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generate a new ${widget.type.shortName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'The current version will remain available in History. '
              'Generating consumes API tokens.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Optional instructions',
                hintText: 'For example: Focus more on formulas.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    controller.dispose();
    return instruction;
  }

  /// Opens the same full-screen rich editor used for notes; the result is
  /// converted back to markdown and saved as a new version or in place.
  Future<void> _edit(PdfAiMaterial selected) async {
    if (_editing || _generating || _deleting) return;
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FullExplanationScreen(
          initialText: MarkdownToQuill.toDeltaJson(selected.content),
          title: 'Edit ${widget.type.shortName}',
          materialId: widget.materialId,
          lessonId: _lessonId,
        ),
      ),
    );
    if (edited == null || !mounted) return;
    final markdown = QuillToMarkdown.fromStored(edited);
    if (markdown.trim().isEmpty) {
      _showError('The ${widget.type.shortName} cannot be empty.');
      return;
    }
    await _applyContentEdit(selected, markdown);
  }

  Future<void> _delete(PdfAiMaterial selected) async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete version ${selected.version}?'),
        content: const Text(
          'This deletes only this generated version. The PDF, other versions, '
          'and AI chats will remain.',
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
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    await ref.read(pdfAiMaterialServiceProvider).deleteVersion(selected.id);
    if (!mounted) return;
    setState(() {
      _selectedId = null;
      _deleting = false;
    });
  }

  Future<void> _askAboutThis() {
    return AiChatNavigation.openNewWithAttachment(
      context,
      ref,
      attachment: AiContextItem(
        kind: AiContextKind.material,
        id: widget.materialId,
        materialId: widget.materialId,
        title: widget.pdfTitle,
      ),
      draftText: switch (widget.type) {
        PdfAiMaterialType.realWorldExamples =>
          'Let\'s practice with real-world examples from this PDF. Pick one '
              'topic, give me a new realistic scenario, and then ask me how '
              'the theory maps to it before you reveal the answer.',
        _ => 'I have a question about this PDF.',
      },
    );
  }

  Future<void> _showHistory(
    List<PdfAiMaterial> history,
    PdfAiMaterial selected,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          children: [
            Text(
              '${widget.type.shortName} History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < history.length; i++)
              ListTile(
                selected: history[i].id == selected.id,
                leading: const Icon(Icons.history),
                title: Text('Version ${history[i].version}'),
                subtitle: Text(
                  DateFormat.yMMMd().add_jm().format(
                    history[i].generatedAt.toLocal(),
                  ),
                ),
                trailing: i == 0 ? const Chip(label: Text('Current')) : null,
                onTap: () => Navigator.pop(context, history[i].id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedId = picked);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('no extractable text')) {
      return 'This PDF has no extractable text. OCR is not available yet.';
    }
    return 'Could not generate this study material. Please try again.';
  }

  void _syncSlideGeneration(String id) {
    if (_slideGenerationId == id) return;
    _slideGenerationId = id;
    _slideIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _slideGenerationId == id && _slideController.hasClients) {
        _slideController.jumpToPage(0);
      }
    });
  }

  Future<void> _showSlideOverview(List<String> slides) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: slides.length,
          itemBuilder: (context, index) {
            final title = slides[index]
                .split('\n')
                .first
                .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
                .trim();
            return ListTile(
              selected: index == _slideIndex,
              leading: Text('${index + 1}'),
              title: Text(
                title.isEmpty ? 'Slide ${index + 1}' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(context, index),
            );
          },
        ),
      ),
    );
    if (picked != null && mounted && _slideController.hasClients) {
      await _slideController.animateToPage(
        picked,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _slideshowBody(
    PdfAiMaterial selected,
    List<String> slides,
    AiTokenUsage? usage,
  ) {
    final theme = Theme.of(context);
    final slideStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      h1: theme.textTheme.headlineMedium,
      h2: theme.textTheme.titleLarge,
    );
    return Column(
      children: [
        if (!widget.embedded)
          MaterialBookLinksSection(materialId: widget.materialId),
        Expanded(
          child: PageView.builder(
            controller: _slideController,
            itemCount: slides.length,
            onPageChanged: (index) => setState(() => _slideIndex = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: SelectionAiArea(
                      host: _selectionHost(selected),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: MarkdownBody(
                          data: slides[index],
                          selectable: false,
                          styleSheet: slideStyle,
                          builders: chartMarkdownBuilders(slideStyle),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous slide',
                      onPressed: _slideIndex == 0
                          ? null
                          : () => _slideController.previousPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOut,
                            ),
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => _showSlideOverview(slides),
                        child: Text(
                          'Slide ${_slideIndex + 1} of ${slides.length} · All slides',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next slide',
                      onPressed: _slideIndex + 1 == slides.length
                          ? null
                          : () => _slideController.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOut,
                            ),
                      icon: const Icon(Icons.arrow_forward_ios),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _editing || _generating || _deleting
                            ? null
                            : () => _edit(selected),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: slides[_slideIndex]),
                        ),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy slide'),
                      ),
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: selected.content),
                        ),
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Copy all'),
                      ),
                      if (widget.embedded)
                        IconButton(
                          tooltip: 'Open slideshow full screen',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PdfAiMaterialReaderScreen(
                                materialId: widget.materialId,
                                pdfTitle: widget.pdfTitle,
                                filePath: widget.filePath,
                                type: widget.type,
                                initialGenerationId: selected.id,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_full),
                        ),
                    ],
                  ),
                ),
                if (usage != null) AiUsageIndicator(usage: usage),
                if (!widget.embedded)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _askAboutThis,
                          child: const Text('Ask about this'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: _generating ? null : _regenerate,
                          child: Text(
                            _generating ? 'Generating…' : 'Regenerate',
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(pdfAiMaterialsProvider(widget.materialId));

    return allAsync.when(
      loading: () => Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(title: Text(widget.type.displayName)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(title: Text(widget.type.displayName)),
        body: const Center(child: Text('Could not load saved generations.')),
      ),
      data: (all) {
        final history = [
          for (final material in all)
            if (material.type == widget.type.storageValue) material,
        ];
        if (history.isEmpty) {
          return Scaffold(
            appBar: widget.embedded
                ? null
                : AppBar(title: Text(widget.type.displayName)),
            body: const Center(child: Text('This version no longer exists.')),
          );
        }
        final selected = history.firstWhere(
          (item) => item.id == _selectedId,
          orElse: () => history.first,
        );
        final isSlideshow = widget.type == PdfAiMaterialType.slideshow;
        if (isSlideshow) {
          _syncSlideGeneration(selected.id);
        } else {
          _restoreScrollOffset(selected.id);
        }
        final slides = isSlideshow
            ? PdfAiSlideDeck.parse(selected.content)
            : const <String>[];
        final markdownChunks = isSlideshow
            ? const <String>[]
            : _chunksFor(selected);
        final bodyStyle = MarkdownStyleSheet.fromTheme(Theme.of(context));
        final usage = aiTokenUsageFromColumns(
          promptTokens: selected.promptTokens,
          completionTokens: selected.completionTokens,
          totalTokens: selected.totalTokens,
          cacheHitTokens: selected.cacheHitTokens,
          cacheMissTokens: selected.cacheMissTokens,
          model: selected.model,
          provider: selected.provider,
          durationMs: selected.requestDurationMs,
        );
        return Scaffold(
          appBar: widget.embedded
              ? null
              : AppBar(
                  title: Text(widget.type.displayName),
                  actions: [
                    IconButton(
                      tooltip: 'History',
                      onPressed: () => _showHistory(history, selected),
                      icon: Badge(
                        label: Text('${history.length}'),
                        child: const Icon(Icons.history),
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !_generating && !_editing && !_deleting,
                      onSelected: (value) {
                        if (value == 'delete') _delete(selected);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete this version'),
                        ),
                      ],
                    ),
                  ],
                ),
          body: isSlideshow && slides.isNotEmpty
              ? _slideshowBody(selected, slides, usage)
              : Column(
                  children: [
                    if (!widget.embedded)
                      MaterialBookLinksSection(materialId: widget.materialId),
                    Expanded(
                      child: ScrollEdgeArrows(
                        child: SelectionAiArea(
                          host: _selectionHost(selected),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: markdownChunks.length + 1,
                            itemBuilder: (context, index) {
                              if (index < markdownChunks.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: MarkdownBody(
                                    data: markdownChunks[index],
                                    selectable: false,
                                    styleSheet: bodyStyle,
                                    builders: chartMarkdownBuilders(bodyStyle),
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    children: [
                                      TextButton.icon(
                                        onPressed:
                                            _editing || _generating || _deleting
                                            ? null
                                            : () => _edit(selected),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Edit'),
                                      ),
                                      TextButton.icon(
                                        onPressed:
                                            selected.content.trim().isEmpty
                                            ? null
                                            : () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: selected.content,
                                                  ),
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
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  const Divider(height: 1),
                                  const SizedBox(height: AppSpacing.md),
                                  if (usage != null) ...[
                                    AiUsageIndicator(usage: usage),
                                    const SizedBox(height: AppSpacing.xs),
                                  ],
                                  Text(
                                    'Version ${selected.version} · '
                                    '${DateFormat.yMMMd().format(selected.generatedAt.toLocal())}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  if (!widget.embedded) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _generating
                                                ? null
                                                : _askAboutThis,
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                            ),
                                            label: const Text('Ask about this'),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: _generating
                                                ? null
                                                : _regenerate,
                                            icon: _generating
                                                ? const SizedBox.square(
                                                    dimension: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(Icons.refresh),
                                            label: Text(
                                              _generating
                                                  ? 'Generating…'
                                                  : 'Regenerate',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
