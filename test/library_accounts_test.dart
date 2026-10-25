import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/core/storage/study_vault_paths.dart';
import 'package:study_vault/core/widgets/desktop_frame.dart';
import 'package:study_vault/features/ai_generation_queue/data/ai_generation_providers.dart';
import 'package:study_vault/features/ai_generation_queue/domain/ai_generation_models.dart';
import 'package:study_vault/features/cloud_account/cloud_account_provider.dart';
import 'package:study_vault/features/cloud_account/cloud_api.dart';
import 'package:study_vault/features/library_accounts/data/library_account_store.dart';
import 'package:study_vault/features/library_accounts/data/library_accounts_controller.dart';
import 'package:study_vault/features/library_accounts/domain/library_account.dart';
import 'package:study_vault/features/library_accounts/presentation/account_switcher.dart';
import 'package:study_vault/features/library_accounts/presentation/library_accounts_root.dart';

import 'cloud_account_test.dart' show MemorySessionStore;

final _counterProvider = StateProvider<int>((ref) => 0);

void main() {
  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('sv_accounts_');
  });

  tearDown(() async {
    StudyVaultPaths.useLibraryRoot(null);
    await documents.delete(recursive: true);
  });

  test('a fresh device has only the default account in documents', () async {
    final controller = await LibraryAccountsController.open(
      FileLibraryAccountStore(documents),
    );
    addTearDown(controller.dispose);
    expect(controller.accounts.map((a) => a.name), [
      LibraryAccount.defaultName,
    ]);
    expect(controller.active.isDefault, isTrue);
    expect(
      FileLibraryAccountStore(documents).libraryRoot(controller.active),
      isNull,
    );
  });

  test('accounts, names, and the open account survive a restart', () async {
    final store = FileLibraryAccountStore(documents);
    final controller = await LibraryAccountsController.open(store);
    addTearDown(controller.dispose);
    final work = await controller.add('  Work ');
    final sara = await controller.add('Sara');
    await controller.rename(LibraryAccount.defaultId, 'University');
    await controller.switchTo(work.id);

    expect(work.name, 'Work');
    expect(work.colorIndex, isNot(sara.colorIndex));
    final libraryRoot = p.join(documents.path, 'study_vault_accounts', work.id);
    expect(
      (await StudyVaultPaths.databaseFile()).path,
      p.join(libraryRoot, StudyVaultPaths.databaseFileName),
    );
    expect(
      (await StudyVaultPaths.materialsDirectory()).path,
      p.join(libraryRoot, StudyVaultPaths.materialsDirName),
    );

    StudyVaultPaths.useLibraryRoot(null);
    final reopened = await LibraryAccountsController.open(
      FileLibraryAccountStore(documents),
    );
    addTearDown(reopened.dispose);
    expect(reopened.accounts.map((a) => a.name), [
      'University',
      'Work',
      'Sara',
    ]);
    expect(reopened.active.id, work.id);
    expect((await StudyVaultPaths.libraryDirectory()).path, libraryRoot);
  });

  test('names are validated and duplicates are rejected', () async {
    final controller = LibraryAccountsController.memory();
    addTearDown(controller.dispose);
    await controller.add('Work');
    for (final name in ['', '   ', 'work', 'x' * 41]) {
      await expectLater(
        controller.add(name),
        throwsA(isA<LibraryAccountException>()),
      );
    }
    expect(controller.accounts, hasLength(2));
  });

  test('removal deletes only an inactive non-default library', () async {
    final store = FileLibraryAccountStore(documents);
    final controller = await LibraryAccountsController.open(store);
    addTearDown(controller.dispose);
    final work = await controller.add('Work');
    final folder = store.libraryRoot(work)!;
    await File(p.join(folder.path, 'study_vault.sqlite')).writeAsString('db');

    await controller.switchTo(work.id);
    await expectLater(
      controller.remove(work.id),
      throwsA(isA<LibraryAccountException>()),
    );
    await expectLater(
      controller.remove(LibraryAccount.defaultId),
      throwsA(isA<LibraryAccountException>()),
    );
    await controller.switchTo(LibraryAccount.defaultId);
    await controller.remove(work.id);
    expect(await folder.exists(), isFalse);
    expect(controller.accounts, hasLength(1));
  });

  test('a damaged account file hides only that account', () async {
    final store = FileLibraryAccountStore(documents);
    final controller = await LibraryAccountsController.open(store);
    addTearDown(controller.dispose);
    final work = await controller.add('Work');
    final home = await controller.add('Home');
    await controller.switchTo(home.id);
    await File(
      p.join(store.libraryRoot(work)!.path, 'account.json'),
    ).writeAsString('{not json');
    await Directory(p.join(store.root.path, 'not-an-account')).create();

    final reloaded = await store.load();
    expect(reloaded.accounts.map((a) => a.name), ['Personal', 'Home']);
    expect(reloaded.activeId, home.id);
  });

  testWidgets('switching rebuilds a fresh provider scope for the account', (
    tester,
  ) async {
    final controller = LibraryAccountsController.memory();
    addTearDown(controller.dispose);
    final work = await tester.runAsync(() => controller.add('Work'));

    await tester.pumpWidget(
      LibraryAccountsRoot(
        controller: controller,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Text(
              '${ref.watch(activeLibraryAccountProvider).name}: '
              '${ref.watch(_counterProvider)}',
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.textContaining('Personal')),
    );
    container.read(_counterProvider.notifier).state = 5;
    await tester.pump();
    expect(find.text('Personal: 5'), findsOneWidget);

    await tester.runAsync(() => controller.switchTo(work!.id));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump();
    expect(find.text('Work: 0'), findsOneWidget);
  });

  testWidgets('one tap on an account in the switcher opens it', (tester) async {
    final controller = LibraryAccountsController.memory();
    addTearDown(controller.dispose);
    final work = await tester.runAsync(() => controller.add('Work'));
    final api = CloudApi(
      client: MockClient((_) async => http.Response('', 500)),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryAccountsControllerProvider.overrideWithValue(controller),
          cloudAccountProvider.overrideWith(
            (ref) => CloudAccountController(api, MemorySessionStore()),
          ),
          generationQueueSnapshotProvider.overrideWithValue(
            const GenerationQueueSnapshot(
              running: 0,
              queued: 0,
              completed: 0,
              attention: 0,
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: [appRouteObserver],
          home: Scaffold(
            appBar: AppBar(actions: const [AccountSwitcherButton()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('P'), findsOneWidget);

    await tester.tap(find.byType(AccountSwitcherButton));
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.runAsync(() async {
      await Future.doWhile(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return controller.active.id != work!.id;
      }).timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    expect(controller.active.name, 'Work');
    expect(find.text('W'), findsOneWidget);
  });
}
