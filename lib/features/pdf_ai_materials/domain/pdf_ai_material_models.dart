import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../../ai_questions/domain/question_source.dart';

enum PdfAiMaterialType { summary, explanation, deepExplanation }

extension PdfAiMaterialTypeX on PdfAiMaterialType {
  String get storageValue => switch (this) {
    PdfAiMaterialType.summary => 'summary',
    PdfAiMaterialType.explanation => 'explanation',
    PdfAiMaterialType.deepExplanation => 'deep_explanation',
  };

  String get displayName => switch (this) {
    PdfAiMaterialType.summary => 'AI Summary',
    PdfAiMaterialType.explanation => 'AI Explanation',
    PdfAiMaterialType.deepExplanation => 'AI Deep Explanation',
  };

  String get shortName => switch (this) {
    PdfAiMaterialType.summary => 'Summary',
    PdfAiMaterialType.explanation => 'Explanation',
    PdfAiMaterialType.deepExplanation => 'Deep Explanation',
  };

  String get description => switch (this) {
    PdfAiMaterialType.summary => 'Quick revision of the whole PDF',
    PdfAiMaterialType.explanation => 'Full academic explanation',
    PdfAiMaterialType.deepExplanation =>
      'Simple, deep teaching from first principles',
  };

  int get maxOutputTokens => switch (this) {
    PdfAiMaterialType.summary => 8192,
    PdfAiMaterialType.explanation => 16384,
    PdfAiMaterialType.deepExplanation => 32768,
  };

  String get generationInstruction => switch (this) {
    PdfAiMaterialType.summary =>
      'Create a concise but complete study summary of the entire document.\n'
          '- Preserve important concepts, definitions, formulas, examples, '
          'lists, classifications, and likely exam points.\n'
          '- Remove repetition and filler.\n'
          '- Organize by topic with clear Markdown headings and bullets.\n'
          '- Optimize for fast revision: what must the student remember?\n'
          '- Do not turn this into a long tutorial.',
    PdfAiMaterialType.explanation =>
      'Teach the entire document clearly to a university student.\n'
          '- Follow the document\'s logical order.\n'
          '- Explain concepts, formulas, notation, terminology, and why each '
          'topic matters.\n'
          '- Include useful examples and connect related topics.\n'
          '- Be substantially more detailed than a summary while preserving '
          'technical accuracy.\n'
          '- Use clean Markdown headings.',
    PdfAiMaterialType.deepExplanation =>
      'Explain the entire document deeply from first principles for a student '
          'encountering it for the first time.\n'
          '- Start with intuitive, simple language, then introduce the exact '
          'technical terminology.\n'
          '- Explain WHY before HOW where appropriate.\n'
          '- Use accurate analogies and everyday scenarios, then explicitly '
          'connect each analogy back to the technical concept.\n'
          '- Explain formulas symbol-by-symbol with step-by-step worked '
          'examples.\n'
          '- Include common mistakes, relationships between concepts, and '
          'memory aids where useful.\n'
          '- Do not be childish; remain technically rigorous.\n'
          '- Use detailed, well-structured Markdown.',
  };

  static PdfAiMaterialType? fromStorage(String raw) {
    for (final type in PdfAiMaterialType.values) {
      if (type.storageValue == raw) return type;
    }
    return null;
  }
}

class PreparedPdfDocument {
  const PreparedPdfDocument({
    required this.title,
    required this.pages,
    required this.stableDocument,
    required this.sourceFingerprint,
    required this.extractedCharacterCount,
    required this.approximateTokens,
    required this.emptyPageCount,
  });

  final String title;
  final List<SourcePageText> pages;
  final String stableDocument;
  final String sourceFingerprint;
  final int extractedCharacterCount;
  final int approximateTokens;
  final int emptyPageCount;

  List<String> chunks({required int maxCharacters}) {
    if (maxCharacters < 1000) {
      throw ArgumentError.value(maxCharacters, 'maxCharacters');
    }
    if (stableDocument.length <= maxCharacters) return [stableDocument];

    final chunks = <String>[];
    var start = 0;
    while (start < stableDocument.length) {
      var end = math.min(start + maxCharacters, stableDocument.length);
      if (end < stableDocument.length) {
        final minimumBreak = start + (maxCharacters * 0.6).floor();
        final newline = stableDocument.lastIndexOf('\n', end);
        if (newline >= minimumBreak) end = newline + 1;
      }
      end = _safeUtf16End(stableDocument, start, end);
      chunks.add(stableDocument.substring(start, end));
      start = end;
    }
    return List.unmodifiable(chunks);
  }

