import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/pin_coordinates.dart';
import '../../domain/pin_display_mode.dart';
import 'study_pin_marker.dart';

/// Point pin marker that can be repositioned while [canDrag] is true.
///
/// - Annotate OFF ([canDrag] false): uses [PdfOverlayInteractionRegion] so the
///   PDF viewer keeps pan/zoom ownership; tap opens the reader.
/// - Annotate ON ([canDrag] true): real [GestureDetector] tap vs pan so a drag
///   moves the pin locally and only commits via [onMoved] on pan end.
class DraggablePointPinMarker extends StatefulWidget {
  const DraggablePointPinMarker({
    super.key,
    required this.pin,
    required this.contentSize,
    required this.displayMode,
    required this.canDrag,
    required this.onTap,
    this.onMoved,
    this.usePdfOverlayHitTesting = false,
  });

  final StudyPin pin;
  final Size contentSize;
  final PinDisplayMode displayMode;
  final bool canDrag;
  final VoidCallback onTap;

  /// Called once when a drag completes with the clamped normalized point.
  final ValueChanged<NormalizedPoint>? onMoved;

  /// When true and not dragging, use pdfrx overlay hit-testing (pointer-transparent).
  final bool usePdfOverlayHitTesting;

  @override
  State<DraggablePointPinMarker> createState() =>
      _DraggablePointPinMarkerState();
}

class _DraggablePointPinMarkerState extends State<DraggablePointPinMarker> {
  /// Local center within [contentSize]. Set during drag and kept until DB
  /// ratios catch up to avoid a visual jump.
  Offset? _overrideCenter;
  bool _dragging = false;

  Offset get _dbCenter => NormalizedPoint(
    xRatio: widget.pin.xRatio,
    yRatio: widget.pin.yRatio,
  ).toLocalOffset(widget.contentSize);

  Offset get _center {
    final raw = _overrideCenter ?? _dbCenter;
    return _clamp(raw);
  }

  Offset _clamp(Offset local) {
    final size = widget.contentSize;
    return Offset(
      local.dx.clamp(0.0, size.width),
      local.dy.clamp(0.0, size.height),
    );
  }

  @override
  void didUpdateWidget(covariant DraggablePointPinMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging &&
        _overrideCenter != null &&
        (oldWidget.pin.xRatio != widget.pin.xRatio ||
            oldWidget.pin.yRatio != widget.pin.yRatio ||
            oldWidget.contentSize != widget.contentSize)) {
      // DB (or layout) caught up — drop ephemeral override.
      _overrideCenter = null;
    }
    if (!widget.canDrag && _dragging) {
      _dragging = false;
      _overrideCenter = null;
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _dragging = true;
      _overrideCenter = _center;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() {
      _overrideCenter = _clamp((_overrideCenter ?? _center) + details.delta);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_dragging) return;
    final finalCenter = _clamp(_overrideCenter ?? _center);
    final point = NormalizedPoint.fromLocalOffset(
      finalCenter,
      widget.contentSize,
    );
    setState(() {
      _dragging = false;
      _overrideCenter = finalCenter;
    });
    widget.onMoved?.call(point);
  }

  void _onPanCancel() {
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      _overrideCenter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const halfDot = StudyPinMarker.dotSize / 2;
    final center = _center;

    final marker = StudyPinMarker(
      shortText: widget.pin.shortText,
      displayMode: widget.displayMode,
      dragging: _dragging,
    );

    final scaled = Transform.scale(
      scale: _dragging ? 1.1 : 1.0,
      alignment: Alignment.topLeft,
      child: marker,
    );

    final Widget interactive;
    if (widget.canDrag) {
      interactive = MouseRegion(
        cursor: _dragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: scaled,
        ),
      );
    } else if (widget.usePdfOverlayHitTesting) {
      interactive = PdfOverlayInteractionRegion(
        onTap: (_) {
          widget.onTap();
          return true;
        },
        child: marker,
      );
    } else {
      interactive = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: marker,
      );
    }

    return Positioned(
      left: center.dx - halfDot,
      top: center.dy - halfDot,
      child: interactive,
    );
  }
}
