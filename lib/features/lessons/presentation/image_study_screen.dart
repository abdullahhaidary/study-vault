import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_coordinates.dart';
import '../../study_pins/domain/pin_display_mode.dart';
import '../../study_pins/presentation/add_edit_study_pin_sheet.dart';
import '../../study_pins/presentation/study_pin_details_sheet.dart';
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

  Future<void> _onAddPinAt(Offset local, Size contentSize) async {
    final point = NormalizedPoint.fromLocalOffset(local, contentSize);
    final result = await AddEditStudyPinSheet.show(context);
    if (result == null || !mounted) return;

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
    final addPinMode = ref.watch(addPinModeProvider(resourceId));
    final displayMode = ref.watch(pinDisplayModeProvider(resourceId));
    final pinsAsync = ref.watch(studyPinsForResourceProvider(resourceId));
    final pins = pinsAsync.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
      body: _buildBody(
        addPinMode: addPinMode,
        displayMode: displayMode,
        pins: pins,
      ),
    );
  }

  Widget _buildBody({
    required bool addPinMode,
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
                      ImagePinOverlay(
                        pins: pins,
                        contentSize: contentSize,
                        displayMode: displayMode,
                        onPinTap: (pin) {
                          if (addPinMode) return;
                          showStudyPinDetails(context, ref, pin: pin);
                        },
                      ),
                      if (addPinMode)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              _onAddPinAt(
                                details.localPosition,
                                contentSize,
                              );
                            },
                            child: const ColoredBox(
                              color: Color(0x22000000),
                            ),
                          ),
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
