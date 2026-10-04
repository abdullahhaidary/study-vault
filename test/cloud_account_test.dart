import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_vault/features/cloud_account/cloud_account_provider.dart';
import 'package:study_vault/features/cloud_account/cloud_account_section.dart';
import 'package:study_vault/features/cloud_account/cloud_api.dart';

CloudSession session() => CloudSession(
  token: List.filled(43, 'A').join(),
  accountId: 'test-account',
  username: 'test-user',
  expiresAt: DateTime.now().add(const Duration(days: 1)),
);

class MemorySessionStore implements CloudSessionStore {
  CloudSession? value;
  bool failWrite = false;
  bool failClear = false;

  @override
  Future<CloudSession?> read() async => value;
  @override
  Future<void> write(CloudSession session) async {
    if (failWrite) throw StateError('Locked');
    value = session;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('Locked');
    value = null;
  }
}

void main() {
  test(
    'login uses HTTPS, blocks redirects, and does not put credentials in the URL',
    () async {
      final api = CloudApi(
        client: MockClient((request) async {
          expect(request.url, CloudApi.origin.resolve('/v1/login'));
          expect(request.url.scheme, 'https');
          expect(request.url.query, isEmpty);
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'username': 'test-user',
            'password': 'test-only-password',
            'deviceName': 'Linux',
          });
          return http.Response(jsonEncode(session().toJson()), 200);
        }),
      );
      addTearDown(api.close);
      final result = await api.login(
        username: ' test-user ',
        password: 'test-only-password',
        deviceName: 'Linux',
      );
      expect(result.username, 'test-user');
      expect(CloudSession.fromJson(result.toJson()).token, result.token);
    },
  );

  test(
    'authorization is sent only as a header and logout accepts 204',
    () async {
      final current = session();
      final api = CloudApi(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer ${current.token}');
          expect(request.url.toString(), isNot(contains(current.token)));
          if (request.url.path.endsWith('/logout')) {
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode({
              'account': {'id': current.accountId},
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await api.verify(current);
      await api.logout(current);
    },
  );

  test('errors do not echo server bodies and redirects are rejected', () async {
    for (final status in [401, 429, 302, 500]) {
      final api = CloudApi(
        client: MockClient(
          (_) async => http.Response('sensitive-server-body', status),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.verify(session()),
        throwsA(
          isA<CloudApiException>()
              .having((e) => e.status, 'status', status)
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('sensitive-server-body')),
              ),
        ),
      );
    }
  });

  test(
    'invalid tokens, oversized responses, and expired sessions are rejected',
    () async {
      expect(
        () => CloudSession.fromJson({'token': 'invalid'}),
        throwsA(isA<CloudApiException>()),
      );
      final oversized = CloudApi(
        client: MockClient((_) async => http.Response('x' * 65537, 200)),
      );
      addTearDown(oversized.close);
      await expectLater(
        oversized.verify(session()),
        throwsA(isA<CloudApiException>()),
      );
      final expired = session().toJson()
        ..['expiresAt'] = DateTime(2020).toIso8601String();
      final api = CloudApi(
        client: MockClient(
          (_) async => http.Response(jsonEncode(expired), 200),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.login(
          username: 'test',
          password: 'test-only-password',
          deviceName: 'test',
        ),
        throwsA(isA<CloudApiException>()),
      );
    },
  );

  test('login stores a session securely and sign out clears it', () async {
    final store = MemorySessionStore();
    final api = CloudApi(
      client: MockClient(
        (request) async => request.url.path.endsWith('/login')
            ? http.Response(jsonEncode(session().toJson()), 200)
            : http.Response('', 204),
      ),
    );
    final controller = CloudAccountController(api, store);
    addTearDown(controller.dispose);
    addTearDown(api.close);
    await Future<void>.delayed(Duration.zero);
    expect(await controller.signIn('test-user', 'test-only-password'), isTrue);
    expect(store.value, isNotNull);
    expect(controller.state.username, 'test-user');
    expect(controller.state.message, contains('not enabled yet'));
    await controller.signOut();
    expect(store.value, isNull);
    expect(controller.state.username, isNull);
  });

  test(
    'secure-storage failure revokes the newly created server session',
    () async {
      final store = MemorySessionStore()..failWrite = true;
      var revoked = false;
      final api = CloudApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/logout')) {
            revoked = true;
            return http.Response('', 204);
          }
          return http.Response(jsonEncode(session().toJson()), 200);
        }),
      );
      final controller = CloudAccountController(api, store);
      addTearDown(controller.dispose);
      addTearDown(api.close);
      await Future<void>.delayed(Duration.zero);
      expect(
        await controller.signIn('test-user', 'test-only-password'),
        isFalse,
      );
      expect(revoked, isTrue);
      expect(store.value, isNull);
      expect(controller.state.username, isNull);
    },
  );

  test(
    'expired server sessions are cleared but network failures preserve login',
    () async {
      final store = MemorySessionStore()..value = session();
      var status = 500;
      final api = CloudApi(
        client: MockClient((_) async => http.Response('', status)),
      );
      final controller = CloudAccountController(api, store);
      addTearDown(controller.dispose);
      addTearDown(api.close);
      await Future<void>.delayed(Duration.zero);
      await controller.checkConnection();
      expect(store.value, isNotNull);
      status = 401;
      await controller.checkConnection();
      expect(store.value, isNull);
      expect(controller.state.username, isNull);
    },
  );

  testWidgets('settings clearly distinguish account login from library sync', (
    tester,
  ) async {
    final store = MemorySessionStore();
    final api = CloudApi(
      client: MockClient(
        (_) async => http.Response(jsonEncode(session().toJson()), 200),
      ),
    );
    addTearDown(api.close);
    final controller = CloudAccountController(api, store);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cloudAccountProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CloudAccountSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('does not upload'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'test-user');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'test-only-password',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Sign in'));
      await Future.doWhile(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return controller.state.busy;
      }).timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    expect(find.text('Signed in as test-user'), findsOneWidget);
    expect(find.text('Check connection'), findsOneWidget);
  });
}
