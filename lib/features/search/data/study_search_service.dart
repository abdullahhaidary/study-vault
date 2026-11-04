import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/text/search_text_normalizer.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/study_search_result.dart';
import '../domain/study_search_scope.dart';
import '../../pdf_ai_materials/domain/pdf_ai_material_models.dart';

/// Local SQLite-backed search across study entities.
class StudySearchService {
  StudySearchService(this._db);

  final AppDatabase _db;

  Future<List<StudySearchResult>> search({
    required String query,
    SearchResultFilter typeFilter = SearchResultFilter.all,
    String? categoryId,
    bool favoritesOnly = false,
    StudySearchScope scope = const StudySearchScope.library(),
    bool includeFileContents = true,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final pattern = SearchTextNormalizer.likePattern(q);
    final kind = typeFilter.asKind;
    if (favoritesOnly && kind == StudyEntityKind.bookmark) return const [];

    final favorites = await _db.select(_db.favorites).get();
    final favoriteIds = <String, Set<String>>{};
    for (final favorite in favorites) {
      favoriteIds
          .putIfAbsent(favorite.entityType, () => <String>{})
          .add(favorite.entityId);
    }
    Set<String> ids(String type) => favoriteIds[type] ?? const <String>{};

    final searches = <Future<List<StudySearchResult>>>[];
    if (kind == null || kind == StudyEntityKind.class_) {
      searches.add(
        _searchClasses(
          pattern,
          scope: scope,
          favoritesOnly: favoritesOnly,
          favoriteIds: ids(FavoriteEntityType.class_),
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.subject) {
      searches.add(
        _searchSubjects(
          pattern,
          scope: scope,
          favoritesOnly: favoritesOnly,
          favoriteIds: ids(FavoriteEntityType.subject),
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.lesson) {
      searches.add(
        _searchLessons(
          pattern,
          scope: scope,
          favoritesOnly: favoritesOnly,
          favoriteIds: ids(FavoriteEntityType.lesson),
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.material) {
      searches.add(
        _searchMaterials(
          pattern,
          scope: scope,
          favoritesOnly: favoritesOnly,
          favoriteIds: ids(FavoriteEntityType.material),
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.studyPin) {
      searches.add(() async {
        final categories = {
          for (final c in await _db.getAllCategories()) c.id: c,
        };
        return _searchPins(
          pattern,
          query: q,
          scope: scope,
          favoritesOnly: favoritesOnly,
          favoriteIds: ids(FavoriteEntityType.studyPin),
          categoryId: categoryId,
          categories: categories,
        );
      }());
    }
    if (kind == null || kind == StudyEntityKind.note) {
      searches.add(
        _searchNotes(
          pattern,
          scope: scope,
          favoritesOnly: favoritesOnly,
          favoriteIds: ids(FavoriteEntityType.note),
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.flashcard) {
      searches.add(
        _searchFlashcards(
          pattern,
          scope: scope,
          favoritesOnly: favoritesOnly,
          favoriteIds: ids(FavoriteEntityType.flashcard),
        ),
      );
    }
    if (!favoritesOnly && (kind == null || kind == StudyEntityKind.bookmark)) {
      searches.add(
        _searchBookmarks(pattern, favoritesOnly: false, scope: scope),
      );
    }

    if (includeFileContents &&
        (kind == null || kind == StudyEntityKind.material)) {
      searches.add(
        _searchFilePages(
          q,
          scope,
          favoritesOnly ? ids(FavoriteEntityType.material) : null,
        ),
      );
    }
    if (kind == null || kind == StudyEntityKind.aiMaterial) {
      searches.add(
        _searchAiMaterials(
          q,
          scope,
          favoritesOnly ? ids(FavoriteEntityType.material) : null,
        ),
      );
    }
    if (!favoritesOnly &&
        (kind == null || kind == StudyEntityKind.courseReview)) {
      searches.add(_searchCourseReview(q, scope));
    }
    if (!favoritesOnly && (kind == null || kind == StudyEntityKind.book)) {
      searches.add(_searchBooks(q, scope));
    }
    final results = [for (final batch in await Future.wait(searches)) ...batch];
    int rank(StudySearchResult r) {
      final title = SearchTextNormalizer.normalize(r.title);
      final needle = SearchTextNormalizer.normalize(q);
      return title == needle
          ? 0
          : title.contains(needle)
          ? 1
          : 2;
    }

    results.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final byTitle = a.title.compareTo(b.title);
      return byTitle != 0
          ? byTitle
          : (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0);
    });
    return results.take(250).toList();
  }

  Future<List<StudySearchResult>> _searchClasses(
    String pattern, {
    required StudySearchScope scope,
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final scopeSql = scope.predicate(classId: 'id');
    final scopeValues = [
      if (scope.binds(classId: 'id')) Variable.withString(scope.id!),
    ];
    final rows = await _db
        .customSelect(
          '''
SELECT id, name, description
FROM classes
WHERE (${SearchTextNormalizer.sqlNormalizeExpr('name')} LIKE ? ESCAPE '\\'
   OR (description IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('description')} LIKE ? ESCAPE '\\')
) AND $scopeSql
ORDER BY name COLLATE NOCASE
LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
            ...scopeValues,
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
    required StudySearchScope scope,
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final scopeSql = scope.predicate(classId: 's.class_id', subjectId: 's.id');
    final scopeValues = [
      if (scope.binds(classId: 's.class_id', subjectId: 's.id'))
        Variable.withString(scope.id!),
    ];
    final rows = await _db
        .customSelect(
          '''
SELECT s.id, s.name, s.description, s.class_id AS classId, c.name AS className
FROM subjects s
JOIN classes c ON c.id = s.class_id
WHERE (${SearchTextNormalizer.sqlNormalizeExpr('s.name')} LIKE ? ESCAPE '\\'
   OR (s.description IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('s.description')} LIKE ? ESCAPE '\\')
) AND $scopeSql
ORDER BY s.name COLLATE NOCASE
LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
            ...scopeValues,
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
    required StudySearchScope scope,
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final scopeSql = scope.predicate(
      classId: 's.class_id',
      subjectId: 'l.subject_id',
      lessonId: 'l.id',
    );
    final scopeValues = [
      if (scope.binds(
        classId: 's.class_id',
        subjectId: 'l.subject_id',
        lessonId: 'l.id',
      ))
        Variable.withString(scope.id!),
    ];
    final rows = await _db
        .customSelect(
          '''
SELECT l.id, l.name, l.description, l.subject_id AS subjectId,
       s.name AS subjectName, s.class_id AS classId, c.name AS className
FROM lessons l
JOIN subjects s ON s.id = l.subject_id
JOIN classes c ON c.id = s.class_id
WHERE (${SearchTextNormalizer.sqlNormalizeExpr('l.name')} LIKE ? ESCAPE '\\'
   OR (l.description IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('l.description')} LIKE ? ESCAPE '\\')
) AND $scopeSql
ORDER BY l.name COLLATE NOCASE
LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
            ...scopeValues,
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
    required StudySearchScope scope,
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final scopeSql = scope.predicate(
      classId: 's.class_id',
      subjectId: 'l.subject_id',
      lessonId: 'm.lesson_id',
    );
    final scopeValues = [
      if (scope.binds(
        classId: 's.class_id',
        subjectId: 'l.subject_id',
        lessonId: 'm.lesson_id',
      ))
        Variable.withString(scope.id!),
    ];
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
WHERE (${SearchTextNormalizer.sqlNormalizeExpr('m.title')} LIKE ? ESCAPE '\\'
   OR ${SearchTextNormalizer.sqlNormalizeExpr('m.original_file_name')} LIKE ? ESCAPE '\\'
) AND $scopeSql
ORDER BY m.title COLLATE NOCASE
LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
            ...scopeValues,
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
    required StudySearchScope scope,
    required bool favoritesOnly,
    required Set<String> favoriteIds,
    required String? categoryId,
    required Map<String, StudyPinCategory> categories,
  }) async {
    final scopeSql = scope.predicate(
      classId: 's.class_id',
      subjectId: 'l.subject_id',
      lessonId: 'm.lesson_id',
    );
    final scopeValues = [
      if (scope.binds(
        classId: 's.class_id',
        subjectId: 'l.subject_id',
        lessonId: 'm.lesson_id',
      ))
        Variable.withString(scope.id!),
    ];
    final categoryClause = categoryId == null || categoryId.isEmpty
        ? ''
        : 'AND p.category_id = ?';
    final variables = <Variable>[
      Variable.withString(pattern),
      Variable.withString(pattern),
      Variable.withString(pattern),
      if (categoryId != null && categoryId.isNotEmpty)
        Variable.withString(categoryId),
      ...scopeValues,
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
  AND $scopeSql
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
    required StudySearchScope scope,
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final scopeSql = scope.predicate(
      classId:
          '(SELECT class_id FROM subjects WHERE id = COALESCE(n.subject_id, (SELECT subject_id FROM lessons WHERE id = n.lesson_id)))',
      subjectId:
          'COALESCE(n.subject_id, (SELECT subject_id FROM lessons WHERE id = n.lesson_id))',
      lessonId: 'n.lesson_id',
    );
    final scopeValues = [
      if (scope.binds(
        classId:
            '(SELECT class_id FROM subjects WHERE id = COALESCE(n.subject_id, (SELECT subject_id FROM lessons WHERE id = n.lesson_id)))',
        subjectId:
            'COALESCE(n.subject_id, (SELECT subject_id FROM lessons WHERE id = n.lesson_id))',
        lessonId: 'n.lesson_id',
      ))
        Variable.withString(scope.id!),
    ];
    final rows = await _db
        .customSelect(
          '''
SELECT n.id, n.title, n.plain_text_content AS plainText, n.subject_id AS subjectId, n.lesson_id AS lessonId
FROM study_notes n
WHERE n.deleted_at IS NULL AND (
  ${SearchTextNormalizer.sqlNormalizeExpr('n.title')} LIKE ? ESCAPE '\\'
  OR (n.plain_text_content IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('n.plain_text_content')} LIKE ? ESCAPE '\\')
) AND $scopeSql ORDER BY n.updated_at DESC LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
            ...scopeValues,
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
    required StudySearchScope scope,
    required bool favoritesOnly,
    required Set<String> favoriteIds,
  }) async {
    final scopeSql = scope.predicate(
      classId:
          '(SELECT class_id FROM subjects WHERE id = COALESCE(f.subject_id, (SELECT subject_id FROM lessons WHERE id = f.lesson_id)))',
      subjectId:
          'COALESCE(f.subject_id, (SELECT subject_id FROM lessons WHERE id = f.lesson_id))',
      lessonId: 'f.lesson_id',
    );
    final scopeValues = [
      if (scope.binds(
        classId:
            '(SELECT class_id FROM subjects WHERE id = COALESCE(f.subject_id, (SELECT subject_id FROM lessons WHERE id = f.lesson_id)))',
        subjectId:
            'COALESCE(f.subject_id, (SELECT subject_id FROM lessons WHERE id = f.lesson_id))',
        lessonId: 'f.lesson_id',
      ))
        Variable.withString(scope.id!),
    ];
    final rows = await _db
        .customSelect(
          '''
SELECT id, front, back_plain_text AS backText, subject_id AS subjectId, lesson_id AS lessonId
FROM flashcards f
WHERE deleted_at IS NULL AND (
  ${SearchTextNormalizer.sqlNormalizeExpr('front')} LIKE ? ESCAPE '\\'
  OR (back_plain_text IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('back_plain_text')} LIKE ? ESCAPE '\\')
) AND $scopeSql ORDER BY updated_at DESC LIMIT 50
''',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
            ...scopeValues,
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
    required StudySearchScope scope,
    required bool favoritesOnly,
  }) async {
    final scopeSql = scope.predicate(
      classId:
          '(SELECT s.class_id FROM subjects s JOIN lessons l ON l.subject_id = s.id WHERE l.id = m.lesson_id)',
      subjectId: '(SELECT subject_id FROM lessons WHERE id = m.lesson_id)',
      lessonId: 'm.lesson_id',
    );
    final scopeValues = [
      if (scope.binds(
        classId:
            '(SELECT s.class_id FROM subjects s JOIN lessons l ON l.subject_id = s.id WHERE l.id = m.lesson_id)',
        subjectId: '(SELECT subject_id FROM lessons WHERE id = m.lesson_id)',
        lessonId: 'm.lesson_id',
      ))
        Variable.withString(scope.id!),
    ];
    if (favoritesOnly) return const [];
    final rows = await _db
        .customSelect(
          '''
SELECT b.id, b.title, b.page_number AS pageNumber, b.material_id AS materialId,
       m.title AS materialTitle, m.mime_type AS mimeType, m.lesson_id AS lessonId
FROM material_bookmarks b JOIN lesson_materials m ON m.id = b.material_id
WHERE b.title IS NOT NULL AND ${SearchTextNormalizer.sqlNormalizeExpr('b.title')} LIKE ? ESCAPE '\\'
AND $scopeSql
ORDER BY b.updated_at DESC LIMIT 50
''',
          variables: [Variable.withString(pattern), ...scopeValues],
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

  static String snippet(String text, String query) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalized = SearchTextNormalizer.normalize(flat);
    final needle = SearchTextNormalizer.normalize(query.trim());
    var match = normalized.indexOf(needle);
    if (match < 0) {
      for (final term in needle.split(RegExp(r'\s+'))) {
        final at = normalized.indexOf(term);
        if (at >= 0 && (match < 0 || at < match)) match = at;
      }
    }
    final start = ((match < 0 ? 0 : match) - 65).clamp(0, flat.length);
    final end = (start + 240).clamp(0, flat.length);
    return '${start > 0 ? '…' : ''}${flat.substring(start, end)}${end < flat.length ? '…' : ''}';
  }

  List<Variable> _scopeValues(
    StudySearchScope scope, {
    String? classId,
    String? subjectId,
    String? lessonId,
  }) => [
    if (scope.binds(classId: classId, subjectId: subjectId, lessonId: lessonId))
      Variable.withString(scope.id!),
  ];

  Future<List<StudySearchResult>> _searchFilePages(
    String query,
    StudySearchScope scope,
    Set<String>? favorites,
  ) async {
    if (favorites != null && favorites.isEmpty) return [];
    final hasFts = await _db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'local_search_fts'",
        )
        .getSingleOrNull();
    final normalized = SearchTextNormalizer.normalize(query);
    final terms = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(normalized).map((m) => m.group(0)!).take(16).toList();
    final useFts =
        hasFts != null &&
        terms.isNotEmpty &&
        !RegExp(r'[^\p{L}\p{N}\s\u200c]', unicode: true).hasMatch(normalized);
    final expression = useFts
        ? terms.map((t) => '"$t"*').join(' AND ')
        : SearchTextNormalizer.likePattern(query);
    final scopeSql = scope.predicate(
      classId: 's.class_id',
      subjectId: 's.id',
      lessonId: 'l.id',
    );
    final rows = await _db
        .customSelect(
          '''
SELECT m.id, m.title, m.mime_type AS mimeType, m.lesson_id AS lessonId,
 l.name AS lessonName, s.id AS subjectId, s.name AS subjectName,
 s.class_id AS classId, c.name AS className, p.page, p.text
FROM local_search_pages p
${useFts ? 'JOIN local_search_fts ON local_search_fts.rowid = p.id' : ''}
JOIN local_search_files f ON f.material_id = p.material_id
JOIN lesson_materials m ON m.id = p.material_id
JOIN lessons l ON l.id = m.lesson_id
JOIN subjects s ON s.id = l.subject_id JOIN classes c ON c.id = s.class_id
WHERE ${useFts ? 'local_search_fts MATCH ?' : "p.normalized_text LIKE ? ESCAPE '\\'"}
 AND f.status IN ('ready', 'indexing')
 AND f.material_revision = m.updated_at
 AND f.source_identity = m.lesson_id || '/' || m.stored_file_name || '/' || m.mime_type
 AND $scopeSql
 ${favorites == null ? '' : 'AND m.id IN (${List.filled(favorites.length, '?').join(',')})'}
ORDER BY ${useFts ? 'bm25(local_search_fts),' : ''} m.title COLLATE NOCASE, p.page
LIMIT 100
''',
          variables: [
            Variable.withString(expression),
            ..._scopeValues(
              scope,
              classId: 's.class_id',
              subjectId: 's.id',
              lessonId: 'l.id',
            ),
            if (favorites != null) ...favorites.map(Variable.withString),
          ],
          readsFrom: {
            _db.lessonMaterials,
            _db.lessons,
            _db.subjects,
            _db.classes,
          },
        )
        .get();
    final seenTextFiles = <String>{};
    return [
      for (final r in rows)
        if (r.read<String>('mimeType') == 'application/pdf' ||
            seenTextFiles.add(r.read<String>('id')))
          StudySearchResult(
            kind: StudyEntityKind.material,
            id: r.read<String>('id'),
            title: r.read<String>('title'),
            breadcrumb:
                '${r.read<String>('className')} › ${r.read<String>('subjectName')} › ${r.read<String>('lessonName')}',
            subtitle: r.read<String>('mimeType') == 'application/pdf'
                ? 'PDF · page ${r.read<int>('page')}'
                : 'Inside text document',
            matchedSnippet: snippet(r.read<String>('text'), query),
            isFavorite: favorites?.contains(r.read<String>('id')) ?? false,
            classId: r.read<String>('classId'),
            subjectId: r.read<String>('subjectId'),
            lessonId: r.read<String>('lessonId'),
            materialId: r.read<String>('id'),
            materialTitle: r.read<String>('title'),
            mimeType: r.read<String>('mimeType'),
            pageNumber: r.read<String>('mimeType') == 'application/pdf'
                ? r.read<int>('page')
                : null,
          ),
    ];
  }

  Future<List<StudySearchResult>> _searchAiMaterials(
    String query,
    StudySearchScope scope,
    Set<String>? favorites,
  ) async {
    if (favorites != null && favorites.isEmpty) return [];
    final rows = await _db
        .customSelect(
          '''
SELECT a.id, a.type, a.content, m.id AS materialId, m.title, m.mime_type AS mimeType,
 l.id AS lessonId, l.name AS lessonName, s.id AS subjectId, s.name AS subjectName,
 s.class_id AS classId, c.name AS className
FROM pdf_ai_materials a JOIN lesson_materials m ON m.id = a.material_id
JOIN lessons l ON l.id = m.lesson_id JOIN subjects s ON s.id = l.subject_id JOIN classes c ON c.id = s.class_id
WHERE ${SearchTextNormalizer.sqlNormalizeExpr('a.content')} LIKE ? ESCAPE '\\'
 AND NOT EXISTS (SELECT 1 FROM pdf_ai_materials newer WHERE newer.material_id = a.material_id AND newer.type = a.type AND newer.version > a.version)
 AND ${scope.predicate(classId: 's.class_id', subjectId: 's.id', lessonId: 'l.id')}
 ${favorites == null ? '' : 'AND m.id IN (${List.filled(favorites.length, '?').join(',')})'}
ORDER BY a.generated_at DESC LIMIT 60
''',
          variables: [
            Variable.withString(SearchTextNormalizer.likePattern(query)),
            ..._scopeValues(
              scope,
              classId: 's.class_id',
              subjectId: 's.id',
              lessonId: 'l.id',
            ),
            if (favorites != null) ...favorites.map(Variable.withString),
          ],
          readsFrom: {
            _db.pdfAiMaterials,
            _db.lessonMaterials,
            _db.lessons,
            _db.subjects,
            _db.classes,
          },
        )
        .get();
    return [
      for (final r in rows)
        StudySearchResult(
          kind: StudyEntityKind.aiMaterial,
          id: r.read<String>('id'),
          title: r.read<String>('title'),
          subtitle:
              PdfAiMaterialType.values
                  .where((t) => t.storageValue == r.read<String>('type'))
                  .firstOrNull
                  ?.displayName ??
              'AI material',
          matchedSnippet: snippet(r.read<String>('content'), query),
          breadcrumb:
              '${r.read<String>('className')} › ${r.read<String>('subjectName')} › ${r.read<String>('lessonName')}',
          classId: r.read<String>('classId'),
          subjectId: r.read<String>('subjectId'),
          lessonId: r.read<String>('lessonId'),
          materialId: r.read<String>('materialId'),
          materialTitle: r.read<String>('title'),
          mimeType: r.read<String>('mimeType'),
        ),
    ];
  }

  Future<List<StudySearchResult>> _searchCourseReview(
    String query,
    StudySearchScope scope,
  ) async {
    final rows = await _db
        .customSelect(
          '''
SELECT r.id, r.content, r.part, s.id AS subjectId, s.name AS subjectName, s.class_id AS classId, c.name AS className
FROM course_review_entries r JOIN subjects s ON s.id = r.subject_id JOIN classes c ON c.id = s.class_id
WHERE ${SearchTextNormalizer.sqlNormalizeExpr('r.content')} LIKE ? ESCAPE '\\'
 AND ${scope.predicate(classId: 's.class_id', subjectId: 's.id')}
 AND (r.part = 'document' OR NOT EXISTS (SELECT 1 FROM course_review_entries d WHERE d.subject_id = r.subject_id AND d.part = 'document'))
 AND NOT EXISTS (SELECT 1 FROM course_review_entries n WHERE n.subject_id = r.subject_id AND n.material_id IS r.material_id AND n.part = r.part AND n.version > r.version)
ORDER BY r.created_at DESC LIMIT 40
''',
          variables: [
            Variable.withString(SearchTextNormalizer.likePattern(query)),
            ..._scopeValues(scope, classId: 's.class_id', subjectId: 's.id'),
          ],
          readsFrom: {_db.courseReviewEntries, _db.subjects, _db.classes},
        )
        .get();
    return [
      for (final r in rows)
        StudySearchResult(
          kind: StudyEntityKind.courseReview,
          id: r.read<String>('subjectId'),
          title: '${r.read<String>('subjectName')} · Course Review',
          subtitle: 'Course Review',
          matchedSnippet: snippet(r.read<String>('content'), query),
          breadcrumb:
              '${r.read<String>('className')} › ${r.read<String>('subjectName')}',
          classId: r.read<String>('classId'),
          subjectId: r.read<String>('subjectId'),
        ),
    ];
  }

  Future<List<StudySearchResult>> _searchBooks(
    String query,
    StudySearchScope scope,
  ) async {
    final scopeSql = switch (scope.kind) {
      StudySearchScopeKind.library => '1',
      StudySearchScopeKind.class_ =>
        'EXISTS (SELECT 1 FROM reference_book_subjects bs JOIN subjects s ON s.id = bs.subject_id WHERE bs.book_id = b.id AND s.class_id = ?)',
      StudySearchScopeKind.subject =>
        'EXISTS (SELECT 1 FROM reference_book_subjects bs WHERE bs.book_id = b.id AND bs.subject_id = ?)',
      StudySearchScopeKind.lesson =>
        'EXISTS (SELECT 1 FROM reference_book_links bl JOIN lesson_materials m ON m.id = bl.material_id WHERE bl.book_id = b.id AND m.lesson_id = ?)',
    };
    final vars = [
      Variable.withString(SearchTextNormalizer.likePattern(query)),
      Variable.withString(SearchTextNormalizer.likePattern(query)),
      if (scope.id != null) Variable.withString(scope.id!),
    ];
    final titles = await _db
        .customSelect(
          '''
SELECT b.id, b.title, b.author FROM reference_books b
WHERE (${SearchTextNormalizer.sqlNormalizeExpr('b.title')} LIKE ? ESCAPE '\\'
 OR ${SearchTextNormalizer.sqlNormalizeExpr("COALESCE(b.author, '')")} LIKE ? ESCAPE '\\') AND $scopeSql
ORDER BY b.title LIMIT 30
''',
          variables: vars,
          readsFrom: {
            _db.referenceBooks,
            _db.referenceBookSubjects,
            _db.referenceBookLinks,
          },
        )
        .get();
    final pages = await _db
        .customSelect(
          '''
SELECT b.id, b.title, p.page, p.text FROM local_book_pages p JOIN reference_books b ON b.id = p.book_id
WHERE ${SearchTextNormalizer.sqlNormalizeExpr('p.text')} LIKE ? ESCAPE '\\' AND $scopeSql
ORDER BY b.title, p.page LIMIT 40
''',
          variables: [
            Variable.withString(SearchTextNormalizer.likePattern(query)),
            if (scope.id != null) Variable.withString(scope.id!),
          ],
          readsFrom: {
            _db.referenceBooks,
            _db.referenceBookSubjects,
            _db.referenceBookLinks,
          },
        )
        .get();
    return [
      for (final r in titles)
        StudySearchResult(
          kind: StudyEntityKind.book,
          id: r.read<String>('id'),
          title: r.read<String>('title'),
          breadcrumb: 'Reference books',
          subtitle: r.readNullable<String>('author'),
        ),
      for (final r in pages)
        StudySearchResult(
          kind: StudyEntityKind.book,
          id: r.read<String>('id'),
          title: r.read<String>('title'),
          breadcrumb: 'Reference books',
          subtitle: 'Book · page ${r.read<int>('page')}',
          pageNumber: r.read<int>('page'),
          matchedSnippet: snippet(r.read<String>('text'), query),
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
      results.addAll(
        await search(query: q, typeFilter: filter, includeFileContents: false),
      );
    }
    return results;
  }
}
