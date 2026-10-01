import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../study_pins/domain/pin_type.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/review_models.dart';
import '../domain/study_review_item.dart';

const _uuid = Uuid();

/// Loads reviewable pins and persists session / rating events.
class StudyReviewService {
  StudyReviewService(this._db);

  final AppDatabase _db;

  Future<List<StudyReviewItem>> loadItems({
    required ReviewScope scope,
    ReviewSessionFilters filters = const ReviewSessionFilters(),
  }) async {
    final materialIds = await _materialIdsForScope(scope);
    final pins = await _db.getStudyPinsForMaterialIds(materialIds);
    final materials = {
      for (final m in await _db.getMaterialsByIds(materialIds)) m.id: m,
    };
    final categories = {for (final c in await _db.getAllCategories()) c.id: c};
    final favoritePinIds = await _db.favoriteIdsOfType(
      FavoriteEntityType.studyPin,
    );

    var items = <StudyReviewItem>[];
    for (final pin in pins) {
      if (!_isReviewable(pin)) continue;
      final material = materials[pin.resourceId];
      if (material == null) continue;

      final type = StudyPinType.fromDb(pin.pinType);
      if (type == StudyPinType.point && !filters.includePoint) continue;
      if (type == StudyPinType.text && !filters.includeText) continue;

      if (filters.categoryIds != null && filters.categoryIds!.isNotEmpty) {
        if (!filters.categoryIds!.contains(pin.categoryId)) continue;
      }

      final isFavorite = favoritePinIds.contains(pin.id);
      if (filters.favoritesOnly && !isFavorite) continue;

      final category = pin.categoryId == null
          ? null
          : categories[pin.categoryId];

      items.add(
        StudyReviewItem(
          studyPinId: pin.id,
          annotationType: type,
          shortText: pin.shortText,
          categoryId: pin.categoryId,
          categoryName: category?.name,
          selectedText: pin.selectedText,
          fullNote: pin.fullExplanation,
          materialId: material.id,
          materialTitle: material.title,
          mimeType: material.mimeType,
          pageNumber: pin.pageNumber,
          isFavorite: isFavorite,
        ),
      );
    }

    if (scope.type == ReviewScopeType.favorites) {
      items = items.where((i) => i.isFavorite).toList();
    }

    if (filters.shuffle) {
      items = List.of(items)..shuffle(Random());
    }

    return items;
  }

  Future<int> countReviewable({
    required ReviewScope scope,
    ReviewSessionFilters filters = const ReviewSessionFilters(shuffle: false),
  }) async {
    final items = await loadItems(
      scope: scope,
      filters: filters.copyWith(shuffle: false),
    );
    return items.length;
  }

  Future<ReviewSessionState> startSession({
    required ReviewScope scope,
    ReviewSessionFilters filters = const ReviewSessionFilters(),
    List<StudyReviewItem>? presetItems,
  }) async {
    final items =
        presetItems ?? await loadItems(scope: scope, filters: filters);
    final now = DateTime.now();
    final sessionId = _uuid.v4();

    await _db.insertReviewSession(
      StudyReviewSessionsCompanion.insert(
        id: sessionId,
        scopeType: scope.type.storageValue,
        scopeId: Value(scope.id),
        title: scope.title,
        startedAt: now,
        totalItems: items.length,
        reviewedItems: const Value(0),
        shuffle: Value(filters.shuffle),
        createdAt: now,
      ),
    );

    return ReviewSessionState(
      sessionId: sessionId,
      scope: scope,
      items: items,
      currentIndex: 0,
      revealed: false,
      latestRatings: {},
      againRequeued: {},
      completed: items.isEmpty,
      filters: filters,
      cardShownAt: now,
    );
  }

  Future<void> recordRating({
    required String sessionId,
    required String studyPinId,
    required ReviewRating rating,
    int? responseTimeMs,
  }) async {
    final now = DateTime.now();
    await _db.insertReviewEvent(
      StudyReviewEventsCompanion.insert(
        id: _uuid.v4(),
        studyPinId: studyPinId,
        sessionId: sessionId,
        rating: rating.storageValue,
        reviewedAt: now,
        responseTimeMs: Value(responseTimeMs),
        createdAt: now,
      ),
    );
  }

  Future<void> completeSession(ReviewSessionState state) async {
    final existing = await _db.getReviewSessionById(state.sessionId);
    if (existing == null) return;
    await _db.updateReviewSession(
      existing.copyWith(
        completedAt: Value(DateTime.now()),
        reviewedItems: state.latestRatings.length,
      ),
    );
  }

  Future<void> updateReviewedCount(String sessionId, int reviewedItems) async {
    final existing = await _db.getReviewSessionById(sessionId);
    if (existing == null) return;
    await _db.updateReviewSession(
      existing.copyWith(reviewedItems: reviewedItems),
    );
  }

  Future<List<String>> _materialIdsForScope(ReviewScope scope) async {
    switch (scope.type) {
      case ReviewScopeType.material:
        final id = scope.id;
        return id == null ? const [] : [id];
      case ReviewScopeType.lesson:
        final id = scope.id;
        if (id == null) return const [];
        return _db.materialIdsForLesson(id);
      case ReviewScopeType.subject:
        final id = scope.id;
        if (id == null) return const [];
        final lessonIds = await _db.lessonIdsForSubject(id);
        final materialIds = <String>[];
        for (final lessonId in lessonIds) {
          materialIds.addAll(await _db.materialIdsForLesson(lessonId));
        }
        return materialIds;
      case ReviewScopeType.favorites:
        final favIds = await _db.favoriteIdsOfType(FavoriteEntityType.studyPin);
        if (favIds.isEmpty) return const [];
        final pins = <StudyPin>[];
        for (final id in favIds) {
          final pin = await _db.getStudyPinById(id);
          if (pin != null && pin.deletedAt == null) pins.add(pin);
        }
        return pins.map((p) => p.resourceId).toSet().toList();
    }
  }

  static bool _isReviewable(StudyPin pin) {
    final short = pin.shortText.trim();
    if (short.isNotEmpty) return true;
    final selected = pin.selectedText?.trim();
    if (selected != null && selected.isNotEmpty) return true;
    return StudyNoteCodec.hasContent(pin.fullExplanation);
  }
}
