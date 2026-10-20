import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/lessons/domain/lesson_progress.dart';
import 'package:study_vault/features/lessons/presentation/lesson_details_screen.dart';

void main() {
  testWidgets('progress menu explains enrollment and still selects a status', (
    tester,
  ) async {
    LessonProgressStatus? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonProgressBadge(
            status: LessonProgressStatus.studying,
            onSelected: (status) => selected = status,
          ),
        ),
      ),
    );

    expect(find.text('Studying'), findsOneWidget);
    await tester.tap(find.byTooltip('Change progress'));
    await tester.pumpAndSettle();

    expect(
      find.text(LessonProgressBadge.scheduleExplanation),
      findsOneWidget,
    );
    for (final status in LessonProgressStatus.values) {
      expect(find.text(status.label), findsWidgets);
    }

    await tester.tap(find.text('Reviewed').last);
    await tester.pumpAndSettle();
    expect(selected, LessonProgressStatus.reviewed);
    expect(find.text(LessonProgressBadge.scheduleExplanation), findsNothing);
  });
}
