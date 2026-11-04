import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/export/document_download.dart';

void main() {
  test('file names stay readable and keep a single extension', () {
    expect(
      DocumentDownload.fileNameFor('Cell Biology: Week 1', DocumentFileKind.pdf),
      'Cell Biology Week 1.pdf',
    );
    expect(
      DocumentDownload.fileNameFor('فیزیولوژی', DocumentFileKind.markdown),
      'فیزیولوژی.md',
    );
    expect(
      DocumentDownload.fileNameFor('  ', DocumentFileKind.plainText),
      'Study Vault.txt',
    );
    expect(
      DocumentDownload.withExtension('/tmp/notes', 'md'),
      '/tmp/notes.md',
    );
    expect(
      DocumentDownload.withExtension('/tmp/notes.MD', 'md'),
      '/tmp/notes.MD',
    );
  });

  test('markdown text is written to the chosen file', () async {
    final dir = await Directory.systemTemp.createTemp('sv_download');
    addTearDown(() => dir.delete(recursive: true));
    final port = _RecordingPort(destination: '${dir.path}/chosen');

    final result = await DocumentDownload(port: port).save(
      const DocumentTextRequest(fileName: 'Course Review', text: '# Review'),
    );

    expect(result, isA<DocumentDownloadSaved>());
    expect(
      await File('${dir.path}/chosen.md').readAsString(),
      '# Review',
    );
    expect(port.dialogTitle, 'Save Markdown');
    expect(port.suggestedName, 'Course Review.md');
  });

  test('a PDF is copied and the original stays in place', () async {
    final dir = await Directory.systemTemp.createTemp('sv_download_pdf');
    addTearDown(() => dir.delete(recursive: true));
    final source = File('${dir.path}/stored.pdf')..writeAsStringSync('pdf-bytes');
    final port = _RecordingPort(destination: '${dir.path}/saved');

    final result = await DocumentDownload(port: port).save(
      DocumentFileRequest(
        fileName: 'Lecture 1',
        sourcePath: source.path,
        kind: DocumentFileKind.pdf,
      ),
    );

    expect((result as DocumentDownloadSaved).path, '${dir.path}/saved.pdf');
    expect(await File('${dir.path}/saved.pdf').readAsString(), 'pdf-bytes');
    expect(await source.readAsString(), 'pdf-bytes');
  });

  test('cancelling the save dialog leaves no file', () async {
    final dir = await Directory.systemTemp.createTemp('sv_download_cancel');
    addTearDown(() => dir.delete(recursive: true));
    final result = await DocumentDownload(
      port: _RecordingPort(),
    ).save(const DocumentTextRequest(fileName: 'Notes', text: 'hello'));

    expect(result, isA<DocumentDownloadCancelled>());
    expect(dir.listSync(), isEmpty);
  });

  test('phones share the file under the readable name', () async {
    final dir = await Directory.systemTemp.createTemp('sv_download_share');
    addTearDown(() => dir.delete(recursive: true));
    final source = File('${dir.path}/id.pdf')..writeAsStringSync('%PDF');
    final port = _RecordingPort(share: true);

    final result = await DocumentDownload(port: port).save(
      DocumentFileRequest(
        fileName: 'Lecture',
        sourcePath: source.path,
        kind: DocumentFileKind.pdf,
      ),
    );

    expect(result, isA<DocumentDownloadShared>());
    expect(port.sharedPath, source.path);
    expect(port.sharedName, 'Lecture.pdf');
    expect(port.sharedMime, 'application/pdf');
  });

  test('a missing file is reported before a destination is chosen', () async {
    final port = _RecordingPort(destination: '/tmp/should-not-be-used');
    expect(
      () => DocumentDownload(port: port).save(
        const DocumentFileRequest(
          fileName: 'Gone',
          sourcePath: '/tmp/study-vault-missing-download.pdf',
          kind: DocumentFileKind.pdf,
        ),
      ),
      throwsA(
        isA<DocumentDownloadException>().having(
          (error) => error.message,
          'message',
          'The file is not on this device.',
        ),
      ),
    );
    expect(port.dialogTitle, isNull);
  });
}

class _RecordingPort implements DocumentSavePort {
  _RecordingPort({this.destination, this.share = false});

  final String? destination;
  final bool share;
  String? dialogTitle;
  String? suggestedName;
  String? sharedPath;
  String? sharedName;
  String? sharedMime;

  @override
  bool get usesSystemShare => share;

  @override
  Future<String?> chooseSavePath({
    required String dialogTitle,
    required String fileName,
    required String extension,
  }) async {
    this.dialogTitle = dialogTitle;
    suggestedName = fileName;
    return destination;
  }

  @override
  Future<bool> shareFile({
    required String path,
    required String fileName,
    required String mimeType,
  }) async {
    sharedPath = path;
    sharedName = fileName;
    sharedMime = mimeType;
    return true;
  }
}
