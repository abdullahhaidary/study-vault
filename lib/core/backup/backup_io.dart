import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Streaming SHA-256 of a file without loading it fully into memory.
Future<String> sha256File(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

String sha256Utf8(String value) =>
    sha256.convert(utf8.encode(value)).toString();

/// Build a stable index string used for materials integrity checks.
///
/// Format (one line per file, sorted): `relativePosixPath\tbyteSize`
String buildFilesIndex(List<({String relativePath, int size})> entries) {
  final lines = entries.map((e) => '${e.relativePath}\t${e.size}').toList()
    ..sort();
  return '${lines.join('\n')}\n';
}

/// List all files under [root] with POSIX relative paths.
Future<List<({File file, String relativePath, int size})>> listFilesRecursive(
  Directory root,
) async {
  if (!await root.exists()) return const [];

  final results = <({File file, String relativePath, int size})>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: root.path);
    final posix = p.posix.fromUri(p.toUri(rel));
    final size = await entity.length();
    results.add((file: entity, relativePath: posix, size: size));
  }
  results.sort((a, b) => a.relativePath.compareTo(b.relativePath));
  return results;
}

String suggestedBackupFileName(DateTime when) {
  final local = when.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'StudyVault-'
      '${local.year}-${two(local.month)}-${two(local.day)}-'
      '${two(local.hour)}${two(local.minute)}.svbackup';
}

Future<void> copyFileStreaming(File source, File destination) async {
  await destination.parent.create(recursive: true);
  final sink = destination.openWrite();
  try {
    await source.openRead().pipe(sink);
  } finally {
    await sink.close();
  }
}

Future<void> copyDirectoryStreaming(
  Directory source,
  Directory destination,
) async {
  if (!await source.exists()) {
    await destination.create(recursive: true);
    return;
  }
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: source.path);
    final targetPath = p.join(destination.path, rel);
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      await copyFileStreaming(entity, File(targetPath));
    }
  }
}

Future<void> deleteIfExists(FileSystemEntity entity) async {
  if (await entity.exists()) {
    await entity.delete(recursive: true);
  }
}
