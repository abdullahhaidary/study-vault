/// Stable built-in Study Pin category IDs and seed metadata.
///
/// IDs are fixed strings so migrations and code can reference them safely.
abstract final class BuiltInPinCategories {
  static const definition = 'cat_definition';
  static const important = 'cat_important';
  static const formula = 'cat_formula';
  static const question = 'cat_question';
  static const example = 'cat_example';
  static const exam = 'cat_exam';
  static const confusing = 'cat_confusing';

  /// Seed rows: id, name, ARGB color, iconKey, sortOrder.
  static const List<
    ({String id, String name, int colorValue, String iconKey, int sortOrder})
  >
  seeds = [
    (
      id: definition,
      name: 'Definition',
      colorValue: 0xFF1565C0, // blue
      iconKey: 'menu_book',
      sortOrder: 0,
    ),
    (
      id: important,
      name: 'Important',
      colorValue: 0xFFC62828, // red
      iconKey: 'priority_high',
      sortOrder: 1,
    ),
    (
      id: formula,
      name: 'Formula',
      colorValue: 0xFF6A1B9A, // purple
      iconKey: 'functions',
      sortOrder: 2,
    ),
    (
      id: question,
      name: 'Question',
      colorValue: 0xFFEF6C00, // orange
      iconKey: 'help_outline',
      sortOrder: 3,
    ),
    (
      id: example,
      name: 'Example',
      colorValue: 0xFF2E7D32, // green
      iconKey: 'lightbulb_outline',
      sortOrder: 4,
    ),
    (
      id: exam,
      name: 'Exam',
      colorValue: 0xFF00838F, // teal
      iconKey: 'school',
      sortOrder: 5,
    ),
    (
      id: confusing,
      name: 'Confusing',
      colorValue: 0xFFAD1457, // pink
      iconKey: 'psychology_alt',
      sortOrder: 6,
    ),
  ];
}

/// Favorite entity type strings stored in [Favorites.entityType].
abstract final class FavoriteEntityType {
  static const class_ = 'class';
  static const subject = 'subject';
  static const lesson = 'lesson';
  static const material = 'material';
  static const studyPin = 'studyPin';
  static const flashcard = 'flashcard';
  static const note = 'note';

  static const all = [
    class_,
    subject,
    lesson,
    material,
    studyPin,
    flashcard,
    note,
  ];
}
