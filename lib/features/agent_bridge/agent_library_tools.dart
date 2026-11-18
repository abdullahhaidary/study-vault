import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../ai_assistant/services/markdown_to_quill.dart';
import '../ai_questions/services/pdf_text_extractor.dart';
import '../course_review/data/course_review_repository.dart';
import '../reference_books/data/book_repository.dart';
import '../search/data/file_search_indexer.dart';
import '../search/data/study_search_service.dart';
import '../search/domain/study_search_scope.dart';
import '../study_pins/domain/study_note_codec.dart';

/// Bounded library operations only: no SQL, credentials, deletion, or cloud API.
class AgentLibraryTools {
  AgentLibraryTools(this.db, this.filesRoot);
  final AppDatabase db;
  final Directory filesRoot;
  static const _uuid = Uuid();
  static const maxFileBytes = 256 * 1024 * 1024;
  static const _s = {'type': 'string'};
  static const _i = {'type': 'integer'};
  static const _b = {'type': 'boolean'};
  static const _markdown = {'markdown': _s};
  static const writeTools = {
    'add_lesson',
    'attach_file',
    'add_note',
    'add_flashcards',
    'add_quiz',
    'add_study_material',
    'set_course_review_document',
    'add_book_item',
    'set_chapter_status',
  };
  static const mimeTypes = {
    '.pdf': 'application/pdf',
    '.md': 'text/markdown',
    '.markdown': 'text/markdown',
    '.txt': 'text/plain',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
    '.bmp': 'image/bmp',
  };

  static Map<String, Object?> _tool(
    String name,
    String description,
    Map<String, Object?> properties,
    List<String> required,
  ) => {
    'name': name,
    'description': description,
    'inputSchema': {
      'type': 'object',
      'properties': {...properties, if (writeTools.contains(name)) 'apply': _b},
      'required': required,
      'additionalProperties': false,
    },
  };

