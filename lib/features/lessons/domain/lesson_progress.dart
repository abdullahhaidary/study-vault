/// Persisted lesson study progress states.
enum LessonProgressStatus {
  notStarted,
  studying,
  reviewed,
  mastered;

  static const storageNotStarted = 'notStarted';
  static const storageStudying = 'studying';
  static const storageReviewed = 'reviewed';
  static const storageMastered = 'mastered';

  String get storageValue => switch (this) {
    LessonProgressStatus.notStarted => storageNotStarted,
    LessonProgressStatus.studying => storageStudying,
    LessonProgressStatus.reviewed => storageReviewed,
    LessonProgressStatus.mastered => storageMastered,
  };

  String get label => switch (this) {
    LessonProgressStatus.notStarted => 'Not Started',
    LessonProgressStatus.studying => 'Studying',
    LessonProgressStatus.reviewed => 'Reviewed',
    LessonProgressStatus.mastered => 'Mastered',
  };

  static LessonProgressStatus fromStorage(String? value) {
    switch (value) {
      case storageStudying:
        return LessonProgressStatus.studying;
      case storageReviewed:
        return LessonProgressStatus.reviewed;
      case storageMastered:
        return LessonProgressStatus.mastered;
      case storageNotStarted:
      default:
        return LessonProgressStatus.notStarted;
    }
  }
}
