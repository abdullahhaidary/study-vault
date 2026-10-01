import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../study_pins/data/pin_categories_providers.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_models.dart';
import 'ai_annotation_preview.dart';
import 'ai_assistant_controller.dart';
import 'ai_flashcards_preview.dart';
import 'ai_preview_screen.dart';
import 'ai_questions_preview.dart';

/// Context for where AI was invoked.
enum AiActionContext { pdfSelection, noteEditor, pinReader }

Future<void> showAiActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required String sourceText,
  required AiActionContext actionContext,
  String? selectedText,
  String? shortDescription,
  void Function(AiTextPreviewResult preview)? onTextPreviewApplied,
  Future<void> Function(AiAnnotationDraft draft)? onAnnotationSave,
  Future<void> Function(List<AiFlashcardDraft> cards)? onFlashcardsCreate,
  Future<void> Function(AiQuestionsResult questions)? onQuestionsDone,
}) async {
  final actions = switch (actionContext) {
    AiActionContext.pdfSelection => const [
      AiStudyAction.explain,
      AiStudyAction.simplify,
      AiStudyAction.rephrase,
      AiStudyAction.summarize,
      AiStudyAction.createAnnotation,
      AiStudyAction.generateFlashcards,
      AiStudyAction.generateQuestions,
    ],
    AiActionContext.noteEditor => const [
      AiStudyAction.rephrase,
      AiStudyAction.simplify,
      AiStudyAction.fixGrammar,
      AiStudyAction.organize,
      AiStudyAction.summarize,
      AiStudyAction.generateFlashcards,
      AiStudyAction.generateQuestions,
    ],
    AiActionContext.pinReader => const [
      AiStudyAction.simplify,
      AiStudyAction.summarize,
      AiStudyAction.generateFlashcards,
      AiStudyAction.generateQuestions,
    ],
  };

  final chosen = await showModalBottomSheet<AiStudyAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              'AI Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final action in actions)
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(action.menuLabel),
              onTap: () => Navigator.pop(context, action),
            ),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;

  AiRephraseMode? rephraseMode;
  AiOrganizeMode? organizeMode;
  AiSummarizeMode? summarizeMode;
  AiQuestionType? questionType;
  var flashcardCount = 3;

  if (chosen == AiStudyAction.rephrase) {
    rephraseMode = await _pickEnum(
      context,
      title: 'Rephrase mode',
      values: AiRephraseMode.values,
      label: (m) => switch (m) {
        AiRephraseMode.clearer => 'Clearer',
        AiRephraseMode.simpler => 'Simpler',
        AiRephraseMode.moreAcademic => 'More Academic',
        AiRephraseMode.shorter => 'Shorter',
        AiRephraseMode.moreConcise => 'More Concise',
        AiRephraseMode.fixGrammar => 'Fix Grammar',
        AiRephraseMode.preserveMeaning => 'Preserve Meaning',
      },
    );
    if (rephraseMode == null || !context.mounted) return;
  }
  if (chosen == AiStudyAction.organize) {
    organizeMode = await _pickEnum(
      context,
      title: 'Organize mode',
      values: AiOrganizeMode.values,
      label: (m) => switch (m) {
        AiOrganizeMode.cleanFormatting => 'Clean up formatting',
        AiOrganizeMode.addHeadings => 'Add headings',
        AiOrganizeMode.convertToBullets => 'Convert to bullets',
        AiOrganizeMode.turnIntoStudyNotes => 'Turn into study notes',
        AiOrganizeMode.organizeAcademically => 'Organize academically',
        AiOrganizeMode.examReady => 'Exam-ready structure',
      },
    );
    if (organizeMode == null || !context.mounted) return;
  }
  if (chosen == AiStudyAction.summarize) {
    summarizeMode = await _pickEnum(
      context,
      title: 'Summarize mode',
      values: AiSummarizeMode.values,
      label: (m) => switch (m) {
        AiSummarizeMode.veryShort => 'Very Short',
        AiSummarizeMode.oneParagraph => 'One Paragraph',
        AiSummarizeMode.bulletPoints => 'Bullet Points',
        AiSummarizeMode.keyPoints => 'Key Points',
        AiSummarizeMode.examSummary => 'Exam Summary',
      },
    );
    if (summarizeMode == null || !context.mounted) return;
  }
  if (chosen == AiStudyAction.generateFlashcards) {
    flashcardCount = await _pickCount(context) ?? 3;
    if (!context.mounted) return;
  }
  if (chosen == AiStudyAction.generateQuestions) {
    questionType = await _pickEnum(
      context,
      title: 'Question type',
      values: AiQuestionType.values,
      label: (m) => switch (m) {
        AiQuestionType.conceptual => 'Conceptual',
        AiQuestionType.shortAnswer => 'Short Answer',
        AiQuestionType.mixed => 'Mixed',
      },
    );
    if (questionType == null || !context.mounted) return;
  }

  final categories =
      ref.read(studyPinCategoryMapProvider).valueOrNull ?? const {};
  final categoryNameToId = {
    for (final c in categories.values) c.name: c.id,
  };

  final result = await AiAssistantController.runWithLoading(
    context,
    ref,
    request: AiStudyRequest(
      action: chosen,
      sourceText: sourceText,
      selectedText: selectedText,
      shortDescription: shortDescription,
      rephraseMode: rephraseMode,
      organizeMode: organizeMode,
      summarizeMode: summarizeMode,
      questionType: questionType,
      flashcardCount: flashcardCount,
      categoryNames: categoryNameToId.keys.toList(),
    ),
    categoryNameToId: categoryNameToId,
  );
  if (result == null || !context.mounted) return;

  if (result is AiTextResult) {
    final preview = await showAiTextPreview(
      context,
      originalText: sourceText,
      result: result,
      allowReplace: actionContext != AiActionContext.pdfSelection,
      allowInsertBelow: actionContext == AiActionContext.noteEditor,
    );
    if (preview != null && preview.action != AiPreviewApplyAction.cancel) {
      onTextPreviewApplied?.call(preview);
      if (preview.action == AiPreviewApplyAction.copy && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied')));
      }
    }
  } else if (result is AiAnnotationDraft) {
    await showAiAnnotationPreview(
      context,
      ref,
      draft: result,
      selectedText: selectedText ?? sourceText,
      onSave: onAnnotationSave,
    );
  } else if (result is AiFlashcardsResult) {
    await showAiFlashcardsPreview(
      context,
      cards: result.cards,
      onCreate: onFlashcardsCreate,
    );
  } else if (result is AiQuestionsResult) {
    await showAiQuestionsPreview(
      context,
      questions: result,
      onDone: onQuestionsDone,
      onConvertToFlashcards: onFlashcardsCreate,
    );
  }
}

Future<T?> _pickEnum<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T) label,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(title)),
          for (final v in values)
            ListTile(
              title: Text(label(v)),
              onTap: () => Navigator.pop(context, v),
            ),
        ],
      ),
    ),
  );
}

Future<int?> _pickCount(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('How many flashcards?')),
          for (final n in const [3, 5, 10])
            ListTile(
              title: Text('$n'),
              onTap: () => Navigator.pop(context, n),
            ),
        ],
      ),
    ),
  );
}
