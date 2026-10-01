import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../data/study_pins_providers.dart';
import '../../domain/pin_coordinates.dart';
import '../../domain/pin_display_mode.dart';
import 'draggable_point_pin_marker.dart';

/// Renders point Study Pins over an image sized to [contentSize].
class ImagePinOverlay extends StatelessWidget {
  const ImagePinOverlay({
    super.key,
    required this.pins,
    required this.contentSize,
    required this.displayMode,
    required this.annotateMode,
    required this.onPinTap,
    required this.onPointPinMoved,
  });

  final List<StudyPin> pins;
  final Size contentSize;
  final PinDisplayMode displayMode;
  final bool annotateMode;
  final void Function(StudyPin pin) onPinTap;
  final void Function(StudyPin pin, NormalizedPoint point) onPointPinMoved;

  @override
  Widget build(BuildContext context) {
    if (displayMode == PinDisplayMode.hidden) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final pin in pins.where(
          (p) => p.deletedAt == null && p.isPointPin,
        ))
          DraggablePointPinMarker(
            key: ValueKey(pin.id),
            pin: pin,
            contentSize: contentSize,
            displayMode: displayMode,
            canDrag: annotateMode,
            usePdfOverlayHitTesting: false,
            onTap: () => onPinTap(pin),
            onMoved: (point) => onPointPinMoved(pin, point),
          ),
      ],
    );
  }
}