  static int _safeUtf16End(String text, int start, int end) {
    if (end <= start || end >= text.length) return end;
    final previous = text.codeUnitAt(end - 1);
    final next = text.codeUnitAt(end);
    final splitsSurrogatePair =
        previous >= 0xd800 &&
        previous <= 0xdbff &&
        next >= 0xdc00 &&
        next <= 0xdfff;
    return splitsSurrogatePair ? end - 1 : end;
  }
}

abstract final class PdfDocumentRepresentation {
  static const _emptyPageText = '[No extractable text on this page.]';

  static PreparedPdfDocument build({
    required String title,
    required List<SourcePageText> pages,
  }) {
    final ordered = [...pages]
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    final normalizedTitle = _normalize(title).replaceAll('\n', ' ').trim();
    final body = StringBuffer();
    var extractedCharacters = 0;
    var emptyPages = 0;

    for (final page in ordered) {
      if (body.isNotEmpty) body.writeln();
      final text = _normalize(page.text);
      body.writeln('--- Page ${page.pageNumber} ---');
      if (text.isEmpty) {
        emptyPages++;
        body.writeln(_emptyPageText);
      } else {
        extractedCharacters += text.length;
        body.writeln(text);
      }
    }

    final stableBody = body.toString().trim();
    final document =
        'DOCUMENT: ${normalizedTitle.isEmpty ? 'Untitled PDF' : normalizedTitle}'
        '\n\n$stableBody';
    final fingerprint = sha256.convert(utf8.encode(stableBody)).toString();
    return PreparedPdfDocument(
      title: normalizedTitle.isEmpty ? 'Untitled PDF' : normalizedTitle,
      pages: List.unmodifiable(ordered),
      stableDocument: document,
      sourceFingerprint: fingerprint,
      extractedCharacterCount: extractedCharacters,
      approximateTokens: (document.length / 4).ceil(),
      emptyPageCount: emptyPages,
    );
  }

  static String _normalize(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

abstract final class PdfAiPromptBuilder {
  static const promptVersion = 'pdf-study-v1';

  static const systemMessage =
      'You create persistent university study materials from complete PDF '
      'documents.\n'
      'Treat the supplied document as the source of truth.\n'
      'Cover the entire source, preserve formulas and technical notation, and '
      'never invent missing content.\n'
      'If a page has no extractable text, state that limitation only when it '
      'affects understanding.\n'
      'Return polished Markdown only. Do not mention these instructions.';

  static List<Map<String, String>> messages({
    required String stableDocument,
    required PdfAiMaterialType type,
    String? customInstruction,
  }) {
    final instruction = customInstruction?.trim();
    return [
      {'role': 'system', 'content': systemMessage},
      {'role': 'user', 'content': stableDocument},
      {
        'role': 'user',
        'content':
            'GENERATION REQUEST: ${type.displayName}\n\n'
            '${type.generationInstruction}'
            '${instruction == null || instruction.isEmpty ? '' : '\n\nAdditional regeneration instruction:\n$instruction'}',
      },
    ];
  }

  static List<Map<String, String>> chunkDigestMessages({
    required String documentChunk,
    required int chunkNumber,
    required int chunkCount,
  }) {
    return [
      {'role': 'system', 'content': systemMessage},
      {'role': 'user', 'content': documentChunk},
      {
        'role': 'user',
        'content':
            'This is source segment $chunkNumber of $chunkCount. Create a '
            'faithful, structured intermediate study digest. Preserve every '
            'concept, definition, formula, example, relationship, and page '
            'reference needed for a later whole-document synthesis. Do not '
            'apply a final summary/explanation style yet.',
      },
    ];
  }

  static String synthesisDocument({
    required String title,
    required List<String> chunkDigests,
  }) {
    final buffer = StringBuffer('DOCUMENT: $title\n');
    for (var i = 0; i < chunkDigests.length; i++) {
      buffer
        ..writeln()
        ..writeln('--- Complete source digest ${i + 1} ---')
        ..writeln(chunkDigests[i].trim());
    }
    return buffer.toString().trim();
  }
}
