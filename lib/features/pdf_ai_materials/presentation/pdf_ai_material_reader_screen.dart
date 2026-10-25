import '../../../core/widgets/transient_snack_bar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/markdown/study_markdown.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../../ai_assistant/presentation/ai_assistant_controller.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import '../../ai_assistant/presentation/widgets/ai_usage_indicator.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../ai_assistant/services/quill_to_markdown.dart';
import '../../study_pins/presentation/full_explanation_screen.dart';
import '../../ai_questions/presentation/generate_questions_sheet.dart';
import '../../ai_questions/presentation/live_quiz_launch.dart';
import '../../ai_questions/presentation/question_source_launches.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/services/ai_chat_navigation.dart';
import '../../reference_books/presentation/lecture_book_links.dart';
import '../../selection_ai/domain/markdown_selection_editor.dart';
import '../../selection_ai/domain/selection_ai_host.dart';
import '../../selection_ai/presentation/selection_ai_area.dart';
import '../data/pdf_ai_material_providers.dart';
import '../data/pdf_ai_preferred_store.dart';
import '../domain/pdf_ai_material_models.dart';
import '../domain/pdf_ai_translation.dart';
import '../domain/pdf_ai_versioning.dart';
import '../services/pdf_ai_translation_service.dart';
import '../../ai_generation_queue/data/ai_generation_providers.dart';
import '../../ai_generation_queue/domain/ai_generation_models.dart';
import 'pdf_ai_manual_import_dialog.dart';
import 'pdf_ai_queue_actions.dart';
import 'pdf_ai_translation_actions.dart';

class _PdfAiRegenerateChoice {
  const _PdfAiRegenerateChoice({
    this.preset,
    this.customInstruction = '',
    this.alsoPersian = false,
  });

  final PdfAiRegeneratePreset? preset;
  final String customInstruction;
  final bool alsoPersian;
}

