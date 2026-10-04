import '../../ai_assistant/domain/ai_models.dart';

/// Applies an AI answer back into the host document.
///
/// Returns `true` when the document changed (the AI box closes), `false`
/// when the user cancelled or nothing could be applied.
typedef SelectionAiApply =
    Future<bool> Function(String selectedText, String markdown);

/// Describes the document a text selection lives in and what the host screen
/// can do with the selection / the AI answer.
///
/// Every reader or editor that shows the selection toolbar builds one of
/// these; the toolbar, scope picker and inline AI box are shared.
class SelectionAiHost {
  const SelectionAiHost({
    required this.title,
    this.materialId,
    this.lessonId,
    this.pageNumber,
    this.filePath,
    this.documentText,
    this.loadFullText,
    this.loadSummary,
    this.onReplaceSelection,
    this.onInsertBelow,
    this.onAppendToEnd,
    this.onAddPin,
  });

  /// Short name shown in labels ("Summary", "Note", "Lect-02.pdf").
  final String title;

  final String? materialId;
  final String? lessonId;
  final int? pageNumber;
  final String? filePath;

  /// Current full text of the document when it is cheap to provide
  /// synchronously (markdown readers, notes, chat messages). Used for the
  /// "nearby text" window and, when [loadFullText] is null, for full-text.
  final String? documentText;

  /// Loads the whole document text on demand (PDF extraction).
  final Future<String?> Function()? loadFullText;

  /// Loads a saved summary of this document when one exists.
  final Future<String?> Function()? loadSummary;

  /// Replace the selected text with the AI answer.
  final SelectionAiApply? onReplaceSelection;

  /// Insert the AI answer right after the selected passage.
  final SelectionAiApply? onInsertBelow;

  /// Append the AI answer at the end of the document.
  final SelectionAiApply? onAppendToEnd;

  /// Create a study pin from the selection (PDF only).
  final Future<void> Function(String selectedText)? onAddPin;

  bool get canReplace => onReplaceSelection != null;
  bool get canInsertBelow => onInsertBelow != null;
  bool get canAppend => onAppendToEnd != null;
  bool get canAddPin => onAddPin != null;
  bool get canEdit => canReplace || canInsertBelow || canAppend;

  bool get hasNearbyText => (documentText ?? '').trim().isNotEmpty;
  bool get hasSummary => loadSummary != null;
  bool get hasFullText => loadFullText != null || hasNearbyText;

  /// Scopes the user may pick for this document.
  List<AiContextScope> get availableScopes => [
    AiContextScope.selectionOnly,
    if (hasNearbyText) AiContextScope.surrounding,
    if (hasSummary) AiContextScope.summary,
    if (hasFullText) AiContextScope.fullText,
  ];
}
