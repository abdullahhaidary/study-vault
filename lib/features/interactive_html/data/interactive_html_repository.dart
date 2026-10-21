import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/storage/material_storage.dart';
import '../../lessons/data/material_mime.dart';
import '../domain/html_bundle.dart';
import 'interactive_html_files.dart';

typedef MaterialPathResolver =
    Future<String> Function({
      required String lessonId,
      required String storedFileName,
    });

/// Creates interactive HTML lesson materials.
///
/// Pages are ordinary `lesson_materials` rows with an HTML MIME type, so they
/// sync, back up, and delete exactly like PDFs. The stored file is the page
/// itself (`.html`) or its bundle (`.zip`).
class InteractiveHtmlRepository {
  InteractiveHtmlRepository(
    this.db, {
    MaterialPathResolver? resolvePath,
    InteractiveHtmlFiles? files,
  }) : _resolvePath = resolvePath ?? MaterialStorage.absolutePath,
       files = files ?? InteractiveHtmlFiles();

  final AppDatabase db;
  final InteractiveHtmlFiles files;
  final MaterialPathResolver _resolvePath;
  static const _uuid = Uuid();

  /// Imports an `.html` page or a `.zip` bundle from [sourcePath].
  Future<LessonMaterial> importFile({
    required String lessonId,
    required String sourcePath,
    required String originalName,
    String? title,
  }) async {
    final mimeType = await InteractiveHtmlFiles.mimeTypeForImport(sourcePath);
    final id = _uuid.v4();
    final storedFileName =
        '$id${isHtmlBundleMimeType(mimeType) ? '.zip' : '.html'}';
    final target = await _resolvePath(
      lessonId: lessonId,
      storedFileName: storedFileName,
    );
    await File(sourcePath).copy(target);
    return _insert(
      id: id,
      lessonId: lessonId,
      title: _title(title, originalName),
      originalFileName: originalName,
      storedFileName: storedFileName,
      mimeType: mimeType,
    );
  }

  /// Saves pasted HTML as a single-page material.
  Future<LessonMaterial> createFromText({
    required String lessonId,
    required String title,
    required String html,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const InteractiveHtmlException('Enter a title for this page.');
    }
    final body = unwrapPastedHtml(html);
    if (body.trim().isEmpty) {
      throw const InteractiveHtmlException('Paste the HTML for this page.');
    }
    final bytes = utf8.encode(body);
    if (bytes.length > kMaxInteractiveHtmlBytes) {
      throw const InteractiveHtmlException(
        'The page is larger than 256 MiB, the sync limit for one file.',
      );
    }
    final id = _uuid.v4();
    final storedFileName = '$id.html';
    final target = await _resolvePath(
      lessonId: lessonId,
      storedFileName: storedFileName,
    );
    await File(target).writeAsBytes(bytes, flush: true);
    return _insert(
      id: id,
      lessonId: lessonId,
      title: trimmedTitle.length > 300
          ? trimmedTitle.substring(0, 300)
          : trimmedTitle,
      originalFileName: '${_safeFileStem(trimmedTitle)}.html',
      storedFileName: storedFileName,
      mimeType: kHtmlMimeType,
    );
  }

  /// Whether a stored page loads anything from the internet.
  Future<bool> usesInternet(LessonMaterial material) async {
    final path = await _resolvePath(
      lessonId: material.lessonId,
      storedFileName: material.storedFileName,
    );
    return InteractiveHtmlFiles.usesInternet(
      filePath: path,
      mimeType: material.mimeType,
    );
  }

  Future<LessonMaterial> _insert({
    required String id,
    required String lessonId,
    required String title,
    required String originalFileName,
    required String storedFileName,
    required String mimeType,
  }) async {
    final now = DateTime.now();
    await db.insertLessonMaterial(
      LessonMaterialsCompanion.insert(
        id: id,
        lessonId: lessonId,
        title: title,
        originalFileName: originalFileName,
        storedFileName: storedFileName,
        mimeType: Value(mimeType),
        sortOrder: Value(await db.nextMaterialSortOrder(lessonId)),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final created = await db.getMaterialById(id);
    if (created == null) {
      throw StateError('Failed to save the interactive page.');
    }
    return created;
  }

  static String _title(String? title, String originalName) {
    final chosen = title?.trim() ?? '';
    final value = chosen.isNotEmpty
        ? chosen
        : p.basenameWithoutExtension(originalName).trim();
    final safe = value.isEmpty ? 'Interactive page' : value;
    return safe.length > 300 ? safe.substring(0, 300) : safe;
  }

  static String _safeFileStem(String title) {
    final stem = title
        .replaceAll(RegExp(r'[^\w\s.-]', unicode: true), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    if (stem.isEmpty) return 'page';
    return stem.length > 80 ? stem.substring(0, 80) : stem;
  }
}

/// Removes a Markdown code fence around HTML copied from a chat answer.
String unwrapPastedHtml(String raw) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  final fenced = RegExp(
    r'^```[ \t]*(?:html|htm)?[ \t]*\n([\s\S]*?)\n```$',
    caseSensitive: false,
  ).firstMatch(text);
  final body = fenced?.group(1) ?? text;
  return body.endsWith('\n') ? body : '$body\n';
}

final interactiveHtmlRepositoryProvider = Provider<InteractiveHtmlRepository>((
  ref,
) {
  return InteractiveHtmlRepository(ref.watch(databaseProvider));
});

/// Whether one page needs the internet. Read from the stored file.
final htmlUsesInternetProvider = FutureProvider.family<bool, String>((
  ref,
  materialId,
) async {
  final db = ref.watch(databaseProvider);
  final material = await db.getMaterialById(materialId);
  if (material == null || !isInteractiveHtmlMimeType(material.mimeType)) {
    return false;
  }
  try {
    return await ref
        .watch(interactiveHtmlRepositoryProvider)
        .usesInternet(material);
  } on Object {
    return false;
  }
});
