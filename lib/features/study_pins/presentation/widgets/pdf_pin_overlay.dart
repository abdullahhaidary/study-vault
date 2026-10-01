import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/database/app_database.dart';
import '../../data/study_pins_providers.dart';
import '../../domain/pin_coordinates.dart';
import '../../domain/pin_display_mode.dart';
import 'study_pin_marker.dart';

/// Positions Study Pins and text highlights over a single PDF page.
List<Widget> buildPdfPagePinOverlays({
  required Rect pageRect,
  required PdfPage page,
  required List<StudyPin> pins,
  required List<StudyPinTextRange> textRanges,
  required PinDisplayMode displayMode,
  required void Function(StudyPin pin) onPinTap,
}) {
  if (displayMode == PinDisplayMode.hidden) {
    return const [];
  }

  final pagePins = pins
      .where(
        (pin) => pin.pageNumber == page.pageNumber && pin.deletedAt == null,
      )
      .toList();
  final pinById = {for (final pin in pagePins) pin.id: pin};

  final widgets = <Widget>[];

  // Text highlights first (under point markers).
  final pageRanges = textRanges.where((r) => r.pageNumber == page.pageNumber);
  for (final range in pageRanges) {
    final pin = pinById[range.studyPinId];
    if (pin == null || !pin.isTextPin) continue;

    final local = NormalizedRect(
      xRatio: range.xRatio,
      yRatio: range.yRatio,
      widthRatio: range.widthRatio,
      heightRatio: range.heightRatio,
    ).toLocalRect(pageRect.size);

    widgets.add(
      Positioned(
        key: ValueKey('text-range-${range.id}'),
        left: local.left,
        top: local.top,
        width: local.width.clamp(2.0, double.infinity),
        height: local.height.clamp(2.0, double.infinity),
        child: PdfOverlayInteractionRegion(
          onTap: (_) {
            onPinTap(pin);
            return true;
          },
          child: _TextHighlightBox(showLabel: false),
        ),
      ),
    );
  }

  // Optional short-text label for text pins (dotsAndText only), anchored at pin.
  if (displayMode == PinDisplayMode.dotsAndText) {
    for (final pin in pagePins.where((p) => p.isTextPin)) {
      final local = NormalizedPoint(
        xRatio: pin.xRatio,
        yRatio: pin.yRatio,
      ).toLocalOffset(pageRect.size);
      widgets.add(
        Positioned(
          key: ValueKey('text-label-${pin.id}'),
          left: local.dx + 4,
          top: local.dy - 18,
          child: PdfOverlayInteractionRegion(
            onTap: (_) {
              onPinTap(pin);
              return true;
            },
            child: _TextPinLabel(shortText: pin.shortText),
          ),
        ),
      );
    }
  }

  // Point pin markers.
  for (final pin in pagePins.where((p) => p.isPointPin)) {
    widgets.add(
      _PdfPinnedMarker(
        key: ValueKey(pin.id),
        pin: pin,
        pageSize: pageRect.size,
        displayMode: displayMode,
        onTap: () => onPinTap(pin),
      ),
    );
  }

  return widgets;
}

class _TextHighlightBox extends StatelessWidget {
  const _TextHighlightBox({required this.showLabel});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.35),
        ),
      ),
      child: showLabel ? const SizedBox.expand() : null,
    );
  }
}

class _TextPinLabel extends StatelessWidget {
  const _TextPinLabel({required this.shortText});

  final String shortText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            shortText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PdfPinnedMarker extends StatelessWidget {
  const _PdfPinnedMarker({
    super.key,
    required this.pin,
    required this.pageSize,
    required this.displayMode,
    required this.onTap,
  });

  final StudyPin pin;
  final Size pageSize;
  final PinDisplayMode displayMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = NormalizedPoint(
      xRatio: pin.xRatio,
      yRatio: pin.yRatio,
    ).toLocalOffset(pageSize);

    const halfDot = StudyPinMarker.dotSize / 2;

    return Positioned(
      left: local.dx - halfDot,
      top: local.dy - halfDot,
      child: PdfOverlayInteractionRegion(
        onTap: (_) {
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
