import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/domain/annotation_ai_context.dart';
import '../../ai_assistant/domain/inline_ai_models.dart';
import '../../ai_assistant/presentation/inline_ai_panel.dart';
import '../../ai_assistant/services/annotation_ai_context_builder.dart';
import '../../ai_assistant/services/inline_ai_annotation_saver.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/presentation/widgets/ai_discussions_section.dart';
import '../../ai_questions/domain/question_source.dart';
import '../../ai_questions/presentation/generate_questions_sheet.dart';
import '../../ai_questions/presentation/question_sets_screen.dart';
import '../../ai_questions/presentation/question_source_launches.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../flashcards/data/flashcards_providers.dart';
import '../../notes/data/notes_providers.dart';
import '../data/bookmarks_providers.dart';
import '../data/lesson_progress_providers.dart';
import 'widgets/material_outline_panel.dart';
import 'widgets/pdf_study_dock.dart';
import '../../study_pins/data/pin_categories_providers.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_coordinates.dart';
import '../../study_pins/domain/pin_display_mode.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../../study_pins/presentation/add_edit_study_pin_sheet.dart';
import '../../study_pins/presentation/study_pin_reader.dart';
import '../../study_pins/presentation/widgets/pdf_pin_overlay.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_review/presentation/review_setup_screen.dart';

/// In-app PDF study view with Study Pin overlays and text annotations.
class PdfStudyScreen extends ConsumerStatefulWidget {
  const PdfStudyScreen({
    super.key,
    required this.resourceId,
    required this.title,
    required this.filePath,
    this.focusPinId,
    this.initialPage,
  });

  final String resourceId;
  final String title;
  final String filePath;
  final String? focusPinId;
  final int? initialPage;

  @override
  ConsumerState<PdfStudyScreen> createState() => _PdfStudyScreenState();
}

class _PdfStudyScreenState extends ConsumerState<PdfStudyScreen> {
  final PdfViewerController _controller = PdfViewerController();
  late final Future<bool> _fileExists;
  int? _currentPage;
  int? _pageCount;
  StudyPin? _readerPin;
  String? _focusedPinId;
  bool _didApplyInitialFocus = false;
  bool _showOutline = true;

  /// Active inline AI session over the PDF (selection or page).
  _InlineAiSession? _inlineAi;

