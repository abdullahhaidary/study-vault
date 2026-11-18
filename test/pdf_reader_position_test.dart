import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/lessons/data/bookmarks_providers.dart';
import 'package:study_vault/features/lessons/data/materials_providers.dart';
import 'package:study_vault/features/lessons/presentation/pdf_study_screen.dart';
import 'package:study_vault/features/pdf_ai_materials/data/pdf_ai_material_providers.dart';
import 'package:study_vault/features/reference_books/data/book_providers.dart';
import 'package:study_vault/features/study_pins/data/pin_categories_providers.dart';
import 'package:study_vault/features/study_pins/data/study_pins_providers.dart';

void main() {
  late Directory directory;
  late File file;
  late AppDatabase db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('sv-pdf-position-');
    await pdfrxInitialize(tmpPath: directory.path);
    file = File('${directory.path}/source.pdf');
    await file.writeAsBytes(_pdf());
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> frames(WidgetTester tester, [int count = 5]) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<PdfViewerController> open(
    WidgetTester tester, {
    int? initialPage,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          materialPersianVariantProvider.overrideWith(
            (ref, id) => Stream.value(null),
          ),
          studyPinsForResourceProvider.overrideWith(
            (ref, id) => Stream.value([]),
          ),
          textRangesForResourceProvider.overrideWith(
            (ref, id) => Stream.value([]),
          ),
          bookmarksForMaterialProvider.overrideWith(
            (ref, id) => Stream.value([]),
          ),
          studyPinCategoriesProvider.overrideWith((ref) => Stream.value([])),
          pdfAiMaterialsProvider.overrideWith((ref, id) => Stream.value([])),
          materialBookLinksProvider.overrideWith((ref, id) => Stream.value([])),
        ],
        child: MaterialApp(
          home: PdfStudyScreen(
            resourceId: 'pdf',
            title: 'PDF',
            filePath: file.path,
            initialPage: initialPage,
          ),
        ),
      ),
    );
    for (var i = 0; i < 150; i++) {
      await frames(tester, 1);
      final viewers = find.byType(PdfViewer);
      if (viewers.evaluate().isNotEmpty) {
        final controller = tester.widget<PdfViewer>(viewers.first).controller!;
        if (controller.isReady) {
          await frames(tester);
          return controller;
        }
      }
    }
    throw StateError(
      'PDF viewer did not become ready: ${tester.takeException()}',
    );
  }

  for (final size in [const Size(400, 800), const Size(1400, 900)]) {
    testWidgets(
      'PDF viewport and zoom survive AI overlays and reopening at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = await open(tester);
        await tester.runAsync(
          () => controller.goToPage(pageNumber: 3, duration: Duration.zero),
        );
        await tester.runAsync(
          () => controller.setZoom(
            controller.centerPosition,
            controller.currentZoom * 1.4,
            duration: Duration.zero,
          ),
        );
        await frames(tester);
        final center = controller.centerPosition;
        final zoom = controller.currentZoom;
        await tester.tap(find.byTooltip('AI explanations'));
        await frames(tester);
        await tester.tap(find.byTooltip('Close AI explanations'));
        await frames(tester);
        expect(controller.centerPosition.dy, closeTo(center.dy, 1));
        expect(controller.currentZoom, closeTo(zoom, 0.001));
        await tester.pumpWidget(const SizedBox.shrink());
        await frames(tester);
        final reopened = await open(tester);
        expect(reopened.pageNumber, 3);
        expect(reopened.centerPosition.dy, closeTo(center.dy, 2));
        expect(reopened.currentZoom, closeTo(zoom, 0.001));
        await tester.pumpWidget(const SizedBox.shrink());
        await frames(tester);
        final targeted = await open(tester, initialPage: 1);
        expect(targeted.pageNumber, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await frames(tester);
      },
    );
  }
}

List<int> _pdf() {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [4 0 R 6 0 R 8 0 R 10 0 R 12 0 R] /Count 5 >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  for (var i = 1; i <= 5; i++) {
    final contentId = objects.length + 2;
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents $contentId 0 R >>',
    );
    final stream = 'BT /F1 12 Tf 72 720 Td (Page $i) Tj ET';
    objects.add('<< /Length ${stream.length} >>\nstream\n$stream\nendstream');
  }
  final output = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(output.length);
    output.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = output.length;
  output.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    output.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  output.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return ascii.encode(output.toString());
}
