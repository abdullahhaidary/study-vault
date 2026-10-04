import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_vault/core/widgets/scroll_edge_arrows.dart';

Widget _app({required Widget child}) =>
    MaterialApp(home: Scaffold(body: child));

Finder get _up => find.byTooltip('Go to start');
Finder get _down => find.byTooltip('Go to end');

double _opacity(Finder tooltipFinder) {
  final fader = find
      .ancestor(of: tooltipFinder, matching: find.byType(AnimatedOpacity))
      .first;
  return (fader.evaluate().single.widget as AnimatedOpacity).opacity;
}

void main() {
  testWidgets('arrows show on mount, hide after delay, reappear on scroll', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        child: ScrollEdgeArrows(
          child: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
          ),
        ),
      ),
    );
    await tester.pump();

    // At the top: only the down arrow is useful.
    expect(_opacity(_down), 1);
    expect(_opacity(_up), 0);

    // Hidden after the delay.
    await tester.pump(
      kScrollEdgeArrowsHideDelay + const Duration(milliseconds: 50),
    );
    expect(_opacity(_down), 0);

    // Scrolling reveals again, now both directions are possible.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(_opacity(_down), 1);
    expect(_opacity(_up), 1);

    // Tap "Go to end" jumps to the bottom.
    await tester.tap(_down);
    await tester.pumpAndSettle();
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(_opacity(_down), 0);

    // Tap "Go to start" returns to the top.
    await tester.drag(find.byType(ListView), const Offset(0, 50));
    await tester.pump();
    await tester.tap(_up);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  testWidgets('arrows stay hidden when content does not scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        child: ScrollEdgeArrows(
          child: ListView(children: const [SizedBox(height: 40)]),
        ),
      ),
    );
    await tester.pump();
    expect(_opacity(_up), 0);
    expect(_opacity(_down), 0);
  });

  testWidgets('EdgeArrowsOverlay reveals when revealKey changes', (
    tester,
  ) async {
    var key = 0;
    var starts = 0;
    late StateSetter setOuterState;
    await tester.pumpWidget(
      _app(
        child: StatefulBuilder(
          builder: (context, setState) {
            setOuterState = setState;
            return EdgeArrowsOverlay(
              revealKey: key == 0 ? null : key,
              canGoStart: true,
              canGoEnd: true,
              onGoStart: () => starts++,
              onGoEnd: () {},
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
    expect(_opacity(_up), 0);

    setOuterState(() => key = 1);
    await tester.pump();
    expect(_opacity(_up), 1);
    await tester.tap(_up);
    expect(starts, 1);

    await tester.pump(
      kScrollEdgeArrowsHideDelay + const Duration(milliseconds: 50),
    );
    expect(_opacity(_up), 0);
  });
}
