import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/cloud_account/cloud_api.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_service.dart';

class LocalTestTransport extends http.BaseClient {
  LocalTestTransport(this.origin);
  final Uri origin;
  final http.Client inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final outgoing =
        http.StreamedRequest(
            request.method,
            origin.replace(
              path: request.url.path,
              query: request.url.hasQuery ? request.url.query : null,
            ),
          )
          ..headers.addAll(request.headers)
          ..contentLength = request.contentLength
          ..followRedirects = false;
    final result = await Future.wait<Object?>([
      inner.send(outgoing),
      request.finalize().pipe(outgoing.sink),
    ]);
    return result.first as http.StreamedResponse;
  }

  @override
  void close() => inner.close();
}

class PhoneHttpTestDatabase extends AppDatabase {
  PhoneHttpTestDatabase() : super.forTesting(NativeDatabase.memory());
}

void main() {
  test(
    'Dart client and real PostgreSQL API synchronize two libraries and PDF bytes',
    () async {
      final username = 'flutter-${const Uuid().v4()}';
      final process = await Process.start(
        'node',
        ['sync-server/test/flutter-server.js'],
        environment: {
          'TEST_DATABASE_URL': Platform.environment['TEST_DATABASE_URL']!,
          'TEST_USERNAME': username,
        },
      );
      final errors = process.stderr.drain<void>();
      addTearDown(() async {
        process.kill();
        await process.exitCode;
        await errors;
      });
      final line = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 20));
      expect(line, startsWith('READY:'));
      final api = CloudApi(
        client: LocalTestTransport(
          Uri.parse('http://127.0.0.1:${line.substring(6)}'),
        ),
      );
      addTearDown(api.close);
      final session = await api.login(
        username: username,
        password: 'integration-test-only-password',
        deviceName: 'Integration test',
      );
      final temp = await Directory.systemTemp.createTemp('sv-http-client-');
      addTearDown(() => temp.delete(recursive: true));
      final a = AppDatabase.forTesting(NativeDatabase.memory());
      final b = PhoneHttpTestDatabase();
      addTearDown(a.close);
      addTearDown(b.close);
      final first = CloudSyncService(
        db: a,
        remote: api,
        filesRoot: Directory(p.join(temp.path, 'first-files')),
        recoveryRoot: Directory(p.join(temp.path, 'first-backups')),
        serverId: 'integration',
      );
      final second = CloudSyncService(
        db: b,
        remote: api,
        filesRoot: Directory(p.join(temp.path, 'second-files')),
        recoveryRoot: Directory(p.join(temp.path, 'second-backups')),
        serverId: 'integration',
      );
      final now = DateTime(2026);
      await a.insertClass(
        ClassesCompanion.insert(
          id: 'c',
          name: 'فارسی Class',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await a.insertSubject(
        SubjectsCompanion.insert(
          id: 's',
          classId: 'c',
          name: 'Subject',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await a.insertLesson(
        LessonsCompanion.insert(
          id: 'l',
          subjectId: 's',
          name: 'Lesson',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await a.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'p',
          lessonId: 'l',
          title: 'PDF',
          originalFileName: 'test.pdf',
          storedFileName: 'test.pdf',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final pdf = File(p.join(first.filesRoot.path, 'lessons/l/test.pdf'));
      await pdf.parent.create(recursive: true);
      final data = List.generate(256 * 1024, (i) => i % 256);
      await pdf.writeAsBytes(data);
      await a.insertStudyPin(
        StudyPinsCompanion.insert(
          id: 'pin',
          resourceId: 'p',
          xRatio: 0.0,
          yRatio: 0.125,
          shortText: 'Test pin',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await a.insertCourseReviewVersion(
        id: 'review-section',
        subjectId: 's',
        materialId: 'p',
        part: 'summary',
        content: '- Review point',
        sourceFingerprint: 'pdf:p:test.pdf',
      );
      await a.insertCourseReviewVersion(
        id: 'review-examples',
        subjectId: 's',
        materialId: null,
        part: 'examples',
        content: '### Example 1',
      );
      await a.setCourseReviewExcluded(
        id: 'review-exclusion',
        subjectId: 's',
        materialId: 'p',
        excluded: true,
      );
      final uploaded = await first.sync(
        token: session.token,
        accountId: session.accountId,
        consent: true,
      );
      expect(uploaded.conflicts, isEmpty);
      final downloaded = await second.sync(
        token: session.token,
        accountId: session.accountId,
        consent: true,
      );
      expect(downloaded.conflicts, isEmpty);
      expect((await b.watchAllClasses().first).single.name, 'فارسی Class');
      expect((await b.getStudyPinById('pin'))!.xRatio, 0.0);
      final review = await b.courseReviewEntriesForSubject('s');
      expect(review.map((e) => e.id).toSet(), {
        'review-section',
        'review-examples',
      });
      expect(
        review.firstWhere((e) => e.id == 'review-examples').materialId,
        isNull,
      );
      expect(await b.courseReviewExclusionsForSubject('s'), hasLength(1));
      expect(
        await File(
          p.join(second.filesRoot.path, 'lessons/l/test.pdf'),
        ).readAsBytes(),
        data,
      );
      await b.customStatement('UPDATE classes SET name=? WHERE id=?', [
        'Phone edit',
        'c',
      ]);
      await second.sync(token: session.token, accountId: session.accountId);
      await first.sync(token: session.token, accountId: session.accountId);
      expect((await a.watchAllClasses().first).single.name, 'Phone edit');
    },
    skip: Platform.environment['TEST_DATABASE_URL'] == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
