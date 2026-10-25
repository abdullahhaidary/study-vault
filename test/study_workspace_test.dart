import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/app/app.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:study_vault/features/study_workspace/data/study_workspace_providers.dart';
import 'package:study_vault/features/study_workspace/presentation/study_workspace_overlay.dart';

void main() {
  group('StudyWorkspaceController', () {
    test('opens chat and preserves it while minimized', () {
      final controller = StudyWorkspaceController();
      addTearDown(controller.dispose);

      controller.open();
      controller.minimize();

      expect(controller.state.visible, isTrue);
      expect(controller.state.minimized, isTrue);

      controller.restore();
      expect(controller.state.minimized, isFalse);
    });

    test('close hides the floating chat', () {
      final controller = StudyWorkspaceController();
      addTearDown(controller.dispose);
      controller.open();
      controller.close();

      expect(controller.state.visible, isFalse);
      expect(controller.state.minimized, isFalse);
    });
  });

  testWidgets(
    'floating overlay opens, minimizes, and closes from its launcher',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const StudyVaultApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudyWorkspaceHost)),
      );
    expect(container.read(studyWorkspaceProvider).visible, isFalse);
    expect(find.bySemanticsLabel('Open Study AI'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(StudyWorkspaceHost),
        matching: find.byIcon(Icons.auto_awesome),
      ),
    );
    await tester.pumpAndSettle();
      expect(container.read(studyWorkspaceProvider).visible, isTrue);
      expect(container.read(studyWorkspaceProvider).minimized, isFalse);
      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(find.byTooltip('Open full screen'), findsOneWidget);
      expect(find.byTooltip('Chat history'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      expect(find.byTooltip('Minimize'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.byTooltip('Minimize'));
      await tester.pumpAndSettle();
      expect(container.read(studyWorkspaceProvider).visible, isTrue);
      expect(container.read(studyWorkspaceProvider).minimized, isTrue);
    expect(find.byTooltip('Close'), findsNothing);
    expect(find.bySemanticsLabel('Resume Study AI'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(StudyWorkspaceHost),
        matching: find.byIcon(Icons.auto_awesome),
      ),
    );
    await tester.pumpAndSettle();
      expect(container.read(studyWorkspaceProvider).minimized, isFalse);
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(container.read(studyWorkspaceProvider).visible, isFalse);
      expect(container.read(studyWorkspaceProvider).minimized, isFalse);
      expect(find.bySemanticsLabel('Open Study AI'), findsOneWidget);
      expect(find.byTooltip('Close'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
