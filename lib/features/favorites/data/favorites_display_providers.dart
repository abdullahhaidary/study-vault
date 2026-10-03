import 'package:drift/drift.dart';
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
    yield await resolveFavoriteDisplayItems(db, favorites);
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

Future<List<FavoriteDisplayItem>> resolveFavoriteDisplayItems(
  AppDatabase db,
  List<Favorite> favorites,
) async {
  if (favorites.isEmpty) return const [];
  List<String> ids(String type) => [
    for (final fav in favorites)
      if (fav.entityType == type) fav.entityId,
  ];

  final pins = await (db.select(
    db.studyPins,
  )..where((t) => t.id.isIn(ids(FavoriteEntityType.studyPin)))).get();
  final materials =
      await (db.select(db.lessonMaterials)..where(
            (t) => t.id.isIn([
              ...ids(FavoriteEntityType.material),
              for (final pin in pins) pin.resourceId,
            ]),
          ))
          .get();
  final lessons =
      await (db.select(db.lessons)..where(
            (t) => t.id.isIn([
              ...ids(FavoriteEntityType.lesson),
              for (final material in materials) material.lessonId,
            ]),
          ))
          .get();
  final subjects =
      await (db.select(db.subjects)..where(
            (t) => t.id.isIn([
              ...ids(FavoriteEntityType.subject),
              for (final lesson in lessons) lesson.subjectId,
            ]),
          ))
          .get();
  final classes =
      await (db.select(db.classes)..where(
            (t) => t.id.isIn([
              ...ids(FavoriteEntityType.class_),
              for (final subject in subjects) subject.classId,
            ]),
          ))
          .get();
  final categories =
      await (db.select(db.studyPinCategories)..where(
            (t) => t.id.isIn([
              for (final pin in pins)
                if (pin.categoryId != null) pin.categoryId!,
            ]),
          ))
          .get();
  final notes = await (db.select(
    db.studyNotes,
  )..where((t) => t.id.isIn(ids(FavoriteEntityType.note)))).get();
  final flashcards = await (db.select(
    db.flashcards,
  )..where((t) => t.id.isIn(ids(FavoriteEntityType.flashcard)))).get();

  final pinsById = {for (final pin in pins) pin.id: pin};
  final materialsById = {
    for (final material in materials) material.id: material,
  };
  final lessonsById = {for (final lesson in lessons) lesson.id: lesson};
  final subjectsById = {for (final subject in subjects) subject.id: subject};
  final classesById = {
    for (final studyClass in classes) studyClass.id: studyClass,
  };
  final categoriesById = {
    for (final category in categories) category.id: category,
  };
  final notesById = {for (final note in notes) note.id: note};
  final flashcardsById = {for (final card in flashcards) card.id: card};

  final items = <FavoriteDisplayItem>[];
  for (final fav in favorites) {
    FavoriteDisplayItem? item;
    switch (fav.entityType) {
      case FavoriteEntityType.class_:
        final c = classesById[fav.entityId];
        if (c == null) continue;
        item = FavoriteDisplayItem(
          entityType: fav.entityType,
          entityId: fav.entityId,
          kind: StudyEntityKind.class_,
          title: c.name,
          breadcrumb: 'Class',
        );
      case FavoriteEntityType.subject:
        final s = subjectsById[fav.entityId];
        if (s == null) continue;
        item = FavoriteDisplayItem(
          entityType: fav.entityType,
          entityId: fav.entityId,
          kind: StudyEntityKind.subject,
          title: s.name,
          breadcrumb: classesById[s.classId]?.name ?? 'Subject',
          subtitle: 'Subject',
        );
      case FavoriteEntityType.lesson:
        final l = lessonsById[fav.entityId];
        if (l == null) continue;
        final s = subjectsById[l.subjectId];
        final c = s == null ? null : classesById[s.classId];
        item = FavoriteDisplayItem(
          entityType: fav.entityType,
          entityId: fav.entityId,
          kind: StudyEntityKind.lesson,
          title: l.name,
          breadcrumb: [
            if (c != null) c.name,
            if (s != null) s.name,
          ].join(' › '),
          subtitle: 'Lesson',
        );
      case FavoriteEntityType.material:
        final m = materialsById[fav.entityId];
        if (m == null) continue;
        item = FavoriteDisplayItem(
          entityType: fav.entityType,
          entityId: fav.entityId,
          kind: StudyEntityKind.material,
          title: m.title,
          breadcrumb: lessonsById[m.lessonId]?.name ?? 'Material',
          subtitle: 'Material',
          materialId: m.id,
          materialTitle: m.title,
          mimeType: m.mimeType,
        );
      case FavoriteEntityType.studyPin:
        final p = pinsById[fav.entityId];
        if (p == null) continue;
        final m = materialsById[p.resourceId];
        final page = p.pageNumber;
        item = FavoriteDisplayItem(
          entityType: fav.entityType,
          entityId: fav.entityId,
          kind: StudyEntityKind.studyPin,
          title: p.shortText,
          breadcrumb: [
            if (m != null) m.title,
            if (page != null) 'page $page',
          ].join(' • '),
          subtitle: p.categoryId == null
              ? 'Pin'
              : categoriesById[p.categoryId]?.name ?? 'Pin',
          materialId: m?.id,
          materialTitle: m?.title,
          mimeType: m?.mimeType,
          pageNumber: page,
        );
      case FavoriteEntityType.note:
        final note = notesById[fav.entityId];
        if (note == null) continue;
        item = FavoriteDisplayItem(
          entityType: fav.entityType,
          entityId: fav.entityId,
          kind: StudyEntityKind.note,
          title: note.title,
          breadcrumb: note.lessonId == null ? 'Subject note' : 'Lesson note',
          subtitle: note.plainTextContent,
        );
      case FavoriteEntityType.flashcard:
        final card = flashcardsById[fav.entityId];
        if (card == null) continue;
        item = FavoriteDisplayItem(
          entityType: fav.entityType,
          entityId: fav.entityId,
          kind: StudyEntityKind.flashcard,
          title: card.front,
          breadcrumb: 'Flashcard',
          subtitle: card.backPlainText,
        );
    }
    if (item != null) items.add(item);
  }
  return items;
}
