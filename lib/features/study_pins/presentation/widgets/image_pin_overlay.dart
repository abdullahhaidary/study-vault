import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../data/study_pins_providers.dart';
import '../../domain/pin_coordinates.dart';
import '../../domain/pin_display_mode.dart';
import 'study_pin_marker.dart';

/// Renders point Study Pins over an image sized to [contentSize].
class ImagePinOverlay extends StatelessWidget {
  const ImagePinOverlay({
    super.key,
    required this.pins,
    required this.contentSize,
    required this.displayMode,
    required this.onPinTap,
  });

  final List<StudyPin> pins;
  final Size contentSize;
  final PinDisplayMode displayMode;
  final void Function(StudyPin pin) onPinTap;

  @override
  Widget build(BuildContext context) {
    if (displayMode == PinDisplayMode.hidden) {
      return const SizedBox.shrink();
    }

    const halfDot = StudyPinMarker.dotSize / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final pin in pins.where(
          (p) => p.deletedAt == null && p.isPointPin,
        ))
          Builder(
            builder: (context) {
              final local = NormalizedPoint(
                xRatio: pin.xRatio,
                yRatio: pin.yRatio,
              ).toLocalOffset(contentSize);

              return Positioned(
                left: local.dx - halfDot,
                top: local.dy - halfDot,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPinTap(pin),
                  child: StudyPinMarker(
                    shortText: pin.shortText,
                    displayMode: displayMode,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
