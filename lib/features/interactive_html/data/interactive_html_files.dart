import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../lessons/data/material_mime.dart';
import '../domain/html_bundle.dart';

/// A page unpacked into its own private folder, ready to serve.
class PreparedHtmlPage {
  const PreparedHtmlPage({required this.root, required this.entryPath});

  /// Folder that holds only this page's files.
  final Directory root;

  /// Start page, relative to [root], with `/` separators.
  final String entryPath;
}

/// Reads stored interactive pages and unpacks them for viewing.
///
/// A single page is copied into its own folder so the page can never request
/// the lesson's other files. Bundles are unpacked with zip-slip and size
/// checks. Unpacked copies live in a cache and are rebuilt when the stored
/// file changes.
class InteractiveHtmlFiles {
  InteractiveHtmlFiles({Future<Directory> Function()? cacheRoot})
    : _cacheRoot = cacheRoot ?? _defaultCacheRoot;

  final Future<Directory> Function() _cacheRoot;

  static Future<Directory> _defaultCacheRoot() async {
    final temp = await getTemporaryDirectory();
    return Directory(p.join(temp.path, 'study_vault_html'));
  }

  /// Checks a file before import and returns its material MIME type.
  static Future<String> mimeTypeForImport(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw const InteractiveHtmlException('The selected file is missing.');
    }
    final length = await file.length();
    if (length == 0) {
      throw const InteractiveHtmlException('The selected file is empty.');
    }
    if (length > kMaxInteractiveHtmlBytes) {
      throw const InteractiveHtmlException(
        'The file is larger than 256 MiB, the sync limit for one file.',
      );
    }
    final ext = p.extension(sourcePath).toLowerCase();
    if (ext == '.html' || ext == '.htm') return kHtmlMimeType;
    if (ext == '.zip') {
      _readBundle(sourcePath, (archive, entries) {
        HtmlBundleLayout.entryPage(entries.keys);
      });
      return kHtmlBundleMimeType;
    }
    throw const InteractiveHtmlException(
      'Choose an .html file or a .zip that contains index.html.',
    );
  }

  /// Whether the stored page loads anything from the internet.
  static Future<bool> usesInternet({
    required String filePath,
    required String mimeType,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    if (isHtmlPageMimeType(mimeType)) {
      return HtmlInternetScan.usesInternet(await _readText(file));
    }
    if (!isHtmlBundleMimeType(mimeType)) return false;
    var found = false;
    _readBundle(filePath, (archive, entries) {
      for (final entry in entries.entries) {
        if (!HtmlBundleLayout.isScannableText(entry.key)) continue;
        final bytes = entry.value.readBytes();
        if (bytes == null) continue;
        final text = utf8.decode(bytes, allowMalformed: true);
        if (HtmlInternetScan.usesInternet(text)) {
          found = true;
          return;
        }
      }
    });
    return found;
  }

  /// Unpacks [filePath] for [materialId] and returns where to serve it from.
  Future<PreparedHtmlPage> prepare({
    required String materialId,
    required String filePath,
    required String mimeType,
  }) async {
    final source = File(filePath);
    if (!await source.exists()) {
      throw const InteractiveHtmlException(
        'This page’s file is not on this device yet. Sync or restore it first.',
      );
    }
    final stat = await source.stat();
    final stamp = '${stat.size}-${stat.modified.millisecondsSinceEpoch}';
    final materialDir = Directory(
      p.join((await _cacheRoot()).path, materialId),
    );
    final root = Directory(p.join(materialDir.path, stamp));
    final marker = File(p.join(materialDir.path, '$stamp.entry'));

    if (await marker.exists() && await root.exists()) {
      return PreparedHtmlPage(
        root: root,
        entryPath: (await marker.readAsString()).trim(),
      );
    }
    if (await materialDir.exists()) {
      await materialDir.delete(recursive: true);
    }
    await root.create(recursive: true);

    final String entry;
    if (isHtmlPageMimeType(mimeType)) {
      entry = 'index.html';
      await source.copy(p.join(root.path, entry));
    } else if (isHtmlBundleMimeType(mimeType)) {
      entry = _extractBundle(filePath, root);
    } else {
      throw const InteractiveHtmlException('This material is not a web page.');
    }
    await marker.writeAsString(entry, flush: true);
    return PreparedHtmlPage(root: root, entryPath: entry);
  }

  /// Removes the unpacked copy of one page.
  Future<void> clear(String materialId) async {
    final dir = Directory(p.join((await _cacheRoot()).path, materialId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static String _extractBundle(String zipPath, Directory root) {
    late String entry;
    _readBundle(zipPath, (archive, entries) {
      entry = HtmlBundleLayout.entryPage(entries.keys);
      for (final item in entries.entries) {
        final target = p.joinAll([root.path, ...item.key.split('/')]);
        if (!p.isWithin(root.path, target)) {
          throw const InteractiveHtmlException(
            'The zip contains a file outside its folder.',
          );
        }
        Directory(p.dirname(target)).createSync(recursive: true);
        final output = OutputFileStream(target);
        try {
          item.value.writeContent(output);
        } finally {
          output.closeSync();
        }
      }
    });
    return entry;
  }

  /// Opens a bundle and passes its safe file entries, keyed by relative path.
  static void _readBundle(
    String zipPath,
    void Function(Archive archive, Map<String, ArchiveFile> entries) read,
  ) {
    final input = InputFileStream(zipPath);
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } on Object {
        throw const InteractiveHtmlException('The zip file could not be read.');
      }
      final entries = <String, ArchiveFile>{};
      var total = 0;
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final path = HtmlBundleLayout.safeEntryPath(file.name);
        if (path == null) {
          if (file.name.contains('..') || file.name.startsWith('/')) {
            throw const InteractiveHtmlException(
              'The zip contains a file outside its folder.',
            );
          }
          continue;
        }
        total += file.size;
        if (entries.length >= kMaxHtmlBundleEntries) {
          throw const InteractiveHtmlException(
            'The zip has more than 5000 files.',
          );
        }
        if (total > kMaxUnpackedHtmlBundleBytes) {
          throw const InteractiveHtmlException(
            'The zip unpacks to more than 512 MiB.',
          );
        }
        entries[path] = file;
      }
      read(archive, entries);
    } finally {
      input.closeSync();
    }
  }

  static Future<String> _readText(File file) async {
    return utf8.decode(await file.readAsBytes(), allowMalformed: true);
  }
}
