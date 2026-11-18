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
import 'package:study_vault/core/theme/app_spacing.dart';
import 'package:study_vault/core/widgets/responsive_grid.dart';
import 'package:study_vault/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:study_vault/features/flashcards/presentation/flashcards_list_screen.dart';
import 'package:study_vault/features/search/presentation/search_screen.dart';
import 'package:study_vault/features/study_review/presentation/recent_reviews_screen.dart';
import 'package:study_vault/features/study_review/presentation/review_setup_screen.dart';
import 'package:study_vault/features/study_schedule/presentation/study_schedule_screen.dart';
import 'package:study_vault/features/study_workspace/data/study_workspace_providers.dart';

Future<AppDatabase> _pumpApp(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
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
      expect(find.text('Recent Reviews'), findsNothing);
      expect(find.text('Schedule'), findsNothing);
      expect(find.text('Review'), findsOneWidget);
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

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.widgetWithText(ListTile, 'Due Lessons')).width,
        AppSpacing.contentMaxWidthWide - 2 * AppSpacing.pagePaddingWide,
      );
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.byType(RecentReviewsScreen), findsOneWidget);
      expect(find.byType(StudyScheduleScreen), findsNothing);
      final reviewsRail = tester.widget<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(reviewsRail.selectedIndex, 4);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Due Lessons'));
      await tester.pumpAndSettle();
      expect(find.byType(StudyScheduleScreen), findsOneWidget);
      expect(find.byType(RecentReviewsScreen), findsNothing);
      final scheduleRail = tester.widget<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(scheduleRail.selectedIndex, 4);
      await _dispose(tester, db);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('desktop rail opens full-screen AI Chat', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final db = await _pumpApp(tester, const Size(1440, 900));
      final aiChatLabels = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('AI Chat'),
      );
      expect(aiChatLabels, findsOneWidget);

      await tester.tap(aiChatLabels);
      await tester.pumpAndSettle();
      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(find.byTooltip('Leave chat'), findsOneWidget);
      expect(find.byTooltip('Chat history'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      expect(find.byTooltip('Open full screen'), findsNothing);
      expect(find.byTooltip('Minimize'), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 3);
      await _dispose(tester, db);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile AI Chat opens the full-screen page', (tester) async {
    final db = await _pumpApp(tester, const Size(400, 800));
    await tester.tap(find.byTooltip('AI Chat'));
    await tester.pumpAndSettle();
    expect(find.byType(AiChatScreen), findsOneWidget);
    expect(find.byTooltip('Leave chat'), findsOneWidget);
    expect(find.byTooltip('Minimize'), findsNothing);
    await _dispose(tester, db);
  });

  testWidgets('closing the AI chat window keeps app navigation working', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final db = await _pumpApp(tester, const Size(1440, 900));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NavigationRail)),
      );
      container.read(studyWorkspaceProvider.notifier).open();
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
      expect(find.text('StudyDesk'), findsWidgets);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Recent Reviews'), findsNothing);
      expect(find.text('Study Schedule'), findsNothing);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pins'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewSetupScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flashcards'));
      await tester.pumpAndSettle();
      expect(find.byType(FlashcardsListScreen), findsOneWidget);
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
    expect(find.text('StudyDesk'), findsWidgets);
    await _dispose(tester, db);
  });

  testWidgets('advanced settings contains profiles and agent access', (
    tester,
  ) async {
    final db = await _pumpApp(tester, const Size(400, 800));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('AI API Profiles'), findsNothing);
    expect(find.text('Termux agent access'), findsNothing);

    final advanced = find.text('Advanced Settings');
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.widgetWithText(ListTile, 'Advanced Settings')).width,
      400 - 2 * AppSpacing.pagePadding,
    );
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(find.text('AI API Profiles'), findsOneWidget);
    expect(find.text('Termux agent access'), findsOneWidget);
    expect(find.text('Open Manual Entry'), findsOneWidget);
    await _dispose(tester, db);
  });
}