  @override
  void initState() {
    super.initState();
    _fileExists = File(widget.filePath).exists();
    _focusedPinId = widget.focusPinId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      recordMaterialStudyActivity(ref, materialId: widget.resourceId);
    });
  }

  bool get _isWide => MediaQuery.sizeOf(context).width >= 720;

  Future<void> _openReader(StudyPin pin) async {
    if (_isWide) {
      setState(() => _readerPin = pin);
      return;
    }
    await showStudyPinReader(context, pin: pin);
  }

  Future<void> _openEditor(StudyPin pin) async {
    final result = await AddEditStudyPinSheet.show(
      context,
      initialShortText: pin.shortText,
      initialFullExplanation: pin.fullExplanation,
      initialCategoryId: pin.categoryId,
      selectedText: pin.selectedText,
      pinType: pin.type,
      isEditing: true,
      allowDelete: true,
    );
    if (result == null || !mounted) return;

    if (result is StudyPinEditorDeleted) {
      await deleteStudyPin(ref, pinId: pin.id);
      if (_readerPin?.id == pin.id) {
        setState(() => _readerPin = null);
      }
      return;
    }

    if (result is StudyPinEditorSaved) {
      await updateStudyPinTexts(
        ref,
        pin: pin,
        shortText: result.shortText,
        fullExplanation: result.fullExplanation,
        categoryId: result.categoryId,
        updateCategory: true,
      );
    }
  }

  Future<void> _onAnnotationTap(StudyPin pin, {required bool annotate}) async {
    if (annotate) {
      await _openEditor(pin);
    } else {
      await _openReader(pin);
    }
  }

  Future<void> _onPointPinMoved(StudyPin pin, NormalizedPoint point) async {
    await updateStudyPinPosition(ref, pin: pin, point: point);
  }

  Future<void> _toggleBookmark() async {
    final page = _currentPage;
    if (page == null) return;
    final created = await toggleMaterialBookmark(
      ref,
      materialId: widget.resourceId,
      pageNumber: page,
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bookmarked page $page'),
          action: SnackBarAction(
            label: 'Title',
            onPressed: () => _editBookmark(created),
          ),
        ),
      );
    }
  }

  Future<void> _editBookmark(MaterialBookmark bookmark) async {
    final controller = TextEditingController(text: bookmark.title ?? '');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmark title'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null) {
      await updateBookmarkTitle(ref, bookmark: bookmark, title: title);
    }
  }

  Widget _outlinePanel(List<MaterialBookmark> bookmarks, List<StudyPin> pins) {
    final categories =
        ref.read(studyPinCategoryMapProvider).valueOrNull ?? const {};
    return MaterialOutlinePanel(
      materialId: widget.resourceId,
      controller: _controller,
      bookmarks: bookmarks,
      pins: pins,
      currentPage: _currentPage,
      onBookmarkTap: (bookmark) =>
          _controller.goToPage(pageNumber: bookmark.pageNumber),
      onBookmarkEdit: _editBookmark,
      onBookmarkDelete: (bookmark) =>
          deleteMaterialBookmarkById(ref, id: bookmark.id),
      onPinTap: (pin) {
        setState(() {
          _focusedPinId = pin.id;
          _readerPin = pin;
        });
        if (pin.pageNumber != null) {
          _controller.goToPage(pageNumber: pin.pageNumber!);
        }
      },
      categoryNames: {
        for (final entry in categories.entries) entry.key: entry.value.name,
      },
    );
  }

  Future<void> _openOutlineSheet(
    List<MaterialBookmark> bookmarks,
    List<StudyPin> pins,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: _outlinePanel(bookmarks, pins),
      ),
    );
  }

  Future<void> _handleAddPointPinTap(
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) async {
    final hit = controller.getPdfPageHitTestResult(
      details.documentPosition,
      useDocumentLayoutCoordinates: true,
    );
    if (hit == null) return;

    final pageRect = controller.layout.pageLayouts[hit.page.pageNumber - 1];
    final local = details.documentPosition - pageRect.topLeft;
    final point = NormalizedPoint.fromLocalOffset(local, pageRect.size);

    final result = await AddEditStudyPinSheet.show(
      context,
      pinType: StudyPinType.point,
    );
    if (result is! StudyPinEditorSaved || !mounted) return;

    await createStudyPin(
      ref,
      CreateStudyPinInput(
        resourceId: widget.resourceId,
        pageNumber: hit.page.pageNumber,
        point: point,
        shortText: result.shortText,
        fullExplanation: result.fullExplanation,
        categoryId: result.categoryId,
      ),
    );
  }

  Future<void> _handleAddTextDescription(
    PdfTextSelectionDelegate selection,
  ) async {
    final selectedText = (await selection.getSelectedText()).trim();
    final rangeInputs = await _textRangeInputs(selection);
    if (selectedText.isEmpty || rangeInputs.isEmpty || !mounted) return;

    final result = await AddEditStudyPinSheet.show(
      context,
      pinType: StudyPinType.text,
      selectedText: selectedText,
    );
    if (result is! StudyPinEditorSaved || !mounted) return;

    await createTextStudyPin(
      ref,
      CreateTextStudyPinInput(
        resourceId: widget.resourceId,
        selectedText: selectedText,
        ranges: rangeInputs,
        shortText: result.shortText,
        fullExplanation: result.fullExplanation,
        categoryId: result.categoryId,
      ),
    );

    await selection.clearTextSelection();
  }

  Future<List<TextRangeInput>> _textRangeInputs(
    PdfTextSelectionDelegate selection,
  ) async {
    final ranges = await selection.getSelectedTextRanges();
    final rangeInputs = <TextRangeInput>[];
    for (final range in ranges) {
      final pageIndex = range.pageNumber - 1;
      if (pageIndex < 0 || pageIndex >= _controller.pages.length) continue;
      final page = _controller.pages[pageIndex];
      final pageSize = Size(page.width, page.height);

      for (final fragment in range.enumerateFragmentBoundingRects()) {
        final local = fragment.bounds.toRect(
          page: page,
          scaledPageSize: pageSize,
        );
        if (local.width <= 0 || local.height <= 0) continue;
        rangeInputs.add(
          TextRangeInput(
            pageNumber: range.pageNumber,
            rect: NormalizedRect.fromLocalRect(local, pageSize),
          ),
        );
      }
    }
    return rangeInputs;
  }

  Future<Set<int>?> _pickPages() async {
    final count = _pageCount;
    final current = _currentPage ?? 1;
    if (count == null) return {current};
    final controller = TextEditingController(text: '$current');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select pages'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Pages (e.g. 1,3,5-8)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return null;
    return _parsePageList(result, maxPage: count);
  }

  Set<int> _parsePageList(String raw, {required int maxPage}) {
    final pages = <int>{};
    for (final part in raw.split(',')) {
      final token = part.trim();
      if (token.isEmpty) continue;
      if (token.contains('-')) {
        final bits = token.split('-');
        if (bits.length != 2) continue;
        final a = int.tryParse(bits[0].trim());
        final b = int.tryParse(bits[1].trim());
        if (a == null || b == null) continue;
        final start = a < b ? a : b;
        final end = a < b ? b : a;
        for (var p = start; p <= end; p++) {
          if (p >= 1 && p <= maxPage) pages.add(p);
        }
      } else {
        final p = int.tryParse(token);
        if (p != null && p >= 1 && p <= maxPage) pages.add(p);
      }
    }
    return pages;
  }

  Future<void> _openGenerateQuestions({String? selectedText}) async {
    Set<int>? selectedPages;
    final launch = selectedText != null && selectedText.isNotEmpty
        ? QuestionSourceLaunches.forPdfSelection(
            ref: ref,
            selectedText: selectedText,
            materialId: widget.resourceId,
            filePath: widget.filePath,
            currentPage: _currentPage,
            pageNumber: _currentPage,
          )
        : QuestionSourceLaunches.forPdfMaterial(
            ref: ref,
            materialId: widget.resourceId,
            filePath: widget.filePath,
            currentPage: _currentPage,
          );

    // Intercept pages source to collect page numbers first.
    final wrapped = GenerateQuestionsLaunch(
      title: launch.title,
      availableSources: launch.availableSources,
      initialSource: launch.initialSource,
      resolveSource: (type) async {
        if (type == QuestionSourceType.pages) {
          selectedPages = await _pickPages();
          if (selectedPages == null || selectedPages!.isEmpty) {
            throw StateError('No pages selected');
          }
          return QuestionSourceLaunches.forPdfMaterial(
            ref: ref,
            materialId: widget.resourceId,
            filePath: widget.filePath,
            currentPage: _currentPage,
            selectedPages: selectedPages,
          ).resolveSource(type);
        }
        return launch.resolveSource(type);
      },
    );

    if (!mounted) return;
    await showGenerateQuestionsSheet(context, ref, launch: wrapped);
  }

  Future<void> _openPdfInlineAi(PdfTextSelectionDelegate selection) async {
    final selectedText = (await selection.getSelectedText()).trim();
    final ranges = await _textRangeInputs(selection);
    if (selectedText.isEmpty || ranges.isEmpty || !mounted) return;

    final pageNumber = ranges.first.pageNumber;
    final material = await ref
        .read(databaseProvider)
        .getMaterialById(widget.resourceId);
    final aiContext =
        await AnnotationAiContextBuilder.fromPdfSelectionWithPageLoad(
          selectedText: selectedText,
          filePath: widget.filePath,
          materialId: widget.resourceId,
          lessonId: material?.lessonId,
          pageNumber: pageNumber,
        );
    if (!mounted) return;

    final pins =
        ref.read(studyPinsForResourceProvider(widget.resourceId)).valueOrNull ??
        const <StudyPin>[];
    final existing = InlineAiAnnotationSaver.findMatchingTextPin(
      pins: pins,
      selectedText: selectedText,
      pageNumber: pageNumber,
    );

    AnnotationAiContext context = aiContext;
    if (existing != null) {
      final fullPlain = StudyNoteCodec.plainTextPreview(
        existing.fullExplanation,
      ).trim();
      context = AnnotationAiContext(
        selectedText: aiContext.selectedText,
        materialId: aiContext.materialId,
        lessonId: aiContext.lessonId,
        pageNumber: aiContext.pageNumber,
        annotationText: [
          existing.shortText.trim(),
          if (fullPlain.isNotEmpty) fullPlain,
        ].where((s) => s.isNotEmpty).join('\n\n'),
        surroundingText: aiContext.surroundingText,
        annotationId: existing.id,
        shortDescription: existing.shortText,
        language: aiContext.language,
        direction: aiContext.direction,
        filePath: aiContext.filePath,
      );
    }

    setState(() {
      _inlineAi = _InlineAiSession(
        mode: InlineAiSourceMode.selection,
        context: context,
        ranges: ranges,
        existingPin: existing,
        materialLessonId: material?.lessonId,
        selectedText: selectedText,
      );
    });
  }

  Future<void> _openPageInlineAi() async {
    final page = _currentPage;
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the PDF page to load.')),
      );
      return;
    }

    final material = await ref
        .read(databaseProvider)
        .getMaterialById(widget.resourceId);
    final aiContext = await AnnotationAiContextBuilder.fromPdfPage(
      filePath: widget.filePath,
      pageNumber: page,
      materialId: widget.resourceId,
      lessonId: material?.lessonId,
    );
    if (!mounted) return;

    if (!aiContext.hasUsableText &&
        (aiContext.filePath == null || aiContext.pageNumber == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This page has no extractable text.')),
      );
      return;
    }

    setState(() {
      _inlineAi = _InlineAiSession(
        mode: InlineAiSourceMode.page,
        context: aiContext,
        ranges: const [],
        existingPin: null,
        materialLessonId: material?.lessonId,
        selectedText: aiContext.primaryText,
      );
    });
  }

  Future<void> _openAiDiscussions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ListView(
            controller: controller,
            children: [
              Text(
                'AI Discussions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              AiDiscussionsList(
                kind: AiContextKind.material,
                id: widget.resourceId,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAiTools() async {
    final action = await showModalBottomSheet<_PdfAiTool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Ask about this page'),
              subtitle: Text(
                _currentPage == null
                    ? 'Wait for the current page to load'
                    : 'Explain, summarize, or study page $_currentPage',
              ),
              enabled: _currentPage != null,
              onTap: _currentPage == null
                  ? null
                  : () => Navigator.pop(context, _PdfAiTool.page),
            ),
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Generate questions'),
              subtitle: const Text('Create a quiz from this PDF'),
              onTap: () => Navigator.pop(context, _PdfAiTool.generateQuestions),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Question sets'),
              subtitle: const Text('Open saved AI questions'),
              onTap: () => Navigator.pop(context, _PdfAiTool.questionSets),
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('AI discussions'),
              subtitle: const Text('Continue chats about this material'),
              onTap: () => Navigator.pop(context, _PdfAiTool.discussions),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _PdfAiTool.page:
        await _openPageInlineAi();
      case _PdfAiTool.generateQuestions:
        await _openGenerateQuestions();
      case _PdfAiTool.questionSets:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuestionSetsScreen(
              scope: QuestionSetsScope.material(
                id: widget.resourceId,
                title: widget.title,
              ),
            ),
          ),
        );
      case _PdfAiTool.discussions:
        await _openAiDiscussions();
    }
  }

  void _closeInlineAi() {
    if (_inlineAi == null) return;
    setState(() => _inlineAi = null);
  }

  InlineAiHostCallbacks _inlineAiCallbacks(_InlineAiSession session) {
    final lessonId = session.materialLessonId;
    return InlineAiHostCallbacks(
      onDismiss: _closeInlineAi,
      resourceId: widget.resourceId,
      rangeInputs: session.ranges,
      onGoToSource: session.context.pageNumber == null
          ? null
          : () {
              _controller.goToPage(pageNumber: session.context.pageNumber!);
            },
      onAnnotationSaved: (pin) async {
        await _controller.textSelectionDelegate.clearTextSelection();
      },
      questionsLaunch: session.mode == InlineAiSourceMode.selection
          ? QuestionSourceLaunches.forPdfSelection(
              ref: ref,
              selectedText: session.selectedText,
              materialId: widget.resourceId,
              filePath: widget.filePath,
              currentPage: _currentPage,
              pageNumber: session.context.pageNumber,
              surroundingText: session.context.surroundingText,
            )
          : QuestionSourceLaunches.forPdfMaterial(
              ref: ref,
              materialId: widget.resourceId,
              filePath: widget.filePath,
              currentPage: _currentPage,
              selectedPages: session.context.pageNumber == null
                  ? null
                  : {session.context.pageNumber!},
            ),
      onCreateNote: lessonId == null
          ? null
          : (markdown) async {
              final raw = session.selectedText;
              final title = raw.length > 48 ? '${raw.substring(0, 48)}…' : raw;
              await createStudyNote(
                ref,
                lessonId: lessonId,
                title: title.isEmpty ? 'AI note' : title,
                content: MarkdownToQuill.toDeltaJson(markdown),
              );
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Note created')));
              }
            },
      onFlashcardsCreate: lessonId == null
          ? null
          : (cards) async {
              for (final card in cards) {
                await createFlashcard(
                  ref,
                  lessonId: lessonId,
                  front: card.front,
                  back: MarkdownToQuill.toDeltaJson(card.back),
                );
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final resourceId = widget.resourceId;
    final annotate = ref.watch(addPinModeProvider(resourceId));
    final displayMode = ref.watch(pinDisplayModeProvider(resourceId));
    final pinsAsync = ref.watch(studyPinsForResourceProvider(resourceId));
    final rangesAsync = ref.watch(textRangesForResourceProvider(resourceId));
    final pins = pinsAsync.valueOrNull ?? const [];
    final bookmarks =
        ref.watch(bookmarksForMaterialProvider(resourceId)).valueOrNull ??
        const <MaterialBookmark>[];
    final currentBookmark = _currentPage == null
        ? null
        : bookmarks
              .where((bookmark) => bookmark.pageNumber == _currentPage)
              .firstOrNull;
    final textRanges = rangesAsync.valueOrNull ?? const [];
    final categoryMap =
        ref.watch(studyPinCategoryMapProvider).valueOrNull ?? const {};

    // Keep floating reader in sync with DB updates / deletes.
    final readingId = _readerPin?.id;
    if (readingId != null) {
      final latest = pins.where((p) => p.id == readingId).firstOrNull;
      if (latest == null && _readerPin != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _readerPin = null);
        });
      } else if (latest != null && !identical(latest, _readerPin)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _readerPin = latest);
        });
      }
    }

    // Open focused pin reader once pins are loaded.
    if (!_didApplyInitialFocus &&
        widget.focusPinId != null &&
        pins.isNotEmpty) {
      final focus = pins.where((p) => p.id == widget.focusPinId).firstOrNull;
      if (focus != null) {
        _didApplyInitialFocus = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openReader(focus);
        });
      }
    }

    final pageLabel = _currentPage != null && _pageCount != null
        ? 'Page $_currentPage / $_pageCount'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          FavoriteStarButton(
            entityType: FavoriteEntityType.material,
            entityId: widget.resourceId,
          ),
          if (pageLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  pageLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _fileExists,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return const Center(
              child: Text('PDF file is missing from local storage.'),
            );
          }

          return Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    PdfViewer.file(
                      widget.filePath,
                      controller: _controller,
                      params: PdfViewerParams(
                        margin: 8,
                        textSelectionParams: const PdfTextSelectionParams(
                          enabled: true,
                        ),
                        customizeContextMenuItems: (params, items) {
                          if (!params.textSelectionDelegate.hasSelectedText) {
                            return;
                          }
                          items.insert(
                            0,
                            ContextMenuButtonItem(
                              label: 'AI',
                              type: ContextMenuButtonType.custom,
                              onPressed: () {
                                params.dismissContextMenu();
                                _openPdfInlineAi(params.textSelectionDelegate);
                              },
                            ),
                          );
                          if (!annotate) return;
                          items.insert(
                            1,
                            ContextMenuButtonItem(
                              label: 'Add Description',
                              type: ContextMenuButtonType.custom,
                              onPressed: () {
                                params.dismissContextMenu();
                                _handleAddTextDescription(
                                  params.textSelectionDelegate,
                                );
                              },
                            ),
                          );
                        },
                        onPageChanged: (pageNumber) {
                          setState(() => _currentPage = pageNumber);
                        },
                        onViewerReady: (document, controller) {
                          setState(() {
                            _pageCount = document.pages.length;
                            _currentPage = controller.pageNumber;
                          });
                          final page = widget.initialPage;
                          if (page != null &&
                              page >= 1 &&
                              page <= document.pages.length) {
                            controller.goToPage(pageNumber: page);
                          }
                        },
                        onGeneralTap: (context, controller, details) {
                          if (!annotate) return false;
                          if (details.type != PdfViewerGeneralTapType.tap) {
                            return false;
                          }
                          // Avoid creating a point pin under a text selection gesture.
                          if (details.tapOn == PdfViewerPart.selectedText) {
                            return false;
                          }
                          if (controller
                              .textSelectionDelegate
                              .hasSelectedText) {
                            return false;
                          }
                          _handleAddPointPinTap(controller, details);
                          return true;
                        },
                        pageOverlaysBuilder: (context, pageRect, page) {
                          return buildPdfPagePinOverlays(
                            pageRect: pageRect,
                            page: page,
                            pins: pins,
                            textRanges: textRanges,
                            displayMode: displayMode,
                            annotateMode: annotate,
                            categoryMap: categoryMap,
                            focusedPinId: _focusedPinId,
                            onPinTap: (pin) {
                              setState(() => _focusedPinId = pin.id);
                              _onAnnotationTap(pin, annotate: annotate);
                            },
                            onPointPinMoved: _onPointPinMoved,
                          );
                        },
                      ),
                    ),
                    if (_isWide && _readerPin != null)
                      StudyPinReaderOverlay(
                        pin: _readerPin!,
                        onClose: () => setState(() => _readerPin = null),
                      ),
                    if (_inlineAi == null)
                      Positioned.fill(
                        child: PdfStudyDock(
                          bookmarked: currentBookmark != null,
                          bookmarkEnabled: _currentPage != null,
                          annotating: annotate,
                          pinDisplayMode: displayMode,
                          onOpenNavigation: () {
                            if (!_controller.isReady) return;
                            if (_isWide) {
                              setState(() => _showOutline = !_showOutline);
                            } else {
                              _openOutlineSheet(bookmarks, pins);
                            }
                          },
                          onToggleBookmark: _toggleBookmark,
                          onToggleAnnotating: () {
                            ref
                                    .read(
                                      addPinModeProvider(resourceId).notifier,
                                    )
                                    .state =
                                !annotate;
                          },
                          onOpenAi: _openAiTools,
                          onAction: (action) {
                            switch (action) {
                              case PdfStudyDockAction.reviewPins:
                                openReviewSetup(
                                  context,
                                  scope: ReviewScope(
                                    type: ReviewScopeType.material,
                                    id: widget.resourceId,
                                    title: widget.title,
                                  ),
                                );
                              case PdfStudyDockAction.hidePins:
                                ref
                                        .read(
                                          pinDisplayModeProvider(
                                            resourceId,
                                          ).notifier,
                                        )
                                        .state =
                                    PinDisplayMode.hidden;
                              case PdfStudyDockAction.showPinDots:
                                ref
                                        .read(
                                          pinDisplayModeProvider(
                                            resourceId,
                                          ).notifier,
                                        )
                                        .state =
                                    PinDisplayMode.dotsOnly;
                              case PdfStudyDockAction.showPinText:
                                ref
                                        .read(
                                          pinDisplayModeProvider(
                                            resourceId,
                                          ).notifier,
                                        )
                                        .state =
                                    PinDisplayMode.dotsAndText;
                            }
                          },
                        ),
                      ),
                    if (_inlineAi != null)
                      InlineAiOverlay(
                        mode: _inlineAi!.mode,
                        aiContext: _inlineAi!.context,
                        existingPin: _inlineAi!.existingPin,
                        useBottomSheetLayout: !_isWide,
                        callbacks: _inlineAiCallbacks(_inlineAi!),
                      ),
                  ],
                ),
              ),
              if (_isWide && _showOutline && _controller.isReady)
                SizedBox(width: 340, child: _outlinePanel(bookmarks, pins)),
            ],
          );
        },
      ),
    );
  }
}

enum _PdfAiTool { page, generateQuestions, questionSets, discussions }

class _InlineAiSession {
  const _InlineAiSession({
    required this.mode,
    required this.context,
    required this.ranges,
    required this.existingPin,
    required this.materialLessonId,
    required this.selectedText,
  });

  final InlineAiSourceMode mode;
  final AnnotationAiContext context;
  final List<TextRangeInput> ranges;
  final StudyPin? existingPin;
  final String? materialLessonId;
  final String selectedText;
}
