import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../../../core/markdown/chart_spec.dart';
import '../../ai_questions/domain/question_source.dart';

enum PdfAiMaterialType {
  summary,
  explanation,
  deepExplanation,
  realWorldExamples,
  slideshow,
}

extension PdfAiMaterialTypeX on PdfAiMaterialType {
  String get storageValue => switch (this) {
    PdfAiMaterialType.summary => 'summary',
    PdfAiMaterialType.explanation => 'explanation',
    PdfAiMaterialType.deepExplanation => 'deep_explanation',
    PdfAiMaterialType.realWorldExamples => 'real_world_examples',
    PdfAiMaterialType.slideshow => 'slideshow',
  };

  String get displayName => switch (this) {
    PdfAiMaterialType.summary => 'AI Summary',
    PdfAiMaterialType.explanation => 'AI Explanation',
    PdfAiMaterialType.deepExplanation => 'AI Deep Explanation',
    PdfAiMaterialType.realWorldExamples => 'AI Real-World Examples',
    PdfAiMaterialType.slideshow => 'AI Slideshow',
  };

  String get shortName => switch (this) {
    PdfAiMaterialType.summary => 'Summary',
    PdfAiMaterialType.explanation => 'Explanation',
    PdfAiMaterialType.deepExplanation => 'Deep Explanation',
    PdfAiMaterialType.realWorldExamples => 'Real-World Examples',
    PdfAiMaterialType.slideshow => 'Slideshow',
  };

  String get description => switch (this) {
    PdfAiMaterialType.summary => 'Quick revision of the whole PDF',
    PdfAiMaterialType.explanation => 'Full academic explanation',
    PdfAiMaterialType.deepExplanation =>
      'Simple, deep teaching from first principles',
    PdfAiMaterialType.realWorldExamples =>
      'Concrete scenarios and case studies mapped to each topic',
    PdfAiMaterialType.slideshow =>
      'A slide-by-slide presentation of the whole PDF',
  };

  int get maxOutputTokens => switch (this) {
    PdfAiMaterialType.summary => 8192,
    PdfAiMaterialType.explanation => 16384,
    PdfAiMaterialType.deepExplanation => 32768,
    PdfAiMaterialType.realWorldExamples => 16384,
    PdfAiMaterialType.slideshow => 16384,
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
    PdfAiMaterialType.realWorldExamples =>
      'Show how the document\'s topics appear in the real world. Focus ONLY '
          'on concrete scenarios, case studies, and worked examples; do not '
          're-teach the theory.\n'
          '- Start with "## Topic map": a Markdown table with columns '
          '"Topic" (as named in the document, with page numbers) and '
          '"Real-world examples" (the example titles for that topic).\n'
          '- Then, for every major topic in source order, write a section '
          '"## <Topic name> (p. N)" containing 1–3 examples, each under a '
          '"### Example: <short title>" heading with:\n'
          '  - **Scenario** – a specific, realistic situation (industry, '
          'everyday life, research, engineering, business, medicine, etc.).\n'
          '  - **How the concept applies** – walk through the scenario using '
          'the document\'s exact terms, formulas, and notation; include '
          'realistic numbers and the calculation when the topic is '
          'quantitative.\n'
          '  - **Mapping to the theory** – bullet list pairing each element '
          'of the scenario with the corresponding concept/term/formula from '
          'the document.\n'
          '  - **Try it yourself** – one short variation of the scenario for '
          'the student to reason about (no answer needed).\n'
          '- Prefer well-known, verifiable examples; when inventing a '
          'scenario, keep it plausible and clearly hypothetical.\n'
          '- Cover every topic in the document; do not skip minor topics—'
          'give them at least one brief example.\n'
          '- Do not add introductions, summaries, or theory recaps outside '
          'the structure above.',
    PdfAiMaterialType.slideshow =>
      'Create a presentation for studying the entire document, in source order.\n'
          '- Use one focused idea per slide, with a short descriptive title, '
          'concise bullet points, and a formula or example when useful.\n'
          '- Cover all important concepts, definitions, relationships, and '
          'likely exam points without inventing content.\n'
          '- Aim for 8–20 slides, but use more if needed to cover a long PDF.\n'
          '- Start every slide with a Markdown heading such as '
          '"# Slide 1: Introduction".\n'
          '- Put exactly <!-- slide --> on its own line between slides. '
          'Do not put this marker elsewhere or add text outside the slides.\n'
          '- Keep each slide readable on a phone; avoid long paragraphs.',
  };

  static PdfAiMaterialType? fromStorage(String raw) {
    for (final type in PdfAiMaterialType.values) {
      if (type.storageValue == raw) return type;
    }
    return null;
  }
}

/// Preset regenerate choices shown before a new version is requested.
enum PdfAiRegeneratePreset {
  reformatOnly,
  shorter,
  moreDetailed,
  focusFormulas,
}

