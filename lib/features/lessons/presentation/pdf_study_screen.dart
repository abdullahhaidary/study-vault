import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/presentation/ai_actions_sheet.dart';
import '../../ai_assistant/services/markdown_to_quill.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../flashcards/data/flashcards_providers.dart';
import '../data/bookmarks_providers.dart';
import '../data/lesson_progress_providers.dart';
import 'widgets/material_outline_panel.dart';
import '../../study_pins/data/pin_categories_providers.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_coordinates.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/presentation/add_edit_study_pin_sheet.dart';
import '../../study_pins/presentation/study_pin_reader.dart';
import '../../study_pins/presentation/widgets/pdf_pin_overlay.dart';
import '../../study_pins/presentation/widgets/study_pin_toolbar.dart';
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

  Future<void> _openPdfAiActions(PdfTextSelectionDelegate selection) async {
    final selectedText = (await selection.getSelectedText()).trim();
    final ranges = await _textRangeInputs(selection);
    if (selectedText.isEmpty || ranges.isEmpty || !mounted) return;

    await showAiActionsSheet(
      context,
      ref,
      sourceText: selectedText,
      selectedText: selectedText,
      actionContext: AiActionContext.pdfSelection,
      onAnnotationSave: (draft) async {
        await createTextStudyPin(
          ref,
          CreateTextStudyPinInput(
            resourceId: widget.resourceId,
            selectedText: selectedText,
            ranges: ranges,
            shortText: draft.shortDescription,
            fullExplanation: draft.fullNoteMarkdown,
            categoryId: draft.suggestedCategory,
          ),
        );
        await selection.clearTextSelection();
      },
      onFlashcardsCreate: (cards) async {
        final material = await ref
            .read(databaseProvider)
            .getMaterialById(widget.resourceId);
        if (material == null) return;
        for (final card in cards) {
          await createFlashcard(
            ref,
            lessonId: material.lessonId,
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
          IconButton(
            tooltip: currentBookmark == null
                ? 'Bookmark page'
                : 'Remove bookmark',
            onPressed: _currentPage == null ? null : _toggleBookmark,
            icon: Icon(
              currentBookmark == null ? Icons.bookmark_border : Icons.bookmark,
            ),
          ),
          IconButton(
            tooltip: 'Document navigation',
            onPressed: !_controller.isReady
                ? null
                : () {
                    if (_isWide) {
                      setState(() => _showOutline = !_showOutline);
                    } else {
                      _openOutlineSheet(bookmarks, pins);
                    }
                  },
            icon: const Icon(Icons.toc_outlined),
          ),
          IconButton(
            tooltip: 'Review Pins',
            onPressed: () => openReviewSetup(
              context,
              scope: ReviewScope(
                type: ReviewScopeType.material,
                id: widget.resourceId,
                title: widget.title,
              ),
            ),
            icon: const Icon(Icons.school_outlined),
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
      body: Column(
        children: [
          StudyPinToolbar(
            addPinMode: annotate,
            displayMode: displayMode,
            onAddPinModeChanged: (value) {
              ref.read(addPinModeProvider(resourceId).notifier).state = value;
            },
            onDisplayModeChanged: (mode) {
              ref.read(pinDisplayModeProvider(resourceId).notifier).state =
                  mode;
            },
          ),
          Expanded(
            child: FutureBuilder<bool>(
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
                                if (!annotate) return;
                                if (!params
                                    .textSelectionDelegate
                                    .hasSelectedText) {
                                  return;
                                }
                                items.insert(
                                  0,
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
                                items.insert(
                                  1,
                                  ContextMenuButtonItem(
                                    label: 'AI Actions',
                                    type: ContextMenuButtonType.custom,
                                    onPressed: () {
                                      params.dismissContextMenu();
                                      _openPdfAiActions(
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
                                if (details.type !=
                                    PdfViewerGeneralTapType.tap) {
                                  return false;
                                }
                                // Avoid creating a point pin under a text selection gesture.
                                if (details.tapOn ==
                                    PdfViewerPart.selectedText) {
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
                        ],
                      ),
                    ),
                    if (_isWide && _showOutline && _controller.isReady)
                      SizedBox(
                        width: 340,
                        child: _outlinePanel(bookmarks, pins),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
