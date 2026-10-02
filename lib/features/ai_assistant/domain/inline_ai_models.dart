import 'dart:ui' show Offset;

import '../../../core/database/app_database.dart';
import 'ai_actions.dart';
import 'ai_execution_selection.dart';
import 'ai_models.dart';
import 'annotation_ai_context.dart';
import 'annotation_ai_history.dart';

/// Where inline AI was opened from.
enum InlineAiSourceMode { selection, page }

/// Compact panel phase (UI state machine).
enum InlineAiPhase { ready, loading, success, error }

/// Destination when saving an AI response onto a study pin.
enum InlineAiAnnotationTarget {
  shortDescription,
  fullExplanation,
  appendToExplanation,
}

/// Session identity for one open inline AI panel.
class InlineAiSessionArgs {
  const InlineAiSessionArgs({
    required this.mode,
    required this.context,
    this.rangeInputs = const [],
    this.existingPin,
    this.anchorGlobal,
  });

  final InlineAiSourceMode mode;
  final AnnotationAiContext context;

  /// Normalized text ranges for creating a new text pin (selection mode).
  /// Stored as opaque maps to avoid pulling study-pin types into this layer;
  /// the PDF screen converts these back to [TextRangeInput].
  final List<InlineAiTextRange> rangeInputs;

  /// Existing study pin when the selection already has an annotation.
  final StudyPin? existingPin;

  /// Optional global anchor hint near the selection (desktop popover).
  final Offset? anchorGlobal;
}

/// Lightweight range payload for pin creation from selection AI.
class InlineAiTextRange {
  const InlineAiTextRange({
    required this.pageNumber,
    required this.xRatio,
    required this.yRatio,
    required this.widthRatio,
    required this.heightRatio,
  });

  final int pageNumber;
  final double xRatio;
  final double yRatio;
  final double widthRatio;
  final double heightRatio;
}

/// Immutable snapshot of inline AI UI + history state.
class InlineAiViewState {
  const InlineAiViewState({
    required this.mode,
    required this.context,
    required this.phase,
    this.action,
    this.generations = const [],
    this.selected,
    this.errorMessage,
    this.counts = const {},
    this.focusAskField = false,
    this.summarizeMode,
    this.rephraseMode,
    this.translateTarget,
    this.customPrompt,
    this.pageSendMode = AiPageSendMode.text,
    this.selection,
  });

  final InlineAiSourceMode mode;
  final AnnotationAiContext context;
  final InlineAiPhase phase;
  final AiStudyAction? action;
  final List<AnnotationAiGeneration> generations;
  final AnnotationAiGeneration? selected;
  final String? errorMessage;
  final Map<AiStudyAction, int> counts;
  final bool focusAskField;
  final AiSummarizeMode? summarizeMode;
  final AiRephraseMode? rephraseMode;
  final AiLanguage? translateTarget;
  final String? customPrompt;
  final AiPageSendMode pageSendMode;
  final AiExecutionSelection? selection;

  String get sourceFingerprint =>
      AnnotationAiSourceFingerprint.fromContext(context);

  String get markdown => selected?.responseText ?? '';

  bool get hasResponse => markdown.trim().isNotEmpty;

  String get contextLabel {
    final page = context.pageNumber;
    if (mode == InlineAiSourceMode.page) {
      return page == null ? 'Context: Current page' : 'Context: Page $page';
    }
    if (page == null) return 'Based on: Selection';
    return 'Based on: Selection + Page $page context';
  }

  InlineAiViewState copyWith({
    InlineAiSourceMode? mode,
    AnnotationAiContext? context,
    InlineAiPhase? phase,
    AiStudyAction? action,
    List<AnnotationAiGeneration>? generations,
    AnnotationAiGeneration? selected,
    String? errorMessage,
    Map<AiStudyAction, int>? counts,
    bool? focusAskField,
    AiSummarizeMode? summarizeMode,
    AiRephraseMode? rephraseMode,
    AiLanguage? translateTarget,
    String? customPrompt,
    AiPageSendMode? pageSendMode,
    AiExecutionSelection? selection,
    bool clearAction = false,
    bool clearSelected = false,
    bool clearError = false,
  }) {
    return InlineAiViewState(
      mode: mode ?? this.mode,
      context: context ?? this.context,
      phase: phase ?? this.phase,
      action: clearAction ? null : (action ?? this.action),
      generations: generations ?? this.generations,
      selected: clearSelected ? null : (selected ?? this.selected),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      counts: counts ?? this.counts,
      focusAskField: focusAskField ?? this.focusAskField,
      summarizeMode: summarizeMode ?? this.summarizeMode,
      rephraseMode: rephraseMode ?? this.rephraseMode,
      translateTarget: translateTarget ?? this.translateTarget,
      customPrompt: customPrompt ?? this.customPrompt,
      pageSendMode: pageSendMode ?? this.pageSendMode,
      selection: selection ?? this.selection,
    );
  }
}

/// Quick chips shown on the first panel screen.
abstract final class InlineAiQuickActions {
  static const selection = <AiStudyAction>[
    AiStudyAction.explain,
    AiStudyAction.simplify,
    AiStudyAction.define,
    AiStudyAction.summarize,
  ];

  static const page = <AiStudyAction>[
    AiStudyAction.summarize,
    AiStudyAction.keyConcepts,
    AiStudyAction.explain,
    AiStudyAction.examPoints,
  ];

  static const selectionMore = <AiStudyAction>[
    AiStudyAction.giveExample,
    AiStudyAction.rephrase,
    AiStudyAction.fixGrammar,
    AiStudyAction.organize,
    AiStudyAction.translate,
    AiStudyAction.customPrompt,
    AiStudyAction.generateFlashcards,
    AiStudyAction.generateQuestions,
  ];

  static const pageMore = <AiStudyAction>[
    AiStudyAction.define,
    AiStudyAction.giveExample,
    AiStudyAction.translate,
    AiStudyAction.customPrompt,
    AiStudyAction.generateFlashcards,
    AiStudyAction.generateQuestions,
  ];
}
