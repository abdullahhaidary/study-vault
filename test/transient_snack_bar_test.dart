import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/widgets/transient_snack_bar.dart';

void main() {
  test('uses the shared three-second non-persistent policy', () {
    const snackBar = TransientSnackBar(content: Text('Saved'));

    expect(snackBar.duration, transientSnackBarDuration);
    expect(snackBar.persist, isFalse);
  });

  testWidgets('action snackbars dismiss automatically', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  TransientSnackBar(
                    content: const Text('Generation ready'),
                    action: SnackBarAction(label: 'View', onPressed: () {}),
                  ),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Generation ready'), findsOneWidget);

    await tester.pump(transientSnackBarDuration);
    await tester.pumpAndSettle();
    expect(find.text('Generation ready'), findsNothing);
  });
}
