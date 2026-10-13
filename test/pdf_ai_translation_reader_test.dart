import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/lessons/data/materials_providers.dart';
import 'package:study_vault/features/pdf_ai_materials/data/pdf_ai_material_providers.dart';
import 'package:study_vault/features/pdf_ai_materials/data/pdf_ai_preferred_store.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_material_models.dart';
import 'package:study_vault/features/pdf_ai_materials/domain/pdf_ai_translation.dart';
import 'package:study_vault/features/pdf_ai_materials/presentation/pdf_ai_material_reader_screen.dart';
import 'package:study_vault/features/reference_books/data/book_providers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final original = [
    for (var i = 1; i <= 12; i++)
      '## Section $i\n\n${'Cells divide and grow. ' * 170}\n',
  ].join('\n');
  final source = PdfAiMaterial(
    id: 'v1',
    materialId: 'pdf-1',
    type: 'summary',
    content: original,
    version: 1,
    generatedAt: DateTime(2026),
    sourceFingerprint: 'f',
  );
  // Persian sections are much longer, so a plain pixel offset would land in
  // the wrong place; the reader must keep the same section instead.
  final translation = PdfAiMaterialTranslation(
    id: 't1',
    sourceId: 'v1',
    language: 'fa',
    content: PdfAiTranslation.join([
      for (final segment in PdfAiTranslation.segments(original))
        segment
            .replaceAll('Section', 'بخش')
            .replaceAll(
              'Cells divide and grow. ',
              'سلول‌ها تقسیم و رشد می‌کنند. ' * 2,
            ),
    ]),
    sourceHash: PdfAiTranslation.sourceHash(original),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(
    WidgetTester tester, {
    Map<String, PdfAiMaterialTranslation> translations = const {},
  }) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pdfAiPreferredStoreProvider.overrideWithValue(
            MemoryPdfAiPreferredStore(),
          ),
          pdfAiMaterialsProvider(
            'pdf-1',
          ).overrideWith((ref) => Stream.value([source])),
          pdfAiTranslationsProvider(
            'pdf-1',
          ).overrideWith((ref) => Stream.value(translations)),
          pdfAiAlsoPersianProvider.overrideWith((ref) async => false),
          materialsForLessonProvider(
            'lesson-1',
          ).overrideWith((ref) => Stream.value([])),
          materialBookLinksProvider.overrideWith(
            (ref, id) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(
          home: PdfAiMaterialReaderScreen(
            materialId: 'pdf-1',
            pdfTitle: 'PDF',
            filePath: '/fake.pdf',
            type: PdfAiMaterialType.summary,
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Finder heading(String text) => find.text(text, findRichText: true);
  final list = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );

  testWidgets('toggling languages keeps the same section on screen', (
    tester,
  ) async {
    await pump(tester, translations: {'v1': translation});
    await tester.scrollUntilVisible(
      heading('Section 7'),
      300,
      scrollable: list.first,
    );
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byType(ListView)).dy;
    final before = tester.getTopLeft(heading('Section 7')).dy - top;

    await tester.tap(find.text('فا'));
    await tester.pumpAndSettle();
    expect(heading('Section 7'), findsNothing);
    final persian = heading('بخش 7');
    expect(persian, findsOneWidget);
    expect((tester.getTopLeft(persian).dy - top - before).abs(), lessThan(40));
    final direction = tester.widget<Directionality>(
      find.ancestor(of: persian, matching: find.byType(Directionality)).first,
    );
    expect(direction.textDirection, TextDirection.rtl);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(
      (tester.getTopLeft(heading('Section 7')).dy - top - before).abs(),
      lessThan(40),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('choosing فا without a translation offers to create one', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('فا'));
    await tester.pumpAndSettle();
    expect(find.text('Create a Persian version?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(heading('Section 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
