import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/app/app.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/core/widgets/responsive_grid.dart';
import 'package:study_vault/features/search/presentation/search_screen.dart';

Future<AppDatabase> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const StudyVaultApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  return db;
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
  await db.close();
}

void main() {
  testWidgets('a single grid item starts at the left edge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: const ResponsiveGrid(
              minItemWidth: 260,
              children: [SizedBox(key: Key('only-card'), height: 40)],
            ),
          ),
        ),
      ),
    );
    final gridLeft = tester.getTopLeft(find.byType(ResponsiveGrid)).dx;
    expect(tester.getTopLeft(find.byKey(const Key('only-card'))).dx, gridLeft);
    expect(
      tester.getSize(find.byType(ResponsiveGrid)).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
  });

  testWidgets('desktop window shows a persistent navigation rail', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final db = await _pumpApp(tester, const Size(1440, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Library'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Add Class'), findsWidgets);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 2);

      await tester.tap(find.text('Library').first);
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.text('My Classes'), findsOneWidget);
      await _dispose(tester, db);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('closing the AI chat window keeps app navigation working', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final db = await _pumpApp(tester, const Size(1440, 900));
      await tester.tap(find.byIcon(Icons.auto_awesome).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      await tester.tap(find.text('Library').first);
      await tester.pumpAndSettle();
      expect(find.text('My Classes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester, db);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('narrow desktop window falls back to the compact layout', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final db = await _pumpApp(tester, const Size(900, 800));
      expect(find.byType(NavigationRail), findsNothing);
      await _dispose(tester, db);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('phones keep the mobile layout even on wide screens', (
    tester,
  ) async {
    final db = await _pumpApp(tester, const Size(1440, 900));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Study Vault'), findsWidgets);
    await _dispose(tester, db);
  });
}
