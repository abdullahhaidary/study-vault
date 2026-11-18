import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/storage/study_vault_paths.dart';
import 'package:study_vault/features/agent_bridge/agent_bridge_server.dart';
import 'package:study_vault/features/agent_bridge/agent_bridge_controller.dart';
import 'package:study_vault/features/agent_bridge/agent_library_tools.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_schema.dart';
import 'package:study_vault/features/study_pins/domain/study_note_codec.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory temp;
  late AgentLibraryTools tools;
  late AgentBridgeServer bridge;
  late HttpClient client;

  Future<(int, dynamic)> request(
    String path, {
    Object? data,
    String? token,
    String? origin,
    String? host,
    List<int>? bytes,
  }) async {
    final req = await client.openUrl(
      data != null || bytes != null ? 'POST' : 'GET',
      Uri.parse('${bridge.url}$path'),
    );
    req.headers.set('Authorization', 'Bearer ${token ?? bridge.token}');
    if (origin != null) req.headers.set('Origin', origin);
    if (host != null) req.headers.set('Host', host);
    if (bytes != null) {
      req.contentLength = bytes.length;
      req.add(bytes);
    }
    if (data != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(data));
    }
    final response = await req.close();
    final text = await utf8.decodeStream(response);
    return (response.statusCode, jsonDecode(text));
  }

  Future<(int, dynamic)> remote(
    String name,
    Map<String, dynamic> args, {
    String id = 'r1',
  }) => request(
    '/call',
    data: {'name': name, 'arguments': args, 'request_id': id},
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sv_agent_test_');
    StudyVaultPaths.useLibraryRoot(temp);
    final files = await StudyVaultPaths.materialsDirectory();
    await files.create();
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
        name: 'Physics',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertSubject(
      SubjectsCompanion.insert(
        id: 's2',
        classId: 'c',
        name: 'Math',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'l',
        subjectId: 's',
        name: 'Motion',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLesson(
      LessonsCompanion.insert(
        id: 'l2',
        subjectId: 's2',
        name: 'Algebra',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: 'm',
        lessonId: 'l',
        title: 'Lecture',
        originalFileName: 'lecture.pdf',
        storedFileName: 'lecture.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
    tools = AgentLibraryTools(db, files);
    bridge = AgentBridgeServer(
      tools,
      clientSource: await File('tool/study_vault_termux_mcp.py').readAsString(),
    );
    client = HttpOverrides.runWithHttpOverrides(
      () => HttpClient(),
      _RealHttpOverrides(),
    )..findProxy = (_) => 'DIRECT';
  });

  tearDown(() async {
    await bridge.stop();
    client.close(force: true);
    await db.close();
    StudyVaultPaths.useLibraryRoot(null);
    await temp.delete(recursive: true);
  });

  test(
    'tool definitions are unique, bounded and have no SQL or delete tools',
    () {
      final definitions = AgentLibraryTools.definitions;
      expect(definitions.length, 19);
      expect(definitions.map((t) => t['name']).toSet().length, 19);
      for (final tool in definitions) {
        expect(tool['name'], isNot(contains('delete')));
        expect((tool['inputSchema'] as Map)['additionalProperties'], false);
      }
    },
  );

  test('notes preview first, encode rich text and enforce one owner', () async {
    final a = {
      'lesson_id': 'l',
      'title': 'Newton',
      'markdown': '# Force\n\n**Mass** matters.',
    };
    expect((await tools.call('add_note', a) as Map)['saved'], false);
    expect(await db.select(db.studyNotes).get(), isEmpty);
    await tools.call('add_note', {...a, 'apply': true});
    final row = await db.select(db.studyNotes).getSingle();
    expect(StudyNoteCodec.isRichDeltaJson(row.content), true);
    expect(row.plainTextContent, contains('Mass'));
    await expectLater(
      tools.call('add_note', {...a, 'subject_id': 's', 'apply': true}),
      throwsFormatException,
    );
    expect(await db.select(db.studyNotes).get(), hasLength(1));
  });

  test(
    'lesson creation uses sort order and immediately updates Drift streams',
    () async {
      final stream = db.select(db.lessons).watch();
      expect(await stream.first, hasLength(2));
      await tools.call('add_lesson', {
        'subject_id': 's',
        'name': 'Momentum',
        'apply': true,
      });
      final lessons = await stream.first;
      expect(lessons, hasLength(3));
      expect(lessons.singleWhere((l) => l.name == 'Momentum').sortOrder, 1);
    },
  );

  test(
    'flashcards skip duplicate fronts, invalid batches save nothing',
    () async {
      final a = {
        'lesson_id': 'l',
        'cards': [
          {'front': 'Force?', 'back': '**ma**'},
          {'front': 'force?', 'back': 'Duplicate'},
        ],
        'apply': true,
      };
      expect((await tools.call('add_flashcards', a) as Map)['added'], 1);
      expect((await tools.call('add_flashcards', a) as Map)['added'], 0);
      await expectLater(
        tools.call('add_flashcards', {
          'lesson_id': 'l',
          'cards': [
            {'front': 'New', 'back': 'OK'},
            {'front': '', 'back': 'Invalid'},
          ],
          'apply': true,
        }),
        throwsFormatException,
      );
      expect(await db.select(db.flashcards).get(), hasLength(1));
    },
  );

  test(
    'quiz validates ownership and answers atomically, then stores options',
    () async {
      final a = {
        'lesson_id': 'l',
        'material_id': 'm',
        'title': 'Quiz',
        'apply': true,
        'questions': [
          {
            'type': 'mcq',
            'question': 'Unit of force?',
            'correct_answer': '1',
            'options': ['Metre', 'Newton'],
          },
          {
            'type': 'true_false',
            'question': 'Mass is force.',
            'correct_answer': 'false',
          },
        ],
      };
      await expectLater(
        tools.call('add_quiz', {...a, 'lesson_id': 'l2'}),
        throwsFormatException,
      );
      await expectLater(
        tools.call('add_quiz', {
          ...a,
          'questions': [
            {
              'type': 'mcq',
              'question': '?',
              'correct_answer': '4',
              'options': ['a', 'b'],
            },
          ],
        }),
        throwsFormatException,
      );
      expect(await db.select(db.questionSets).get(), isEmpty);
      await tools.call('add_quiz', a);
      expect(await db.select(db.quizQuestions).get(), hasLength(2));
      final options = await db.select(db.quizQuestionOptions).get();
      expect(
        options.where((o) => o.isCorrect).map((o) => o.optionText),
        containsAll(['Newton', 'False']),
      );
    },
  );

  test('generated materials and Course Review append valid versions', () async {
    for (var i = 0; i < 2; i++) {
      await tools.call('add_study_material', {
        'material_id': 'm',
        'type': 'summary',
        'markdown': 'Motion $i',
        'apply': true,
      });
      await tools.call('set_course_review_document', {
        'subject_id': 's',
        'markdown': '# Review $i',
        'apply': true,
      });
    }
    expect((await db.select(db.pdfAiMaterials).get()).map((r) => r.version), [
      1,
      2,
    ]);
    final reviews = await db.select(db.courseReviewEntries).get();
    expect(reviews.map((r) => r.version), [1, 2]);
    expect(
      reviews.every(
        (r) =>
            r.part == 'document' &&
            r.materialId == null &&
            r.sourceFingerprint != null,
      ),
      true,
    );
    final schema = await CloudSyncSchema.load(db);
    for (final table in ['pdf_ai_materials', 'course_review_entries']) {
      for (final row in await db.customSelect('SELECT * FROM $table').get()) {
        expect(
          () => schema.validateRow('$table/${row.data['id']}', row.data),
          returnsNormally,
        );
      }
    }
  });

  test(
    'scoped search returns indexed file contents and excludes other subjects',
    () async {
      final dir = Directory(p.join(tools.filesRoot.path, 'lessons', 'l'));
      await dir.create(recursive: true);
      await File(
        p.join(dir.path, 'motion.md'),
      ).writeAsString('Inertia keeps an object moving.');
      final now = DateTime.now();
      await db.insertLessonMaterial(
        LessonMaterialsCompanion.insert(
          id: 'md',
          lessonId: 'l',
          title: 'Notes',
          originalFileName: 'motion.md',
          storedFileName: 'motion.md',
          mimeType: const Value('text/markdown'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final hits =
          await tools.call('search_library', {
                'query': 'Inertia',
                'subject_id': 's',
                'index_files': true,
              })
              as List;
      expect(hits, isNotEmpty);
      expect(hits.any((h) => (h as Map)['material_id'] == 'md'), true);
      expect(
        await tools.call('search_library', {
          'query': 'Inertia',
          'subject_id': 's2',
        }),
        isEmpty,
      );
    },
  );

  test(
    'file lookup blocks traversal and symlinks outside the library',
    () async {
      await (db.update(
        db.lessonMaterials,
      )..where((t) => t.id.equals('m'))).write(
        const LessonMaterialsCompanion(storedFileName: Value('../secret.pdf')),
      );
      await expectLater(
        tools.fileFor({'material_id': 'm'}),
        throwsFormatException,
      );
      await (db.update(
        db.lessonMaterials,
      )..where((t) => t.id.equals('m'))).write(
        const LessonMaterialsCompanion(storedFileName: Value('lecture.pdf')),
      );
      final dir = Directory(p.join(tools.filesRoot.path, 'lessons', 'l'));
      await dir.create(recursive: true);
      final outside = await File(
        p.join(temp.path, 'secret'),
      ).writeAsString('private');
      await Link(p.join(dir.path, 'lecture.pdf')).create(outside.path);
      await expectLater(
        tools.fileFor({'material_id': 'm'}),
        throwsFormatException,
      );
    },
  );

  test(
    'HTTP requires token, rejects browser origins and untrusted hostnames',
    () async {
      await bridge.start();
      expect((await request('/tools', token: 'wrong')).$1, 401);
      expect((await request('/tools', origin: 'https://example.com')).$1, 401);
      expect((await request('/tools', host: 'example.com')).$1, 401);
      expect((await request('/tools')).$1, 200);
      expect((await request('/database')).$1, 404);
    },
  );

  test(
    'read-only sessions preview writes but refuse commits and uploads',
    () async {
      await bridge.start();
      final a = {'subject_id': 's', 'name': 'New'};
      expect((await remote('add_lesson', a)).$1, 200);
      expect(
        (await remote('add_lesson', {...a, 'apply': true}, id: 'write')).$1,
        400,
      );
      expect((await request('/upload', bytes: [1, 2, 3])).$1, 400);
      expect(await db.select(db.lessons).get(), hasLength(2));
    },
  );

  test(
    'session request IDs prevent duplicate writes and reject changed bodies',
    () async {
      await bridge.start(writes: true);
      final args = {'subject_id': 's', 'name': 'New', 'apply': true};
      final first = await remote('add_lesson', args);
      expect(first.$1, 200);
      expect((await remote('add_lesson', args)).$2, first.$2);
      expect(await db.select(db.lessons).get(), hasLength(3));
      expect(
        (await remote('add_lesson', {...args, 'name': 'Different'})).$1,
        400,
      );
    },
  );

  test('stop revokes old credentials and restart rotates them', () async {
    await bridge.start();
    final old = bridge.token;
    await bridge.stop();
    expect(bridge.token, isNull);
    await bridge.start();
    expect(bridge.token, isNot(old));
    expect((await request('/tools', token: old)).$1, 401);
  });

  test(
    'book item scopes match native readers and chapters stay in their book',
    () async {
      final now = DateTime.now();
      await db
          .into(db.referenceBooks)
          .insert(
            ReferenceBooksCompanion.insert(
              id: 'book',
              title: 'Physics',
              originalFileName: 'b.pdf',
              storedFileName: 'b.pdf',
              pageCount: 20,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.referenceBookChapters)
          .insert(
            ReferenceBookChaptersCompanion.insert(
              id: 'chapter',
              bookId: 'book',
              title: 'Mechanics',
              sortOrder: 0,
              startPage: 1,
              endPage: 10,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final a = {
        'book_id': 'book',
        'chapter_id': 'chapter',
        'kind': 'summary',
        'markdown': 'Mechanics',
        'apply': true,
      };
      await tools.call('add_book_item', a);
      await tools.call('add_book_item', a);
      final items = await db.select(db.referenceBookAiItems).get();
      expect(items.map((i) => i.scopeKey).toSet(), {'chapter'});
      expect(items.map((i) => i.version), [1, 2]);
      await tools.call('set_chapter_status', {
        'chapter_id': 'chapter',
        'status': 'done',
        'apply': true,
      });
      expect(
        (await db.select(db.referenceBookChapters).getSingle()).status,
        'done',
      );
    },
  );

  test(
    'real Python MCP adapter lists tools, previews, uploads, reads and downloads',
    () async {
      await bridge.start(writes: true);
      final process = await Process.start(
        'python3',
        ['tool/study_vault_termux_mcp.py'],
        environment: {
          'STUDY_VAULT_BRIDGE_URL': bridge.url,
          'STUDY_VAULT_BRIDGE_TOKEN': bridge.token!,
          'STUDY_VAULT_DOWNLOAD_DIR': p.join(temp.path, 'downloads'),
        },
      );
      final errors = process.stderr.transform(utf8.decoder).join();
      final replies = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );
      var id = 0;
      Future<Map> rpc(String method, [Map? params]) async {
        process.stdin.writeln(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': ++id,
            'method': method,
            'params': params,
          }),
        );
        expect(
          await replies.moveNext().timeout(const Duration(seconds: 20)),
          true,
        );
        return jsonDecode(replies.current) as Map;
      }

      Future<Map> call(String name, Map args) async {
        final response = await rpc('tools/call', {
          'name': name,
          'arguments': args,
        });
        final result = response['result'] as Map;
        expect(result['isError'], isNot(true), reason: result.toString());
        return jsonDecode(
              ((result['content'] as List).single as Map)['text'] as String,
            )
            as Map;
      }

      try {
        expect(
          (await rpc('initialize', {
            'protocolVersion': '2025-06-18',
          }))['result']['serverInfo']['name'],
          'study-vault-mobile',
        );
        expect((await rpc('tools/list'))['result']['tools'], hasLength(19));
        final source = await File(
          p.join(temp.path, 'motion.md'),
        ).writeAsString('# Momentum\nPreserve inertia.');
        final a = {'lesson_id': 'l', 'path': source.path};
        expect((await call('attach_file', a))['saved'], false);
        final saved = await call('attach_file', {...a, 'apply': true});
        final material = await (db.select(
          db.lessonMaterials,
        )..where((t) => t.id.equals(saved['id'] as String))).getSingle();
        expect(material.mimeType, 'text/markdown');
        final download = await call('get_file', {'material_id': material.id});
        final target = File(download['path'] as String);
        expect(await target.readAsString(), await source.readAsString());
        expect(p.isWithin(temp.path, target.path), true);
        await call('add_note', {
          'lesson_id': 'l',
          'title': 'Agent note',
          'markdown': '**Momentum**',
          'apply': true,
        });
        expect(await db.select(db.studyNotes).get(), hasLength(1));
      } finally {
        await process.stdin.close();
        expect(await process.exitCode.timeout(const Duration(seconds: 5)), 0);
        await replies.cancel();
        expect(await errors, isEmpty);
      }
    },
  );

  test(
    'session-configured adapter is served privately and can be compiled',
    () async {
      await bridge.start();
      final req = await client.getUrl(Uri.parse('${bridge.url}/client.py'));
      req.headers.set('Authorization', 'Bearer ${bridge.token}');
      final response = await req.close();
      expect(response.statusCode, 200);
      final source = await utf8.decodeStream(response);
      expect(source, contains('DEFAULT_URL = "${bridge.url}"'));
      expect(source, contains('DEFAULT_TOKEN = "${bridge.token}"'));
      final file = await File(
        p.join(temp.path, 'adapter.py'),
      ).writeAsString(source);
      final check = await Process.run('python3', [
        '-m',
        'py_compile',
        file.path,
      ]);
      expect(check.exitCode, 0, reason: check.stderr.toString());
    },
  );

  test('adapter is bundled for installation without internet', () async {
    expect(
      await rootBundle.loadString('tool/study_vault_termux_mcp.py'),
      contains('class BridgeError'),
    );
  });
  test('stopping during startup cancels the pending bridge', () async {
    final controller = AgentBridgeController(db);
    final starting = controller.start(true);
    await controller.stop();
    await starting;
    expect(controller.running, false);
    controller.shutdown();
    controller.dispose();
  });

  test('account shutdown immediately revokes the active session', () async {
    final controller = AgentBridgeController(db);
    await controller.start(true);
    expect(controller.running, true);
    final active = controller.server!;
    controller.shutdown();
    expect(active.token, isNull);
    controller.dispose();
    await active.stop();
  });

  test('session lifetime expires without retaining its credential', () async {
    await bridge.start(lifetime: const Duration(milliseconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(bridge.running, false);
    expect(bridge.token, isNull);
  });
}
