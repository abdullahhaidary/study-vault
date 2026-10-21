import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:study_vault/app/routes.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/navigation/study_navigator.dart';
import 'package:study_vault/features/cloud_account/cloud_sync_models.dart';
import 'package:study_vault/features/interactive_html/data/interactive_html_files.dart';
import 'package:study_vault/features/interactive_html/data/interactive_html_repository.dart';
import 'package:study_vault/features/interactive_html/domain/html_bundle.dart';
import 'package:study_vault/features/interactive_html/services/html_page_server.dart';
import 'package:study_vault/features/interactive_html/services/linux_html_window.dart';
import 'package:study_vault/features/lessons/data/material_mime.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('interactive_html');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  File writeZip(String name, Map<String, String> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, utf8.encode(entry.value)));
    }
    return File(p.join(temp.path, name))
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
  }

  group('material types', () {
    test('HTML is its own kind, routed to the HTML viewer', () {
      expect(isInteractiveHtmlMimeType(kHtmlMimeType), isTrue);
      expect(isInteractiveHtmlMimeType(kHtmlBundleMimeType), isTrue);
      expect(isDocumentMimeType(kHtmlMimeType), isFalse);
      expect(isDocumentMimeType(kHtmlBundleMimeType), isFalse);
      expect(isImageMimeType(kHtmlBundleMimeType), isFalse);
      expect(guessMimeType('quiz.HTML'), kHtmlMimeType);
      expect(materialKindLabel(kHtmlMimeType), 'Interactive HTML');
      expect(
        StudyNavigator.studyRouteForMime(kHtmlMimeType),
        AppRoutes.htmlStudy,
      );
      expect(
        StudyNavigator.studyRouteForMime(kHtmlBundleMimeType),
        AppRoutes.htmlStudy,
      );
      expect(
        StudyNavigator.studyRouteForMime('application/pdf'),
        AppRoutes.pdfStudy,
      );
    });

    test('HTML rows sync through the lesson material file path', () {
      expect(
        cloudFilePath('lesson_materials', {
          'lesson_id': 'lesson-1',
          'stored_file_name': 'page.zip',
        }),
        'lessons/lesson-1/page.zip',
      );
    });
  });

  group('bundle layout', () {
    test('unsafe and metadata entries are rejected', () {
      expect(HtmlBundleLayout.safeEntryPath('img/a.png'), 'img/a.png');
      expect(HtmlBundleLayout.safeEntryPath('./css//site.css'), 'css/site.css');
      expect(HtmlBundleLayout.safeEntryPath(r'js\app.js'), 'js/app.js');
      expect(HtmlBundleLayout.safeEntryPath('../evil.js'), isNull);
      expect(HtmlBundleLayout.safeEntryPath('a/../../evil.js'), isNull);
      expect(HtmlBundleLayout.safeEntryPath('/etc/passwd'), isNull);
      expect(HtmlBundleLayout.safeEntryPath('C:/x.html'), isNull);
      expect(HtmlBundleLayout.safeEntryPath('folder/'), isNull);
      expect(HtmlBundleLayout.safeEntryPath('__MACOSX/._index.html'), isNull);
    });

    test(
      'the start page is index.html, a single folder index, or the only page',
      () {
        expect(
          HtmlBundleLayout.entryPage(['img/a.png', 'index.html', 'about.html']),
          'index.html',
        );
        expect(
          HtmlBundleLayout.entryPage(['site/index.html', 'site/app.js']),
          'site/index.html',
        );
        expect(
          HtmlBundleLayout.entryPage(['mindmap.html', 'a.css']),
          'mindmap.html',
        );
        expect(
          () => HtmlBundleLayout.entryPage(['a.html', 'b.html']),
          throwsA(isA<InteractiveHtmlException>()),
        );
        expect(
          () => HtmlBundleLayout.entryPage(['a.png']),
          throwsA(isA<InteractiveHtmlException>()),
        );
      },
    );
  });

  group('internet scan', () {
    test('remote scripts, styles, images, modules, and requests count', () {
      for (final text in [
        '<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>',
        "<link rel='stylesheet' href='//fonts.googleapis.com/css'>",
        '<img src=https://example.com/a.png>',
        'body { background: url("https://example.com/bg.jpg"); }',
        "@import 'https://example.com/theme.css';",
        "import * as d3 from 'https://cdn.skypack.dev/d3';",
        "const m = await import('https://esm.sh/x');",
        "fetch('https://api.example.com/data')",
      ]) {
        expect(HtmlInternetScan.usesInternet(text), isTrue, reason: text);
      }
    });

    test('local files and ordinary links do not count', () {
      for (final text in [
        '<script src="app.js"></script><link href="css/site.css">',
        '<img src="img/cell.png">',
        '<a href="https://en.wikipedia.org/wiki/Cell">Read more</a>',
        'body { background: url(img/bg.png); }',
        "fetch('data/questions.json')",
      ]) {
        expect(HtmlInternetScan.usesInternet(text), isFalse, reason: text);
      }
    });

    test('bundles are scanned across their text files', () async {
      final offline = writeZip('offline.zip', {
        'index.html': '<script src="app.js"></script>',
        'app.js': 'console.log(1)',
      });
      final online = writeZip('online.zip', {
        'index.html': '<link href="style.css">',
        'style.css': "@import url('https://fonts.example.com/a.css');",
      });
      expect(
        await InteractiveHtmlFiles.usesInternet(
          filePath: offline.path,
          mimeType: kHtmlBundleMimeType,
        ),
        isFalse,
      );
      expect(
        await InteractiveHtmlFiles.usesInternet(
          filePath: online.path,
          mimeType: kHtmlBundleMimeType,
        ),
        isTrue,
      );
    });
  });

  group('import checks', () {
    test('HTML files and valid bundles are accepted', () async {
      final page = File(p.join(temp.path, 'quiz.html'))
        ..writeAsStringSync('<h1>Quiz</h1>');
      final bundle = writeZip('map.zip', {'index.html': '<h1>Map</h1>'});
      expect(
        await InteractiveHtmlFiles.mimeTypeForImport(page.path),
        kHtmlMimeType,
      );
      expect(
        await InteractiveHtmlFiles.mimeTypeForImport(bundle.path),
        kHtmlBundleMimeType,
      );
    });

    test('bad files are rejected with a reason', () async {
      final noPage = writeZip('assets.zip', {'img.png': 'x'});
      final escape = writeZip('escape.zip', {
        'index.html': '<h1>x</h1>',
        '../outside.js': 'alert(1)',
      });
      final empty = File(p.join(temp.path, 'empty.html'))
        ..writeAsStringSync('');
      final pdf = File(p.join(temp.path, 'notes.pdf'))
        ..writeAsStringSync('%PDF');
      final broken = File(p.join(temp.path, 'broken.zip'))
        ..writeAsStringSync('not a zip');
      for (final file in [noPage, escape, empty, pdf, broken]) {
        await expectLater(
          InteractiveHtmlFiles.mimeTypeForImport(file.path),
          throwsA(isA<InteractiveHtmlException>()),
          reason: file.path,
        );
      }
    });
  });

  group('preparing pages', () {
    InteractiveHtmlFiles files() => InteractiveHtmlFiles(
      cacheRoot: () async => Directory(p.join(temp.path, 'cache')),
    );

    test('a single page is copied alone into its own folder', () async {
      final lessonDir = Directory(p.join(temp.path, 'lesson'))..createSync();
      final page = File(p.join(lessonDir.path, 'p1.html'))
        ..writeAsStringSync('<h1>One</h1>');
      File(p.join(lessonDir.path, 'secret.pdf')).writeAsStringSync('%PDF');

      final prepared = await files().prepare(
        materialId: 'm1',
        filePath: page.path,
        mimeType: kHtmlMimeType,
      );
      expect(prepared.entryPath, 'index.html');
      expect(prepared.root.listSync().map((e) => p.basename(e.path)), [
        'index.html',
      ]);
      expect(
        File(p.join(prepared.root.path, 'index.html')).readAsStringSync(),
        '<h1>One</h1>',
      );
    });

    test(
      'bundles unpack with folders and are rebuilt after a change',
      () async {
        final bundle = writeZip('b.zip', {
          'site/index.html': '<img src="img/a.png">',
          'site/img/a.png': 'png',
          'site/js/app.js': 'run()',
        });
        final cache = files();
        final first = await cache.prepare(
          materialId: 'm2',
          filePath: bundle.path,
          mimeType: kHtmlBundleMimeType,
        );
        expect(first.entryPath, 'site/index.html');
        expect(
          File(p.join(first.root.path, 'site', 'img', 'a.png')).existsSync(),
          isTrue,
        );
        final again = await cache.prepare(
          materialId: 'm2',
          filePath: bundle.path,
          mimeType: kHtmlBundleMimeType,
        );
        expect(again.root.path, first.root.path);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        writeZip('b.zip', {'index.html': '<h1>New</h1>', 'extra.css': 'a{}'});
        final rebuilt = await cache.prepare(
          materialId: 'm2',
          filePath: bundle.path,
          mimeType: kHtmlBundleMimeType,
        );
        expect(rebuilt.entryPath, 'index.html');
        expect(first.root.existsSync(), isFalse);

        await cache.clear('m2');
        expect(rebuilt.root.existsSync(), isFalse);
      },
    );
  });

  group('page server', () {
    late HtmlPageServer server;
    late PreparedHtmlPage page;

    setUp(() async {
      final root = Directory(p.join(temp.path, 'served'))..createSync();
      File(p.join(root.path, 'index.html')).writeAsStringSync('<h1>Hi</h1>');
      Directory(p.join(root.path, 'js')).createSync();
      File(p.join(root.path, 'js', 'app.js')).writeAsStringSync('go()');
      File(p.join(temp.path, 'outside.txt')).writeAsStringSync('private');
      page = PreparedHtmlPage(root: root, entryPath: 'index.html');
      server = await HtmlPageServer.start(materialId: 'material-a', page: page);
    });

    tearDown(() => server.close());

    Future<(int, String, String?)> get(Uri uri) async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        return (
          response.statusCode,
          body,
          response.headers.contentType?.mimeType,
        );
      } finally {
        client.close(force: true);
      }
    }

    test(
      'serves the page and its files on loopback with content types',
      () async {
        expect(server.entryUri.host, '127.0.0.1');
        final (status, body, type) = await get(server.entryUri);
        expect(status, 200);
        expect(body, '<h1>Hi</h1>');
        expect(type, 'text/html');

        final script = server.entryUri.resolve('js/app.js');
        final (scriptStatus, scriptBody, scriptType) = await get(script);
        expect(scriptStatus, 200);
        expect(scriptBody, 'go()');
        expect(scriptType, 'text/javascript');
        expect(server.owns(script), isTrue);
      },
    );

    test(
      'refuses paths without the token or outside the page folder',
      () async {
        final origin = Uri.parse(server.origin);
        expect((await get(origin.replace(path: '/index.html'))).$1, 404);
        final prefix = server.pagePrefix;
        expect((await get(Uri.parse('$prefix..%2Foutside.txt'))).$1, 404);
        expect((await get(Uri.parse('$prefix%2e%2e/outside.txt'))).$1, 404);
        expect(server.owns(origin.replace(path: '/index.html')), isFalse);
        expect(server.owns(Uri.parse('https://example.com/')), isFalse);
      },
    );

    test('each page keeps a stable port of its own', () async {
      expect(
        HtmlPageServer.preferredPort('material-a'),
        HtmlPageServer.preferredPort('material-a'),
      );
      expect(
        HtmlPageServer.preferredPort('material-a'),
        isNot(HtmlPageServer.preferredPort('material-b')),
      );
      expect(server.port, HtmlPageServer.preferredPort('material-a'));
      final other = await HtmlPageServer.start(
        materialId: 'material-b',
        page: page,
      );
      addTearDown(other.close);
      expect(other.origin, isNot(server.origin));
    });
  });

  group('repository', () {
    late AppDatabase db;
    late InteractiveHtmlRepository repository;

    setUp(() async {
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
          name: 'Subject',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insertLesson(
        LessonsCompanion.insert(
          id: 'l',
          subjectId: 's',
          name: 'Lesson',
          createdAt: now,
          updatedAt: now,
        ),
      );
      repository = InteractiveHtmlRepository(
        db,
        resolvePath: ({required lessonId, required storedFileName}) async {
          final dir = Directory(p.join(temp.path, 'lessons', lessonId))
            ..createSync(recursive: true);
          return p.join(dir.path, storedFileName);
        },
      );
    });

    tearDown(() => db.close());

    test(
      'pasted HTML is saved as a page material without its chat fence',
      () async {
        final material = await repository.createFromText(
          lessonId: 'l',
          title: 'Cell mind map',
          html: '```html\n<!DOCTYPE html>\n<script>go()</script>\n```',
        );
        expect(material.mimeType, kHtmlMimeType);
        expect(material.storedFileName, endsWith('.html'));
        expect(material.originalFileName, 'Cell_mind_map.html');
        final stored = File(
          p.join(temp.path, 'lessons', 'l', material.storedFileName),
        ).readAsStringSync();
        expect(stored, '<!DOCTYPE html>\n<script>go()</script>\n');
        expect(await repository.usesInternet(material), isFalse);
      },
    );

    test('an imported zip keeps its bundle as one stored file', () async {
      final zip = writeZip('mind-map.zip', {
        'index.html': '<script src="https://cdn.example.com/d3.js"></script>',
        'img/a.png': 'png',
      });
      final material = await repository.importFile(
        lessonId: 'l',
        sourcePath: zip.path,
        originalName: 'mind-map.zip',
      );
      expect(material.mimeType, kHtmlBundleMimeType);
      expect(material.title, 'mind-map');
      expect(material.storedFileName, endsWith('.zip'));
      expect(
        File(
          p.join(temp.path, 'lessons', 'l', material.storedFileName),
        ).lengthSync(),
        zip.lengthSync(),
      );
      expect(await repository.usesInternet(material), isTrue);
    });

    test('empty input is refused', () async {
      await expectLater(
        repository.createFromText(lessonId: 'l', title: ' ', html: '<p>x</p>'),
        throwsA(isA<InteractiveHtmlException>()),
      );
      await expectLater(
        repository.createFromText(lessonId: 'l', title: 'T', html: '  '),
        throwsA(isA<InteractiveHtmlException>()),
      );
    });
  });

  test('the Linux page window script is valid Python', () async {
    final script = File(p.join(temp.path, 'viewer.py'))
      ..writeAsStringSync(LinuxHtmlWindow.viewerScript);
    final result = await Process.run('python3', [
      '-m',
      'py_compile',
      script.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }, skip: Platform.isLinux ? false : 'Linux only');
}
