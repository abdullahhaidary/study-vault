import 'manual_entry_models.dart';

enum ManualEntryKind {
  studyMaterial,
  note,
  annotation,
  flashcard,
  quiz,
  courseReview,
}

extension ManualEntryKindX on ManualEntryKind {
  String get label => switch (this) {
    ManualEntryKind.studyMaterial => 'AI Study Materials',
    ManualEntryKind.note => 'Notes',
    ManualEntryKind.annotation => 'Annotations',
    ManualEntryKind.flashcard => 'Flashcards',
    ManualEntryKind.quiz => 'Quizzes',
    ManualEntryKind.courseReview => 'Course Review',
  };

  /// Versioned kinds: overlapping content becomes a new version.
  bool get isVersioned =>
      this == ManualEntryKind.studyMaterial ||
      this == ManualEntryKind.courseReview;

  bool get needsLesson => this != ManualEntryKind.courseReview;
}

/// How to handle an item that overlaps something already saved.
enum ConflictResolution { add, replace, skip }

extension ConflictResolutionX on ConflictResolution {
  String label(ManualEntryKind kind) => switch (this) {
    ConflictResolution.add => kind.isVersioned ? 'New version' : 'Add',
    ConflictResolution.replace =>
      kind.isVersioned ? 'Replace latest' : 'Replace',
    ConflictResolution.skip => 'Skip',
  };
}

/// A PDF a Course Review section can be attached to.
class ManualEntryPdfChoice {
  const ManualEntryPdfChoice({required this.id, required this.label});
  final String id;
  final String label;
}

/// An existing row the imported item overlaps with.
class ExistingMatch {
  const ExistingMatch({required this.id, required this.description});
  final String id;

  /// e.g. `Summary v2 · 1,204 chars` or `Note "Key terms"`.
  final String description;
}

/// One importable thing with the user's decision attached.
class ManualEntryPlanItem {
  ManualEntryPlanItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.preview,
    required this.markdown,
    this.existing,
    this.page,
    this.detail,
    this.targetMaterialId,
    this.requiresTarget = false,
    bool? included,
    ConflictResolution? resolution,
  }) : included = included ?? true,
       resolution = resolution ?? ConflictResolution.add;

  final String id;
  final ManualEntryKind kind;
  final String title;

  /// One-line description for lists.
  final String preview;

  /// Full markdown shown in the preview reader.
  final String markdown;
  final ExistingMatch? existing;
  final int? page;

  /// Extra line, e.g. `12 questions · mixed`.
  final String? detail;

  /// PDF a Course Review section is written to; required when
  /// [requiresTarget].
  final String? targetMaterialId;
  final bool requiresTarget;

  bool included;
  ConflictResolution resolution;

  bool get hasConflict => existing != null;

  bool get missingTarget => requiresTarget && targetMaterialId == null;

  /// Whether applying this item writes anything.
  bool get willWrite =>
      included && resolution != ConflictResolution.skip && !missingTarget;

  bool get replaces => willWrite && resolution == ConflictResolution.replace;
}

/// Counts shown as "before → after" in the preview.
class ManualEntryCounts {
  const ManualEntryCounts({
    required this.studyMaterialVersions,
    required this.notes,
    required this.annotations,
    required this.flashcards,
    required this.quizzes,
    this.courseReviewParts = 0,
  });

  final int studyMaterialVersions;
  final int notes;
  final int annotations;
  final int flashcards;
  final int quizzes;

  /// Review sections plus subject-wide parts that currently exist.
  final int courseReviewParts;

  int forKind(ManualEntryKind kind) => switch (kind) {
    ManualEntryKind.studyMaterial => studyMaterialVersions,
    ManualEntryKind.note => notes,
    ManualEntryKind.annotation => annotations,
    ManualEntryKind.flashcard => flashcards,
    ManualEntryKind.quiz => quizzes,
    ManualEntryKind.courseReview => courseReviewParts,
  };
}

/// Where the content will be written. Course Review content needs only the
/// subject; everything else needs a lesson.
class ManualEntryTarget {
  const ManualEntryTarget({
    this.lessonId,
    this.lessonName,
    required this.subjectId,
    this.subjectName,
    this.materialId,
    this.materialTitle,
  });

  final String? lessonId;
  final String? lessonName;
  final String subjectId;
  final String? subjectName;
  final String? materialId;
  final String? materialTitle;

  String get displayName => lessonName ?? subjectName ?? 'Subject';
}

/// Something already saved on the target, shown in the virtual lesson preview.
class ManualEntryExistingItem {
  const ManualEntryExistingItem({
    required this.id,
    required this.kind,
    required this.title,
    this.detail,
    this.page,
  });

  final String id;
  final ManualEntryKind kind;
  final String title;
  final String? detail;
  final int? page;
}

class ManualEntryPlan {
  ManualEntryPlan({
    required this.bundle,
    required this.target,
    required this.items,
    required this.before,
    this.existing = const [],
    this.reviewPdfs = const [],
  });

  final ManualEntryBundle bundle;
  final ManualEntryTarget target;
  final List<ManualEntryPlanItem> items;
  final ManualEntryCounts before;
  final List<ManualEntryExistingItem> existing;

  /// Subject PDFs that Course Review sections can be attached to.
  final List<ManualEntryPdfChoice> reviewPdfs;

  /// Lesson content is selected but no lesson is chosen.
  bool get missingLesson =>
      target.lessonId == null &&
      items.any((i) => i.willWrite && i.kind.needsLesson);

  /// Course Review sections still waiting for a PDF choice.
  int get unassignedSections =>
      items.where((i) => i.included && i.missingTarget).length;

  bool get canSave => writeCount > 0 && !missingPdf && !missingLesson;

  /// Existing rows that a replacing item will overwrite.
  Set<String> get replacedIds => {
    for (final item in items)
      if (item.replaces) item.existing!.id,
  };

  Iterable<ManualEntryPlanItem> ofKind(ManualEntryKind kind) =>
      items.where((i) => i.kind == kind);

  int get writeCount => items.where((i) => i.willWrite).length;

  /// Items that need a PDF but none is selected.
  bool get missingPdf =>
      target.materialId == null &&
      items.any(
        (i) =>
            i.willWrite &&
            (i.kind == ManualEntryKind.studyMaterial ||
                i.kind == ManualEntryKind.annotation),
      );

  ManualEntryCounts get after {
    int added(ManualEntryKind kind) => ofKind(kind)
        .where((i) => i.willWrite && i.resolution == ConflictResolution.add)
        .length;
    return ManualEntryCounts(
      studyMaterialVersions:
          before.studyMaterialVersions + added(ManualEntryKind.studyMaterial),
      notes: before.notes + added(ManualEntryKind.note),
      annotations: before.annotations + added(ManualEntryKind.annotation),
      flashcards: before.flashcards + added(ManualEntryKind.flashcard),
      quizzes: before.quizzes + added(ManualEntryKind.quiz),
      courseReviewParts:
          before.courseReviewParts +
          ofKind(
            ManualEntryKind.courseReview,
          ).where((i) => i.willWrite && !i.hasConflict).length,
    );
  }
}

class ManualEntryImportResult {
  const ManualEntryImportResult({
    required this.added,
    required this.replaced,
    required this.skipped,
  });

  final int added;
  final int replaced;
  final int skipped;

  String get summary {
    final parts = <String>[
      if (added > 0) '$added added',
      if (replaced > 0) '$replaced replaced',
      if (skipped > 0) '$skipped skipped',
    ];
    return parts.isEmpty ? 'Nothing was saved.' : parts.join(' · ');
  }
}
