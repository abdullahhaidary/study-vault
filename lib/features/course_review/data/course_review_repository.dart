import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../lessons/data/materials_providers.dart' show isDocumentMimeType;
import '../domain/course_review_models.dart';

/// Reads a subject's Course Review and the state of every source PDF.
class CourseReviewRepository {
  CourseReviewRepository(this._db);

  final AppDatabase _db;

  /// Re-emits whenever review content or its sources change.
  Stream<CourseReviewState?> watch(String subjectId) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.subjects,
            _db.lessons,
            _db.lessonMaterials,
            _db.pdfAiMaterials,
            _db.courseReviewEntries,
            _db.courseReviewExclusions,
          },
        )
        .watch()
        .asyncMap((_) => load(subjectId));
  }

  Future<CourseReviewState?> load(String subjectId) async {
    final subject = await (_db.select(
      _db.subjects,
    )..where((t) => t.id.equals(subjectId))).getSingleOrNull();
    if (subject == null) return null;

    final lessons =
        await (_db.select(_db.lessons)
              ..where((t) => t.subjectId.equals(subjectId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get();
    final lessonIds = [for (final l in lessons) l.id];
    final materials = lessonIds.isEmpty
        ? const <LessonMaterial>[]
        : await (_db.select(_db.lessonMaterials)
                ..where((t) => t.lessonId.isIn(lessonIds))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.sortOrder),
                  (t) => OrderingTerm.asc(t.createdAt),
                ]))
              .get();
    final pdfs = materials.where((m) => isDocumentMimeType(m.mimeType)).toList();
    final pdfIds = [for (final m in pdfs) m.id];

    final lessonMaterials = pdfIds.isEmpty
        ? const <PdfAiMaterial>[]
        : await (_db.select(_db.pdfAiMaterials)..where(
                (t) =>
                    t.materialId.isIn(pdfIds) &
                    t.type.isIn(const ['summary', 'explanation']),
              ))
              .get();
    final latestLesson = <String, PdfAiMaterial>{};
    for (final m in lessonMaterials) {
      final key = '${m.materialId}:${m.type}';
      final current = latestLesson[key];
      if (current == null || _newer(m.version, m.generatedAt, current)) {
        latestLesson[key] = m;
      }
    }

    final entries = await _db.courseReviewEntriesForSubject(subjectId);
    final latest = <String?, Map<CourseReviewPart, CourseReviewEntry>>{};
    for (final entry in entries) {
      final part = CourseReviewPart.fromStorage(entry.part);
      if (part == null) continue;
      final map = latest.putIfAbsent(entry.materialId, () => {});
      final current = map[part];
      if (current == null ||
          entry.version > current.version ||
          (entry.version == current.version &&
              entry.createdAt.isAfter(current.createdAt))) {
        map[part] = entry;
      }
    }
    final excluded = {
      for (final e in await _db.courseReviewExclusionsForSubject(subjectId))
        e.materialId,
    };

    final lessonById = {for (final l in lessons) l.id: l};
    final sources = <CourseReviewSource>[];
    for (final lesson in lessons) {
      for (final pdf in pdfs.where((m) => m.lessonId == lesson.id)) {
        final summary = latestLesson['${pdf.id}:summary'];
        final explanation = latestLesson['${pdf.id}:explanation'];
        sources.add(
          CourseReviewSource(
            lesson: lessonById[pdf.lessonId]!,
            material: pdf,
            excluded: excluded.contains(pdf.id),
            latest: {
              for (final e in (latest[pdf.id] ?? const {}).entries)
                if (e.key.isSection) e.key: e.value,
            },
            currentFingerprint: sourceFingerprint(
              pdf,
              summary: summary,
              explanation: explanation,
            ),
            lessonSummary: summary,
            lessonExplanation: explanation,
          ),
        );
      }
    }
    return CourseReviewState(
      subject: subject,
      sources: sources,
      overview: {
        for (final e in (latest[null] ?? const {}).entries)
          if (!e.key.isSection) e.key: e.value,
      },
      overviewFingerprint: overviewFingerprint(sources),
    );
  }

  static bool _newer(int version, DateTime at, PdfAiMaterial current) =>
      version > current.version ||
      (version == current.version && at.isAfter(current.generatedAt));

  /// Lesson materials win over raw PDF text, so regenerating them makes the
  /// section outdated.
  static String sourceFingerprint(
    LessonMaterial pdf, {
    PdfAiMaterial? summary,
    PdfAiMaterial? explanation,
  }) {
    if (summary != null || explanation != null) {
      return 'ai:${summary?.id ?? '-'}:${explanation?.id ?? '-'}';
    }
    return 'pdf:${pdf.id}:${pdf.storedFileName}';
  }

  static String overviewFingerprint(Iterable<CourseReviewSource> sources) {
    final ids = [
      for (final s in sources)
        if (!s.excluded)
          for (final part in CourseReviewPart.sectionParts)
            if (s.latest[part] != null) s.latest[part]!.id,
    ]..sort();
    return 'sections:${sha256.convert(utf8.encode(ids.join(','))).toString().substring(0, 24)}';
  }
}
