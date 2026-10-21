import '../../../core/database/app_database.dart';

/// One kind of Course Review content.
enum CourseReviewPart {
  summary('summary', 'Summary', 'SUMMARY'),
  explanation('explanation', 'Explanation', 'EXPLANATION'),
  deepExplanation('deep_explanation', 'Deep', 'DEEP_EXPLANATION'),
  examples('examples', 'Examples', 'EXAMPLES'),
  bigPicture('big_picture', 'Big picture', 'BIG_PICTURE'),

  /// One complete Markdown review for the subject. [materialId] is null.
  document('document', 'Document', 'DOCUMENT');

  const CourseReviewPart(this.storageValue, this.label, this.marker);

  final String storageValue;
  final String label;

  /// Line marker (`<<<MARKER>>>`) separating parts in AI responses.
  final String marker;

  /// Per-PDF parts. The complete document and overview parts are subject-wide.
  bool get isSection =>
      this == summary || this == explanation || this == deepExplanation;

  bool get isOverview => this == examples || this == bigPicture;

  static const sectionParts = [summary, explanation, deepExplanation];
  static const overviewParts = [bigPicture, examples];

  static CourseReviewPart? fromStorage(String value) {
    for (final part in values) {
      if (part.storageValue == value) return part;
    }
    return null;
  }
}

enum CourseReviewSourceStatus {
  notAdded('Not added yet'),
  added('Added'),
  outdated('Outdated'),
  excluded('Excluded');

  const CourseReviewSourceStatus(this.label);
  final String label;
}

/// A PDF in the subject and its latest review section parts.
class CourseReviewSource {
  const CourseReviewSource({
    required this.lesson,
    required this.material,
    required this.excluded,
    required this.latest,
    required this.currentFingerprint,
    this.lessonSummary,
    this.lessonExplanation,
  });

  final Lesson lesson;
  final LessonMaterial material;
  final bool excluded;
  final Map<CourseReviewPart, CourseReviewEntry> latest;

  /// Identity of the input a new section would be generated from.
  final String currentFingerprint;

  /// Latest lesson-level AI materials, preferred over raw PDF text.
  final PdfAiMaterial? lessonSummary;
  final PdfAiMaterial? lessonExplanation;

  String get label => '${lesson.name} — ${material.title}';

  bool get hasSection => latest.isNotEmpty;

  bool get usesLessonMaterials =>
      lessonSummary != null || lessonExplanation != null;

  CourseReviewSourceStatus get status {
    if (excluded) return CourseReviewSourceStatus.excluded;
    if (!hasSection) return CourseReviewSourceStatus.notAdded;
    final stale = latest.values.any(
      (e) => e.sourceFingerprint != currentFingerprint,
    );
    return stale
        ? CourseReviewSourceStatus.outdated
        : CourseReviewSourceStatus.added;
  }
}

class CourseReviewState {
  const CourseReviewState({
    required this.subject,
    required this.sources,
    required this.overview,
    required this.overviewFingerprint,
    required this.document,
    required this.documentFingerprint,
  });

  final Subject subject;

  /// Every PDF in the subject, in lesson then material order.
  final List<CourseReviewSource> sources;

  /// Latest subject-wide parts (examples, big picture).
  final Map<CourseReviewPart, CourseReviewEntry> overview;

  /// Identity of the current included sections; overview parts generated
  /// from a different set are outdated.
  final String overviewFingerprint;

  /// Latest complete review, or null when the subject has none yet.
  final CourseReviewEntry? document;

  /// Identity of every included PDF and that PDF's current source fingerprint.
  final String documentFingerprint;

  Iterable<CourseReviewSource> get included =>
      sources.where((s) => !s.excluded);

  Iterable<CourseReviewSource> get withSections =>
      included.where((s) => s.hasSection);

  int count(CourseReviewSourceStatus status) =>
      sources.where((s) => s.status == status).length;

  bool get isEmpty =>
      document == null && withSections.isEmpty && overview.isEmpty;

  /// Older per-section rows that can be compiled into one document.
  bool get hasLegacyContent =>
      overview.isNotEmpty || sources.any((source) => source.hasSection);

  bool get overviewOutdated =>
      overview.values.any((e) => e.sourceFingerprint != overviewFingerprint);

  /// True when a saved document was built from a different set of sources.
  bool get documentOutdated =>
      document != null && document!.sourceFingerprint != documentFingerprint;

  CourseReviewSource? sourceFor(String materialId) {
    for (final source in sources) {
      if (source.material.id == materialId) return source;
    }
    return null;
  }
}
