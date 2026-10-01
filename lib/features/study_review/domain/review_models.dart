/// Where a review session draws its Study Pins from.
enum ReviewScopeType {
  lesson,
  material,
  subject,
  favorites;

  String get storageValue => name;

  static ReviewScopeType fromStorage(String value) {
    return ReviewScopeType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReviewScopeType.lesson,
    );
  }

  String get label => switch (this) {
    ReviewScopeType.lesson => 'Lesson',
    ReviewScopeType.material => 'Material',
    ReviewScopeType.subject => 'Subject',
    ReviewScopeType.favorites => 'Favorites',
  };
}

/// Self-assessment recall rating (not spaced-repetition scheduling).
enum ReviewRating {
  again,
  hard,
  good,
  easy;

  String get storageValue => name;

  static ReviewRating fromStorage(String value) {
    return ReviewRating.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReviewRating.again,
    );
  }

  String get label => switch (this) {
    ReviewRating.again => 'Again',
    ReviewRating.hard => 'Hard',
    ReviewRating.good => 'Good',
    ReviewRating.easy => 'Easy',
  };

  String get hint => switch (this) {
    ReviewRating.again => 'I did not remember it.',
    ReviewRating.hard => 'I remembered only part of it.',
    ReviewRating.good => 'I remembered it correctly.',
    ReviewRating.easy => 'I knew it immediately.',
  };
}

/// Filters applied when building a review queue.
class ReviewSessionFilters {
  const ReviewSessionFilters({
    this.categoryIds,
    this.favoritesOnly = false,
    this.includePoint = true,
    this.includeText = true,
    this.shuffle = true,
  });

  /// Null or empty = all categories (including uncategorized / General).
  final Set<String?>? categoryIds;
  final bool favoritesOnly;
  final bool includePoint;
  final bool includeText;
  final bool shuffle;

  ReviewSessionFilters copyWith({
    Set<String?>? categoryIds,
    bool? favoritesOnly,
    bool? includePoint,
    bool? includeText,
    bool? shuffle,
  }) {
    return ReviewSessionFilters(
      categoryIds: categoryIds ?? this.categoryIds,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      includePoint: includePoint ?? this.includePoint,
      includeText: includeText ?? this.includeText,
      shuffle: shuffle ?? this.shuffle,
    );
  }
}

/// Launch parameters for a review session.
class ReviewScope {
  const ReviewScope({required this.type, this.id, required this.title});

  final ReviewScopeType type;

  /// Entity id; null for [ReviewScopeType.favorites].
  final String? id;
  final String title;

  @override
  bool operator ==(Object other) {
    return other is ReviewScope &&
        other.type == type &&
        other.id == id &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(type, id, title);
}
