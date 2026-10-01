import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/study_pins/domain/pin_coordinates.dart';
import 'package:study_vault/features/study_pins/domain/pin_display_mode.dart';
import 'package:study_vault/features/study_pins/presentation/widgets/draggable_point_pin_marker.dart';

void main() {
  StudyPin makePin({double x = 0.5, double y = 0.5, String type = 'point'}) {
    final now = DateTime.now();
    return StudyPin(
      id: 'pin-1',
      resourceId: 'mat-1',
      pinType: type,
      pageNumber: 1,
      xRatio: x,
      yRatio: y,
      shortText: 'Marker',
      fullExplanation: 'Explain',
      selectedText: null,
      sortOrder: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  testWidgets('tap opens callback without move when canDrag is true', (
    tester,
  ) async {
    var taps = 0;
    var moves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                DraggablePointPinMarker(
                  pin: makePin(),
                  contentSize: const Size(200, 200),
                  displayMode: PinDisplayMode.dotsOnly,
                  canDrag: true,
                  onTap: () => taps++,
                  onMoved: (_) => moves++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DraggablePointPinMarker));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(moves, 0);
  });

  testWidgets('pan commits a single onMoved and does not tap', (tester) async {
    var taps = 0;
    final moved = <NormalizedPoint>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                DraggablePointPinMarker(
                  pin: makePin(x: 0.25, y: 0.25),
                  contentSize: const Size(200, 200),
                  displayMode: PinDisplayMode.dotsOnly,
                  canDrag: true,
                  onTap: () => taps++,
                  onMoved: moved.add,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(DraggablePointPinMarker));
    final gesture = await tester.startGesture(center);
    // Exceed touch slop, then continue so a real pan is recognized.
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(50, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 0);
    expect(moved, hasLength(1));
    // Started at (0.25, 0.25); after drag must have moved right/down and stay in range.
    expect(moved.single.xRatio, greaterThan(0.25));
    expect(moved.single.yRatio, greaterThan(0.25));
    expect(moved.single.xRatio, inInclusiveRange(0.0, 1.0));
    expect(moved.single.yRatio, inInclusiveRange(0.0, 1.0));
  });

  testWidgets('cannot drag when canDrag is false', (tester) async {
    var moves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                DraggablePointPinMarker(
                  pin: makePin(),
                  contentSize: const Size(200, 200),
                  displayMode: PinDisplayMode.dotsOnly,
                  canDrag: false,
                  onTap: () {},
                  onMoved: (_) => moves++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(DraggablePointPinMarker));
    await tester.dragFrom(center, const Offset(50, 30));
    await tester.pumpAndSettle();

    expect(moves, 0);
  });
}
