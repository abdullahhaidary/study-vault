import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/study_pins/domain/pin_coordinates.dart';
import 'package:study_vault/features/study_pins/domain/pin_type.dart';

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

  test('normalized rect round-trips through content size', () {
    const size = Size(200, 400);
    final rect = NormalizedRect.fromLocalRect(
      const Rect.fromLTWH(20, 40, 60, 20),
      size,
    );

    expect(rect.xRatio, closeTo(0.1, 0.0001));
    expect(rect.yRatio, closeTo(0.1, 0.0001));
    expect(rect.widthRatio, closeTo(0.3, 0.0001));
    expect(rect.heightRatio, closeTo(0.05, 0.0001));

    final back = rect.toLocalRect(size);
    expect(back.left, closeTo(20, 0.0001));
    expect(back.top, closeTo(40, 0.0001));
    expect(back.width, closeTo(60, 0.0001));
    expect(back.height, closeTo(20, 0.0001));
    expect(rect.center.xRatio, closeTo(0.25, 0.0001));
  });

  test('study pin type parses db values with point fallback', () {
    expect(StudyPinType.fromDb('point'), StudyPinType.point);
    expect(StudyPinType.fromDb('text'), StudyPinType.text);
    expect(StudyPinType.fromDb('unknown'), StudyPinType.point);
    expect(StudyPinType.point.dbValue, 'point');
  });
}
