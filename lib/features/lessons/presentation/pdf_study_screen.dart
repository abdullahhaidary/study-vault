import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/database/app_database.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_coordinates.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/presentation/add_edit_study_pin_sheet.dart';
import '../../study_pins/presentation/study_pin_reader.dart';
import '../../study_pins/presentation/widgets/pdf_pin_overlay.dart';
import '../../study_pins/presentation/widgets/study_pin_toolbar.dart';

/// In-app PDF study view with Study Pin overlays and text annotations.
class PdfStudyScreen extends ConsumerStatefulWidget {
  const PdfStudyScreen({
    super.key,
    required this.resourceId,
    required this.title,
    required this.filePath,
  });

  final String resourceId;
  final String title;
  final String filePath;

  @override
  ConsumerState<PdfStudyScreen> createState() => _PdfStudyScreenState();
}

class _PdfStudyScreenState extends ConsumerState<PdfStudyScreen> {
  final PdfViewerController _controller = PdfViewerController();
  late final Future<bool> _fileExists;
  int? _currentPage;
  int? _pageCount;
  StudyPin? _readerPin;

  @override
  void initState() {
    super.initState();
    _fileExists = File(widget.filePath).exists();
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
      ),
    );
  }

  Future<void> _handleAddTextDescription(
    PdfTextSelectionDelegate selection,
  ) async {
    final selectedText = (await selection.getSelectedText()).trim();
    final ranges = await selection.getSelectedTextRanges();
    if (selectedText.isEmpty || ranges.isEmpty || !mounted) return;

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

    if (rangeInputs.isEmpty || !mounted) return;

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
      ),
    );

    await selection.clearTextSelection();
  }

  @override
  Widget build(BuildContext context) {
    final resourceId = widget.resourceId;
    final annotate = ref.watch(addPinModeProvider(resourceId));
    final displayMode = ref.watch(pinDisplayModeProvider(resourceId));
    final pinsAsync = ref.watch(studyPinsForResourceProvider(resourceId));
    final rangesAsync = ref.watch(textRangesForResourceProvider(resourceId));
    final pins = pinsAsync.valueOrNull ?? const [];
    final textRanges = rangesAsync.valueOrNull ?? const [];

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

    final pageLabel = _currentPage != null && _pageCount != null
        ? 'Page $_currentPage / $_pageCount'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: StudyPinToolbar(
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
        ),
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

          return Stack(
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
                    if (!params.textSelectionDelegate.hasSelectedText) return;
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
                  },
                  onPageChanged: (pageNumber) {
                    setState(() => _currentPage = pageNumber);
                  },
                  onViewerReady: (document, controller) {
                    setState(() {
                      _pageCount = document.pages.length;
                      _currentPage = controller.pageNumber;
                    });
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
                    if (controller.textSelectionDelegate.hasSelectedText) {
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
                      onPinTap: (pin) {
                        _onAnnotationTap(pin, annotate: annotate);
                      },
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
          );
        },
      ),
    );
  }
}
