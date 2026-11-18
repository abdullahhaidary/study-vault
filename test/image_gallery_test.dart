import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/core/storage/study_vault_paths.dart';
import 'package:study_vault/features/favorites/presentation/favorite_star_button.dart';
import 'package:study_vault/features/favorites/data/favorites_providers.dart';
import 'package:study_vault/features/lessons/data/materials_providers.dart';
import 'package:study_vault/features/lessons/presentation/image_study_screen.dart';
import 'package:study_vault/features/lessons/presentation/lesson_images_screen.dart';
import 'package:study_vault/features/study_pins/data/pin_categories_providers.dart';
import 'package:study_vault/features/study_pins/data/study_pins_providers.dart';

void main() {
  late Directory temp;
  late AppDatabase db;
  late List<LessonMaterial> materials;
  final viewport = find.byKey(const ValueKey('image-swipe-area'));

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sv-image-gallery-');
    StudyVaultPaths.useLibraryRoot(temp);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime(2026);
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'c',
        name: 'Class',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's',
        classId: 'c',
        name: 'Subject',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'l',
        subjectId: 's',
        name: 'Lesson',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final directory = await Directory(
      '${temp.path}/study_vault_files/lessons/l',
    ).create(recursive: true);
    for (var i = 1; i <= 3; i++) {
      await File('${directory.path}/$i.png').writeAsBytes(
        image.encodePng(
          image.fill(
            image.Image(width: 8, height: 8),
            color: image.ColorRgb8(i * 60, 0, 0),
          ),
        ),
      );
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'i$i',
          lessonId: 'l',
          title: 'Image $i',
          originalFileName: '$i.png',
          storedFileName: '$i.png',
          mimeType: const Value('image/png'),
          sortOrder: Value(i * 2),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'pdf',
        lessonId: 'l',
        title: 'PDF',
        originalFileName: 'lecture.pdf',
        storedFileName: 'lecture.pdf',
        sortOrder: const Value(3),
        createdAt: now,
        updatedAt: now,
      ),
    );
    materials = await db.watchMaterialsForLesson('l').first;
  });
  tearDown(() async {
    await db.close();
    StudyVaultPaths.useLibraryRoot(null);
    await temp.delete(recursive: true);
  });

  Future<void> frames(WidgetTester tester, [int count = 5]) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> open(WidgetTester tester, {int initial = 2}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final selected = materials.firstWhere(
      (material) => material.id == 'i$initial',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          isFavoriteProvider.overrideWith((ref, key) => Stream.value(false)),
          materialByIdProvider.overrideWith(
            (ref, id) => Stream.value(materials.firstWhere((m) => m.id == id)),
          ),
          materialsForLessonProvider.overrideWith(
            (ref, id) => Stream.value(materials),
          ),
          studyPinsForResourceProvider.overrideWith(
            (ref, id) => Stream.value([]),
          ),
          studyPinCategoriesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: ImageStudyScreen(
            resourceId: selected.id,
            title: selected.title,
            filePath: '${temp.path}/study_vault_files/lessons/l/$initial.png',
          ),
        ),
      ),
    );
    await frames(tester);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await frames(tester);
  }

  testWidgets('cancelling image removal keeps the attachment', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          materialsForLessonProvider.overrideWith(
            (ref, id) => Stream.value(materials),
          ),
        ],
        child: const MaterialApp(
          home: LessonImagesScreen(
            scope: LessonImagesScope(lessonId: 'l', title: 'Lesson'),
          ),
        ),
      ),
    );
    await frames(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('i1')),
        matching: find.byTooltip('Image options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove image?'), findsOneWidget);
    expect(find.textContaining('Study Pins on this resource'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Remove image?'), findsNothing);
    expect(await tester.runAsync(() => db.getMaterialById('i1')), isNotNull);
    expect(
      File('${temp.path}/study_vault_files/lessons/l/1.png').existsSync(),
      isTrue,
    );
    await close(tester);
  });

  testWidgets(
    'left and right swipes follow only lesson images without wrapping',
    (tester) async {
      await open(tester);
      expect(find.text('2 of 3'), findsOneWidget);
      await tester.drag(viewport, const Offset(-220, 0));
      await frames(tester);
      expect(find.text('Image 3'), findsOneWidget);
      expect(find.text('3 of 3'), findsOneWidget);
      expect(
        tester
            .widget<FavoriteStarButton>(find.byType(FavoriteStarButton))
            .entityId,
        'i3',
      );
      await tester.drag(viewport, const Offset(-220, 0));
      await frames(tester);
      expect(find.text('Image 3'), findsOneWidget);
      await tester.drag(viewport, const Offset(220, 0));
      await frames(tester);
      expect(find.text('Image 2'), findsOneWidget);
      await tester.drag(viewport, const Offset(220, 0));
      await frames(tester);
      expect(find.text('Image 1'), findsOneWidget);
      await tester.drag(viewport, const Offset(220, 0));
      await frames(tester);
      expect(find.text('Image 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'zoomed panning, vertical drags, and annotation do not switch images',
    (tester) async {
      await open(tester);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
      await tester.drag(viewport, const Offset(-220, 0));
      await frames(tester);
      expect(find.text('Image 2'), findsOneWidget);
      controller.value = Matrix4.identity();
      await tester.pump();
      await tester.drag(viewport, const Offset(0, -220));
      await frames(tester);
      expect(find.text('Image 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Annotate: OFF'));
      await tester.pump();
      await tester.drag(viewport, const Offset(-220, 0));
      await frames(tester);
      expect(find.text('Image 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets('two-finger gestures do not navigate, next swipe still works', (
    tester,
  ) async {
    await open(tester);
    final center = tester.getCenter(viewport);
    final first = await tester.startGesture(
      center + const Offset(0, -40),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(0, 40),
      pointer: 2,
    );
    await first.moveBy(const Offset(-100, 0));
    await second.moveBy(const Offset(-100, 0));
    await first.up();
    await second.up();
    await frames(tester);
    expect(find.text('Image 2'), findsOneWidget);
    tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value =
        Matrix4.identity();
    await tester.pump();
    await tester.drag(viewport, const Offset(-220, 0));
    await frames(tester);
    expect(find.text('Image 3'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'rapid navigation keeps the final image and missing files can be skipped',
    (tester) async {
      File('${temp.path}/study_vault_files/lessons/l/2.png').deleteSync();
      await open(tester, initial: 1);
      await tester.drag(viewport, const Offset(-220, 0));
      await frames(tester);
      expect(find.textContaining('Could not load image:'), findsOneWidget);
      await tester.drag(viewport, const Offset(-220, 0));
      await frames(tester);
      expect(find.text('Image 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous image'));
      await tester.pump();
      await tester.tap(find.byTooltip('Previous image'));
      await tester.pump();
      await tester.tap(find.byTooltip('Next image'));
      await tester.pump();
      await tester.tap(find.byTooltip('Next image'));
      await frames(tester);
      expect(find.text('Image 3'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
      final pixels = await tester.runAsync(
        () => decoded.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(pixels!.getUint8(0), 180);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
}
