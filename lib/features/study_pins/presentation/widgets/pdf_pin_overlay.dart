import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/database/app_database.dart';
import '../../data/study_pins_providers.dart';
import '../../domain/pin_category_style.dart';
import '../../domain/pin_coordinates.dart';
import '../../domain/pin_display_mode.dart';
import 'draggable_point_pin_marker.dart';

/// Positions Study Pins and text highlights over a single PDF page.
List<Widget> buildPdfPagePinOverlays({
  required Rect pageRect,
  required PdfPage page,
  required List<StudyPin> pins,
  required List<StudyPinTextRange> textRanges,
  required PinDisplayMode displayMode,
  required bool annotateMode,
  required Map<String, StudyPinCategory> categoryMap,
  String? focusedPinId,
  required void Function(StudyPin pin) onPinTap,
  required void Function(StudyPin pin, NormalizedPoint point) onPointPinMoved,
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

  // Text highlights first (under point markers). Never draggable.
  final pageRanges = textRanges.where((r) => r.pageNumber == page.pageNumber);
  for (final range in pageRanges) {
    final pin = pinById[range.studyPinId];
    if (pin == null || !pin.isTextPin) continue;
    final category = pin.categoryId == null
        ? null
        : categoryMap[pin.categoryId!];

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
          child: _TextHighlightBox(
            category: category,
            focused: pin.id == focusedPinId,
          ),
        ),
      ),
    );
  }

  // Optional short-text label for text pins (dotsAndText only).
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

  // Point pin markers (draggable only while annotate mode is on).
  for (final pin in pagePins.where((p) => p.isPointPin)) {
    final category = pin.categoryId == null
        ? null
        : categoryMap[pin.categoryId!];
    widgets.add(
      DraggablePointPinMarker(
        key: ValueKey(pin.id),
        pin: pin,
        contentSize: pageRect.size,
        displayMode: displayMode,
        canDrag: annotateMode,
        usePdfOverlayHitTesting: true,
        category: category,
        selected: pin.id == focusedPinId,
        onTap: () => onPinTap(pin),
        onMoved: (point) => onPointPinMoved(pin, point),
      ),
    );
  }

  return widgets;
}

class _TextHighlightBox extends StatelessWidget {
  const _TextHighlightBox({this.category, this.focused = false});

  final StudyPinCategory? category;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = PinCategoryStyle.colorOf(category, theme.colorScheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base.withValues(alpha: focused ? 0.35 : 0.22),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: base.withValues(alpha: focused ? 0.7 : 0.35),
          width: focused ? 1.5 : 1,
        ),
      ),
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
