import 'package:flutter/painting.dart';

import '../../../core/text/text_direction_utils.dart';
import '../../ai_questions/services/pdf_text_extractor.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/ai_actions.dart';
import '../domain/annotation_ai_context.dart';
import '../domain/ai_models.dart';
import 'surrounding_text_extractor.dart';

/// Builds [AnnotationAiContext] in one place for PDF selection / pins.
abstract final class AnnotationAiContextBuilder {
  /// Context from a PDF text selection (optionally with page body for window).
  static AnnotationAiContext fromPdfSelection({
    required String selectedText,
    String? materialId,
    String? lessonId,
    int? pageNumber,
    String? pageText,
    String? filePath,
    AiLanguage language = AiLanguage.auto,
  }) {
    final selected = selectedText.trim();
    final surrounding = pageText == null || pageText.trim().isEmpty
        ? null
        : SurroundingTextExtractor.extract(
            pageText: pageText,
            selectedText: selected,
          );

    return AnnotationAiContext(
      selectedText: selected,
      materialId: materialId,
      lessonId: lessonId,
      pageNumber: pageNumber,
      surroundingText: _clampSurrounding(surrounding),
      language: language,
      direction: _directionFor(selected),
      filePath: filePath,
    );
  }

  /// Context from a selection inside any plain / markdown text document
  /// (AI materials, notes, chat messages). [documentText] is used only to
  /// extract the nearby window; the scope decides what is actually sent.
  static AnnotationAiContext fromTextSelection({
    required String selectedText,
    String? documentText,
    String? materialId,
    String? lessonId,
    int? pageNumber,
    String? sourceTitle,
    AiLanguage language = AiLanguage.auto,
  }) {
    return fromPdfSelection(
      selectedText: selectedText,
      materialId: materialId,
      lessonId: lessonId,
      pageNumber: pageNumber,
      pageText: documentText,
      language: language,
    ).copyWith(sourceTitle: sourceTitle);
  }

  /// Returns [base] with [scope] applied. [nearbyText] is the already
  /// extracted window, [summaryText] / [fullText] are loaded by the host.
  /// Large documents are truncated so selection + context stays sendable.
  static AnnotationAiContext withScope(
    AnnotationAiContext base, {
    required AiContextScope scope,
    String? nearbyText,
    String? summaryText,
    String? fullText,
  }) {
    final selectedLength = base.primaryText.length;
    final budget = (kAiHardSourceLimit - selectedLength - 500).clamp(
      0,
      kAiDocumentContextLimit,
    );
    String? clamp(String? text) {
      final trimmed = text?.trim();
      if (trimmed == null || trimmed.isEmpty || budget == 0) return null;
      if (trimmed.length <= budget) return trimmed;
      return '${trimmed.substring(0, budget)}…';
    }

    final extra = switch (scope) {
      AiContextScope.selectionOnly => null,
      AiContextScope.surrounding => _clampSurrounding(
        nearbyText ?? base.surroundingText,
      ),
      AiContextScope.summary => clamp(summaryText),
      AiContextScope.fullText => clamp(fullText),
    };
    return base.copyWith(
      contextScope: scope,
      surroundingText: extra,
      clearSurrounding: extra == null,
    );
  }

  /// Context from an existing study pin / annotation.
  static AnnotationAiContext fromStudyPin({
    required String pinId,
    required String shortText,
    required String fullExplanationStored,
    String? selectedText,
    String? materialId,
    String? lessonId,
    int? pageNumber,
    String? pageText,
    String? filePath,
    AiLanguage language = AiLanguage.auto,
  }) {
    final selected = (selectedText ?? '').trim();
    final fullPlain = StudyNoteCodec.plainTextPreview(fullExplanationStored);
    final annotationBody = [
      shortText.trim(),
      fullPlain.trim(),
    ].where((s) => s.isNotEmpty).join('\n\n');

    final anchor = selected.isNotEmpty ? selected : shortText.trim();
    final surrounding =
        pageText == null || pageText.trim().isEmpty || anchor.isEmpty
        ? null
        : SurroundingTextExtractor.extract(
            pageText: pageText,
            selectedText: anchor,
          );

    return AnnotationAiContext(
      selectedText: selected,
      annotationText: annotationBody,
      shortDescription: shortText.trim().isEmpty ? null : shortText.trim(),
      annotationId: pinId,
      materialId: materialId,
      lessonId: lessonId,
      pageNumber: pageNumber,
      surroundingText: _clampSurrounding(surrounding),
      language: language,
      direction: _directionFor(selected.isNotEmpty ? selected : annotationBody),
      filePath: filePath,
    );
  }

  /// Loads page text via [PdfTextExtractor] when a file path is available.
  static Future<AnnotationAiContext> fromPdfSelectionWithPageLoad({
    required String selectedText,
    required String filePath,
    String? materialId,
    String? lessonId,
    int? pageNumber,
    AiLanguage language = AiLanguage.auto,
  }) async {
    String? pageText;
    if (pageNumber != null) {
      try {
        final pages = await PdfTextExtractor.extractPages(
          filePath: filePath,
          pageNumbers: {pageNumber},
        );
        if (pages.isNotEmpty) pageText = pages.first.text;
      } on Object {
        pageText = null;
      }
    }

    return fromPdfSelection(
      selectedText: selectedText,
      materialId: materialId,
      lessonId: lessonId,
      pageNumber: pageNumber,
      pageText: pageText,
      filePath: filePath,
      language: language,
    );
  }

  /// Page / slide AI: primary source is the current page text (bounded).
  static Future<AnnotationAiContext> fromPdfPage({
    required String filePath,
    required int pageNumber,
    String? materialId,
    String? lessonId,
    AiLanguage language = AiLanguage.auto,
    int maxPageChars = 12000,
  }) async {
    String pageText = '';
    try {
      final pages = await PdfTextExtractor.extractPages(
        filePath: filePath,
        pageNumbers: {pageNumber},
      );
      if (pages.isNotEmpty) pageText = pages.first.text.trim();
    } on Object {
      pageText = '';
    }

    if (pageText.length > maxPageChars) {
      pageText = '${pageText.substring(0, maxPageChars)}…';
    }

    return AnnotationAiContext(
      selectedText: pageText,
      materialId: materialId,
      lessonId: lessonId,
      pageNumber: pageNumber,
      surroundingText: null,
      language: language,
      direction: _directionFor(pageText),
      filePath: filePath,
    );
  }

  static String? _clampSurrounding(String? surrounding) {
    if (surrounding == null) return null;
    final trimmed = surrounding.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= kAiSurroundingContextLimit) return trimmed;
    return '${trimmed.substring(0, kAiSurroundingContextLimit)}…';
  }

  static TextDirection? _directionFor(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return TextDirectionUtils.resolve(t);
  }
}
