import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/features/lessons/presentation/widgets/pdf_study_dock.dart';
import 'package:study_vault/features/study_pins/domain/pin_display_mode.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PDF study dock collapses and restores', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfStudyDock(
            bookmarked: false,
            annotating: false,
            pinDisplayMode: PinDisplayMode.dotsOnly,
            onOpenNavigation: () {},
            onToggleBookmark: () {},
            onToggleAnnotating: () {},
            onOpenAi: () {},
            onAction: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.toc_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('pdf_study_dock_collapsed_v1'), isTrue);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.toc_outlined), findsOneWidget);
  });
}
