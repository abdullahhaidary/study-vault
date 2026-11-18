import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../backup/backup_io.dart';

enum DocumentFileKind { pdf, markdown, plainText }

/// A PDF or text document the user can save outside the app.
sealed class DocumentDownloadRequest {
  const DocumentDownloadRequest({required this.fileName, required this.kind});

  final String fileName;
  final DocumentFileKind kind;
}

class DocumentFileRequest extends DocumentDownloadRequest {
  const DocumentFileRequest({
    required super.fileName,
    required this.sourcePath,
    required super.kind,
  });

  final String sourcePath;
}

class DocumentTextRequest extends DocumentDownloadRequest {
  const DocumentTextRequest({
    required super.fileName,
    required this.text,
    super.kind = DocumentFileKind.markdown,
  });

  final String text;
}

sealed class DocumentDownloadResult {
  const DocumentDownloadResult();
}

class DocumentDownloadCancelled extends DocumentDownloadResult {
  const DocumentDownloadCancelled();
}

class DocumentDownloadSaved extends DocumentDownloadResult {
  const DocumentDownloadSaved(this.path);

  final String path;
}

class DocumentDownloadShared extends DocumentDownloadResult {
  const DocumentDownloadShared(this.fileName);

  final String fileName;
}

class DocumentDownloadException implements Exception {
  const DocumentDownloadException(this.message);

  final String message;
}

/// Saves a file with the platform's own destination picker.
abstract interface class DocumentSavePort {
  /// Phones hand the file to the system share sheet. Computers use a save dialog.
  bool get usesSystemShare;

  Future<String?> chooseSavePath({
    required String dialogTitle,
    required String fileName,
    required String extension,
  });

  /// Returns false when the user dismisses the sheet.
  Future<bool> shareFile({
    required String path,
    required String fileName,
    required String mimeType,
  });
}

class PlatformDocumentSavePort implements DocumentSavePort {
  const PlatformDocumentSavePort();

  @override
  bool get usesSystemShare => Platform.isAndroid || Platform.isIOS;

  @override
  Future<String?> chooseSavePath({
    required String dialogTitle,
    required String fileName,
    required String extension,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
  }

  @override
  Future<bool> shareFile({
    required String path,
    required String fileName,
    required String mimeType,
  }) async {
    final result = await Share.shareXFiles(
      [XFile(path, mimeType: mimeType, name: fileName)],
      subject: 'StudyDesk',
    );
    return result.status != ShareResultStatus.dismissed;
  }
}

/// Copies a study PDF or Markdown file to a place the user chooses.
class DocumentDownload {
  const DocumentDownload({this.port = const PlatformDocumentSavePort()});

  final DocumentSavePort port;

  static String extensionFor(DocumentFileKind kind) => switch (kind) {
    DocumentFileKind.pdf => 'pdf',
    DocumentFileKind.markdown => 'md',
    DocumentFileKind.plainText => 'txt',
  };

  static String mimeTypeFor(DocumentFileKind kind) => switch (kind) {
    DocumentFileKind.pdf => 'application/pdf',
    DocumentFileKind.markdown => 'text/markdown',
    DocumentFileKind.plainText => 'text/plain',
  };

  static String dialogTitleFor(DocumentFileKind kind) => switch (kind) {
    DocumentFileKind.pdf => 'Save PDF',
    DocumentFileKind.markdown => 'Save Markdown',
    DocumentFileKind.plainText => 'Save text',
  };

  /// A file name that is safe on phones and computers.
  static String fileNameFor(String title, DocumentFileKind kind) {
    final cleaned = title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    final limited = cleaned.length > 80
        ? cleaned.substring(0, 80).trim()
        : cleaned;
    final stem = limited.isEmpty ? 'StudyDesk' : limited;
    return '$stem.${extensionFor(kind)}';
  }

  static String withExtension(String path, String extension) {
    final suffix = '.${extension.toLowerCase()}';
    if (p.extension(path).toLowerCase() == suffix) return path;
    return '$path$suffix';
  }

  Future<DocumentDownloadResult> save(DocumentDownloadRequest request) async {
    final fileName = fileNameFor(request.fileName, request.kind);
    final extension = extensionFor(request.kind);
    Directory? staging;

    try {
      final File source;
      switch (request) {
        case DocumentTextRequest(:final text):
          staging = await Directory.systemTemp.createTemp('sv_download_');
          source = File(p.join(staging.path, fileName));
          await source.writeAsString(text, flush: true);
        case DocumentFileRequest(:final sourcePath):
          source = File(sourcePath);
          if (!await source.exists()) {
            throw const DocumentDownloadException(
              'The file is not on this device.',
            );
          }
      }

      if (port.usesSystemShare) {
        final shared = await port.shareFile(
          path: source.path,
          fileName: fileName,
          mimeType: mimeTypeFor(request.kind),
        );
        if (!shared) return const DocumentDownloadCancelled();
        return DocumentDownloadShared(fileName);
      }

      final chosen = await port.chooseSavePath(
        dialogTitle: dialogTitleFor(request.kind),
        fileName: fileName,
        extension: extension,
      );
      if (chosen == null) return const DocumentDownloadCancelled();

      final destinationPath = withExtension(chosen, extension);
      if (p.equals(p.normalize(source.path), p.normalize(destinationPath))) {
        throw const DocumentDownloadException(
          'Choose a different place to save the file.',
        );
      }
      await copyFileStreaming(source, File(destinationPath));
      return DocumentDownloadSaved(destinationPath);
    } finally {
      if (staging != null) await deleteIfExists(staging);
    }
  }
}
