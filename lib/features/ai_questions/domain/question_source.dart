import 'dart:convert';

import 'quiz_models.dart';

export 'quiz_models.dart' show QuestionSourceType;

/// Normalized educational material ready for Gemini question generation.
class QuestionSource {
  const QuestionSource({
    required this.type,
    required this.text,
    required this.pageTexts,
    this.materialId,
    this.lessonId,
    this.subjectId,
    this.pageNumbers = const [],
    this.referenceLabel,
    this.metadata = const {},
    this.filePath,
  });

  final QuestionSourceType type;

  /// Combined text with page markers when available.
  final String text;

  /// Per-page snippets preserving provenance for chunking.
  final List<SourcePageText> pageTexts;

  final String? materialId;
  final String? lessonId;
  final String? subjectId;
  final List<int> pageNumbers;
  final String? referenceLabel;
  final Map<String, Object?> metadata;
  final String? filePath;

  bool get isEmpty => text.trim().isEmpty;

  int get characterCount => text.length;

  String toSourceReferenceJson() {
    return jsonEncode({
      'type': type.storageValue,
      'materialId': materialId,
      'lessonId': lessonId,
      'subjectId': subjectId,
      'pageNumbers': pageNumbers,
      'label': referenceLabel,
      'metadata': metadata,
    });
  }
}

