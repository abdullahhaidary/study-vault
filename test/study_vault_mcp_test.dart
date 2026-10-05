import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_schema.dart';
import 'package:study_vault/features/course_review/data/course_review_repository.dart';
import 'package:study_vault/features/course_review/domain/course_review_models.dart';
import 'package:study_vault/features/study_pins/domain/study_note_codec.dart';

/// Drives tool/study_vault_mcp.py over stdio like Devin does.
class _Mcp {
  _Mcp(this._process) {
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _replies.add(jsonDecode(line) as Map));
  }

  final Process _process;
  final _replies = StreamController<Map>.broadcast();
  var _id = 0;

  static Future<_Mcp> start(String dbPath) async => _Mcp(
    await Process.start(
      'python3',
      ['tool/study_vault_mcp.py'],
      environment: {'STUDY_VAULT_DB': dbPath},
    ),
  );

  Future<Map> request(String method, [Map? params]) async {
    final id = ++_id;
    final reply = _replies.stream.firstWhere((m) => m['id'] == id);
    _process.stdin.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': ?params,
      }),
    );
    return reply.timeout(const Duration(seconds: 20));
  }

  Future<({String text, bool error})> call(String tool, Map args) async {
    final result =
        (await request('tools/call', {
              'name': tool,
              'arguments': args,
            }))['result']
            as Map;
    return (
      text: ((result['content'] as List).single as Map)['text'] as String,
      error: result['isError'] == true,
    );
  }

  Future<void> close() async {
    await _process.stdin.close();
    await _process.exitCode;
  }
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime(2026);
  await db.insertClass(
    ClassesCompanion.insert(
      id: 'c1',
      name: 'MCS-1',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertSubject(
    SubjectsCompanion.insert(
      id: 's1',
      classId: 'c1',
      name: 'Project Management',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertLesson(
    LessonsCompanion.insert(
      id: 'l1',
      subjectId: 's1',
      name: 'Slide 2',
      sortOrder: const Value(0),
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertLessonMaterial(
    LessonMaterialsCompanion.insert(
      id: 'm1',
      lessonId: 'l1',
      title: 'Lect-02 .pdf',
      originalFileName: 'l.pdf',
      storedFileName: 'l.pdf',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.insertPdfAiMaterialVersion(
    materialId: 'm1',
    type: 'summary',
    builder: (version) => PdfAiMaterialsCompanion.insert(
      id: 'sum1',
      materialId: 'm1',
      type: 'summary',
      content: 'Lesson summary',
      version: version,
      generatedAt: now,
      sourceFingerprint: 'fp',
    ),
  );
  await db
      .into(db.referenceBooks)
      .insert(
        ReferenceBooksCompanion.insert(
          id: 'b1',
          title: 'PM Book',
          originalFileName: 'b.pdf',
          storedFileName: 'b.pdf',
          pageCount: 3,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.referenceBookChapters)
      .insert(
        ReferenceBookChaptersCompanion.insert(
          id: 'ch1',
          bookId: 'b1',
          title: 'Risk',
          startPage: 1,
          endPage: 3,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final (page, text) in [
    (1, 'Intro to projects'),
    (2, 'A risk register lists each risk with probability and impact'),
    (3, 'Budgets'),
  ]) {
    await db.customStatement(
      'INSERT INTO local_book_pages (book_id, page, text) VALUES (?, ?, ?)',
      ['b1', page, text],
    );
  }
}

void main() {
  final hasPython = Process.runSync('which', ['python3']).exitCode == 0;

  late Directory dir;
  late String dbPath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sv_mcp');
    dbPath = p.join(dir.path, 'study_vault.sqlite');
    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    await _seed(db);
    await db.close();
  });

  tearDown(() => dir.delete(recursive: true));

  test('Devin writes through MCP produce valid, syncable app data', () async {
    final mcp = await _Mcp.start(dbPath);
    addTearDown(mcp.close);
    final init = await mcp.request('initialize', {
      'protocolVersion': '2025-06-18',
    });
    expect(
      (init['result'] as Map)['serverInfo'],
      containsPair('name', 'study-vault'),
    );
    final tools =
        ((await mcp.request('tools/list'))['result'] as Map)['tools'] as List;
    expect(
      tools.map((t) => (t as Map)['name']),
      containsAll([
        'library_overview',
        'add_flashcards',
        'set_course_review_section',
        'add_book_item',
      ]),
    );

    final overview = await mcp.call('library_overview', {});
    expect(overview.text, contains('"material_id": "m1"'));
    expect(overview.text, contains('summary v1'));

    final cards = {
      'lesson_id': 'l1',
      'cards': [
        {
          'front': 'What is a project?',
          'back': 'A **temporary** endeavour.\n- unique',
        },
        {'front': 'Scope?', 'back': 'What is included'},
      ],
    };
    final preview = await mcp.call('add_flashcards', cards);
    expect(preview.text, startsWith('PREVIEW'));
    expect(preview.text, contains('2 flashcard(s)'));
    expect(
      (await mcp.call('add_flashcards', {...cards, 'apply': true})).text,
      startsWith('Saved'),
    );
    expect(
      (await mcp.call('add_flashcards', cards)).text,
      contains('2 skipped'),
    );

    for (final (tool, args) in [
      (
        'add_study_material',
        {
          'material_id': 'm1',
          'type': 'deep_explanation',
          'markdown': '# Why\nBecause.',
        },
      ),
      (
        'set_course_review_section',
        {
          'material_id': 'm1',
          'summary': '- point',
          'explanation': 'reminder',
          'deep_explanation': 'core',
        },
      ),
      (
        'set_course_overview',
        {
          'subject_id': 's1',
          'big_picture': 'Big',
          'examples': '### Example 1: X',
        },
      ),
      (
        'add_note',
        {
          'lesson_id': 'l1',
          'title': 'Key terms',
          'markdown': '## Terms\n1. Risk',
        },
      ),
      (
        'add_quiz',
        {
          'lesson_id': 'l1',
          'material_id': 'm1',
          'title': 'Basics',
          'questions': [
            {
              'type': 'mcq',
              'question': 'Q1',
              'options': ['a', 'b', 'c', 'd'],
              'correct': 'B',
            },
            {'type': 'true_false', 'question': 'Q2', 'correct': false},
            {'type': 'short_answer', 'question': 'Q3', 'answer': 'scope'},
          ],
        },
      ),
      (
        'add_book_item',
        {
          'book_id': 'b1',
          'kind': 'brief',
          'chapter_id': 'ch1',
          'markdown': 'Read [p. 2] closely',
        },
      ),
      (
        'set_lecture_book_links',
        {
          'book_id': 'b1',
          'material_id': 'm1',
          'ranges': [
            {'start': 2, 'end': 3, 'priority': 'must', 'reason': 'risk'},
          ],
        },
      ),
      ('set_chapter_status', {'chapter_id': 'ch1', 'status': 'reading'}),
    ]) {
      final result = await mcp.call(tool, {...args, 'apply': true});
      expect(result.error, isFalse, reason: '$tool: ${result.text}');
      expect(result.text, startsWith('Saved'), reason: tool);
    }

    expect(
      (await mcp.call('search_book', {
        'book_id': 'b1',
        'query': 'risk register',
      })).text,
      startsWith('p. 2'),
    );
    final review = await mcp.call('get_course_review', {'subject_id': 's1'});
    expect(review.text, isNot(contains('outdated')));
    final bad = await mcp.call('add_quiz', {
      'lesson_id': 'l1',
      'questions': [
        {
          'type': 'mcq',
          'question': 'Q',
          'options': ['a'],
          'correct': 0,
        },
      ],
      'apply': true,
    });
    expect(bad.error, isTrue);
    expect(bad.text, contains('exactly 4 options'));
    final missing = await mcp.call('get_lecture', {'material_id': 'nope'});
    expect(missing.error, isTrue);

    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    addTearDown(db.close);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    final flashcards = await db.watchFlashcardsForLesson('l1').first;
    expect(flashcards, hasLength(2));
    final card = flashcards.firstWhere((c) => c.front == 'What is a project?');
    expect(
      StudyNoteCodec.plainTextPreview(card.back),
      'A temporary endeavour. unique',
    );
    expect(
      StudyNoteCodec.decode(card.back).toPlainText(),
      contains('temporary'),
    );
    final note = (await db.getStudyNotesForLesson('l1')).single;
    expect(StudyNoteCodec.decode(note.content).toPlainText(), contains('Risk'));

    final state = (await CourseReviewRepository(db).load('s1'))!;
    expect(state.sources.single.status, CourseReviewSourceStatus.added);
    expect(state.overview.keys, hasLength(2));
    expect(state.overviewOutdated, isFalse);

    final options = await db
        .customSelect(
          'SELECT is_correct FROM quiz_question_options ORDER BY position',
        )
        .get();
    expect(options, hasLength(6));
    final questions = await db
        .customSelect(
          'SELECT type, correct_answer FROM quiz_questions ORDER BY position',
        )
        .get();
    expect(
      [for (final q in questions) q.data['correct_answer']],
      ['1', 'false', 'scope'],
    );

    final schema = await CloudSyncSchema.load(db);
    for (final table in [
      'flashcards',
      'study_notes',
      'pdf_ai_materials',
      'course_review_entries',
      'question_sets',
      'quiz_questions',
      'quiz_question_options',
      'reference_book_ai_items',
      'reference_book_links',
      'reference_book_chapters',
    ]) {
      for (final row in await db.customSelect('SELECT * FROM "$table"').get()) {
        schema.validateRow(cloudKey(table, row.data['id'] as String), row.data);
      }
    }
  }, skip: !hasPython);

  test('an open app database notices commits from the MCP tool', () async {
    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)))
      ..watchExternalChanges(interval: const Duration(milliseconds: 100));
    addTearDown(db.close);
    final counts = <int>[];
    final sub = db
        .watchFlashcardsForLesson('l1')
        .listen((c) => counts.add(c.length));
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final mcp = await _Mcp.start(dbPath);
    addTearDown(mcp.close);
    await mcp.request('initialize');
    await mcp.call('add_flashcards', {
      'lesson_id': 'l1',
      'cards': [
        {'front': 'F', 'back': 'B'},
      ],
      'apply': true,
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(counts.first, 0);
    expect(counts.last, 1);
  }, skip: !hasPython);
}
