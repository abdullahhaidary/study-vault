import 'manual_entry_models.dart';

enum ManualEntryKind { studyMaterial, note, annotation, flashcard, quiz }

extension ManualEntryKindX on ManualEntryKind {
  String get label => switch (this) {
    ManualEntryKind.studyMaterial => 'AI Study Materials',
    ManualEntryKind.note => 'Notes',
    ManualEntryKind.annotation => 'Annotations',
    ManualEntryKind.flashcard => 'Flashcards',
    ManualEntryKind.quiz => 'Quizzes',
  };
}

/// How to handle an item that overlaps something already saved.
enum ConflictResolution { add, replace, skip }

extension ConflictResolutionX on ConflictResolution {
  String label(ManualEntryKind kind) => switch (this) {
    ConflictResolution.add =>
      kind == ManualEntryKind.studyMaterial ? 'New version' : 'Add',
    ConflictResolution.replace =>
      kind == ManualEntryKind.studyMaterial ? 'Replace latest' : 'Replace',
    ConflictResolution.skip => 'Skip',
  };
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

  bool included;
  ConflictResolution resolution;

  bool get hasConflict => existing != null;

  /// Whether applying this item writes anything.
  bool get willWrite => included && resolution != ConflictResolution.skip;

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
  });

  final int studyMaterialVersions;
  final int notes;
  final int annotations;
  final int flashcards;
  final int quizzes;

  int forKind(ManualEntryKind kind) => switch (kind) {
    ManualEntryKind.studyMaterial => studyMaterialVersions,
    ManualEntryKind.note => notes,
    ManualEntryKind.annotation => annotations,
    ManualEntryKind.flashcard => flashcards,
    ManualEntryKind.quiz => quizzes,
  };
}

/// Where the content will be written.
class ManualEntryTarget {
  const ManualEntryTarget({
    required this.lessonId,
    required this.lessonName,
    required this.subjectId,
    this.materialId,
    this.materialTitle,
  });

  final String lessonId;
  final String lessonName;
  final String subjectId;
  final String? materialId;
  final String? materialTitle;
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
  });

  final ManualEntryBundle bundle;
  final ManualEntryTarget target;
  final List<ManualEntryPlanItem> items;
  final ManualEntryCounts before;
  final List<ManualEntryExistingItem> existing;

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
