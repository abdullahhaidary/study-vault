import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_coordinates.dart';
import '../../study_pins/presentation/add_edit_study_pin_sheet.dart';
import '../../study_pins/presentation/study_pin_details_sheet.dart';
import '../../study_pins/presentation/widgets/pdf_pin_overlay.dart';
import '../../study_pins/presentation/widgets/study_pin_toolbar.dart';

/// In-app PDF study view with Study Pin overlays.
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

  @override
  void initState() {
    super.initState();
    _fileExists = File(widget.filePath).exists();
  }

  Future<void> _handleAddPinTap(
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

    final result = await AddEditStudyPinSheet.show(context);
    if (result == null || !mounted) return;

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

  @override
  Widget build(BuildContext context) {
    final resourceId = widget.resourceId;
    final addPinMode = ref.watch(addPinModeProvider(resourceId));
    final displayMode = ref.watch(pinDisplayModeProvider(resourceId));
    final pinsAsync = ref.watch(studyPinsForResourceProvider(resourceId));
    final pins = pinsAsync.valueOrNull ?? const [];

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
            addPinMode: addPinMode,
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

          return PdfViewer.file(
            widget.filePath,
            controller: _controller,
            params: PdfViewerParams(
              margin: 8,
              textSelectionParams: PdfTextSelectionParams(
                enabled: !addPinMode,
              ),
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
                if (!addPinMode) return false;
                if (details.type != PdfViewerGeneralTapType.tap) return false;
                _handleAddPinTap(controller, details);
                return true;
              },
              pageOverlaysBuilder: (context, pageRect, page) {
                return buildPdfPagePinOverlays(
                  pageRect: pageRect,
                  page: page,
                  pins: pins,
                  displayMode: displayMode,
                  addPinMode: addPinMode,
                  onPinTap: (pin) {
                    showStudyPinDetails(context, ref, pin: pin);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