  static List<Map<String, Object?>> get definitions => [
    _tool(
      'library_overview',
      'List classes, subjects, lessons, files and books. Paginated; use offset/limit.',
      {'offset': _i, 'limit': _i},
      [],
    ),
    _tool(
      'search_library',
      'Search the library or one class/subject/lesson, including indexed file pages. Set index_files=true to refresh PDF/text indexing (may take time).',
      {
        'query': _s,
        'class_id': _s,
        'subject_id': _s,
        'lesson_id': _s,
        'index_files': _b,
      },
      ['query'],
    ),
    _tool(
      'get_lesson',
      'Read a lesson with files, notes, flashcards and quiz metadata. Use get_quiz for questions/options. Paginated collections.',
      {'lesson_id': _s, 'offset': _i, 'limit': _i},
      ['lesson_id'],
    ),
    _tool(
      'get_quiz',
      'Read a quiz with paginated questions and answer options.',
      {'quiz_id': _s, 'offset': _i, 'limit': _i},
      ['quiz_id'],
    ),
    _tool(
      'read_note',
      'Read a full note by its ID (including subject notes).',
      {'note_id': _s},
      ['note_id'],
    ),
    _tool(
      'get_book',
      'Read book metadata, chapters, notes and generated study materials. Paginated collections.',
      {'book_id': _s, 'offset': _i, 'limit': _i},
      ['book_id'],
    ),
    _tool(
      'read_study_material',
      'Read the latest generated material for a lecture PDF.',
      {'material_id': _s, 'type': _s},
      ['material_id', 'type'],
    ),
    _tool(
      'read_pdf_text',
      'Extract up to 120 PDF pages on the phone. Scanned PDFs need OCR elsewhere; get_file downloads originals. Supply exactly one material_id or book_id.',
      {
        'material_id': _s,
        'book_id': _s,
        'start_page': _i,
        'end_page': _i,
        'max_chars': _i,
      },
      [],
    ),
    _tool(
      'get_file',
      'Download an original lesson file or book PDF into Termux. Supply exactly one material_id or book_id. Returns the local path.',
      {'material_id': _s, 'book_id': _s},
      [],
    ),
    _tool(
      'get_course_review',
      'Read all saved Course Review versions for a subject. Paginated.',
      {'subject_id': _s, 'offset': _i, 'limit': _i},
      ['subject_id'],
    ),
    _tool(
      'add_lesson',
      'Add a lesson to an existing subject. Previews unless apply=true.',
      {'subject_id': _s, 'name': _s},
      ['subject_id', 'name'],
    ),
    _tool(
      'attach_file',
      'Attach a Termux-local PDF, image, Markdown or text file to a lesson (up to 256 MiB). Previews unless apply=true.',
      {'lesson_id': _s, 'path': _s, 'title': _s},
      ['lesson_id', 'path'],
    ),
    _tool(
      'add_note',
      'Add a rich Markdown note to exactly one lesson or subject. Previews unless apply=true.',
      {'lesson_id': _s, 'subject_id': _s, 'title': _s, ..._markdown},
      ['title', 'markdown'],
    ),
    _tool(
      'add_flashcards',
      'Add cards to a lesson, skipping existing fronts. Previews unless apply=true.',
      {
        'lesson_id': _s,
        'cards': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 200,
          'items': {
            'type': 'object',
            'properties': {'front': _s, 'back': _s},
            'required': ['front', 'back'],
            'additionalProperties': false,
          },
        },
      },
      ['lesson_id', 'cards'],
    ),
    _tool(
      'add_quiz',
      'Add a quiz to a lesson. MCQ correct_answer is a zero-based option index; true_false uses true/false. Previews unless apply=true.',
      {
        'lesson_id': _s,
        'material_id': _s,
        'title': _s,
        'questions': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 200,
          'items': {
            'type': 'object',
            'properties': {
              'type': {
                'type': 'string',
                'enum': ['mcq', 'true_false', 'short_answer', 'fill_blank'],
              },
              'question': _s,
              'correct_answer': _s,
              'explanation': _s,
              'options': {'type': 'array', 'items': _s, 'maxItems': 10},
            },
            'required': ['type', 'question', 'correct_answer'],
            'additionalProperties': false,
          },
        },
      },
      ['lesson_id', 'title', 'questions'],
    ),
    _tool(
      'add_study_material',
      'Append a version of mental_blueprint, summary, explanation, deep_explanation, real_world_examples or slideshow for a lecture PDF. Previews unless apply=true.',
      {'material_id': _s, 'type': _s, ..._markdown},
      ['material_id', 'type', 'markdown'],
    ),
    _tool(
      'set_course_review_document',
      'Append a complete Course Review Markdown document, preserving previous versions. Previews unless apply=true.',
      {'subject_id': _s, ..._markdown},
      ['subject_id', 'markdown'],
    ),
    _tool(
      'add_book_item',
      'Append book/chapter/range brief, summary or explanation. Supply a chapter_id OR start_page/end_page, or neither for the whole book. Previews unless apply=true.',
      {
        'book_id': _s,
        'chapter_id': _s,
        'kind': {
          'type': 'string',
          'enum': ['brief', 'summary', 'explanation'],
        },
        'start_page': _i,
        'end_page': _i,
        ..._markdown,
      },
      ['book_id', 'kind', 'markdown'],
    ),
    _tool(
      'set_chapter_status',
      'Set chapter status to notStarted, reading or done. Previews unless apply=true.',
      {
        'chapter_id': _s,
        'status': {
          'type': 'string',
          'enum': ['notStarted', 'reading', 'done'],
        },
      },
      ['chapter_id', 'status'],
    ),
  ];

  static String text(Map a, String key, {int max = 1000000}) {
    final value = a[key];
    if (value is! String || value.trim().isEmpty || value.length > max) {
      throw FormatException(
        '$key must be nonempty text, at most $max characters.',
      );
    }
    return value.trim();
  }

  static int integer(
    Map a,
    String key,
    int fallback, {
    int min = 0,
    int max = 1000000,
  }) {
    final v = a[key] ?? fallback;
    if (v is! int || v < min || v > max) {
      throw FormatException('Invalid $key ($min–$max).');
    }
    return v;
  }

  Future<List<Map<String, Object?>>> _rows(
    String sql, [
    List<Object> args = const [],
  ]) async => [
    for (final row
        in await db
            .customSelect(
              sql,
              variables: [
                for (final v in args)
                  if (v is int)
                    Variable<int>(v)
                  else
                    Variable<String>(v as String),
              ],
            )
            .get())
      row.data,
  ];

  Future<Map<String, Object?>> _one(String table, String id) async {
    // Table names are constants from this class, never client input.
    final rows = await _rows('SELECT * FROM $table WHERE id = ?', [id]);
    if (rows.isEmpty) throw const FormatException('Library item not found.');
    return rows.single;
  }

  Future<Lesson> _lesson(Map a) async =>
      await db.getLessonById(text(a, 'lesson_id', max: 100)) ??
      (throw const FormatException('Lesson not found.'));

  Future<({File file, String name, String mime})> fileFor(Map a) async {
    if ((a['material_id'] != null) == (a['book_id'] != null)) {
      throw const FormatException('Supply exactly one material_id or book_id.');
    }
    final book = a['book_id'] != null;
    final row = await _one(
      book ? 'reference_books' : 'lesson_materials',
      text(a, book ? 'book_id' : 'material_id', max: 100),
    );
    final owner = row[book ? 'id' : 'lesson_id'] as String;
    final name = row['stored_file_name'] as String;
    for (final part in [owner, name]) {
      if (part.isEmpty ||
          part == '.' ||
          part == '..' ||
          part.contains('/') ||
          part.contains('\\')) {
        throw const FormatException('Invalid stored file path.');
      }
    }
    final base = await filesRoot.resolveSymbolicLinks();
    final file = File(p.join(base, book ? 'books' : 'lessons', owner, name));
    if (!await file.exists()) {
      throw const FormatException(
        'File missing on this phone. Download/sync it first.',
      );
    }
    final resolved = await file.resolveSymbolicLinks();
    if (!p.isWithin(base, resolved)) {
      throw const FormatException('Invalid stored file path.');
    }
    return (
      file: File(resolved),
      name: row['original_file_name'] as String,
      mime: book ? 'application/pdf' : row['mime_type'] as String,
    );
  }

  Future<Object?> call(
    String name,
    Map<String, dynamic> a, {
    File? upload,
  }) async {
    final offset = integer(a, 'offset', 0);
    final limit = integer(a, 'limit', 20, min: 1, max: 100);
    switch (name) {
      case 'library_overview':
        return {
          for (final table in [
            'classes',
            'subjects',
            'lessons',
            'lesson_materials',
            'reference_books',
          ])
            table: await _rows(
              'SELECT * FROM $table ORDER BY id LIMIT ? OFFSET ?',
              [limit, offset],
            ),
          'offset': offset,
          'limit': limit,
          'next_offset': offset + limit,
        };
      case 'search_library':
        final owners = [
          'class_id',
          'subject_id',
          'lesson_id',
        ].where((k) => a[k] != null).toList();
        if (owners.length > 1) {
          throw const FormatException('Use one search scope.');
        }
        final scope = owners.isEmpty
            ? const StudySearchScope.library()
            : switch (owners.single) {
                'class_id' => StudySearchScope.class_(
                  id: text(a, 'class_id'),
                  title: '',
                ),
                'subject_id' => StudySearchScope.subject(
                  id: text(a, 'subject_id'),
                  title: '',
                ),
                _ => StudySearchScope.lesson(
                  id: text(a, 'lesson_id'),
                  title: '',
                ),
              };
        if (a['index_files'] == true) {
          final indexer = FileSearchIndexer(db);
          try {
            await indexer.ensureIndexed(scope);
          } finally {
            indexer.dispose();
          }
        }
        return [
          for (final r in await StudySearchService(
            db,
          ).search(query: text(a, 'query', max: 500), scope: scope))
            {
              'kind': r.kind.name,
              'id': r.id,
              'title': r.title,
              'breadcrumb': r.breadcrumb,
              'snippet': r.matchedSnippet,
              'page': r.pageNumber,
              'material_id': r.materialId,
              'lesson_id': r.lessonId,
              'subject_id': r.subjectId,
            },
        ];
      case 'get_lesson':
        final lesson = await _lesson(a);
        final quizzes = await _rows(
          'SELECT * FROM question_sets WHERE lesson_id = ? ORDER BY id LIMIT ? OFFSET ?',
          [lesson.id, limit, offset],
        );
        return {
          'lesson': await _one('lessons', lesson.id),
          for (final table in ['lesson_materials', 'study_notes', 'flashcards'])
            table: await _rows(
              'SELECT * FROM $table WHERE lesson_id = ? ORDER BY id LIMIT ? OFFSET ?',
              [lesson.id, limit, offset],
            ),
          'quizzes': quizzes,
        };
      case 'read_note':
        return _one('study_notes', text(a, 'note_id'));
      case 'get_quiz':
        final quizId = text(a, 'quiz_id');
        return {
          'quiz': await _one('question_sets', quizId),
          'questions': [
            for (final question in await _rows(
              'SELECT * FROM quiz_questions WHERE question_set_id = ? ORDER BY position LIMIT ? OFFSET ?',
              [quizId, limit, offset],
            ))
              {
                ...question,
                'options': await _rows(
                  'SELECT * FROM quiz_question_options WHERE question_id = ? ORDER BY position',
                  [question['id'] as String],
                ),
              },
          ],
        };
      case 'get_book':
        final id = text(a, 'book_id');
        return {
          'book': await _one('reference_books', id),
          for (final table in [
            'reference_book_chapters',
            'reference_book_notes',
            'reference_book_ai_items',
          ])
            table: await _rows(
              'SELECT * FROM $table WHERE book_id = ? ORDER BY id LIMIT ? OFFSET ?',
              [id, limit, offset],
            ),
        };
      case 'get_course_review':
        final id = text(a, 'subject_id');
        await _one('subjects', id);
        return _rows(
          'SELECT * FROM course_review_entries WHERE subject_id = ? ORDER BY version DESC LIMIT ? OFFSET ?',
          [id, limit, offset],
        );
      case 'read_study_material':
        await _one('lesson_materials', text(a, 'material_id'));
        return _rows(
          'SELECT * FROM pdf_ai_materials WHERE material_id = ? AND type = ? ORDER BY version DESC, generated_at DESC LIMIT 1',
          [text(a, 'material_id'), text(a, 'type')],
        );
      case 'read_pdf_text':
        final source = await fileFor(a);
        if (source.mime != 'application/pdf') {
          throw const FormatException('Choose a PDF.');
        }
        final start = integer(a, 'start_page', 1, min: 1);
        final end = integer(
          a,
          'end_page',
          start + 19,
          min: start,
          max: start + 119,
        );
        final chars = integer(a, 'max_chars', 120000, min: 1, max: 500000);
        final pages = await PdfTextExtractor.extractPages(
          filePath: source.file.path,
          pageNumbers: {for (var i = start; i <= end; i++) i},
          includeEmptyPages: true,
        );
        final output = pages
            .map((r) => '--- Page ${r.pageNumber} ---\n${r.text}')
            .join('\n\n');
        return {
          'text': output.length > chars ? output.substring(0, chars) : output,
          'truncated': output.length > chars,
        };
      case 'get_file':
        await fileFor(a);
        return {
          'download': a,
        }; // The Termux adapter streams this file, not JSON/base64.
    }
    if (!writeTools.contains(name)) {
      throw const FormatException('Unknown tool.');
    }
    if (a['apply'] != null && a['apply'] is! bool) {
      throw const FormatException('apply must be boolean.');
    }
    // A write is one app transaction. Drift emits the usual live UI updates.
    return db.transaction(() => _write(name, a, upload));
  }

  Future<Object?> _write(
    String name,
    Map<String, dynamic> a,
    File? upload,
  ) async {
    final apply = a['apply'] == true;
    Map<String, Object?> preview(String description) => {
      'preview': description,
      'saved': false,
      'next':
          'Show the preview to the user; call with apply=true after approval.',
    };
    final id = _uuid.v4();
    final now = DateTime.now();
    switch (name) {
      case 'add_lesson':
        final subject = text(a, 'subject_id');
        await _one('subjects', subject);
        final title = text(a, 'name', max: 200);
        if (!apply) return preview('Add lesson "$title" to subject $subject.');
        await db.insertLesson(
          LessonsCompanion.insert(
            id: id,
            subjectId: subject,
            name: title,
            sortOrder: Value(await db.nextLessonSortOrder(subject)),
            createdAt: now,
            updatedAt: now,
          ),
        );
      case 'attach_file':
        final lesson = await _lesson(a);
        final fileName = text(a, 'file_name', max: 255);
        if (p.basename(fileName) != fileName || fileName.contains('\\')) {
          throw const FormatException('Invalid filename.');
        }
        final ext = p.extension(fileName).toLowerCase();
        final mime = mimeTypes[ext];
        if (mime == null) {
          throw const FormatException(
            'Only PDFs, images, Markdown or text files are supported.',
          );
        }
        final title = a['title'] == null
            ? fileName
            : text(a, 'title', max: 300);
        if (!apply) return preview('Attach "$title" to ${lesson.name}.');
        if (upload == null ||
            !await upload.exists() ||
            await upload.length() > maxFileBytes) {
          throw const FormatException('Upload missing or too large.');
        }
        if (ext == '.pdf') {
          final input = await upload.open();
          try {
            if (ascii.decode(await input.read(5), allowInvalid: true) !=
                '%PDF-') {
              throw const FormatException('Invalid PDF header.');
            }
          } finally {
            await input.close();
          }
        }
        if (lesson.id == '.' ||
            lesson.id == '..' ||
            lesson.id.contains('/') ||
            lesson.id.contains('\\')) {
          throw const FormatException('Invalid lesson folder.');
        }
        final ownerDir = Directory(
          p.join(filesRoot.path, 'lessons', lesson.id),
        );
        await ownerDir.create(recursive: true);
        final base = await filesRoot.resolveSymbolicLinks();
        if (!p.isWithin(base, await ownerDir.resolveSymbolicLinks())) {
          throw const FormatException('Invalid lesson folder.');
        }
        final stored = '$id$ext';
        final target = File(p.join(ownerDir.path, stored));
        try {
          await upload.copy(target.path);
          await db.insertLessonMaterial(
            LessonMaterialsCompanion.insert(
              id: id,
              lessonId: lesson.id,
              title: title,
              originalFileName: fileName,
              storedFileName: stored,
              mimeType: Value(mime),
              sortOrder: Value(await db.nextMaterialSortOrder(lesson.id)),
              createdAt: now,
              updatedAt: now,
            ),
          );
        } catch (_) {
          if (await target.exists()) await target.delete();
          rethrow;
        }
      case 'add_note':
        if ((a['lesson_id'] != null) == (a['subject_id'] != null)) {
          throw const FormatException(
            'Supply exactly one lesson_id or subject_id.',
          );
        }
        final lessonId = a['lesson_id'] == null ? null : (await _lesson(a)).id;
        final subjectId = a['subject_id'] == null
            ? null
            : text(a, 'subject_id');
        if (subjectId != null) await _one('subjects', subjectId);
        final title = text(a, 'title', max: 300);
        final markdown = text(a, 'markdown');
        if (!apply) {
          return preview('Add note "$title" (${markdown.length} characters).');
        }
        final delta = MarkdownToQuill.toDeltaJson(markdown);
        await db.insertStudyNote(
          StudyNotesCompanion.insert(
            id: id,
            lessonId: Value(lessonId),
            subjectId: Value(subjectId),
            title: title,
            content: delta,
            plainTextContent: Value(StudyNoteCodec.plainTextPreview(delta)),
            sortOrder: Value(
              await db.nextNoteSortOrder(
                lessonId: lessonId,
                subjectId: subjectId,
              ),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
      case 'add_flashcards':
        final lesson = await _lesson(a);
        final cards = _objects(a, 'cards');
        final existing = {
          for (final r in await _rows(
            'SELECT front FROM flashcards WHERE lesson_id = ?',
            [lesson.id],
          ))
            (r['front'] as String).trim().toLowerCase(),
        };
        final pending = <Map<String, String>>[];
        for (final card in cards) {
          final front = text(card, 'front', max: 2000);
          final back = text(card, 'back');
          if (existing.add(front.toLowerCase())) {
            pending.add({'front': front, 'back': back});
          }
        }
        if (!apply) {
          return preview(
            'Add ${pending.length} flashcards to ${lesson.name}; ${cards.length - pending.length} duplicates skipped.',
          );
        }
        for (final card in pending) {
          final delta = MarkdownToQuill.toDeltaJson(card['back']!);
          await db.insertFlashcard(
            FlashcardsCompanion.insert(
              id: _uuid.v4(),
              subjectId: Value(lesson.subjectId),
              lessonId: Value(lesson.id),
              front: card['front']!,
              back: delta,
              backPlainText: Value(StudyNoteCodec.plainTextPreview(delta)),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
        return {'saved': true, 'added': pending.length};
      case 'add_study_material':
        final materialId = text(a, 'material_id');
        final material = await _one('lesson_materials', materialId);
        if (material['mime_type'] != 'application/pdf') {
          throw const FormatException('Choose a lecture PDF.');
        }
        final kind = text(a, 'type');
        if (![
          'mental_blueprint',
          'summary',
          'explanation',
          'deep_explanation',
          'real_world_examples',
          'slideshow',
        ].contains(kind)) {
          throw const FormatException('Invalid study material type.');
        }
        final content = text(a, 'markdown');
        if (!apply) {
          return preview(
            'Append $kind on ${material['title']} (${content.length} characters).',
          );
        }
        final row = await db.insertPdfAiMaterialVersion(
          materialId: materialId,
          type: kind,
          builder: (version) => PdfAiMaterialsCompanion.insert(
            id: id,
            materialId: materialId,
            type: kind,
            content: content,
            version: version,
            generatedAt: now,
            provider: const Value('manual'),
            model: const Value('termux-agent'),
            sourceFingerprint: sha256.convert(utf8.encode(content)).toString(),
          ),
        );
        return {'saved': true, 'id': id, 'version': row.version};
      case 'set_course_review_document':
        final subject = text(a, 'subject_id');
        final state = await CourseReviewRepository(db).load(subject);
        if (state == null) throw const FormatException('Subject not found.');
        final content = text(a, 'markdown');
        if (!apply) {
          return preview(
            'Append Course Review document (${content.length} characters).',
          );
        }
        final row = await db.insertCourseReviewVersion(
          id: id,
          subjectId: subject,
          materialId: null,
          part: 'document',
          content: content,
          sourceFingerprint: state.documentFingerprint,
          provider: 'manual',
          model: 'termux-agent',
        );
        return {'saved': true, 'id': id, 'version': row.version};
      case 'add_quiz':
        final lesson = await _lesson(a);
        final title = text(a, 'title', max: 300);
        final materialId = a['material_id'] == null
            ? null
            : text(a, 'material_id');
        if (materialId != null &&
            (await _one('lesson_materials', materialId))['lesson_id'] !=
                lesson.id) {
          throw const FormatException('Material belongs to another lesson.');
        }
        final questions = _objects(a, 'questions');
        final normalized =
            <
              ({
                String type,
                String question,
                String answer,
                String? explanation,
                List<String> options,
              })
            >[];
        for (final q in questions) {
          final type = text(q, 'type');
          final question = text(q, 'question', max: 20000);
          final answer = text(q, 'correct_answer', max: 20000);
          if (![
            'mcq',
            'true_false',
            'short_answer',
            'fill_blank',
          ].contains(type)) {
            throw const FormatException('Invalid question type.');
          }
          List<String> options = [];
          if (type == 'mcq') {
            final raw = q['options'];
            if (raw is! List ||
                raw.length < 2 ||
                raw.length > 10 ||
                raw.any(
                  (o) => o is! String || o.trim().isEmpty || o.length > 20000,
                )) {
              throw const FormatException('MCQ needs 2–10 options.');
            }
            options = raw.cast<String>();
            final index = int.tryParse(answer);
            if (index == null || index < 0 || index >= options.length) {
              throw const FormatException(
                'MCQ answer must be a zero-based option index.',
              );
            }
          }
          if (type == 'true_false') {
            if (!['true', 'false'].contains(answer)) {
              throw const FormatException('Use true or false.');
            }
            options = ['True', 'False'];
          }
          normalized.add((
            type: type,
            question: question,
            answer: answer,
            explanation: q['explanation'] == null
                ? null
                : text(q, 'explanation', max: 100000),
            options: options,
          ));
        }
        if (!apply) {
          return preview(
            'Add quiz "$title" with ${questions.length} questions to ${lesson.name}.',
          );
        }
        final types = normalized.map((q) => q.type).toSet();
        await db.insertQuestionSet(
          QuestionSetsCompanion.insert(
            id: id,
            lessonId: Value(lesson.id),
            subjectId: Value(lesson.subjectId),
            materialId: Value(materialId),
            title: title,
            sourceType: 'manual_entry',
            questionCount: normalized.length,
            questionType: types.length == 1 ? types.single : 'mixed',
            difficulty: 'mixed',
            aiProvider: const Value('manual'),
            aiModel: const Value('termux-agent'),
            createdAt: now,
            updatedAt: now,
          ),
        );
        for (var n = 0; n < normalized.length; n++) {
          final q = normalized[n];
          final qid = _uuid.v4();
          await db.insertQuizQuestion(
            QuizQuestionsCompanion.insert(
              id: qid,
              questionSetId: id,
              type: q.type,
              question: q.question,
              correctAnswer: q.answer,
              explanation: Value(q.explanation),
              position: n,
              createdAt: now,
              updatedAt: now,
            ),
          );
          for (var j = 0; j < q.options.length; j++) {
            await db.insertQuizQuestionOption(
              QuizQuestionOptionsCompanion.insert(
                id: _uuid.v4(),
                questionId: qid,
                optionText: q.options[j],
                isCorrect: q.type == 'mcq'
                    ? j == int.parse(q.answer)
                    : (j == 0) == (q.answer == 'true'),
                position: j,
              ),
            );
          }
        }
      case 'add_book_item':
        final bookId = text(a, 'book_id');
        final book = await _one('reference_books', bookId);
        final kindText = text(a, 'kind');
        final kind = BookAiKind.values
            .where((k) => k.storageValue == kindText)
            .firstOrNull;
        if (kind == null) {
          throw const FormatException('Invalid book item kind.');
        }
        final content = text(a, 'markdown');
        String? chapterId;
        var start = integer(
          a,
          'start_page',
          1,
          min: 1,
          max: book['page_count'] as int,
        );
        var end = integer(
          a,
          'end_page',
          book['page_count'] as int,
          min: start,
          max: book['page_count'] as int,
        );
        var scope = a['start_page'] == null && a['end_page'] == null
            ? 'book'
            : 'pages:$start-$end';
        if (a['chapter_id'] != null) {
          if (a['start_page'] != null || a['end_page'] != null) {
            throw const FormatException('Use chapter_id or a page range.');
          }
          chapterId = text(a, 'chapter_id');
          final chapter = await _one('reference_book_chapters', chapterId);
          if (chapter['book_id'] != bookId) {
            throw const FormatException('Chapter belongs to another book.');
          }
          start = chapter['start_page'] as int;
          end = chapter['end_page'] as int;
          scope = chapterId;
        }
        if (!apply) {
          return preview(
            'Append $kindText for ${book['title']}, pages $start–$end.',
          );
        }
        final row = await BookRepository(db).addAiItem(
          bookId: bookId,
          chapterId: chapterId,
          kind: kind,
          scopeKey: scope,
          startPage: start,
          endPage: end,
          content: content,
          provider: 'manual',
          model: 'termux-agent',
        );
        return {'saved': true, 'id': row.id, 'version': row.version};
      case 'set_chapter_status':
        final chapterId = text(a, 'chapter_id');
        final chapter = await (db.select(
          db.referenceBookChapters,
        )..where((t) => t.id.equals(chapterId))).getSingleOrNull();
        if (chapter == null) throw const FormatException('Chapter not found.');
        final value = text(a, 'status');
        final status = ChapterStatus.values
            .where((s) => s.storageValue == value)
            .firstOrNull;
        if (status == null) {
          throw const FormatException('Invalid chapter status.');
        }
        if (!apply) return preview('Set ${chapter.title} to $value.');
        await BookRepository(db).setChapterStatus(chapter, status);
    }
    return {'saved': true, 'id': id};
  }

  static List<Map<String, dynamic>> _objects(Map a, String key) {
    final value = a[key];
    if (value is! List ||
        value.isEmpty ||
        value.length > 200 ||
        value.any((v) => v is! Map)) {
      throw FormatException('$key must contain 1–200 objects.');
    }
    return [for (final item in value) Map<String, dynamic>.from(item as Map)];
  }
}
