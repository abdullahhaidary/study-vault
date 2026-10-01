import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_coordinates.dart';
import '../../study_pins/domain/pin_display_mode.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/presentation/add_edit_study_pin_sheet.dart';
import '../../study_pins/presentation/study_pin_reader.dart';
import '../../study_pins/presentation/widgets/image_pin_overlay.dart';
import '../../study_pins/presentation/widgets/study_pin_toolbar.dart';

/// In-app image study view with zoom/pan and Study Pin overlays.
class ImageStudyScreen extends ConsumerStatefulWidget {
  const ImageStudyScreen({
    super.key,
    required this.resourceId,
    required this.title,
    required this.filePath,
  });

  final String resourceId;
  final String title;
  final String filePath;

  @override
  ConsumerState<ImageStudyScreen> createState() => _ImageStudyScreenState();
}

class _ImageStudyScreenState extends ConsumerState<ImageStudyScreen> {
  final TransformationController _transformController =
      TransformationController();
  ui.Image? _decoded;
  Object? _loadError;
  StudyPin? _readerPin;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  bool get _isWide => MediaQuery.sizeOf(context).width >= 720;

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _decoded?.dispose();
        _decoded = frame.image;
        _loadError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    }
  }

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

  Future<void> _onPinTap(StudyPin pin, {required bool annotate}) async {
    if (annotate) {
      await _openEditor(pin);
    } else {
      await _openReader(pin);
    }
  }

  Future<void> _onPointPinMoved(StudyPin pin, NormalizedPoint point) async {
    await updateStudyPinPosition(ref, pin: pin, point: point);
  }

  Future<void> _onAddPinAt(Offset local, Size contentSize) async {
    final point = NormalizedPoint.fromLocalOffset(local, contentSize);
    final result = await AddEditStudyPinSheet.show(
      context,
      pinType: StudyPinType.point,
    );
    if (result is! StudyPinEditorSaved || !mounted) return;

    await createStudyPin(
      ref,
      CreateStudyPinInput(
        resourceId: widget.resourceId,
        pageNumber: null,
        point: point,
        shortText: result.shortText,
        fullExplanation: result.fullExplanation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resourceId = widget.resourceId;
    final annotate = ref.watch(addPinModeProvider(resourceId));
    final displayMode = ref.watch(pinDisplayModeProvider(resourceId));
    final pinsAsync = ref.watch(studyPinsForResourceProvider(resourceId));
    final pins = pinsAsync.valueOrNull ?? const [];

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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
      body: Stack(
        children: [
          _buildBody(annotate: annotate, displayMode: displayMode, pins: pins),
          if (_isWide && _readerPin != null)
            StudyPinReaderOverlay(
              pin: _readerPin!,
              onClose: () => setState(() => _readerPin = null),
            ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required bool annotate,
    required PinDisplayMode displayMode,
    required List<StudyPin> pins,
  }) {
    if (_loadError != null) {
      return Center(child: Text('Could not load image: $_loadError'));
    }
    final image = _decoded;
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitted = applyBoxFit(
          BoxFit.contain,
          imageSize,
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        final contentSize = fitted.destination;

        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 8,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: SizedBox(
                  width: contentSize.width,
                  height: contentSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RawImage(
                        image: image,
                        fit: BoxFit.fill,
                        width: contentSize.width,
                        height: contentSize.height,
                      ),
                      if (annotate)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              _onAddPinAt(details.localPosition, contentSize);
                            },
                            child: const ColoredBox(color: Color(0x22000000)),
                          ),
                        ),
                      ImagePinOverlay(
                        pins: pins,
                        contentSize: contentSize,
                        displayMode: displayMode,
                        annotateMode: annotate,
                        onPinTap: (pin) {
                          _onPinTap(pin, annotate: annotate);
                        },
                        onPointPinMoved: _onPointPinMoved,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