typedef _ScrollAnchor = ({int index, double fraction});

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
  AiGenerationJob? _queueJob;
  bool get _generating => _queueJob?.isActive ?? false;
  bool _editing = false;
  bool _deleting = false;
  String? _restoredGenerationId;
  PdfAiLanguage _restoredLanguage = PdfAiLanguage.original;
  bool _restoringScroll = false;
  Timer? _scrollSaveTimer;
  double? _pendingScrollOffset;
  String? _chunkedContent;
  List<String> _markdownChunks = const [];
  String? _lessonId;

  /// Section shown at the top when the language changed; restored after the
  /// other language is laid out so the reader stays at the same place.
  _ScrollAnchor? _anchor;
  final GlobalKey _listKey = GlobalKey();
  final Map<int, GlobalKey> _chunkKeys = {};

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialGenerationId;
    _scrollController.addListener(_saveScrollOffset);
    ref.read(databaseProvider).getMaterialById(widget.materialId).then((m) {
      if (mounted && m != null) setState(() => _lessonId = m.lessonId);
    });
  }

  /// [persianText] is set while the Persian translation is shown; AI edits
  /// then stay disabled because they would change the original.
  SelectionAiHost _selectionHost(
    PdfAiMaterial selected, [
    String? persianText,
  ]) {
    if (persianText != null) {
      return SelectionAiHost(
        title: '${widget.type.shortName} (فارسی)',
        materialId: widget.materialId,
        lessonId: _lessonId,
        filePath: widget.filePath,
        documentText: persianText,
      );
    }
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
          TransientSnackBar(
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

  PdfAiMaterialScrollKey _scrollKey(
    String generationId,
    PdfAiLanguage language,
  ) => (
    materialId: widget.materialId,
    type: widget.type,
    generationId: generationId,
    language: language,
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
                _scrollKey(generationId, _restoredLanguage),
              ).notifier,
            )
            .state =
        offset;
  }

  /// Restores the saved position of this version + language; after a
  /// language toggle it keeps the same section on screen instead.
  void _restoreScrollOffset(
    String generationId,
    PdfAiLanguage language,
    int sectionCount,
  ) {
    if (_restoredGenerationId == generationId &&
        _restoredLanguage == language) {
      return;
    }
    final languageToggled =
        _restoredGenerationId == generationId && _restoredLanguage != language;
    _scrollSaveTimer?.cancel();
    _persistScrollOffset();
    // Layout still shows the previous language here (build runs before
    // layout), so the visible section can be read before it is replaced.
    final anchor = languageToggled ? _captureAnchor() : null;
    _restoredGenerationId = generationId;
    _restoredLanguage = language;
    _restoringScroll = true;
    if (anchor != null) {
      _anchor = anchor;
      _applyAnchor(sectionCount);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _restoringScroll = false;
        return;
      }
      final position = _scrollController.position;
      final saved = ref.read(
        pdfAiMaterialScrollOffsetProvider(_scrollKey(generationId, language)),
      );
      _scrollController.jumpTo(
        saved
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      _restoringScroll = false;
    });
  }

  RenderBox? _box(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  _ScrollAnchor? _captureAnchor() {
    final list = _box(_listKey);
    if (list == null || !_scrollController.hasClients) return null;
    final indexes = _chunkKeys.keys.toList()..sort();
    for (final index in indexes) {
      final box = _box(_chunkKeys[index]);
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: list).dy;
      if (top + box.size.height > 0) {
        return (
          index: index,
          fraction: (-top / box.size.height).clamp(0.0, 1.0),
        );
      }
    }
    return null;
  }

  /// Scrolls until section [_anchor] is back at the top. Sections below the
  /// viewport are built lazily, so it may first jump to an estimate.
  void _applyAnchor(int sectionCount, [int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _anchor;
      if (!mounted || anchor == null || !_scrollController.hasClients) {
        _restoringScroll = false;
        return;
      }
      final position = _scrollController.position;
      double clamp(double value) =>
          value.clamp(position.minScrollExtent, position.maxScrollExtent);
      final list = _box(_listKey);
      // Sections currently laid out, with their top relative to the list.
      final built = <({int index, double top, double height})>[];
      for (final entry in _chunkKeys.entries) {
        final box = _box(entry.value);
        if (list == null || box == null || entry.key >= sectionCount) continue;
        built.add((
          index: entry.key,
          top: box.localToGlobal(Offset.zero, ancestor: list).dy,
          height: box.size.height,
        ));
      }
      final target = built.where((b) => b.index == anchor.index).firstOrNull;
      double? delta;
      if (target != null) {
        delta = target.top + anchor.fraction * target.height;
      } else if (built.isNotEmpty) {
        // Step from the nearest laid-out section using real section heights.
        built.sort(
          (a, b) => (a.index - anchor.index).abs().compareTo(
            (b.index - anchor.index).abs(),
          ),
        );
        final nearest = built.first;
        final average =
            built.fold<double>(0, (sum, b) => sum + b.height) / built.length;
        delta = nearest.top + (anchor.index - nearest.index) * average;
      }
      if (delta != null && delta.abs() > 1 && attempt < 12) {
        position.jumpTo(clamp(position.pixels + delta));
        _applyAnchor(sectionCount, attempt + 1);
        return;
      }
      _anchor = null;
      _restoringScroll = false;
    });
  }

  List<String> _chunksFor(PdfAiMaterial material) {
    if (_chunkedContent != material.content) {
      _chunkedContent = material.content;
      _markdownChunks = PdfAiTranslation.segments(material.content);
    }
    return _markdownChunks;
  }

  Future<void> _regenerate(PdfAiMaterial selected) async {
    if (_generating) return;
    final choice = await _showRegenerationDialog(
      hasCurrentContent: selected.content.trim().isNotEmpty,
    );
    if (choice == null || !mounted) return;

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

    final extra = choice.customInstruction.trim();
    final preset = choice.preset;
    final promptInstruction = [
      if (preset?.pdfInstruction != null) preset!.pdfInstruction!,
      if (extra.isNotEmpty) extra,
    ].join('\n');
    final storedInstruction = [
      if (preset != null) preset.label,
      if (extra.isNotEmpty) extra,
    ].join('\n');
    final reformatSource = preset != null && preset.usesCurrentContent
        ? selected.content
        : null;
    if (!mounted) return;

    await enqueuePdfMaterialGeneration(
      context: context,
      ref: ref,
      materialId: widget.materialId,
      lessonId: _lessonId,
      title: widget.pdfTitle,
      filePath: widget.filePath,
      type: widget.type,
      selection: selection,
      customInstruction: promptInstruction.isEmpty ? null : promptInstruction,
      storedInstruction: storedInstruction.isEmpty ? null : storedInstruction,
      reformatSource: reformatSource,
      reuseSourceFingerprint: reformatSource == null
          ? null
          : selected.sourceFingerprint,
      translateToPersian: choice.alsoPersian,
    );
  }

  Future<_PdfAiRegenerateChoice?> _showRegenerationDialog({
    required bool hasCurrentContent,
  }) async {
    final controller = TextEditingController();
    PdfAiRegeneratePreset? selected;
    var alsoPersian = ref.read(pdfAiAlsoPersianProvider).valueOrNull ?? false;

    final choice = await showDialog<_PdfAiRegenerateChoice>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final preset = selected;
            final usesCurrent = preset?.usesCurrentContent ?? false;
            return AlertDialog(
              title: Text('Generate a new ${widget.type.shortName}?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'The current version will remain available in History. '
                      'Generating consumes API tokens.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final option in PdfAiRegeneratePreset.values)
                          ChoiceChip(
                            label: Text(option.label),
                            selected: preset == option,
                            onSelected:
                                option.usesCurrentContent && !hasCurrentContent
                                ? null
                                : (isSelected) {
                                    setDialogState(() {
                                      selected = isSelected ? option : null;
                                    });
                                  },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      preset?.description ??
                          'Regenerate from the PDF using this study format. '
                              'Choose Reformat only to keep the current text '
                              'and fix Markdown, charts, and flow.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: controller,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: usesCurrent
                            ? 'Optional formatting notes'
                            : 'Optional extra instructions',
                        hintText: usesCurrent
                            ? 'For example: keep my heading names.'
                            : 'For example: Focus more on formulas.',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: alsoPersian,
                      onChanged: (value) =>
                          setDialogState(() => alsoPersian = value ?? false),
                      title: const Text('Also create Persian (فارسی)'),
                      subtitle: const Text(
                        'Same structure, section by section. Uses more tokens.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _PdfAiRegenerateChoice(
                      preset: selected,
                      customInstruction: controller.text,
                      alsoPersian: alsoPersian,
                    ),
                  ),
                  child: const Text('Regenerate'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (choice != null) await setPdfAiAlsoPersian(ref, choice.alsoPersian);
    return choice;
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
    final key = _preferredKey;
    final preferredId = await ref.read(pdfAiPreferredStoreProvider).read(key);
    if (preferredId == selected.id) {
      await ref.read(pdfAiPreferredStoreProvider).clear(key);
      ref.invalidate(pdfAiPreferredVersionProvider(key));
    }
    if (!mounted) return;
    setState(() {
      _selectedId = null;
      _deleting = false;
    });
  }

  PdfAiPreferredKey get _preferredKey =>
      PdfAiPreferredKey(materialId: widget.materialId, type: widget.type);

  Future<void> _makeDefault(PdfAiMaterial selected) async {
    await ref
        .read(pdfAiPreferredStoreProvider)
        .write(_preferredKey, selected.id);
    ref.invalidate(pdfAiPreferredVersionProvider(_preferredKey));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      TransientSnackBar(
        content: Text(
          '${widget.type.shortName} version ${selected.version} will open by default.',
        ),
      ),
    );
  }

  Future<void> _importJson([PdfAiMaterial? current]) async {
    final markdown = await showPdfAiManualImportDialog(
      context,
      type: widget.type,
      pdfTitle: widget.pdfTitle,
    );
    if (markdown == null || !mounted) return;
    try {
      final created = await ref
          .read(pdfAiMaterialServiceProvider)
          .importManual(
            materialId: widget.materialId,
            type: widget.type,
            content: markdown,
            sourceFingerprint: current?.sourceFingerprint,
          );
      if (!mounted) return;
      setState(() => _selectedId = created.id);
    } on Object catch (error) {
      _showError(_friendlyError(error));
    }
  }

  PopupMenuButton<String> _versionMenu(
    PdfAiMaterial selected,
    PdfAiMaterialTranslation? translation,
  ) {
    final translating =
        ref.watch(pdfAiTranslationProgressProvider(selected.id)) != null;
    return PopupMenuButton<String>(
      tooltip: 'Version options',
      enabled: !_generating && !_editing && !_deleting,
      onSelected: (value) {
        switch (value) {
          case 'default':
            _makeDefault(selected);
          case 'json':
            _importJson(selected);
          case 'translate':
            translatePdfAiVersion(context, ref, selected);
          case 'delete':
            _delete(selected);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'default',
          child: Text('Make this the default'),
        ),
        const PopupMenuItem(value: 'json', child: Text('Add from JSON')),
        PopupMenuItem(
          value: 'translate',
          enabled: !translating,
          child: Text(
            translation == null
                ? 'Translate to Persian (فارسی)'
                : 'Retranslate Persian (فارسی)',
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete this version'),
        ),
      ],
    );
  }

  Future<void> _setLanguage(
    PdfAiMaterial selected,
    PdfAiMaterialTranslation? translation,
    PdfAiLanguage next,
  ) async {
    if (next == PdfAiLanguage.persian && translation == null) {
      if (ref.read(pdfAiTranslationProgressProvider(selected.id)) != null) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create a Persian version?'),
          content: Text(
            'The ${widget.type.shortName.toLowerCase()} is translated section by '
            'section with the same headings, lists, formulas and code, so you '
            'can switch between both at the same place. This uses API tokens.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Translate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await translatePdfAiVersion(context, ref, selected);
      return;
    }
    ref.read(pdfAiLanguageProvider(widget.materialId).notifier).state = next;
  }

  /// EN | فا switch. Selecting فا without a translation offers to create it.
  Widget _languageToggle(
    PdfAiMaterial selected,
    PdfAiMaterialTranslation? translation,
    PdfAiLanguage showing,
  ) {
    final progress = ref.watch(pdfAiTranslationProgressProvider(selected.id));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: SegmentedButton<PdfAiLanguage>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: [
          const ButtonSegment(
            value: PdfAiLanguage.original,
            label: Text('EN'),
            tooltip: 'Original',
          ),
          ButtonSegment(
            value: PdfAiLanguage.persian,
            tooltip: translation == null
                ? 'Translate to Persian'
                : 'Persian (فارسی)',
            icon: progress != null
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : translation == null
                ? const Icon(Icons.translate, size: 16)
                : null,
            label: Text(progress == null ? 'فا' : 'فا $progress'),
          ),
        ],
        selected: {showing},
        onSelectionChanged: (value) =>
            _setLanguage(selected, translation, value.first),
      ),
    );
  }

  /// Hint shown above the text when Persian is wanted but missing or stale.
  Widget _translationNotice(
    PdfAiMaterial selected,
    PdfAiMaterialTranslation? translation,
    PdfAiLanguage wanted,
  ) {
    final missing = wanted == PdfAiLanguage.persian && translation == null;
    final stale =
        translation != null &&
        wanted == PdfAiLanguage.persian &&
        PdfAiTranslationService.isStale(translation, selected);
    if (!missing && !stale) return const SizedBox.shrink();
    final translating =
        ref.watch(pdfAiTranslationProgressProvider(selected.id)) != null;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.xs,
          AppSpacing.xxs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                missing
                    ? 'This version has no Persian translation yet.'
                    : 'The original changed after this translation.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: translating
                  ? null
                  : () => translatePdfAiVersion(context, ref, selected),
              child: Text(missing ? 'Translate' : 'Retranslate'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _embeddedVersionBar(
    List<PdfAiMaterial> history,
    PdfAiMaterial selected,
    PdfAiMaterialTranslation? translation,
    PdfAiLanguage showing,
  ) {
    if (!widget.embedded) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          IconButton(
            tooltip: 'History',
            onPressed: () => _showHistory(history, selected),
            icon: Badge(
              label: Text('${history.length}'),
              child: const Icon(Icons.history),
            ),
          ),
          const Spacer(),
          _languageToggle(selected, translation, showing),
          _versionMenu(selected, translation),
        ],
      ),
    );
  }

  // Batch quiz-set builder. Ask me questions uses the live tutor instead.
  // ignore: unused_element
  Future<void> _generateQuestions() {
    return showGenerateQuestionsSheet(
      context,
      ref,
      launch: QuestionSourceLaunches.forPdfAiMaterial(
        ref: ref,
        materialId: widget.materialId,
        filePath: widget.filePath,
        type: widget.type,
      ),
    );
  }

  Future<void> _askMeQuestions() {
    return showLiveQuizLaunch(
      context,
      ref,
      launch: QuestionSourceLaunches.forPdfAiMaterial(
        ref: ref,
        materialId: widget.materialId,
        filePath: widget.filePath,
        type: widget.type,
      ),
    );
  }

  Future<void> _askAboutThis() async {
    final all = await ref.read(
      pdfAiMaterialsProvider(widget.materialId).future,
    );
    final preferredId = await ref.read(
      pdfAiPreferredVersionProvider(_preferredKey).future,
    );
    final selected = PdfAiVersionPicker.pick(
      materials: all,
      type: widget.type,
      selectedId: _selectedId,
      preferredId: preferredId,
    );
    final body = selected?.content.trim() ?? '';
    if (!mounted) return;
    return AiChatNavigation.openNewWithAttachment(
      context,
      ref,
      attachment: AiContextItem(
        kind: AiContextKind.material,
        id: selected?.id ?? widget.materialId,
        materialId: widget.materialId,
        title: '${widget.type.shortName} · ${widget.pdfTitle}',
        // Pack the on-screen AI material so Claude sees that text (not only
        // a PDF extract that may be empty or unrelated to "translate this").
        packedText: body.isEmpty ? null : body,
      ),
      draftText: switch (widget.type) {
        PdfAiMaterialType.realWorldExamples =>
          'Let\'s practice with real-world examples from this PDF. Pick one '
              'topic, give me a new realistic scenario, and then ask me how '
              'the theory maps to it before you reveal the answer.',
        _ => 'I have a question about this ${widget.type.shortName}.',
      },
    );
  }

  Future<void> _showHistory(
    List<PdfAiMaterial> history,
    PdfAiMaterial selected,
  ) async {
    final preferredId = ref
        .read(pdfAiPreferredVersionProvider(_preferredKey))
        .valueOrNull;
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
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (i == 0) const Chip(label: Text('Latest')),
                    if (history[i].id == preferredId)
                      const Chip(label: Text('Default')),
                  ],
                ),
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
    ).showSnackBar(TransientSnackBar(content: Text(message)));
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
    List<PdfAiMaterial> history,
    PdfAiMaterialTranslation? translation,
    PdfAiLanguage wanted,
    String? persianText,
  ) {
    final theme = Theme.of(context);
    final slideStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      h1: theme.textTheme.headlineMedium,
      h2: theme.textTheme.titleLarge,
    );
    final showing = persianText == null
        ? PdfAiLanguage.original
        : PdfAiLanguage.persian;
    // The same slide stays open when switching languages.
    if (_slideIndex >= slides.length) {
      _slideIndex = slides.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _slideController.hasClients) {
          _slideController.jumpToPage(_slideIndex);
        }
      });
    }
    return Column(
      children: [
        _embeddedVersionBar(history, selected, translation, showing),
        _translationNotice(selected, translation, wanted),
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
                      host: _selectionHost(selected, persianText),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Directionality(
                          textDirection: persianText == null
                              ? Directionality.of(context)
                              : TextDirection.rtl,
                          child: StudyMarkdown(
                            data: slides[index],
                            selectable: false,
                            styleSheet: slideStyle,
                          ),
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
                        onPressed:
                            _editing ||
                                _generating ||
                                _deleting ||
                                persianText != null
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
                          ClipboardData(text: persianText ?? selected.content),
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
                  Column(
                    children: [
                      PdfAiQueueBanner(
                        materialId: widget.materialId,
                        type: widget.type,
                      ),
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
                              onPressed: _generating
                                  ? null
                                  : () => _regenerate(selected),
                              child: Text(
                                _generating
                                    ? (_queueJob?.progressLabel ??
                                          'Generating…')
                                    : 'Regenerate',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _askMeQuestions,
                          icon: const Icon(Icons.quiz_outlined),
                          label: const Text('Ask me questions'),
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
    _queueJob = ref.watch(
      pdfAiJobForTargetProvider((
        materialId: widget.materialId,
        type: widget.type,
      )),
    );
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
        final preferredId = ref
            .watch(pdfAiPreferredVersionProvider(_preferredKey))
            .valueOrNull;
        final history = [
          for (final material in all)
            if (material.type == widget.type.storageValue) material,
        ];
        if (history.isEmpty) {
          return Scaffold(
            appBar: widget.embedded
                ? null
                : AppBar(
                    title: Text(widget.type.displayName),
                    actions: [
                      IconButton(
                        tooltip: 'Add from JSON',
                        onPressed: () => _importJson(),
                        icon: const Icon(Icons.data_object_outlined),
                      ),
                    ],
                  ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This version no longer exists.'),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => _importJson(),
                      icon: const Icon(Icons.data_object_outlined),
                      label: const Text('Add from JSON'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final selected = PdfAiVersionPicker.pick(
          materials: all,
          type: widget.type,
          selectedId: _selectedId,
          preferredId: preferredId,
        )!;
        // Loaded early so the Regenerate dialog opens with the saved choice.
        ref.watch(pdfAiAlsoPersianProvider);
        final wanted = ref.watch(pdfAiLanguageProvider(widget.materialId));
        final translation = ref
            .watch(pdfAiTranslationsProvider(widget.materialId))
            .valueOrNull?[selected.id];
        final persianStored = wanted == PdfAiLanguage.persian
            ? translation?.content
            : null;
        final showing = persianStored == null
            ? PdfAiLanguage.original
            : PdfAiLanguage.persian;
        final persianText = persianStored == null
            ? null
            : PdfAiTranslation.plain(persianStored);
        final shownText = persianText ?? selected.content;
        final isSlideshow = widget.type == PdfAiMaterialType.slideshow;
        final slides = isSlideshow
            ? PdfAiSlideDeck.parse(shownText)
            : const <String>[];
        final markdownChunks = isSlideshow
            ? const <String>[]
            : persianStored != null
            ? PdfAiTranslation.split(persianStored)
            : _chunksFor(selected);
        if (isSlideshow) {
          _syncSlideGeneration(selected.id);
        } else {
          _restoreScrollOffset(selected.id, showing, markdownChunks.length);
        }
        final rtl = persianStored != null;
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
                    _languageToggle(selected, translation, showing),
                    IconButton(
                      tooltip: 'History',
                      onPressed: () => _showHistory(history, selected),
                      icon: Badge(
                        label: Text('${history.length}'),
                        child: const Icon(Icons.history),
                      ),
                    ),
                    _versionMenu(selected, translation),
                  ],
                ),
          body: isSlideshow && slides.isNotEmpty
              ? _slideshowBody(
                  selected,
                  slides,
                  usage,
                  history,
                  translation,
                  wanted,
                  persianText,
                )
              : Column(
                  children: [
                    _embeddedVersionBar(
                      history,
                      selected,
                      translation,
                      showing,
                    ),
                    _translationNotice(selected, translation, wanted),
                    if (!widget.embedded)
                      MaterialBookLinksSection(materialId: widget.materialId),
                    Expanded(
                      child: ScrollEdgeArrows(
                        child: SelectionAiArea(
                          host: _selectionHost(selected, persianText),
                          child: ListView.builder(
                            key: _listKey,
                            controller: _scrollController,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: markdownChunks.length + 1,
                            itemBuilder: (context, index) {
                              if (index < markdownChunks.length) {
                                return Padding(
                                  key: _chunkKeys.putIfAbsent(
                                    index,
                                    GlobalKey.new,
                                  ),
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Directionality(
                                    textDirection: rtl
                                        ? TextDirection.rtl
                                        : Directionality.of(context),
                                    child: StudyMarkdown(
                                      data: markdownChunks[index],
                                      selectable: false,
                                      styleSheet: bodyStyle,
                                    ),
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
                                            _editing ||
                                                _generating ||
                                                _deleting ||
                                                rtl
                                            ? null
                                            : () => _edit(selected),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Edit'),
                                      ),
                                      TextButton.icon(
                                        onPressed: shownText.trim().isEmpty
                                            ? null
                                            : () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: shownText,
                                                  ),
                                                );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const TransientSnackBar(
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
                                      TextButton.icon(
                                        onPressed: _generating
                                            ? null
                                            : _askMeQuestions,
                                        icon: const Icon(
                                          Icons.quiz_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Ask me questions'),
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
                                                : () => _regenerate(selected),
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
                                    const SizedBox(height: AppSpacing.sm),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _generating
                                            ? null
                                            : _askMeQuestions,
                                        icon: const Icon(Icons.quiz_outlined),
                                        label: const Text('Ask me questions'),
                                      ),
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
