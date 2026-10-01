import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/database/database_provider.dart';
import '../../search/domain/study_search_result.dart';

class FavoriteDisplayItem {
  const FavoriteDisplayItem({
    required this.entityType,
    required this.entityId,
    required this.kind,
    required this.title,
    required this.breadcrumb,
    this.subtitle,
    this.materialId,
    this.materialTitle,
    this.mimeType,
    this.pageNumber,
  });

  final String entityType;
  final String entityId;
  final StudyEntityKind kind;
  final String title;
  final String breadcrumb;
  final String? subtitle;
  final String? materialId;
  final String? materialTitle;
  final String? mimeType;
  final int? pageNumber;
}

final favoriteDisplayItemsProvider = StreamProvider<List<FavoriteDisplayItem>>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);
  await for (final favorites in db.watchAllFavorites()) {
    final items = <FavoriteDisplayItem>[];
    for (final fav in favorites) {
      final item = await _resolve(db, fav);
      if (item != null) items.add(item);
    }
    yield items;
  }
});

/// Recent favorites for the Home strip (max 6).
final homeFavoritesProvider = Provider<AsyncValue<List<FavoriteDisplayItem>>>((
  ref,
) {
  return ref
      .watch(favoriteDisplayItemsProvider)
      .whenData((items) => items.take(6).toList());
});

Future<FavoriteDisplayItem?> _resolve(AppDatabase db, Favorite fav) async {
  switch (fav.entityType) {
    case FavoriteEntityType.class_:
      final c = await db.getClassById(fav.entityId);
      if (c == null) return null;
      return FavoriteDisplayItem(
        entityType: fav.entityType,
        entityId: fav.entityId,
        kind: StudyEntityKind.class_,
        title: c.name,
        breadcrumb: 'Class',
      );
    case FavoriteEntityType.subject:
      final s = await db.getSubjectById(fav.entityId);
      if (s == null) return null;
      final c = await db.getClassById(s.classId);
      return FavoriteDisplayItem(
        entityType: fav.entityType,
        entityId: fav.entityId,
        kind: StudyEntityKind.subject,
        title: s.name,
        breadcrumb: c?.name ?? 'Subject',
        subtitle: 'Subject',
      );
    case FavoriteEntityType.lesson:
      final l = await db.getLessonById(fav.entityId);
      if (l == null) return null;
      final s = await db.getSubjectById(l.subjectId);
      final c = s == null ? null : await db.getClassById(s.classId);
      return FavoriteDisplayItem(
        entityType: fav.entityType,
        entityId: fav.entityId,
        kind: StudyEntityKind.lesson,
        title: l.name,
        breadcrumb: [if (c != null) c.name, if (s != null) s.name].join(' › '),
        subtitle: 'Lesson',
      );
    case FavoriteEntityType.material:
      final m = await db.getMaterialById(fav.entityId);
      if (m == null) return null;
      final l = await db.getLessonById(m.lessonId);
      return FavoriteDisplayItem(
        entityType: fav.entityType,
        entityId: fav.entityId,
        kind: StudyEntityKind.material,
        title: m.title,
        breadcrumb: l?.name ?? 'Material',
        subtitle: 'Material',
        materialId: m.id,
        materialTitle: m.title,
        mimeType: m.mimeType,
      );
    case FavoriteEntityType.studyPin:
      final p = await db.getStudyPinById(fav.entityId);
      if (p == null) return null;
      final m = await db.getMaterialById(p.resourceId);
      final category = p.categoryId == null
          ? null
          : await db.getCategoryById(p.categoryId!);
      final page = p.pageNumber;
      return FavoriteDisplayItem(
        entityType: fav.entityType,
        entityId: fav.entityId,
        kind: StudyEntityKind.studyPin,
        title: p.shortText,
        breadcrumb: [
          if (m != null) m.title,
          if (page != null) 'page $page',
        ].join(' • '),
        subtitle: category?.name ?? 'Pin',
        materialId: m?.id,
        materialTitle: m?.title,
        mimeType: m?.mimeType,
        pageNumber: page,
      );
    case FavoriteEntityType.note:
      final note = await db.getStudyNoteById(fav.entityId);
      if (note == null) return null;
      return FavoriteDisplayItem(
        entityType: fav.entityType,
        entityId: fav.entityId,
        kind: StudyEntityKind.note,
        title: note.title,
        breadcrumb: note.lessonId == null ? 'Subject note' : 'Lesson note',
        subtitle: note.plainTextContent,
      );
    case FavoriteEntityType.flashcard:
      final card = await db.getFlashcardById(fav.entityId);
      if (card == null) return null;
      return FavoriteDisplayItem(
        entityType: fav.entityType,
        entityId: fav.entityId,
        kind: StudyEntityKind.flashcard,
        title: card.front,
        breadcrumb: 'Flashcard',
        subtitle: card.backPlainText,
      );
    default:
      return null;
  }
}
