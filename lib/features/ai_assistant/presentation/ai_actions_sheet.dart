import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/auto_direction_text_field.dart';
import '../../ai_questions/domain/question_source.dart';
import '../../ai_questions/presentation/generate_questions_sheet.dart';
import '../../study_pins/data/pin_categories_providers.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_models.dart';
import '../domain/annotation_ai_context.dart';
import 'ai_annotation_preview.dart';
import 'ai_assistant_controller.dart';
import 'ai_flashcards_preview.dart';
import 'ai_preview_screen.dart';
import 'ai_response_screen.dart';

/// Context for where AI was invoked.
enum AiActionContext { pdfSelection, noteEditor, pinReader }

Future<void> showAiActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required String sourceText,
  required AiActionContext actionContext,
  String? selectedText,
  String? shortDescription,
  AnnotationAiContext? annotationContext,
  void Function(AiTextPreviewResult preview)? onTextPreviewApplied,
  Future<void> Function(AiAnnotationDraft draft)? onAnnotationSave,
  Future<void> Function(List<AiFlashcardDraft> cards)? onFlashcardsCreate,
  Future<void> Function(AiQuestionsResult questions)? onQuestionsDone,
  Future<void> Function(String markdown)? onCreateNote,
  VoidCallback? onGoToSource,
  GenerateQuestionsLaunch? questionsLaunch,
}) async {
  final primary = (annotationContext?.primaryText ?? sourceText).trim();
  final selected = selectedText ?? annotationContext?.selectedText;

  final chosen = await _pickAction(context, actionContext);
  if (chosen == null || !context.mounted) return;

  if (chosen == AiStudyAction.generateQuestions) {
    final launch =
        questionsLaunch ??
        GenerateQuestionsLaunch(
          availableSources: const [QuestionSourceType.selectedText],
          initialSource: QuestionSourceType.selectedText,
          resolveSource: (type) async {
            return QuestionSourceBuilder.fromSelectedText(
              text: selected ?? primary,
              materialId: annotationContext?.materialId,
              lessonId: annotationContext?.lessonId,
              pageNumber: annotationContext?.pageNumber,
            );
          },
        );
    await showGenerateQuestionsSheet(context, ref, launch: launch);
    return;
  }

  AiRephraseMode? rephraseMode;
  AiOrganizeMode? organizeMode;
  AiSummarizeMode? summarizeMode;
  AiLanguage? translateTarget;
  String? customPrompt;
  var flashcardCount = _defaultFlashcardCount(primary);

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
  if (chosen == AiStudyAction.translate) {
    translateTarget = await _pickEnum(
      context,
      title: 'Translate to',
      values: const [AiLanguage.english, AiLanguage.persianDari],
      label: (m) => m.label,
    );
    if (translateTarget == null || !context.mounted) return;
  }
  if (chosen == AiStudyAction.askAi) {
    customPrompt = await _promptDialog(
      context,
      title: 'Ask AI',
      hint: 'What does this mean? Why is it important?',
    );
    if (customPrompt == null || !context.mounted) return;
  }
  if (chosen == AiStudyAction.customPrompt) {
    customPrompt = await _promptDialog(
      context,
      title: 'Custom prompt',
      hint: 'Explain this using a real-world banking example.',
    );
    if (customPrompt == null || !context.mounted) return;
  }
  if (chosen == AiStudyAction.generateFlashcards) {
    flashcardCount =
        await _pickCount(context, options: _flashcardCountOptions(primary)) ??
        flashcardCount;
    if (!context.mounted) return;
  }

  final categories =
      ref.read(studyPinCategoryMapProvider).valueOrNull ?? const {};
  final categoryNameToId = {for (final c in categories.values) c.name: c.id};

  final request =
      annotationContext?.toStudyRequest(
        action: chosen,
        rephraseMode: rephraseMode,
        organizeMode: organizeMode,
        summarizeMode: summarizeMode,
        flashcardCount: flashcardCount,
        categoryNames: categoryNameToId.keys.toList(),
        customPrompt: customPrompt,
        translateTarget: translateTarget,
      ) ??
      AiStudyRequest(
        action: chosen,
        sourceText: primary,
        selectedText: selected,
        shortDescription: shortDescription,
        rephraseMode: rephraseMode,
        organizeMode: organizeMode,
        summarizeMode: summarizeMode,
        flashcardCount: flashcardCount,
        categoryNames: categoryNameToId.keys.toList(),
        customPrompt: customPrompt,
        translateTarget: translateTarget,
      );

  final result = await AiAssistantController.runWithLoading(
    context,
    ref,
    request: request,
    categoryNameToId: categoryNameToId,
    annotationContext: annotationContext,
  );
  if (result == null || !context.mounted) return;

  if (result is AiTextResult) {
    final useAnnotationResponseUi =
        actionContext == AiActionContext.pdfSelection ||
        actionContext == AiActionContext.pinReader;

    if (useAnnotationResponseUi) {
      await showAiResponseScreen(
        context,
        ref,
        result: result,
        action: chosen,
        request: request,
        annotationContext: annotationContext,
        questionsLaunch: questionsLaunch,
        onFlashcardsCreate: onFlashcardsCreate,
        onCreateNote: onCreateNote,
        onGoToSource: onGoToSource,
      );
    } else {
      final preview = await showAiTextPreview(
        context,
        originalText: primary,
        result: result,
        allowReplace: true,
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
    }
  } else if (result is AiAnnotationDraft) {
    await showAiAnnotationPreview(
      context,
      ref,
      draft: result,
      selectedText: selected ?? primary,
      onSave: onAnnotationSave,
    );
  } else if (result is AiFlashcardsResult) {
    await showAiFlashcardsPreview(
      context,
      cards: result.cards,
      onCreate: onFlashcardsCreate,
    );
  }
}

Future<AiStudyAction?> _pickAction(
  BuildContext context,
  AiActionContext actionContext,
) async {
  final primary = switch (actionContext) {
    AiActionContext.pdfSelection => const [
      AiStudyAction.explain,
      AiStudyAction.simplify,
      AiStudyAction.summarize,
      AiStudyAction.generateFlashcards,
      AiStudyAction.generateQuestions,
      AiStudyAction.askAi,
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
      AiStudyAction.explain,
      AiStudyAction.simplify,
      AiStudyAction.summarize,
      AiStudyAction.generateFlashcards,
      AiStudyAction.generateQuestions,
      AiStudyAction.askAi,
    ],
  };

  final more = switch (actionContext) {
    AiActionContext.pdfSelection => const [
      AiStudyAction.define,
      AiStudyAction.giveExample,
      AiStudyAction.translate,
      AiStudyAction.rephrase,
      AiStudyAction.createAnnotation,
      AiStudyAction.customPrompt,
    ],
    AiActionContext.noteEditor => const [
      AiStudyAction.define,
      AiStudyAction.giveExample,
      AiStudyAction.translate,
      AiStudyAction.askAi,
      AiStudyAction.customPrompt,
    ],
    AiActionContext.pinReader => const [
      AiStudyAction.define,
      AiStudyAction.giveExample,
      AiStudyAction.translate,
      AiStudyAction.rephrase,
      AiStudyAction.customPrompt,
    ],
  };

  final first = await showModalBottomSheet<Object>(
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
          for (final action in primary)
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(action.menuLabel),
              onTap: () => Navigator.pop(context, action),
            ),
          if (more.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: const Text('More AI Actions'),
              onTap: () => Navigator.pop(context, 'more'),
            ),
        ],
      ),
    ),
  );

  if (first is AiStudyAction) return first;
  if (first != 'more' || !context.mounted) return null;

  return showModalBottomSheet<AiStudyAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              'More AI Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final action in more)
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(action.menuLabel),
              onTap: () => Navigator.pop(context, action),
            ),
        ],
      ),
    ),
  );
}

Future<String?> _promptDialog(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: AutoDirectionTextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Run'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.isEmpty) return null;
  return result;
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

Future<int?> _pickCount(BuildContext context, {required List<int> options}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('How many flashcards?')),
          for (final n in options)
            ListTile(title: Text('$n'), onTap: () => Navigator.pop(context, n)),
        ],
      ),
    ),
  );
}

int _defaultFlashcardCount(String source) {
  final len = source.trim().length;
  if (len < 120) return 3;
  if (len < 400) return 5;
  return 10;
}

List<int> _flashcardCountOptions(String source) {
  final len = source.trim().length;
  if (len < 120) return const [3, 5];
  if (len < 400) return const [5, 10];
  return const [5, 10, 20];
}
