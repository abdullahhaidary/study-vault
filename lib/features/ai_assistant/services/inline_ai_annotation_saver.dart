import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../study_pins/data/study_pins_providers.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/ai_actions.dart';
import '../domain/inline_ai_models.dart';
import 'markdown_to_quill.dart';

/// Persists an AI response onto a study pin without duplicating pin CRUD.
abstract final class InlineAiAnnotationSaver {
  /// Heading used when appending, derived from the action that produced the text.
  static String headingFor(AiStudyAction? action) => switch (action) {
    AiStudyAction.summarize => 'AI Summary',
    AiStudyAction.define => 'AI Definition',
    AiStudyAction.giveExample => 'AI Example',
    AiStudyAction.keyConcepts => 'AI Key Concepts',
    AiStudyAction.examPoints => 'AI Exam Points',
    AiStudyAction.simplify => 'AI Simplified',
    AiStudyAction.translate => 'AI Translation',
    _ => 'AI Explanation',
  };

  /// Find an existing text pin that matches this selection on the material.
  static StudyPin? findMatchingTextPin({
    required List<StudyPin> pins,
    required String selectedText,
    int? pageNumber,
  }) {
    final selected = selectedText.trim();
    if (selected.isEmpty) return null;
    for (final pin in pins) {
      if (!pin.isTextPin) continue;
      final pinSelected = (pin.selectedText ?? '').trim();
      if (pinSelected != selected) continue;
      if (pageNumber != null &&
          pin.pageNumber != null &&
          pin.pageNumber != pageNumber) {
        continue;
      }
      return pin;
    }
    return null;
  }

  static Future<StudyPin> save({
    required WidgetRef ref,
    required InlineAiAnnotationTarget target,
    required String markdown,
    required AiStudyAction? action,
    required String resourceId,
    required String selectedText,
    required List<TextRangeInput> ranges,
    StudyPin? existingPin,
  }) async {
    final trimmed = markdown.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('AI response is empty');
    }

    if (existingPin != null) {
      return _updateExisting(
        ref: ref,
        pin: existingPin,
        target: target,
        markdown: trimmed,
        action: action,
      );
    }

    return _createNew(
      ref: ref,
      target: target,
      markdown: trimmed,
      action: action,
      resourceId: resourceId,
      selectedText: selectedText,
      ranges: ranges,
    );
  }

  static Future<StudyPin> _createNew({
    required WidgetRef ref,
    required InlineAiAnnotationTarget target,
    required String markdown,
    required AiStudyAction? action,
    required String resourceId,
    required String selectedText,
    required List<TextRangeInput> ranges,
  }) async {
    final short = switch (target) {
      InlineAiAnnotationTarget.shortDescription => _shortFromMarkdown(markdown),
      InlineAiAnnotationTarget.fullExplanation ||
      InlineAiAnnotationTarget.appendToExplanation => _shortFromSelection(
        selectedText,
      ),
    };
    final full = switch (target) {
      InlineAiAnnotationTarget.shortDescription => null,
      InlineAiAnnotationTarget.fullExplanation => MarkdownToQuill.toDeltaJson(
        markdown,
      ),
      InlineAiAnnotationTarget.appendToExplanation =>
        MarkdownToQuill.toDeltaJson('## ${headingFor(action)}\n\n$markdown'),
    };

    return createTextStudyPin(
      ref,
      CreateTextStudyPinInput(
        resourceId: resourceId,
        selectedText: selectedText,
        ranges: ranges,
        shortText: short,
        fullExplanation: full,
      ),
    );
  }

  static Future<StudyPin> _updateExisting({
    required WidgetRef ref,
    required StudyPin pin,
    required InlineAiAnnotationTarget target,
    required String markdown,
    required AiStudyAction? action,
  }) async {
    switch (target) {
      case InlineAiAnnotationTarget.shortDescription:
        await updateStudyPinTexts(
          ref,
          pin: pin,
          shortText: _shortFromMarkdown(markdown),
          fullExplanation: pin.fullExplanation,
        );
      case InlineAiAnnotationTarget.fullExplanation:
        // Never silently overwrite student-authored full notes without intent.
        // Full explanation target replaces fullExplanation only after confirm.
        await updateStudyPinTexts(
          ref,
          pin: pin,
          shortText: pin.shortText,
          fullExplanation: MarkdownToQuill.toDeltaJson(markdown),
        );
      case InlineAiAnnotationTarget.appendToExplanation:
        final appended = appendMarkdownSection(
          existingStored: pin.fullExplanation,
          heading: headingFor(action),
          markdownBody: markdown,
        );
        await updateStudyPinTexts(
          ref,
          pin: pin,
          shortText: pin.shortText,
          fullExplanation: appended,
        );
    }
    return pin;
  }

  /// Append [markdownBody] under [heading], skipping a duplicate heading.
  static String appendMarkdownSection({
    required String? existingStored,
    required String heading,
    required String markdownBody,
  }) {
    final existingPlain = StudyNoteCodec.plainTextPreview(
      existingStored,
    ).trim();
    final buffer = StringBuffer();
    if (existingPlain.isNotEmpty) {
      buffer.writeln(existingPlain);
      buffer.writeln();
    }
    final alreadyHasHeading = existingPlain.contains(heading);
    if (!alreadyHasHeading) {
      buffer.writeln('## $heading');
      buffer.writeln();
    }
    buffer.write(markdownBody.trim());
    return MarkdownToQuill.toDeltaJson(buffer.toString());
  }

  static String _shortFromMarkdown(String markdown) {
    final plain = markdown
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'[*_`>]'), '')
        .trim();
    if (plain.length <= 120) return plain.isEmpty ? 'AI note' : plain;
    return '${plain.substring(0, 117)}…';
  }

  static String _shortFromSelection(String selectedText) {
    final t = selectedText.trim();
    if (t.isEmpty) return 'AI note';
    if (t.length <= 80) return t;
    return '${t.substring(0, 77)}…';
  }
}
