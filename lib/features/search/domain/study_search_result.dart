/// Unified search / favorites destination types.
enum StudyEntityKind {
  class_,
  subject,
  lesson,
  material,
  studyPin,
  note,
  flashcard,
  bookmark,
}

/// Lightweight search hit for the Search UI.
class StudySearchResult {
  const StudySearchResult({
    required this.kind,
    required this.id,
    required this.title,
    required this.breadcrumb,
    this.subtitle,
    this.matchedSnippet,
    this.isFavorite = false,
    this.categoryId,
    this.categoryName,
    this.pageNumber,
    this.classId,
    this.subjectId,
    this.lessonId,
    this.materialId,
    this.materialTitle,
    this.mimeType,
    this.pinType,
  });

  final StudyEntityKind kind;
  final String id;
  final String title;
  final String breadcrumb;
  final String? subtitle;
  final String? matchedSnippet;
  final bool isFavorite;
  final String? categoryId;
  final String? categoryName;
  final int? pageNumber;

  /// Navigation metadata
  final String? classId;
  final String? subjectId;
  final String? lessonId;
  final String? materialId;
  final String? materialTitle;
  final String? mimeType;
  final String? pinType;
}

enum SearchResultFilter {
  all,
  classes,
  subjects,
  lessons,
  materials,
  pins,
  notes,
  flashcards,
  bookmarks,
}

extension SearchResultFilterX on SearchResultFilter {
  String get label => switch (this) {
    SearchResultFilter.all => 'All',
    SearchResultFilter.classes => 'Classes',
    SearchResultFilter.subjects => 'Subjects',
    SearchResultFilter.lessons => 'Lessons',
    SearchResultFilter.materials => 'Materials',
    SearchResultFilter.pins => 'Pins',
    SearchResultFilter.notes => 'Notes',
    SearchResultFilter.flashcards => 'Flashcards',
    SearchResultFilter.bookmarks => 'Bookmarks',
  };

  StudyEntityKind? get asKind => switch (this) {
    SearchResultFilter.all => null,
    SearchResultFilter.classes => StudyEntityKind.class_,
    SearchResultFilter.subjects => StudyEntityKind.subject,
    SearchResultFilter.lessons => StudyEntityKind.lesson,
    SearchResultFilter.materials => StudyEntityKind.material,
    SearchResultFilter.pins => StudyEntityKind.studyPin,
    SearchResultFilter.notes => StudyEntityKind.note,
    SearchResultFilter.flashcards => StudyEntityKind.flashcard,
    SearchResultFilter.bookmarks => StudyEntityKind.bookmark,
  };
}
