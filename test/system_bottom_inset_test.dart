import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/widgets/system_bottom_inset.dart';

void main() {
  testWidgets('SystemBottomInset includes padding and keyboard', (
    tester,
  ) async {
    late double inset;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(bottom: 48),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
        child: Builder(
          builder: (context) {
            inset = SystemBottomInset.of(context, extra: 12);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(inset, 48 + 300 + 12);
  });

  testWidgets('SystemBottomInset can ignore keyboard', (tester) async {
    late double inset;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(bottom: 48),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
        child: Builder(
          builder: (context) {
            inset = SystemBottomInset.of(context, includeKeyboard: false);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(inset, 48);
  });

  testWidgets('SystemBottomSafeArea disables top/left/right', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SystemBottomSafeArea(child: Text('ok')),
        ),
      ),
    );

    final safe = tester.widget<SafeArea>(find.byType(SafeArea));
    expect(safe.top, isFalse);
    expect(safe.left, isFalse);
    expect(safe.right, isFalse);
    expect(safe.bottom, isTrue);
    expect(find.text('ok'), findsOneWidget);
  });
}
