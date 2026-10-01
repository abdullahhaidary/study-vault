import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
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

    final pattern = '%${_escapeLike(q.toLowerCase())}%';
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
WHERE lower(name) LIKE ? ESCAPE '\\'
   OR (description IS NOT NULL AND lower(description) LIKE ? ESCAPE '\\')
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
WHERE lower(s.name) LIKE ? ESCAPE '\\'
   OR (s.description IS NOT NULL AND lower(s.description) LIKE ? ESCAPE '\\')
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
WHERE lower(l.name) LIKE ? ESCAPE '\\'
   OR (l.description IS NOT NULL AND lower(l.description) LIKE ? ESCAPE '\\')
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
WHERE lower(m.title) LIKE ? ESCAPE '\\'
   OR lower(m.original_file_name) LIKE ? ESCAPE '\\'
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
    lower(p.short_text) LIKE ? ESCAPE '\\'
    OR (p.selected_text IS NOT NULL AND lower(p.selected_text) LIKE ? ESCAPE '\\')
    OR (p.full_explanation_plain_text IS NOT NULL AND lower(p.full_explanation_plain_text) LIKE ? ESCAPE '\\')
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
    final q = query.toLowerCase();
    for (final source in [selected, plainNote]) {
      if (source == null || source.isEmpty) continue;
      if (!source.toLowerCase().contains(q)) continue;
      return StudyNoteCodec.plainTextPreview(source, maxLength: 120);
    }
    return null;
  }

  static String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
