import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:drift/native.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/features/ai_assistant/domain/ai_execution_selection.dart';
import 'package:study_vault/features/lessons/data/materials_providers.dart';
import 'package:study_vault/features/pdf_ai_materials/services/pdf_ai_material_service.dart';

class _UnusedClient implements PdfAiCompletionClient {
  @override
  Future<PdfAiCompletion> complete({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('text document mime helpers', () {
    test('recognizes markdown and plain text as documents', () {
      expect(isMarkdownMimeType(kMarkdownMimeType), isTrue);
      expect(isPlainTextMimeType(kPlainTextMimeType), isTrue);
      expect(isTextDocumentMimeType(kMarkdownMimeType), isTrue);
      expect(isDocumentMimeType(kMarkdownMimeType), isTrue);
      expect(isDocumentMimeType('application/pdf'), isTrue);
      expect(isDocumentMimeType('image/png'), isFalse);
      expect(guessMimeType('notes.md'), kMarkdownMimeType);
      expect(guessMimeType('notes.txt'), kPlainTextMimeType);
      expect(materialKindLabel(kMarkdownMimeType), 'Markdown');
    });

    test('detects text paths by extension', () {
      expect(isTextDocumentPath('/x/a.md'), isTrue);
      expect(isTextDocumentPath('/x/a.markdown'), isTrue);
      expect(isTextDocumentPath('/x/a.txt'), isTrue);
      expect(isTextDocumentPath('/x/a.pdf'), isFalse);
    });
  });

  group('PdfAiMaterialService.prepareDocument for markdown', () {
    late Directory tempDir;
    late AppDatabase db;
    late PdfAiMaterialService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sv-md-');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = PdfAiMaterialService(db, _UnusedClient());
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reads markdown file as a single-page document', () async {
      final path = p.join(tempDir.path, 'lecture.md');
      await File(path).writeAsString('# HTML\n\nAll the tags.\n');

      final document = await service.prepareDocument(
        title: 'HTML notes',
        filePath: path,
      );

      expect(document.pages, hasLength(1));
      expect(document.pages.single.pageNumber, 1);
      expect(document.pages.single.text, contains('# HTML'));
      expect(document.extractedCharacterCount, greaterThan(0));
      expect(document.stableDocument, contains('DOCUMENT: HTML notes'));
      expect(document.sourceFingerprint, isNotEmpty);
    });

    test('rejects empty markdown', () async {
      final path = p.join(tempDir.path, 'empty.md');
      await File(path).writeAsString('   \n');
      expect(
        () => service.prepareDocument(title: 'Empty', filePath: path),
        throwsA(isA<StateError>()),
      );
    });
  });
}
