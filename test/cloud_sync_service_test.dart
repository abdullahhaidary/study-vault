import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/cloud_account/cloud_api.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_schema.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_service.dart';

class PhoneSyncTestDatabase extends AppDatabase {
  PhoneSyncTestDatabase() : super.forTesting(NativeDatabase.memory());
}

class MemoryCloud implements CloudSyncRemote {
  MemoryCloud(this.schema);
  final CloudSyncSchema schema;
  CloudRows rows = {};
  final revisions = <String, int>{};
  final operations = <String, String>{};
  final blobs = <String, List<int>>{};
  int head = 0;
  int committed = 0;
  bool disconnectAfterCommit = false;
  bool corruptDownload = false;
  bool interruptDownload = false;
  bool raceBeforeCommit = false;
  int rateLimits = 0;
  Future<void> Function()? afterUpload;

  @override
  Future<CloudSnapshot> snapshot(String token) async => CloudSnapshot(
    head: head,
    rows: cloudRowsFromJson(jsonDecode(jsonEncode(rows))),
    revisions: Map.of(revisions),
  );

  @override
  Future<void> commit(String token, Map<String, dynamic> body) async {
    if (rateLimits > 0) {
      rateLimits--;
      throw const CloudApiException(
        'Rate limited',
        status: 429,
        retryAfter: Duration.zero,
      );
    }
    final id = body['operationId'] as String;
    if (operations.containsKey(id)) {
      expect(operations[id], cloudCanonical(body));
      return;
    }
    if (raceBeforeCommit) {
      raceBeforeCommit = false;
      head++;
    }
    if (body['expectedHead'] != head) {
      throw const CloudApiException(
        'Stale snapshot',
        status: 409,
        code: 'head_changed',
      );
    }
    final proposed = Map<String, Map<String, dynamic>>.from(rows);
    for (final m in body['mutations'] as List) {
      final key = cloudKey(m['table'] as String, m['id'] as String);
      expect(m['baseRevision'], revisions[key] ?? 0);
      if (m['data'] == null) {
        proposed.remove(key);
      } else {
        proposed[key] = Map<String, dynamic>.from(m['data'] as Map);
      }
    }
    schema.validate(proposed);
    rows = proposed;
    for (final m in body['mutations'] as List) {
      revisions[cloudKey(m['table'] as String, m['id'] as String)] = ++head;
    }
    operations[id] = cloudCanonical(body);
    committed++;
    if (disconnectAfterCommit) {
      disconnectAfterCommit = false;
      throw const CloudApiException('Connection lost after commit');
    }
  }

  @override
  Future<bool> hasFile(String token, String digest) async =>
      blobs.containsKey(digest);
  @override
  Future<void> uploadFile(String token, String digest, File file) async {
    final bytes = await file.readAsBytes();
    expect(sha256.convert(bytes).toString(), digest);
    blobs[digest] = bytes;
    await afterUpload?.call();
  }

  @override
  Future<void> downloadFile(
    String token,
    String digest,
    int bytes,
    File target,
  ) async {
    await target.parent.create(recursive: true);
    if (interruptDownload) {
      await target.writeAsBytes([1]);
      throw const CloudApiException('Disconnected while downloading');
    }
    await target.writeAsBytes(corruptDownload ? [1, 2, 3] : blobs[digest]!);
  }
}

