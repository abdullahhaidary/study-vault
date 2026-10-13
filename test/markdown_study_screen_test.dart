import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/ai_chat/data/ai_chat_providers.dart';
import 'package:study_vault/features/lessons/presentation/markdown_study_screen.dart';
import 'package:study_vault/features/pdf_ai_materials/data/pdf_ai_material_providers.dart';
import 'package:study_vault/features/pdf_ai_materials/presentation/pdf_ai_materials_panel.dart';
import 'package:study_vault/features/reference_books/data/book_providers.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late AppDatabase db;
  late File file;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final dir = await Directory.systemTemp.createTemp('markdown_study');
    file = File('${dir.path}/notes.md')..writeAsStringSync('# Cells\nMitosis');
  });
  tearDown(() async {
    await db.close();
    await file.parent.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pdfAiMaterialsProvider.overrideWith(
            (ref, id) => Stream.value(const []),
          ),
          materialBookLinksProvider.overrideWith(
            (ref, id) => Stream.value(const []),
          ),
          aiDiscussionsCountProvider.overrideWith(
            (ref, key) => Stream.value(0),
          ),
        ],
        child: MaterialApp(
          home: MarkdownStudyScreen(
            resourceId: 'm',
            title: 'Notes',
            filePath: file.path,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20 && find.text('Cells').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await settle(tester);
  }

  testWidgets('wide windows open AI materials beside the document', (
    tester,
  ) async {
    await pump(tester, const Size(1400, 900));
    expect(find.text('Cells'), findsOneWidget);
    expect(find.byType(PdfAiMaterialsPanel), findsNothing);

    await tester.tap(find.byTooltip('AI explanations'));
    await settle(tester);
    expect(find.byType(PdfAiMaterialsPanel), findsOneWidget);
    expect(find.text('Cells'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(PdfAiMaterialsPanel)).dx,
      greaterThan(tester.getTopRight(find.text('Cells')).dx),
    );

    await tester.tap(find.byTooltip('Close AI explanations'));
    await settle(tester);
    expect(find.byType(PdfAiMaterialsPanel), findsNothing);
    await unmount(tester);
  });

  testWidgets('phones show AI materials as an overlay', (tester) async {
    await pump(tester, const Size(400, 800));
    await tester.tap(find.byTooltip('AI explanations'));
    await settle(tester);
    expect(
      tester.getSize(find.byType(PdfAiMaterialsPanel)).width,
      greaterThan(360),
    );
    await unmount(tester);
  });
}
