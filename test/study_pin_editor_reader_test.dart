import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/favorites/data/favorites_providers.dart';
import 'package:study_vault/features/study_pins/data/pin_categories_providers.dart';
import 'package:study_vault/features/study_pins/domain/pin_type.dart';
import 'package:study_vault/features/study_pins/domain/study_note_codec.dart';
import 'package:study_vault/features/study_pins/presentation/add_edit_study_pin_sheet.dart';
import 'package:study_vault/features/study_pins/presentation/study_pin_reader.dart';
import 'package:study_vault/features/study_pins/presentation/widgets/study_rich_text_viewer.dart';

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [
      studyPinCategoriesProvider.overrideWith(
        (ref) => Stream.value(const <StudyPinCategory>[]),
      ),
      isFavoriteProvider.overrideWith((ref, key) => Stream.value(false)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('editor shows selected text context for text annotations', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AddEditStudyPinSheet(
          pinType: StudyPinType.text,
          selectedText: 'supervised learning',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Text Annotation'), findsOneWidget);
    expect(find.text('Selected text'), findsOneWidget);
    expect(find.text('supervised learning'), findsOneWidget);
    expect(find.text('Full Note'), findsOneWidget);
    expect(find.text('Write Full Note'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('editor shows delete only when allowed for editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AddEditStudyPinSheet(
          isEditing: true,
          allowDelete: true,
          initialShortText: 'Existing',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Point Annotation'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('editor previews legacy plain full notes as text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AddEditStudyPinSheet(
          initialShortText: 'Rate',
          initialFullExplanation: 'Learning rate scales each update.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Full Editor'), findsOneWidget);
    expect(
      find.textContaining('Learning rate scales each update.'),
      findsOneWidget,
    );
  });

  testWidgets('reader renders rich full note without being editable', (
    tester,
  ) async {
    final now = DateTime.now();
    final rich = StudyNoteCodec.encode(
      Document.fromJson([
        {
          'insert': 'Gradient Descent\n',
          'attributes': {'header': 1},
        },
        {
          'insert': 'A longer explanation that can be copied.',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]),
    );

    final pin = StudyPin(
      id: 'p1',
      resourceId: 'm1',
      pinType: 'text',
      pageNumber: 1,
      xRatio: 0.1,
      yRatio: 0.2,
      shortText: 'Definition',
      fullExplanation: rich,
      selectedText: 'gradient descent',
      sortOrder: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );

    await tester.pumpWidget(
      _app(
        SizedBox(
          height: 500,
          child: StudyPinReaderPanel(pin: pin, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Study Annotation'), findsOneWidget);
    expect(find.text('Definition'), findsOneWidget);
    expect(find.text('gradient descent'), findsOneWidget);
    expect(find.text('Full Note'), findsOneWidget);
    expect(find.byType(StudyRichTextViewer), findsOneWidget);
    expect(find.text(rich), findsNothing);
    expect(
      find.textContaining('Gradient Descent', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'A longer explanation that can be copied.',
        findRichText: true,
      ),
      findsWidgets,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  testWidgets('reader still shows legacy plain-text full notes', (
    tester,
  ) async {
    final now = DateTime.now();
    final pin = StudyPin(
      id: 'p2',
      resourceId: 'm1',
      pinType: 'point',
      pageNumber: 1,
      xRatio: 0.1,
      yRatio: 0.2,
      shortText: 'Plain',
      fullExplanation: 'A longer explanation that can be copied.',
      selectedText: null,
      sortOrder: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );

    await tester.pumpWidget(
      _app(
        SizedBox(
          height: 500,
          child: StudyPinReaderPanel(pin: pin, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'A longer explanation that can be copied.',
        findRichText: true,
      ),
      findsWidgets,
    );
    expect(find.byType(StudyRichTextViewer), findsOneWidget);
  });
}
