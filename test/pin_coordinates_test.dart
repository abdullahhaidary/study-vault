import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/study_pins/domain/pin_coordinates.dart';

void main() {
  test('normalized point round-trips through content size', () {
    const size = Size(200, 400);
    final point = NormalizedPoint.fromLocalOffset(const Offset(50, 100), size);

    expect(point.xRatio, closeTo(0.25, 0.0001));
    expect(point.yRatio, closeTo(0.25, 0.0001));

    final back = point.toLocalOffset(size);
    expect(back.dx, closeTo(50, 0.0001));
    expect(back.dy, closeTo(100, 0.0001));
  });

  test('normalized point clamps out-of-bounds taps', () {
    const size = Size(100, 100);
    final point = NormalizedPoint.fromLocalOffset(const Offset(-10, 150), size);

    expect(point.xRatio, 0);
    expect(point.yRatio, 1);
  });
}
