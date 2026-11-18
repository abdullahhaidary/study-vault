import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/presentation/widgets/ai_discussions_section.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../data/lesson_progress_providers.dart';
import '../data/materials_providers.dart';
import '../../study_pins/data/pin_categories_providers.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/pin_coordinates.dart';
import '../../study_pins/domain/pin_display_mode.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/presentation/add_edit_study_pin_sheet.dart';
import '../../study_pins/presentation/study_pin_reader.dart';
import '../../study_pins/presentation/widgets/image_pin_overlay.dart';
import '../../study_pins/presentation/widgets/study_pin_toolbar.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_review/presentation/review_setup_screen.dart';

/// In-app image study view with zoom/pan and Study Pin overlays.
class ImageStudyScreen extends ConsumerStatefulWidget {
  const ImageStudyScreen({
    super.key,
    required this.resourceId,
    required this.title,
    required this.filePath,
    this.focusPinId,
  });

  final String resourceId;
  final String title;
  final String filePath;
  final String? focusPinId;

  @override
  ConsumerState<ImageStudyScreen> createState() => _ImageStudyScreenState();
}

class _ImageStudyScreenState extends ConsumerState<ImageStudyScreen> {
  final TransformationController _transformController =
      TransformationController();
  late String _resourceId;
  late String _title;
  String? _lessonId;
  int _loadEpoch = 0;
  final _pointers = <int>{};
  Offset? _swipeStart;
  Offset? _swipeEnd;
  bool _swipeAllowed = false;
  ui.Image? _decoded;
  Object? _loadError;
  StudyPin? _readerPin;
  String? _focusedPinId;
  bool _didApplyInitialFocus = false;

  @override
  void initState() {
    super.initState();
    _resourceId = widget.resourceId;
    _title = widget.title;
    _focusedPinId = widget.focusPinId;
    _loadImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) recordMaterialStudyActivity(ref, materialId: _resourceId);
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  bool get _isWide => MediaQuery.sizeOf(context).width >= 720;