void main() {
  late Directory temp;
  late AppDatabase a;
  late AppDatabase b;
  late MemoryCloud cloud;
  late CloudSyncService first;
  late CloudSyncService second;
  Future<void> sync(CloudSyncService service) async {
    final outcome = await service.sync(
      token: 'test-token',
      accountId: 'owner',
      consent: true,
    );
    expect(outcome.conflicts, isEmpty);
    expect(outcome.lastSync, isNotNull);
  }

  Future<void> seed(AppDatabase db) async {
    final now = DateTime(2026);
    await db.insertClass(
      ClassesCompanion.insert(
        id: 'class',
        name: 'Class',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 'subject',
        classId: 'class',
        name: 'Subject',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'lesson',
        subjectId: 'subject',
        name: 'Lesson',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> addNote(
    AppDatabase db,
    String id,
    String text,
  ) => db.customStatement(
    'INSERT INTO study_notes(id,lesson_id,title,content,sort_order,created_at,updated_at) VALUES(?,?,?,?,0,1,1)',
    [id, 'lesson', id, text],
  );
  Future<String> note(AppDatabase db, String id) async =>
      (await db
                  .customSelect(
                    'SELECT content FROM study_notes WHERE id=\'$id\'',
                  )
                  .getSingle())
              .data['content']
          as String;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('study-vault-sync-test-');
    a = AppDatabase.forTesting(NativeDatabase.memory());
    b = PhoneSyncTestDatabase();
    cloud = MemoryCloud(await CloudSyncSchema.load(a));
    first = CloudSyncService(
      db: a,
      remote: cloud,
      filesRoot: Directory(p.join(temp.path, 'a-files')),
      recoveryRoot: Directory(p.join(temp.path, 'a-recovery')),
      serverId: 'test-server',
    );
    second = CloudSyncService(
      db: b,
      remote: cloud,
      filesRoot: Directory(p.join(temp.path, 'b-files')),
      recoveryRoot: Directory(p.join(temp.path, 'b-recovery')),
      serverId: 'test-server',
    );
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await temp.delete(recursive: true);
  });

  test(
    'first sync needs consent and a library cannot switch accounts',
    () async {
      await seed(a);
      await expectLater(
        first.sync(token: 'test-token', accountId: 'owner'),
        throwsA(isA<CloudSyncFailure>()),
      );
      expect(cloud.rows, isEmpty);
      await sync(first);
      await expectLater(
        first.sync(token: 'other-token', accountId: 'other', consent: true),
        throwsA(isA<CloudSyncFailure>()),
      );
      expect((await first.info())['account'], 'test-server|owner');
    },
  );

  test(
    'initial upload and download preserve hierarchy and a recovery archive',
    () async {
      await seed(a);
      await addNote(a, 'n', 'Initial note');
      await sync(first);
      await sync(second);
      expect(await note(b, 'n'), 'Initial note');
      expect((await b.watchAllClasses().first).single.name, 'Class');
      expect(
        await File((await second.info())['backup_path'] as String).exists(),
        isTrue,
      );
      final writes = cloud.committed;
      await sync(second);
      expect(cloud.committed, writes);
    },
  );

  test(
    'independent offline changes on two devices merge without overwriting',
    () async {
      await seed(a);
      await sync(first);
      await sync(second);
      await addNote(a, 'left', 'Linux note');
      await addNote(b, 'right', 'Phone note');
      await sync(first);
      await sync(second);
      await sync(first);
      expect(await note(a, 'right'), 'Phone note');
      expect(await note(b, 'left'), 'Linux note');
    },
  );

  test(
    'same-note conflict pauses; a stale resolution token cannot overwrite newer edits',
    () async {
      await seed(a);
      await addNote(a, 'n', 'Base');
      await sync(first);
      await sync(second);
      await a.customStatement('UPDATE study_notes SET content=? WHERE id=?', [
        'Linux',
        'n',
      ]);
      await b.customStatement('UPDATE study_notes SET content=? WHERE id=?', [
        'Phone',
        'n',
      ]);
      await sync(first);
      final paused = await second.sync(token: 'test-token', accountId: 'owner');
      expect(paused.conflicts, hasLength(1));
      expect(await note(b, 'n'), 'Phone');
      await b.customStatement('UPDATE study_notes SET content=? WHERE id=?', [
        'New phone edit',
        'n',
      ]);
      final stale = await second.sync(
        token: 'test-token',
        accountId: 'owner',
        choice: CloudConflictChoice.device,
        resolutionToken: paused.resolutionToken,
      );
      expect(stale.conflicts, isNotEmpty);
      final resolved = await second.sync(
        token: 'test-token',
        accountId: 'owner',
        choice: CloudConflictChoice.device,
        resolutionToken: stale.resolutionToken,
      );
      expect(resolved.conflicts, isEmpty);
      await sync(first);
      expect(await note(a, 'n'), 'New phone edit');
    },
  );

  test(
    'parent deletion versus a new offline child offers recovery or deletion explicitly',
    () async {
      await seed(a);
      await sync(first);
      await sync(second);
      await addNote(b, 'offline', 'Keep this work');
      await a.customStatement('DELETE FROM lessons WHERE id=?', ['lesson']);
      await sync(first);
      final paused = await second.sync(token: 'test-token', accountId: 'owner');
      expect(paused.conflicts, isNotEmpty);
      await second.sync(
        token: 'test-token',
        accountId: 'owner',
        choice: CloudConflictChoice.device,
        resolutionToken: paused.resolutionToken,
      );
      await sync(first);
      expect(await note(a, 'offline'), 'Keep this work');
      expect(await a.getLessonById('lesson'), isNotNull);
    },
  );

  test(
    'an accepted commit with a lost response retries once after restart',
    () async {
      await seed(a);
      cloud.disconnectAfterCommit = true;
      await expectLater(sync(first), throwsA(isA<CloudApiException>()));
      expect((await first.info())['pending'], isNotNull);
      final writes = cloud.committed;
      final restarted = CloudSyncService(
        db: a,
        remote: cloud,
        filesRoot: first.filesRoot,
        recoveryRoot: first.recoveryRoot,
        serverId: 'test-server',
      );
      await sync(restarted);
      expect(cloud.committed, writes);
      expect((await restarted.info())['pending'], isNull);
      await sync(second);
      expect(await b.getLessonById('lesson'), isNotNull);
    },
  );

  test(
    'PDF bytes are downloaded before metadata, checksum failures leave the device unchanged',
    () async {
      await seed(a);
      final file = File(
        p.join(first.filesRoot.path, 'lessons/lesson/document.pdf'),
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('test PDF bytes');
      final now = DateTime(2026);
      await a.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'pdf',
          lessonId: 'lesson',
          title: 'PDF',
          originalFileName: 'document.pdf',
          storedFileName: 'document.pdf',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await sync(first);
      cloud.corruptDownload = true;
      await expectLater(sync(second), throwsA(isA<CloudSyncFailure>()));
      expect(await b.getLessonById('lesson'), isNull);
      cloud.corruptDownload = false;
      cloud.interruptDownload = true;
      await expectLater(sync(second), throwsA(isA<CloudApiException>()));
      expect(await b.getLessonById('lesson'), isNull);
      cloud.interruptDownload = false;
      await sync(second);
      final downloaded = File(
        p.join(second.filesRoot.path, 'lessons/lesson/document.pdf'),
      );
      expect(await downloaded.readAsString(), 'test PDF bytes');
      await downloaded.delete();
      await sync(second);
      expect(await downloaded.readAsString(), 'test PDF bytes');
    },
  );

  test(
    'a racing cloud commit leaves local data intact and can be retried',
    () async {
      await seed(a);
      cloud.raceBeforeCommit = true;
      await expectLater(sync(first), throwsA(isA<CloudApiException>()));
      expect(await a.getLessonById('lesson'), isNotNull);
      expect((await first.info())['pending'], isNull);
      expect(cloud.committed, 0);
      await sync(first);
      await sync(second);
      expect(await b.getLessonById('lesson'), isNotNull);
    },
  );

  test(
    'a local edit arriving during transfer is never overwritten or replayed as stale data',
    () async {
      await seed(a);
      final file = File(p.join(first.filesRoot.path, 'extra.pdf'));
      await file.parent.create(recursive: true);
      await file.writeAsString('Local file');
      cloud.afterUpload = () async {
        await a.customStatement('UPDATE classes SET name=? WHERE id=?', [
          'New local edit',
          'class',
        ]);
        cloud.afterUpload = null;
      };
      await expectLater(sync(first), throwsA(isA<CloudSyncFailure>()));
      expect(cloud.committed, 0);
      expect((await first.info())['pending'], isNull);
      expect((await a.watchAllClasses().first).single.name, 'New local edit');
      await sync(first);
      await sync(second);
      expect((await b.watchAllClasses().first).single.name, 'New local edit');
    },
  );

  test('symbolic links are rejected before uploads', () async {
    await first.filesRoot.create(recursive: true);
    final external = File(p.join(temp.path, 'external.txt'));
    await external.writeAsString('Do not upload');
    await Link(p.join(first.filesRoot.path, 'unsafe')).create(external.path);
    await expectLater(sync(first), throwsA(isA<CloudSyncFailure>()));
    expect(cloud.blobs, isEmpty);
    expect(cloud.rows, isEmpty);
  });

  test(
    'rate limits retry the same operation without duplicate records',
    () async {
      await seed(a);
      cloud.rateLimits = 2;
      await sync(first);
      expect(cloud.committed, 1);
      expect(cloud.rateLimits, 0);
      expect((await first.info())['pending'], isNull);
    },
  );

  test('offline deletion propagates while unrelated data remains', () async {
    await seed(a);
    await addNote(a, 'remove', 'Delete later');
    await addNote(a, 'keep', 'Keep');
    await sync(first);
    await sync(second);
    await a.customStatement('DELETE FROM study_notes WHERE id=?', ['remove']);
    await sync(first);
    await sync(second);
    expect(
      await b
          .customSelect("SELECT id FROM study_notes WHERE id='remove'")
          .get(),
      isEmpty,
    );
    expect(await note(b, 'keep'), 'Keep');
  });
}