extension PdfAiRegeneratePresetX on PdfAiRegeneratePreset {
  String get label => switch (this) {
    PdfAiRegeneratePreset.reformatOnly => 'Reformat only',
    PdfAiRegeneratePreset.shorter => 'Shorter',
    PdfAiRegeneratePreset.moreDetailed => 'More detailed',
    PdfAiRegeneratePreset.focusFormulas => 'Focus on formulas',
  };

  String get description => switch (this) {
    PdfAiRegeneratePreset.reformatOnly =>
      'Keep every fact, example, and idea. Only fix Markdown, charts, '
          'headings, and reading flow so pasted ChatGPT-style output matches '
          'this study format.',
    PdfAiRegeneratePreset.shorter =>
      'Regenerate from the PDF, but make it more concise.',
    PdfAiRegeneratePreset.moreDetailed =>
      'Regenerate from the PDF with more explanation and examples.',
    PdfAiRegeneratePreset.focusFormulas =>
      'Regenerate from the PDF with more emphasis on formulas and notation.',
  };

  bool get usesCurrentContent => this == PdfAiRegeneratePreset.reformatOnly;

  String? get pdfInstruction => switch (this) {
    PdfAiRegeneratePreset.reformatOnly => null,
    PdfAiRegeneratePreset.shorter =>
      'Make it shorter and denser. Remove filler while keeping every '
          'important concept, formula, and exam point.',
    PdfAiRegeneratePreset.moreDetailed =>
      'Add more explanation, worked examples, and connections between '
          'topics without inventing content that is not in the source.',
    PdfAiRegeneratePreset.focusFormulas =>
      'Focus more on formulas, notation, and step-by-step calculations.',
  };
}

abstract final class PdfAiSlideDeck {
  static List<String> parse(String content) {
    final markdown = content.trim();
    if (markdown.isEmpty) return const [];
    final marker = RegExp(
      r'^[ \t]*<!--[ \t]*slide[ \t]*-->[ \t]*$',
      multiLine: true,
      caseSensitive: false,
    );
    final separated = markdown
        .split(marker)
        .map((slide) => slide.trim())
        .where((slide) => slide.isNotEmpty)
        .toList();
    if (separated.length > 1) return separated;

    final headings = RegExp(
      r'^#{1,2}[ \t]+slide[ \t]+[0-9]+(?:[ \t]*[:.\-–])?',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(markdown).toList();
    if (headings.length < 2) return [markdown];
    return [
      for (var i = 0; i < headings.length; i++)
        markdown
            .substring(
              i == 0 ? 0 : headings[i].start,
              i + 1 < headings.length ? headings[i + 1].start : markdown.length,
            )
            .trim(),
    ];
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

  static List<Map<String, String>> reformatMessages({
    required PdfAiMaterialType type,
    required String currentMarkdown,
    String? extraInstruction,
  }) {
    final extra = extraInstruction?.trim();
    return [
      {'role': 'system', 'content': systemMessage},
      {
        'role': 'user',
        'content': 'CURRENT STUDY MATERIAL:\n${currentMarkdown.trim()}',
      },
      {
        'role': 'user',
        'content':
            'REFORMAT REQUEST: ${type.displayName}\n\n'
            'Keep every fact, example, formula, definition, and idea. Do not '
            'add new topics, drop existing ones, or change meaning. Content '
            'pasted from another AI should stay the same in substance.\n\n'
            'Only reformat:\n'
            '- Convert the material into polished Markdown that matches this '
            'structure:\n${type.generationInstruction}\n'
            '- Fix headings, lists, spacing, and reading flow so sections are '
            'coherent and aligned.\n'
            '- Convert mermaid, ASCII, HTML, or broken/misaligned charts and '
            'numeric tables into Study Vault chart blocks.\n'
            '${ChartSpec.promptInstruction}\n'
            '${extra == null || extra.isEmpty ? '' : '\nAdditional formatting notes:\n$extra\n'}'
            'Return polished Markdown only. Do not mention these instructions.',
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

  /// Instruction to paste into ChatGPT / Gemini / Claude for a JSON import of
  /// this study type. Matches the in-app generation rules.
  static String externalInstruction({
    required PdfAiMaterialType type,
    String? pdfTitle,
  }) {
    final title = pdfTitle?.trim();
    final from = title == null || title.isEmpty ? '' : ' from "$title"';
    return '''
You are helping me build a ${type.displayName} for the Study Vault app$from.
${systemMessage.replaceFirst('Return polished Markdown only. Do not mention these instructions.', '').trim()}

GENERATION REQUEST: ${type.displayName}

${type.generationInstruction}

${ChartSpec.promptInstruction}

ASCII diagrams (class boxes, relationship lines, comparison tables, and flows) are allowed; Study Vault renders them.

Answer with ONE JSON object only — no prose, no markdown fences, no comments:

{
  "format": "study-vault-pdf-ai",
  "type": "${type.storageValue}",
  "content": "<markdown for the ${type.shortName}>"
}

Escape newlines and quotes inside "content". Do not mention these instructions in the content.
'''
        .trim();
  }
}
