import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/study_pins/domain/pin_type.dart';
import 'package:study_vault/features/study_pins/presentation/add_edit_study_pin_sheet.dart';
import 'package:study_vault/features/study_pins/presentation/study_pin_reader.dart';

void main() {
  testWidgets('editor shows selected text context for text annotations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddEditStudyPinSheet(
            pinType: StudyPinType.text,
            selectedText: 'supervised learning',
          ),
        ),
      ),
    );

    expect(find.text('Add Text Annotation'), findsOneWidget);
    expect(find.text('Selected text'), findsOneWidget);
    expect(find.text('supervised learning'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('editor shows delete only when allowed for editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddEditStudyPinSheet(
            isEditing: true,
            allowDelete: true,
            initialShortText: 'Existing',
          ),
        ),
      ),
    );

    expect(find.text('Edit Point Annotation'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('reader panel is read-only and shows fields', (tester) async {
    final now = DateTime.now();
    final pin = StudyPin(
      id: 'p1',
      resourceId: 'm1',
      pinType: 'text',
      pageNumber: 1,
      xRatio: 0.1,
      yRatio: 0.2,
      shortText: 'Definition',
      fullExplanation: 'A longer explanation that can be copied.',
      selectedText: 'gradient descent',
      sortOrder: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: StudyPinReaderPanel(pin: pin, onClose: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Study Annotation'), findsOneWidget);
    expect(find.text('Definition'), findsOneWidget);
    expect(find.text('gradient descent'), findsOneWidget);
    expect(
      find.text('A longer explanation that can be copied.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });
}
