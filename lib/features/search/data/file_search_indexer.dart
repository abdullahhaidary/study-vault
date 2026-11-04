import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/material_storage.dart';
import '../../../core/text/search_text_normalizer.dart';
import '../../lessons/data/material_mime.dart';
import '../domain/study_search_scope.dart';

class IndexedSearchPage {
  const IndexedSearchPage(this.page, this.text);
  final int page;
  final String text;
}

class FileSearchIndexProgress {
  const FileSearchIndexProgress({
    this.running = false,
    this.completed = 0,
    this.total = 0,
    this.unavailable = 0,
    this.withoutText = 0,
    this.currentTitle,
  });
  final bool running;
  final int completed;
  final int total;
  final int unavailable;
  final int withoutText;
  final String? currentTitle;
}

/// One extraction at a time; cached page text is shared by every search scope.
/// Files are parsed only when their metadata/stat fingerprint changes. Each
/// batch becomes searchable immediately, with progress visible in Search.
class FileSearchIndexer {
  FileSearchIndexer(
    this.db, {
    Future<String> Function(LessonMaterial)? resolvePath,
    Stream<IndexedSearchPage> Function(String, String)? extract,
  }) : _resolvePath =
           resolvePath ??
           ((m) => MaterialStorage.absolutePath(
             lessonId: m.lessonId,
             storedFileName: m.storedFileName,
           )),
       _extract = extract ?? extractPages;
  final AppDatabase db;
  final Future<String> Function(LessonMaterial) _resolvePath;
  final Stream<IndexedSearchPage> Function(String, String) _extract;
  final _changes = StreamController<FileSearchIndexProgress>.broadcast();
  Stream<FileSearchIndexProgress> get changes => _changes.stream;
  FileSearchIndexProgress progress = const FileSearchIndexProgress();
  final _pending = <String, Future<void>>{};
  final _rescan = <String>{};
  Future<void> _tail = Future.value();
  bool _disposed = false;
  DateTime _lastPublished = DateTime(1970);

  void dispose() {
    _disposed = true;
    _changes.close();
  }

  void _publish(FileSearchIndexProgress value, {bool force = false}) {
    final wasRunning = progress.running;
    progress = value;
    final now = DateTime.now();
    if (!_changes.isClosed &&
        (force ||
            !value.running ||
            !wasRunning ||
            now.difference(_lastPublished).inMilliseconds >= 250)) {
      _lastPublished = now;
      _changes.add(value);
    }
  }

  Future<void> ensureIndexed(StudySearchScope scope) {
    final key = '${scope.kind}:${scope.id}';
    final existing = _pending[key];
    if (existing != null) {
      _rescan.add(key);
      return existing;
    }
    final run = _tail.then((_) async {
      do {
        _rescan.remove(key);
        await _scan(scope);
      } while (!_disposed && _rescan.contains(key));
    });
    _pending[key] = run;
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run.whenComplete(() {
      if (identical(_pending[key], run)) _pending.remove(key);
    });
  }

  Future<void> _scan(StudySearchScope scope) async {
    if (_disposed) return;
    final query = db.select(db.lessonMaterials).join([
      innerJoin(
        db.lessons,
        db.lessons.id.equalsExp(db.lessonMaterials.lessonId),
      ),
      innerJoin(db.subjects, db.subjects.id.equalsExp(db.lessons.subjectId)),
    ]);
    switch (scope.kind) {
      case StudySearchScopeKind.library:
        break;
      case StudySearchScopeKind.class_:
        query.where(db.subjects.classId.equals(scope.id!));
      case StudySearchScopeKind.subject:
        query.where(db.subjects.id.equals(scope.id!));
      case StudySearchScopeKind.lesson:
        query.where(db.lessons.id.equals(scope.id!));
    }
    final rows = await query.get();
    final materials =
        [for (final row in rows) row.readTable(db.lessonMaterials)]
            .where(
              (m) =>
                  isPdfMimeType(m.mimeType) ||
                  isTextDocumentMimeType(m.mimeType),
            )
            .toList();
    var completed = 0, unavailable = 0, withoutText = 0;
    void publish({bool running = true, String? title, bool force = false}) =>
        _publish(
          FileSearchIndexProgress(
            running: running,
            completed: completed,
            total: materials.length,
            unavailable: unavailable,
            withoutText: withoutText,
            currentTitle: title,
          ),
          force: force,
        );
    publish();
    for (final material in materials) {
      if (_disposed) return;
      publish(title: material.title);
      try {
        final status = await _index(
          material,
          () => publish(title: material.title, force: true),
        );
        if (status == 'no_text') withoutText++;
      } on Object {
        if (_disposed) return;
        unavailable++;
        // Do not expose stale or partially extracted content as a completed file.
        await db.transaction(() async {
          await db.customStatement(
            'DELETE FROM local_search_pages WHERE material_id = ?',
            [material.id],
          );
          await db.customStatement(
            'DELETE FROM local_search_files WHERE material_id = ?',
            [material.id],
          );
        });
      }
      completed++;
      publish();
      await Future<void>.delayed(Duration.zero);
    }
    publish(running: false);
  }

