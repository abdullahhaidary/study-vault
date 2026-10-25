import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';
import 'package:study_vault/features/ai_assistant/data/ai_credential_store.dart';
import 'package:study_vault/features/ai_assistant/data/ai_providers.dart';
import 'package:study_vault/features/ai_assistant/data/ai_settings_store.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_provider.dart';
import 'package:study_vault/features/ai_chat/data/ai_chat_providers.dart';
import 'package:study_vault/features/ai_chat/domain/ai_chat_models.dart';
import 'package:study_vault/features/ai_chat/domain/referenced_ai_message.dart';
import 'package:study_vault/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:study_vault/features/ai_chat/presentation/widgets/ai_discussions_section.dart';
import 'package:study_vault/features/ai_chat/services/ai_chat_service.dart';
import 'package:study_vault/features/ai_chat/services/gemini_chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI Discussions can be dismissed and returns on a new visit', (
    tester,
  ) async {
    Future<void> pumpSection() {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiDiscussionsCountProvider.overrideWith(
              (ref, key) => Stream.value(2),
            ),
            aiDiscussionsGroupedProvider.overrideWith(
              (ref, key) => Stream.value(const <ReferencedAiChatGroup>[]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AiDiscussionsSection(
                kind: AiContextKind.lesson,
                id: 'lesson-1',
              ),
            ),
          ),
        ),
      );
    }

    await pumpSection();
    await tester.pump();

    expect(find.text('AI Discussions'), findsOneWidget);
    expect(find.text('Loading…'), findsNothing);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pump();

    expect(find.text('AI Discussions'), findsNothing);
    expect(find.byType(AiDiscussionsSection), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpSection();
    await tester.pump();
    expect(find.text('AI Discussions'), findsOneWidget);
  });

  testWidgets('AI Discussions stays hidden until the count arrives', (
    tester,
  ) async {
    final pending = StreamController<int>();
    addTearDown(pending.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiDiscussionsCountProvider.overrideWith((ref, key) => pending.stream),
          aiDiscussionsGroupedProvider.overrideWith(
            (ref, key) => Stream.value(const <ReferencedAiChatGroup>[]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiDiscussionsSection(kind: AiContextKind.note, id: 'note-1'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AI Discussions'), findsNothing);
    expect(find.text('Loading…'), findsNothing);
  });

  testWidgets(
    'scrolling up during a stream stops follow, and returning to the bottom resumes it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final settings = MemoryAiSettingsStore();
      await settings.setPrivacyConsentAccepted(true);
      final credentials = MemoryAiCredentialStore();
      await credentials.saveApiKeyFor(AiProviderId.gemini, 'test-key');
      final service = _GatedChatService(
        db: db,
        settings: settings,
        transport: FakeGeminiChatService(
          credentials: credentials,
          settings: settings,
        ),
      );
      addTearDown(() async {
        await service.chunks.close();
        await db.close();
      });

      final chat = await service.createChat();
      for (var i = 0; i < 8; i++) {
        await db.insertAiChatMessage(
          AiChatMessagesCompanion.insert(
            id: 'seed-$i',
            chatId: chat.id,
            role: i.isEven ? AiChatRole.user : AiChatRole.assistant,
            content: List.filled(
              14,
              'Seeded study line $i about gradient descent.',
            ).join('\n'),
            createdAt: DateTime.utc(2026, 1, 1, 0, i),
          ),
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            aiChatServiceProvider.overrideWithValue(service),
            aiConfiguredProvider.overrideWith((ref) async => true),
            aiPrivacyConsentProvider.overrideWith((ref) async => true),
          ],
          child: const MaterialApp(home: AiChatScreen(embedded: true)),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiChatScreen)),
      );
      container.read(activeAiChatIdProvider.notifier).state = chat.id;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Seeded study line 0'), findsOneWidget);
      expect(chatScroll(tester).position.maxScrollExtent, greaterThan(200));

      await tester.enterText(
        find.byType(TextField),
        'Continue the explanation',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      for (var i = 0; i < 30 && !service.started.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(service.started.isCompleted, isTrue);

      service.emit(List.filled(30, 'First streaming paragraph.').join('\n'));
      await tester.pump();
      await tester.pump();

      expect(isNearBottom(tester), isTrue);

      final heldOffset = chatScroll(tester).offset;
      await tester.drag(find.byType(ListView), const Offset(0, 320));
      await tester.pump();

      expect(isNearBottom(tester), isFalse);

      await tester.pump(const Duration(milliseconds: 80));
      final parked = chatScroll(tester).offset;
      service.emit(
        List.filled(70, 'Second streaming paragraph grows.').join('\n'),
      );
      await tester.pump();
      await tester.pump();

      expect(chatScroll(tester).offset, closeTo(parked, 8));
      expect(isNearBottom(tester), isFalse);
      expect(chatScroll(tester).offset, lessThan(heldOffset));

      await tester.tap(find.byTooltip('Go to end'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(isNearBottom(tester), isTrue);

      await tester.pump(const Duration(milliseconds: 80));
      service.emit(
        List.filled(110, 'Third streaming paragraph keeps growing.').join('\n'),
      );
      await tester.pump();
      await tester.pump();

      expect(isNearBottom(tester), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}

ScrollController chatScroll(WidgetTester tester) {
  return tester.widget<ListView>(find.byType(ListView)).controller!;
}

bool isNearBottom(WidgetTester tester) {
  final position = chatScroll(tester).position;
  return position.maxScrollExtent - position.pixels <= 48;
}

class _GatedChatService extends AiChatService {
  _GatedChatService({
    required super.db,
    required super.settings,
    required super.transport,
  });

  final chunks = StreamController<String>();
  final started = Completer<void>();

  void emit(String text) => chunks.add(text);

  @override
  Stream<String> streamSend({
    required String chatId,
    required String userText,
    List<AiContextItem> attachments = const [],
  }) {
    if (!started.isCompleted) started.complete();
    return chunks.stream;
  }
}