  Future<void> _loadImage({LessonMaterial? material}) async {
    final epoch = ++_loadEpoch;
    try {
      final path = material == null
          ? widget.filePath
          : await materialAbsolutePath(material);
      if (!mounted || epoch != _loadEpoch) return;
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      if (!mounted || epoch != _loadEpoch) {
        buffer.dispose();
        return;
      }
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          const maxSide = 4096;
          if (width <= maxSide && height <= maxSide) {
            return const ui.TargetImageSize();
          }
          return width > height
              ? const ui.TargetImageSize(width: maxSide)
              : const ui.TargetImageSize(height: maxSide);
        },
      );
      try {
        if (!mounted || epoch != _loadEpoch) return;
        final frame = await codec.getNextFrame();
        if (!mounted || epoch != _loadEpoch) {
          frame.image.dispose();
          return;
        }
        setState(() {
          _decoded?.dispose();
          _decoded = frame.image;
          _loadError = null;
        });
      } finally {
        codec.dispose();
      }
    } catch (error) {
      if (mounted && epoch == _loadEpoch) {
        setState(() => _loadError = error);
      }
    }
  }

  bool get _atFit => (_transformController.value.storage[0] - 1).abs() < 0.02;

  void _changeImage(List<LessonMaterial> images, int direction) {
    final current = images.indexWhere((image) => image.id == _resourceId);
    final next = current + direction;
    if (current < 0 || next < 0 || next >= images.length) return;
    final material = images[next];
    setState(() {
      _resourceId = material.id;
      _title = material.title;
      _decoded?.dispose();
      _decoded = null;
      _loadError = null;
      _readerPin = null;
      _focusedPinId = null;
      _didApplyInitialFocus = true;
      _swipeAllowed = false;
      _transformController.value = Matrix4.identity();
    });
    _loadImage(material: material);
    recordMaterialStudyActivity(ref, materialId: material.id);
  }

  Widget _swipeArea({
    required Widget child,
    required bool annotate,
    required List<LessonMaterial> images,
  }) => Listener(
    key: const ValueKey('image-swipe-area'),
    behavior: HitTestBehavior.opaque,
    onPointerDown: (event) {
      _pointers.add(event.pointer);
      if (_pointers.length == 1) {
        _swipeStart = _swipeEnd = event.position;
        _swipeAllowed = !annotate && _atFit && event.buttons == kPrimaryButton;
      } else {
        _swipeAllowed = false;
      }
    },
    onPointerMove: (event) {
      if (_pointers.length == 1) _swipeEnd = event.position;
    },
    onPointerCancel: (event) {
      _pointers.remove(event.pointer);
      _swipeAllowed = false;
    },
    onPointerUp: (event) {
      final allowed =
          _swipeAllowed && _pointers.length == 1 && !annotate && _atFit;
      _pointers.remove(event.pointer);
      _swipeAllowed = false;
      if (!allowed || _swipeStart == null || _swipeEnd == null) return;
      final delta = _swipeEnd! - _swipeStart!;
      if (delta.dx.abs() >= 64 && delta.dx.abs() > delta.dy.abs() * 1.3) {
        _transformController.value = Matrix4.identity();
        _changeImage(images, delta.dx < 0 ? 1 : -1);
      }
    },
    child: child,
  );

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
        resourceId: _resourceId,
        pageNumber: null,
        point: point,
        shortText: result.shortText,
        fullExplanation: result.fullExplanation,
        categoryId: result.categoryId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resourceId = _resourceId;
    final original = ref
        .watch(materialByIdProvider(widget.resourceId))
        .valueOrNull;
    _lessonId ??= original?.lessonId;
    final lessonId = _lessonId;
    final images = lessonId == null
        ? const <LessonMaterial>[]
        : (ref.watch(materialsForLessonProvider(lessonId)).valueOrNull ??
                  const <LessonMaterial>[])
              .where((material) => isImageMimeType(material.mimeType))
              .toList();
    final imageIndex = images.indexWhere((image) => image.id == resourceId);
    final annotate = ref.watch(addPinModeProvider(resourceId));
    final displayMode = ref.watch(pinDisplayModeProvider(resourceId));
    final pinsAsync = ref.watch(studyPinsForResourceProvider(resourceId));
    final pins = pinsAsync.valueOrNull ?? const [];
    final categoryMap =
        ref.watch(studyPinCategoryMapProvider).valueOrNull ?? const {};

    if (!_didApplyInitialFocus &&
        widget.focusPinId != null &&
        pins.isNotEmpty) {
      final focus = pins.where((p) => p.id == widget.focusPinId).firstOrNull;
      if (focus != null) {
        _didApplyInitialFocus = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openReader(focus);
        });
      }
    }

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
        title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          FavoriteStarButton(
            entityType: FavoriteEntityType.material,
            entityId: resourceId,
          ),
          IconButton(
            tooltip: 'AI Discussions',
            onPressed: () async {
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
                          id: resourceId,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: 'Review Pins',
            onPressed: () => openReviewSetup(
              context,
              scope: ReviewScope(
                type: ReviewScopeType.material,
                id: resourceId,
                title: _title,
              ),
            ),
            icon: const Icon(Icons.school_outlined),
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
            child: Stack(
              children: [
                _swipeArea(
                  annotate: annotate,
                  images: images,
                  child: _buildBody(
                    annotate: annotate,
                    displayMode: displayMode,
                    pins: pins,
                    categoryMap: categoryMap,
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
          if (images.length > 1 && imageIndex >= 0)
            SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous image',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: imageIndex > 0
                        ? () => _changeImage(images, -1)
                        : null,
                  ),
                  Text('${imageIndex + 1} of ${images.length}'),
                  IconButton(
                    tooltip: 'Next image',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: imageIndex + 1 < images.length
                        ? () => _changeImage(images, 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required bool annotate,
    required PinDisplayMode displayMode,
    required List<StudyPin> pins,
    required Map<String, StudyPinCategory> categoryMap,
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
                        categoryMap: categoryMap,
                        focusedPinId: _focusedPinId,
                        onPinTap: (pin) {
                          setState(() => _focusedPinId = pin.id);
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