class SourcePageText {
  const SourcePageText({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;
}

/// Builds normalized [QuestionSource] values from study content.
///
/// All factory methods normalize whitespace and attach page markers so Gemini
/// (and later chunking) can preserve provenance.
abstract final class QuestionSourceBuilder {
  static QuestionSource fromSelectedText({
    required String text,
    String? materialId,
    String? lessonId,
    String? subjectId,
    int? pageNumber,
    String? filePath,
  }) {
    final cleaned = _clean(text);
    return QuestionSource(
      type: QuestionSourceType.selectedText,
      text: cleaned,
      pageTexts: pageNumber == null
          ? const []
          : [SourcePageText(pageNumber: pageNumber, text: cleaned)],
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
      pageNumbers: pageNumber == null ? const [] : [pageNumber],
      referenceLabel: pageNumber == null
          ? 'Selected text'
          : 'Selected text (page $pageNumber)',
      filePath: filePath,
    );
  }

  static QuestionSource fromPage({
    required int pageNumber,
    required String pageText,
    String? materialId,
    String? lessonId,
    String? subjectId,
    String? filePath,
  }) {
    return fromPages(
      pages: [SourcePageText(pageNumber: pageNumber, text: pageText)],
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
      type: QuestionSourceType.page,
      filePath: filePath,
    );
  }

  static QuestionSource fromPages({
    required List<SourcePageText> pages,
    String? materialId,
    String? lessonId,
    String? subjectId,
    QuestionSourceType type = QuestionSourceType.pages,
    String? filePath,
  }) {
    final normalized =
        pages
            .map(
              (p) => SourcePageText(
                pageNumber: p.pageNumber,
                text: _clean(p.text),
              ),
            )
            .where((p) => p.text.isNotEmpty)
            .toList()
          ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

    final buffer = StringBuffer();
    for (final page in normalized) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('--- Page ${page.pageNumber} ---');
      buffer.writeln(page.text);
    }

    final pageNumbers = [for (final p in normalized) p.pageNumber];

    return QuestionSource(
      type: type,
      text: buffer.toString().trim(),
      pageTexts: normalized,
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
      pageNumbers: pageNumbers,
      referenceLabel: pageNumbers.isEmpty
          ? 'Pages'
          : pageNumbers.length == 1
          ? 'Page ${pageNumbers.first}'
          : 'Pages ${pageNumbers.first}–${pageNumbers.last}',
      filePath: filePath,
    );
  }

  static QuestionSource fromMaterial({
    required List<SourcePageText> pages,
    String? materialId,
    String? lessonId,
    String? subjectId,
    String? filePath,
  }) {
    return fromPages(
      pages: pages,
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
      type: QuestionSourceType.material,
      filePath: filePath,
    );
  }

  static QuestionSource fromAnnotations({
    required List<AnnotationSourceItem> annotations,
    String? materialId,
    String? lessonId,
    String? subjectId,
  }) {
    final buffer = StringBuffer();
    final pageNumbers = <int>{};
    final pageTexts = <SourcePageText>[];

    for (var i = 0; i < annotations.length; i++) {
      final item = annotations[i];
      final body = _clean(_composeAnnotation(item));
      if (body.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      final pageLabel = item.pageNumber == null
          ? 'Annotation ${i + 1}'
          : 'Annotation ${i + 1} (page ${item.pageNumber})';
      buffer.writeln('--- $pageLabel ---');
      buffer.writeln(body);
      if (item.pageNumber != null) {
        pageNumbers.add(item.pageNumber!);
        pageTexts.add(SourcePageText(pageNumber: item.pageNumber!, text: body));
      }
    }

    return QuestionSource(
      type: QuestionSourceType.annotations,
      text: buffer.toString().trim(),
      pageTexts: pageTexts,
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
      pageNumbers: pageNumbers.toList()..sort(),
      referenceLabel: 'Annotations (${annotations.length})',
      metadata: {'annotationCount': annotations.length},
    );
  }

  static QuestionSource fromNotes({
    required List<NoteSourceItem> notes,
    String? materialId,
    String? lessonId,
    String? subjectId,
  }) {
    final buffer = StringBuffer();
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final body = _clean(note.plainText);
      if (body.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('--- Note: ${note.title} ---');
      buffer.writeln(body);
    }

    return QuestionSource(
      type: QuestionSourceType.notes,
      text: buffer.toString().trim(),
      pageTexts: const [],
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
      referenceLabel: 'Notes (${notes.length})',
      metadata: {
        'noteIds': [for (final n in notes) n.id],
      },
    );
  }

  static QuestionSource fromAnnotationsAndNotes({
    required List<AnnotationSourceItem> annotations,
    required List<NoteSourceItem> notes,
    String? materialId,
    String? lessonId,
    String? subjectId,
  }) {
    final ann = fromAnnotations(
      annotations: annotations,
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
    );
    final noteSrc = fromNotes(
      notes: notes,
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
    );

    final parts = <String>[
      if (ann.text.isNotEmpty) ann.text,
      if (noteSrc.text.isNotEmpty) noteSrc.text,
    ];

    return QuestionSource(
      type: QuestionSourceType.annotationsAndNotes,
      text: parts.join('\n\n').trim(),
      pageTexts: ann.pageTexts,
      materialId: materialId,
      lessonId: lessonId,
      subjectId: subjectId,
      pageNumbers: ann.pageNumbers,
      referenceLabel: 'Annotations + notes',
      metadata: {
        'annotationCount': annotations.length,
        'noteIds': [for (final n in notes) n.id],
      },
    );
  }

  static String _composeAnnotation(AnnotationSourceItem item) {
    final parts = <String>[
      if (item.shortText.trim().isNotEmpty) item.shortText.trim(),
      if ((item.selectedText ?? '').trim().isNotEmpty)
        'Selected: ${item.selectedText!.trim()}',
      if ((item.fullNotePlainText ?? '').trim().isNotEmpty)
        item.fullNotePlainText!.trim(),
    ];
    return parts.join('\n');
  }

  static String _clean(String value) {
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

class AnnotationSourceItem {
  const AnnotationSourceItem({
    required this.id,
    required this.shortText,
    this.selectedText,
    this.fullNotePlainText,
    this.pageNumber,
  });

  final String id;
  final String shortText;
  final String? selectedText;
  final String? fullNotePlainText;
  final int? pageNumber;
}

class NoteSourceItem {
  const NoteSourceItem({
    required this.id,
    required this.title,
    required this.plainText,
  });

  final String id;
  final String title;
  final String plainText;
}
