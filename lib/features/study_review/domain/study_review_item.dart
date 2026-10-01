import '../../study_pins/domain/pin_type.dart';
import 'review_models.dart';

/// Lightweight pin payload for Review Mode cards.
class StudyReviewItem {
  const StudyReviewItem({
    required this.studyPinId,
    required this.annotationType,
    required this.shortText,
    this.categoryId,
    this.categoryName,
    this.selectedText,
    this.fullNote,
    required this.materialId,
    required this.materialTitle,
    this.mimeType,
    this.pageNumber,
    this.isFavorite = false,
  });

  final String studyPinId;
  final StudyPinType annotationType;
  final String shortText;
  final String? categoryId;
  final String? categoryName;
  final String? selectedText;
  final String? fullNote;
  final String materialId;
  final String materialTitle;
  final String? mimeType;
  final int? pageNumber;
  final bool isFavorite;

  bool get hasFullNote {
    final note = fullNote?.trim();
    return note != null && note.isNotEmpty;
  }

  bool get hasSelectedText {
    final text = selectedText?.trim();
    return text != null && text.isNotEmpty;
  }

  /// Deterministic prompt label based on category / type.
  String get promptLabel {
    if (categoryId == BuiltInCategoryIds.question) {
      return shortText.trim();
    }
    return switch (categoryId) {
      BuiltInCategoryIds.definition => 'Define this concept.',
      BuiltInCategoryIds.formula => 'Explain this formula.',
      BuiltInCategoryIds.example => 'Explain why this example matters.',
      BuiltInCategoryIds.confusing => 'Try to explain this difficult point.',
      BuiltInCategoryIds.exam => 'Recall this exam-important concept.',
      BuiltInCategoryIds.important => 'Explain why this is important.',
      _ =>
        annotationType == StudyPinType.text
            ? 'Explain this in your own words.'
            : 'Explain this concept.',
    };
  }

  bool get isQuestionCategory => categoryId == BuiltInCategoryIds.question;
}

/// Stable category id constants mirrored from built-in seeds.
abstract final class BuiltInCategoryIds {
  static const definition = 'cat_definition';
  static const important = 'cat_important';
  static const formula = 'cat_formula';
  static const question = 'cat_question';
  static const example = 'cat_example';
  static const exam = 'cat_exam';
  static const confusing = 'cat_confusing';
}

/// In-memory review session (UI state + queue).
class ReviewSessionState {
  const ReviewSessionState({
    required this.sessionId,
    required this.scope,
    required this.items,
    required this.currentIndex,
    required this.revealed,
    required this.latestRatings,
    required this.againRequeued,
    required this.completed,
    required this.filters,
    this.cardShownAt,
  });

  final String sessionId;
  final ReviewScope scope;
  final List<StudyReviewItem> items;
  final int currentIndex;
  final bool revealed;
  final Map<String, ReviewRating> latestRatings;
  final Set<String> againRequeued;
  final bool completed;
  final ReviewSessionFilters filters;
  final DateTime? cardShownAt;

  StudyReviewItem? get currentItem {
    if (completed || currentIndex < 0 || currentIndex >= items.length) {
      return null;
    }
    return items[currentIndex];
  }

  int get totalCount => items.length;

  int get progressNumber => completed
      ? totalCount
      : (currentIndex + 1).clamp(0, totalCount == 0 ? 0 : totalCount);

  ReviewRating? get currentRating {
    final item = currentItem;
    if (item == null) return null;
    return latestRatings[item.studyPinId];
  }

  Map<ReviewRating, int> get ratingCounts {
    final counts = {for (final r in ReviewRating.values) r: 0};
    for (final rating in latestRatings.values) {
      counts[rating] = (counts[rating] ?? 0) + 1;
    }
    return counts;
  }

  List<StudyReviewItem> itemsWithRating(ReviewRating rating) {
    final ids = latestRatings.entries
        .where((e) => e.value == rating)
        .map((e) => e.key)
        .toSet();
    final seen = <String>{};
    final result = <StudyReviewItem>[];
    for (final item in items) {
      if (ids.contains(item.studyPinId) && seen.add(item.studyPinId)) {
        result.add(item);
      }
    }
    return result;
  }

  ReviewSessionState copyWith({
    List<StudyReviewItem>? items,
    int? currentIndex,
    bool? revealed,
    Map<String, ReviewRating>? latestRatings,
    Set<String>? againRequeued,
    bool? completed,
    DateTime? cardShownAt,
    bool clearCardShownAt = false,
  }) {
    return ReviewSessionState(
      sessionId: sessionId,
      scope: scope,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      revealed: revealed ?? this.revealed,
      latestRatings: latestRatings ?? this.latestRatings,
      againRequeued: againRequeued ?? this.againRequeued,
      completed: completed ?? this.completed,
      filters: filters,
      cardShownAt: clearCardShownAt ? null : (cardShownAt ?? this.cardShownAt),
    );
  }
}