  Future<String> _fingerprint(LessonMaterial m, File file) async {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('File unavailable');
    }
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              m.id,
              m.lessonId,
              m.storedFileName,
              m.mimeType,
              m.updatedAt.microsecondsSinceEpoch,
              file.path,
              stat.size,
              stat.modified.microsecondsSinceEpoch,
            ]),
          ),
        )
        .toString();
  }

  Future<String> _index(LessonMaterial m, void Function() publish) async {
    final path = await _resolvePath(m);
    final file = File(path);
    final fingerprint = await _fingerprint(m, file);
    final cached = await db
        .customSelect(
          'SELECT fingerprint, status FROM local_search_files WHERE material_id = ?',
          variables: [Variable.withString(m.id)],
        )
        .getSingleOrNull();
    if (cached != null &&
        cached.read<String>('fingerprint') == fingerprint &&
        ['ready', 'no_text'].contains(cached.read<String>('status'))) {
      return cached.read<String>('status');
    }
    if (_disposed) return 'cancelled';
    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM local_search_pages WHERE material_id = ?',
        [m.id],
      );
      await db.customStatement(
        'INSERT OR REPLACE INTO local_search_files (material_id, fingerprint, status, material_revision, source_identity) VALUES (?, ?, ?, ?, ?)',
        [
          m.id,
          fingerprint,
          'indexing',
          m.updatedAt.millisecondsSinceEpoch ~/ 1000,
          '${m.lessonId}/${m.storedFileName}/${m.mimeType}',
        ],
      );
    });
    var pageCount = 0, characters = 0;
    var batch = <IndexedSearchPage>[];
    Future<void> flush() async {
      if (batch.isEmpty || _disposed) return;
      final pages = batch;
      batch = [];
      await db.transaction(() async {
        for (final page in pages) {
          await db.customStatement(
            'INSERT INTO local_search_pages (material_id, page, text, normalized_text) VALUES (?, ?, ?, ?)',
            [
              m.id,
              page.page,
              page.text,
              SearchTextNormalizer.normalize(page.text),
            ],
          );
        }
      });
      publish();
    }

    await for (final page in _extract(path, m.mimeType)) {
      if (_disposed) return 'cancelled';
      characters += page.text.length;
      if (characters > 32 * 1024 * 1024 || page.text.length > 1024 * 1024) {
        throw const FormatException('Text extraction limit exceeded');
      }
      pageCount++;
      batch.add(page);
      if (batch.length >= 32) await flush();
    }
    await flush();
    if (_disposed) return 'cancelled';
    final current = await db.getMaterialById(m.id);
    if (current == null ||
        current.updatedAt != m.updatedAt ||
        current.storedFileName != m.storedFileName ||
        current.lessonId != m.lessonId ||
        current.mimeType != m.mimeType ||
        await _fingerprint(m, file) != fingerprint) {
      throw const FileSystemException('File changed while indexing');
    }
    final status = characters == 0 ? 'no_text' : 'ready';
    await db.customStatement(
      'UPDATE local_search_files SET status = ?, page_count = ? WHERE material_id = ?',
      [status, pageCount, m.id],
    );
    return status;
  }

  static Stream<IndexedSearchPage> extractPages(
    String path,
    String mime,
  ) async* {
    if (isTextDocumentMimeType(mime)) {
      // Text documents do not have physical page numbers. Chunk boundaries are
      // internal search sections; navigation opens the text reader normally.
      final file = File(path);
      if (await file.length() > 32 * 1024 * 1024) {
        throw const FormatException('Text file too large');
      }
      final text = await file.readAsString();
      var section = 1;
      for (var start = 0; start < text.length; start += 5600) {
        final end = (start + 6000).clamp(0, text.length);
        yield IndexedSearchPage(section++, text.substring(start, end));
      }
      return;
    }
    final document = await PdfDocument.openFile(path);
    try {
      for (final page in document.pages) {
        final text = await page.loadText();
        yield IndexedSearchPage(page.pageNumber, text?.fullText ?? '');
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      await document.dispose();
    }
  }
}
