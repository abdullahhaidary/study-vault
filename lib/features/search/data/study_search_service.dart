import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/text/search_text_normalizer.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/study_search_result.dart';

/// Local SQLite-backed search across study entities.
class StudySearchService {
  StudySearchService(this._db);

  final AppDatabase _db;

  Future<List<StudySearchResult>> search({
    required String query,
    SearchResultFilter typeFilter = SearchResultFilter.all,
    String? categoryId,
    bool favoritesOnly = false,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final pattern = SearchTextNormalizer.likePattern(q);
    final results = <StudySearchResult>[];

    final favoriteClassIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.class_,
    );
    final favoriteSubjectIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.subject,
    );
    final favoriteLessonIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.lesson,
    );
    final favoriteMaterialIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.material,
    );
    final favoritePinIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.studyPin,
    );
    final favoriteNoteIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.note,
    );
    final favoriteFlashcardIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.flashcard,
    );

    final categories = {for (final c in await _db.getAllCategories()) c.id: c};

    final kind = typeFilter.asKind;

    if (kind == null || kind == StudyEntityKind.class_) {
      results.addAll(
        await _searchClasses(
          pattern,
          favoritesOnly: favoritesOnly,
          favoriteIds: favoriteClassIds,
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.subject) {
      results.addAll(
        await _searchSubjects(
          pattern,
          favoritesOnly: favoritesOnly,
          favoriteIds: favoriteSubjectIds,
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.lesson) {
      results.addAll(
        await _searchLessons(
          pattern,
          favoritesOnly: favoritesOnly,
          favoriteIds: favoriteLessonIds,
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.material) {
      results.addAll(
        await _searchMaterials(
          pattern,
          favoritesOnly: favoritesOnly,
          favoriteIds: favoriteMaterialIds,
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.studyPin) {
      results.addAll(
        await _searchPins(
          pattern,
          query: q,
          favoritesOnly: favoritesOnly,
          favoriteIds: favoritePinIds,
          categoryId: categoryId,
          categories: categories,
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.note) {
      results.addAll(
        await _searchNotes(
          pattern,
          favoritesOnly: favoritesOnly,
          favoriteIds: favoriteNoteIds,
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.flashcard) {
      results.addAll(
        await _searchFlashcards(
          pattern,
          favoritesOnly: favoritesOnly,
          favoriteIds: favoriteFlashcardIds,
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.bookmark) {
      results.addAll(
        await _searchBookmarks(pattern, favoritesOnly: favoritesOnly),
      );
    }

    return results;
  }

  Future<List<StudySearchResult>> _searchClasses(
    String pattern, {
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final rows = await _db
        .customSelect(
          '''
SELECT id, name, description
FROM classes
WHERE ${SearchTextNormalizer.sqlNormalizeExpr('name')} LIKE ? ESCAPE '\\'
   OR (description IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('description')} LIKE ? ESCAPE '\\')
ORDER BY name COLLATE NOCASE
LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_db.classes},
        )
        .get();

    return [
      for (final row in rows)
        if (!favoritesOnly || favoriteIds.contains(row.read<String>('id')))
          StudySearchResult(
            kind: StudyEntityKind.class_,
            id: row.read<String>('id'),
            title: row.read<String>('name'),
            breadcrumb: 'Class',
            subtitle: row.readNullable<String>('description'),
            isFavorite: favoriteIds.contains(row.read<String>('id')),
            classId: row.read<String>('id'),
          ),
    ];
  }

  Future<List<StudySearchResult>> _searchSubjects(
    String pattern, {
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final rows = await _db
        .customSelect(
          '''
SELECT s.id, s.name, s.description, s.class_id AS classId, c.name AS className
FROM subjects s
JOIN classes c ON c.id = s.class_id
WHERE ${SearchTextNormalizer.sqlNormalizeExpr('s.name')} LIKE ? ESCAPE '\\'
   OR (s.description IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('s.description')} LIKE ? ESCAPE '\\')
ORDER BY s.name COLLATE NOCASE
LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_db.subjects, _db.classes},
        )
        .get();

    return [
      for (final row in rows)
        if (!favoritesOnly || favoriteIds.contains(row.read<String>('id')))
          StudySearchResult(
            kind: StudyEntityKind.subject,
            id: row.read<String>('id'),
            title: row.read<String>('name'),
            breadcrumb: row.read<String>('className'),
            subtitle: 'Subject',
            isFavorite: favoriteIds.contains(row.read<String>('id')),
            classId: row.read<String>('classId'),
            subjectId: row.read<String>('id'),
          ),
    ];
  }

  Future<List<StudySearchResult>> _searchLessons(
    String pattern, {
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final rows = await _db
        .customSelect(
          '''
SELECT l.id, l.name, l.description, l.subject_id AS subjectId,
       s.name AS subjectName, s.class_id AS classId, c.name AS className
FROM lessons l
JOIN subjects s ON s.id = l.subject_id
JOIN classes c ON c.id = s.class_id
WHERE ${SearchTextNormalizer.sqlNormalizeExpr('l.name')} LIKE ? ESCAPE '\\'
   OR (l.description IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('l.description')} LIKE ? ESCAPE '\\')
ORDER BY l.name COLLATE NOCASE
LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_db.lessons, _db.subjects, _db.classes},
        )
        .get();

    return [
      for (final row in rows)
        if (!favoritesOnly || favoriteIds.contains(row.read<String>('id')))
          StudySearchResult(
            kind: StudyEntityKind.lesson,
            id: row.read<String>('id'),
            title: row.read<String>('name'),
            breadcrumb:
                '${row.read<String>('className')} › ${row.read<String>('subjectName')}',
            subtitle: 'Lesson',
            isFavorite: favoriteIds.contains(row.read<String>('id')),
            classId: row.read<String>('classId'),
            subjectId: row.read<String>('subjectId'),
            lessonId: row.read<String>('id'),
          ),
    ];
  }

  Future<List<StudySearchResult>> _searchMaterials(
    String pattern, {
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final rows = await _db
        .customSelect(
          '''
SELECT m.id, m.title, m.original_file_name AS originalFileName,
       m.mime_type AS mimeType, m.lesson_id AS lessonId,
       l.name AS lessonName, l.subject_id AS subjectId,
       s.name AS subjectName, s.class_id AS classId, c.name AS className
FROM lesson_materials m
JOIN lessons l ON l.id = m.lesson_id
JOIN subjects s ON s.id = l.subject_id
JOIN classes c ON c.id = s.class_id
WHERE ${SearchTextNormalizer.sqlNormalizeExpr('m.title')} LIKE ? ESCAPE '\\'
   OR ${SearchTextNormalizer.sqlNormalizeExpr('m.original_file_name')} LIKE ? ESCAPE '\\'
ORDER BY m.title COLLATE NOCASE
LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {
            _db.lessonMaterials,
            _db.lessons,
            _db.subjects,
            _db.classes,
          },
        )
        .get();

    return [
      for (final row in rows)
        if (!favoritesOnly || favoriteIds.contains(row.read<String>('id')))
          StudySearchResult(
            kind: StudyEntityKind.material,
            id: row.read<String>('id'),
            title: row.read<String>('title'),
            breadcrumb:
                '${row.read<String>('className')} › ${row.read<String>('subjectName')} › ${row.read<String>('lessonName')}',
            subtitle: 'Material',
            isFavorite: favoriteIds.contains(row.read<String>('id')),
            classId: row.read<String>('classId'),
            subjectId: row.read<String>('subjectId'),
            lessonId: row.read<String>('lessonId'),
            materialId: row.read<String>('id'),
            materialTitle: row.read<String>('title'),
            mimeType: row.read<String>('mimeType'),
          ),
    ];
  }

  Future<List<StudySearchResult>> _searchPins(
    String pattern, {
    required String query,
    required bool favoritesOnly,
    required Set<String> favoriteIds,
    required String? categoryId,
    required Map<String, StudyPinCategory> categories,
  }) async {
    final categoryClause = categoryId == null || categoryId.isEmpty
        ? ''
        : 'AND p.category_id = ?';
    final variables = <Variable>[
      Variable.withString(pattern),
      Variable.withString(pattern),
      Variable.withString(pattern),
      if (categoryId != null && categoryId.isNotEmpty)
        Variable.withString(categoryId),
    ];

    final rows = await _db
        .customSelect(
          '''
SELECT p.id, p.short_text AS shortText, p.selected_text AS selectedText,
       p.full_explanation_plain_text AS plainNote, p.page_number AS pageNumber,
       p.pin_type AS pinType, p.category_id AS categoryId,
       p.resource_id AS materialId, m.title AS materialTitle, m.mime_type AS mimeType,
       m.lesson_id AS lessonId,
       l.name AS lessonName, l.subject_id AS subjectId,
       s.name AS subjectName, s.class_id AS classId, c.name AS className
FROM study_pins p
JOIN lesson_materials m ON m.id = p.resource_id
JOIN lessons l ON l.id = m.lesson_id
JOIN subjects s ON s.id = l.subject_id
JOIN classes c ON c.id = s.class_id
WHERE p.deleted_at IS NULL
  AND (
    ${SearchTextNormalizer.sqlNormalizeExpr('p.short_text')} LIKE ? ESCAPE '\\'
    OR (p.selected_text IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('p.selected_text')} LIKE ? ESCAPE '\\')
    OR (p.full_explanation_plain_text IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('p.full_explanation_plain_text')} LIKE ? ESCAPE '\\')
  )
  $categoryClause
ORDER BY p.updated_at DESC
LIMIT 80
''',
          variables: variables,
          readsFrom: {
            _db.studyPins,
            _db.lessonMaterials,
            _db.lessons,
            _db.subjects,
            _db.classes,
          },
        )
        .get();

    final out = <StudySearchResult>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      if (favoritesOnly && !favoriteIds.contains(id)) continue;

      final catId = row.readNullable<String>('categoryId');
      final category = catId == null ? null : categories[catId];
      final page = row.readNullable<int>('pageNumber');
      final lessonName = row.read<String>('lessonName');
      final pageLabel = page == null ? lessonName : '$lessonName • page $page';

      out.add(
        StudySearchResult(
          kind: StudyEntityKind.studyPin,
          id: id,
          title: row.read<String>('shortText'),
          breadcrumb:
              '${row.read<String>('className')} › ${row.read<String>('subjectName')} › $pageLabel',
          subtitle: category?.name ?? 'Pin',
          matchedSnippet: _snippetForPin(
            query: query,
            selected: row.readNullable<String>('selectedText'),
            plainNote: row.readNullable<String>('plainNote'),
          ),
          isFavorite: favoriteIds.contains(id),
          categoryId: catId,
          categoryName: category?.name,
          pageNumber: page,
          classId: row.read<String>('classId'),
          subjectId: row.read<String>('subjectId'),
          lessonId: row.read<String>('lessonId'),
          materialId: row.read<String>('materialId'),
          materialTitle: row.read<String>('materialTitle'),
          mimeType: row.read<String>('mimeType'),
          pinType: row.read<String>('pinType'),
        ),
      );
    }
    return out;
  }

  static String? _snippetForPin({
    required String query,
    String? selected,
    String? plainNote,
  }) {
    final q = SearchTextNormalizer.normalize(query);
    for (final source in [selected, plainNote]) {
      if (source == null || source.isEmpty) continue;
      if (!SearchTextNormalizer.normalize(source).contains(q)) continue;
      return StudyNoteCodec.plainTextPreview(source, maxLength: 120);
    }
    return null;
  }

  Future<List<StudySearchResult>> _searchNotes(
    String pattern, {
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final rows = await _db
        .customSelect(
          '''
SELECT n.id, n.title, n.plain_text_content AS plainText, n.subject_id AS subjectId, n.lesson_id AS lessonId
FROM study_notes n
WHERE n.deleted_at IS NULL AND (
  ${SearchTextNormalizer.sqlNormalizeExpr('n.title')} LIKE ? ESCAPE '\\'
  OR (n.plain_text_content IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('n.plain_text_content')} LIKE ? ESCAPE '\\')
) ORDER BY n.updated_at DESC LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_db.studyNotes},
        )
        .get();
    return [
      for (final row in rows)
        if (!favoritesOnly || favoriteIds.contains(row.read<String>('id')))
          StudySearchResult(
            kind: StudyEntityKind.note,
            id: row.read<String>('id'),
            title: row.read<String>('title'),
            breadcrumb: row.readNullable<String>('lessonId') == null
                ? 'Subject note'
                : 'Lesson note',
            subtitle: row.readNullable<String>('plainText'),
            isFavorite: favoriteIds.contains(row.read<String>('id')),
            subjectId: row.readNullable<String>('subjectId'),
            lessonId: row.readNullable<String>('lessonId'),
          ),
    ];
  }

  Future<List<StudySearchResult>> _searchFlashcards(
    String pattern, {
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final rows = await _db
        .customSelect(
          '''
SELECT id, front, back_plain_text AS backText, subject_id AS subjectId, lesson_id AS lessonId
FROM flashcards
WHERE deleted_at IS NULL AND (
  ${SearchTextNormalizer.sqlNormalizeExpr('front')} LIKE ? ESCAPE '\\'
  OR (back_plain_text IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('back_plain_text')} LIKE ? ESCAPE '\\')
) ORDER BY updated_at DESC LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_db.flashcards},
        )
        .get();
    return [
      for (final row in rows)
        if (!favoritesOnly || favoriteIds.contains(row.read<String>('id')))
          StudySearchResult(
            kind: StudyEntityKind.flashcard,
            id: row.read<String>('id'),
            title: row.read<String>('front'),
            breadcrumb: 'Flashcard',
            subtitle: row.readNullable<String>('backText'),
            isFavorite: favoriteIds.contains(row.read<String>('id')),
            subjectId: row.readNullable<String>('subjectId'),
            lessonId: row.readNullable<String>('lessonId'),
          ),
    ];
  }

  Future<List<StudySearchResult>> _searchBookmarks(
    String pattern, {
    required bool favoritesOnly,
  }) async {
    if (favoritesOnly) return const [];
    final rows = await _db
        .customSelect(
          '''
SELECT b.id, b.title, b.page_number AS pageNumber, b.material_id AS materialId,
       m.title AS materialTitle, m.mime_type AS mimeType, m.lesson_id AS lessonId
FROM material_bookmarks b JOIN lesson_materials m ON m.id = b.material_id
WHERE b.title IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('b.title')} LIKE ? ESCAPE '\\'
ORDER BY b.updated_at DESC LIMIT 50
''',
          variables: [Variable.withString(pattern)],
          readsFrom: {_db.materialBookmarks, _db.lessonMaterials},
        )
        .get();
    return [
      for (final row in rows)
        StudySearchResult(
          kind: StudyEntityKind.bookmark,
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          breadcrumb:
              '${row.read<String>('materialTitle')} • page ${row.read<int>('pageNumber')}',
          subtitle: 'Bookmark',
          materialId: row.read<String>('materialId'),
          materialTitle: row.read<String>('materialTitle'),
          mimeType: row.read<String>('mimeType'),
          lessonId: row.read<String>('lessonId'),
          pageNumber: row.read<int>('pageNumber'),
        ),
    ];
  }

  /// Recent lessons / materials / notes / pins for empty `@` mention query.
  Future<List<StudySearchResult>> suggestMentions({int limit = 24}) async {
    final results = <StudySearchResult>[];
    final favoriteLessonIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.lesson,
    );
    final favoriteMaterialIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.material,
    );
    final favoriteNoteIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.note,
    );
    final favoritePinIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.studyPin,
    );

    final lessonRows = await _db
        .customSelect(
          '''
SELECT l.id, l.name, l.subject_id AS subjectId,
       s.name AS subjectName, s.class_id AS classId, c.name AS className
FROM lessons l
JOIN subjects s ON s.id = l.subject_id
JOIN classes c ON c.id = s.class_id
ORDER BY COALESCE(l.last_studied_at, l.updated_at) DESC
LIMIT 8
''',
          readsFrom: {_db.lessons, _db.subjects, _db.classes},
        )
        .get();
    for (final row in lessonRows) {
      results.add(
        StudySearchResult(
          kind: StudyEntityKind.lesson,
          id: row.read<String>('id'),
          title: row.read<String>('name'),
          breadcrumb:
              '${row.read<String>('className')} › ${row.read<String>('subjectName')}',
          subtitle: 'Lesson',
          isFavorite: favoriteLessonIds.contains(row.read<String>('id')),
          classId: row.read<String>('classId'),
          subjectId: row.read<String>('subjectId'),
          lessonId: row.read<String>('id'),
        ),
      );
    }

    final materialRows = await _db
        .customSelect(
          '''
SELECT m.id, m.title, m.mime_type AS mimeType, m.lesson_id AS lessonId,
       l.name AS lessonName, l.subject_id AS subjectId,
       s.name AS subjectName, s.class_id AS classId, c.name AS className
FROM lesson_materials m
JOIN lessons l ON l.id = m.lesson_id
JOIN subjects s ON s.id = l.subject_id
JOIN classes c ON c.id = s.class_id
ORDER BY m.updated_at DESC
LIMIT 8
''',
          readsFrom: {
            _db.lessonMaterials,
            _db.lessons,
            _db.subjects,
            _db.classes,
          },
        )
        .get();
    for (final row in materialRows) {
      results.add(
        StudySearchResult(
          kind: StudyEntityKind.material,
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          breadcrumb:
              '${row.read<String>('className')} › ${row.read<String>('subjectName')} › ${row.read<String>('lessonName')}',
          subtitle: 'Material',
          isFavorite: favoriteMaterialIds.contains(row.read<String>('id')),
          classId: row.read<String>('classId'),
          subjectId: row.read<String>('subjectId'),
          lessonId: row.read<String>('lessonId'),
          materialId: row.read<String>('id'),
          materialTitle: row.read<String>('title'),
          mimeType: row.read<String>('mimeType'),
        ),
      );
    }

    final noteRows = await _db
        .customSelect(
          '''
SELECT n.id, n.title, n.lesson_id AS lessonId, l.name AS lessonName
FROM study_notes n
LEFT JOIN lessons l ON l.id = n.lesson_id
WHERE n.deleted_at IS NULL
ORDER BY n.updated_at DESC
LIMIT 6
''',
          readsFrom: {_db.studyNotes, _db.lessons},
        )
        .get();
    for (final row in noteRows) {
      final lessonName = row.read<String?>('lessonName');
      results.add(
        StudySearchResult(
          kind: StudyEntityKind.note,
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          breadcrumb: lessonName ?? 'Note',
          subtitle: 'Note',
          isFavorite: favoriteNoteIds.contains(row.read<String>('id')),
          lessonId: row.read<String?>('lessonId'),
        ),
      );
    }

    final pinRows = await _db
        .customSelect(
          '''
SELECT p.id, p.short_text AS shortText, p.page_number AS pageNumber,
       p.resource_id AS materialId, m.title AS materialTitle,
       m.lesson_id AS lessonId, m.mime_type AS mimeType
FROM study_pins p
JOIN lesson_materials m ON m.id = p.resource_id
WHERE p.deleted_at IS NULL
ORDER BY p.updated_at DESC
LIMIT 6
''',
          readsFrom: {_db.studyPins, _db.lessonMaterials},
        )
        .get();
    for (final row in pinRows) {
      final page = row.read<int?>('pageNumber');
      results.add(
        StudySearchResult(
          kind: StudyEntityKind.studyPin,
          id: row.read<String>('id'),
          title: row.read<String>('shortText'),
          breadcrumb: page == null
              ? row.read<String>('materialTitle')
              : '${row.read<String>('materialTitle')} • page $page',
          subtitle: 'Pin',
          isFavorite: favoritePinIds.contains(row.read<String>('id')),
          lessonId: row.read<String>('lessonId'),
          materialId: row.read<String>('materialId'),
          materialTitle: row.read<String>('materialTitle'),
          mimeType: row.read<String>('mimeType'),
          pageNumber: page,
        ),
      );
    }

    if (results.length <= limit) return results;
    return results.sublist(0, limit);
  }

  /// Mention picker search: empty → recent; otherwise lessons/materials/notes/pins.
  Future<List<StudySearchResult>> searchForMentions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return suggestMentions();

    final results = <StudySearchResult>[];
    for (final filter in [
      SearchResultFilter.lessons,
      SearchResultFilter.materials,
      SearchResultFilter.notes,
      SearchResultFilter.pins,
    ]) {
      results.addAll(await search(query: q, typeFilter: filter));
    }
    return results;
  }
}
