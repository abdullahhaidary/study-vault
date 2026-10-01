import 'dart:ui';

/// Normalized point on a PDF page or image (0–1 range).
///
/// Ratios are relative to the content bounds with a top-left origin so pins
/// stay anchored across zoom, pan, and different screen sizes.
class NormalizedPoint {
  const NormalizedPoint({required this.xRatio, required this.yRatio});

  final double xRatio;
  final double yRatio;

  /// Convert a local tap within [contentSize] into normalized ratios.
  static NormalizedPoint fromLocalOffset(Offset local, Size contentSize) {
    if (contentSize.width <= 0 || contentSize.height <= 0) {
      return const NormalizedPoint(xRatio: 0, yRatio: 0);
    }
    return NormalizedPoint(
      xRatio: (local.dx / contentSize.width).clamp(0.0, 1.0),
      yRatio: (local.dy / contentSize.height).clamp(0.0, 1.0),
    );
  }

  /// Convert stored ratios back into local overlay coordinates.
  Offset toLocalOffset(Size contentSize) {
    return Offset(xRatio * contentSize.width, yRatio * contentSize.height);
  }
}

/// Normalized axis-aligned rectangle on a PDF page (0–1 range).
///
/// Used for text-selection fragment bounds so highlights survive reopen / zoom.
class NormalizedRect {
  const NormalizedRect({
    required this.xRatio,
    required this.yRatio,
    required this.widthRatio,
    required this.heightRatio,
  });

  final double xRatio;
  final double yRatio;
  final double widthRatio;
  final double heightRatio;

  static NormalizedRect fromLocalRect(Rect local, Size contentSize) {
    if (contentSize.width <= 0 || contentSize.height <= 0) {
      return const NormalizedRect(
        xRatio: 0,
        yRatio: 0,
        widthRatio: 0,
        heightRatio: 0,
      );
    }
    return NormalizedRect(
      xRatio: (local.left / contentSize.width).clamp(0.0, 1.0),
      yRatio: (local.top / contentSize.height).clamp(0.0, 1.0),
      widthRatio: (local.width / contentSize.width).clamp(0.0, 1.0),
      heightRatio: (local.height / contentSize.height).clamp(0.0, 1.0),
    );
  }

  Rect toLocalRect(Size contentSize) {
    return Rect.fromLTWH(
      xRatio * contentSize.width,
      yRatio * contentSize.height,
      widthRatio * contentSize.width,
      heightRatio * contentSize.height,
    );
  }

  NormalizedPoint get center => NormalizedPoint(
    xRatio: xRatio + widthRatio / 2,
    yRatio: yRatio + heightRatio / 2,
  );
}
