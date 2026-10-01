import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/pin_coordinates.dart';
import '../../domain/pin_display_mode.dart';
import 'study_pin_marker.dart';

/// Positions Study Pins over a single PDF page using normalized ratios.
List<Widget> buildPdfPagePinOverlays({
  required Rect pageRect,
  required PdfPage page,
  required List<StudyPin> pins,
  required PinDisplayMode displayMode,
  required bool addPinMode,
  required void Function(StudyPin pin) onPinTap,
}) {
  if (displayMode == PinDisplayMode.hidden) {
    return const [];
  }

  final pagePins = pins.where(
    (pin) => pin.pageNumber == page.pageNumber && pin.deletedAt == null,
  );

  return [
    for (final pin in pagePins)
      _PdfPinnedMarker(
        key: ValueKey(pin.id),
        pin: pin,
        pageSize: pageRect.size,
        displayMode: displayMode,
        addPinMode: addPinMode,
        onTap: () => onPinTap(pin),
      ),
  ];
}

class _PdfPinnedMarker extends StatelessWidget {
  const _PdfPinnedMarker({
    super.key,
    required this.pin,
    required this.pageSize,
    required this.displayMode,
    required this.addPinMode,
    required this.onTap,
  });

  final StudyPin pin;
  final Size pageSize;
  final PinDisplayMode displayMode;
  final bool addPinMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = NormalizedPoint(
      xRatio: pin.xRatio,
      yRatio: pin.yRatio,
    ).toLocalOffset(pageSize);

    // Anchor the marker so the dot center sits on the stored point.
    const halfDot = StudyPinMarker.dotSize / 2;

    return Positioned(
      left: local.dx - halfDot,
      top: local.dy - halfDot,
      child: PdfOverlayInteractionRegion(
        onTap: (_) {
          // Let Add Pin mode create a new pin even if the tap lands on a marker.
          if (addPinMode) return false;
          onTap();
          return true;
        },
        child: StudyPinMarker(
          shortText: pin.shortText,
          displayMode: displayMode,
        ),
      ),
    );
  }
}
