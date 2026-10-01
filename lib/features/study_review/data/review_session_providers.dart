import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../domain/review_models.dart';
import '../domain/study_review_item.dart';
import 'study_review_service.dart';

final studyReviewServiceProvider = Provider<StudyReviewService>((ref) {
  return StudyReviewService(ref.watch(databaseProvider));
});

/// Count of reviewable pins for a scope (default filters, no shuffle).
final reviewableCountProvider = FutureProvider.family<int, ReviewScope>((
  ref,
  scope,
) async {
  final service = ref.watch(studyReviewServiceProvider);
  return service.countReviewable(scope: scope);
});

final recentReviewSessionsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentReviewSessions();
});

/// Active in-memory review session.
final activeReviewSessionProvider =
    StateNotifierProvider<ActiveReviewSessionNotifier, ReviewSessionState?>((
      ref,
    ) {
      return ActiveReviewSessionNotifier(ref);
    });

class ActiveReviewSessionNotifier extends StateNotifier<ReviewSessionState?> {
  ActiveReviewSessionNotifier(this._ref) : super(null);

  final Ref _ref;

  StudyReviewService get _service => _ref.read(studyReviewServiceProvider);

  Future<ReviewSessionState> start({
    required ReviewScope scope,
    ReviewSessionFilters filters = const ReviewSessionFilters(),
    List<StudyReviewItem>? presetItems,
  }) async {
    final session = await _service.startSession(
      scope: scope,
      filters: filters,
      presetItems: presetItems,
    );
    state = session;
    return session;
  }

  void reveal() {
    final current = state;
    if (current == null || current.completed || current.revealed) return;
    state = current.copyWith(revealed: true);
  }

  Future<void> rate(ReviewRating rating) async {
    final current = state;
    if (current == null || current.completed) return;
    final item = current.currentItem;
    if (item == null) return;
    if (!current.revealed) return;

    final shownAt = current.cardShownAt;
    final responseMs = shownAt == null
        ? null
        : DateTime.now().difference(shownAt).inMilliseconds;

    await _service.recordRating(
      sessionId: current.sessionId,
      studyPinId: item.studyPinId,
      rating: rating,
      responseTimeMs: responseMs,
    );

    final ratings = Map<String, ReviewRating>.from(current.latestRatings)
      ..[item.studyPinId] = rating;

    var items = List<StudyReviewItem>.from(current.items);
    final againRequeued = Set<String>.from(current.againRequeued);

    if (rating == ReviewRating.again &&
        !againRequeued.contains(item.studyPinId)) {
      // Repeat once near the end of this session.
      items = [...items, item];
      againRequeued.add(item.studyPinId);
    }

    final nextIndex = current.currentIndex + 1;
    final done = nextIndex >= items.length;

    final next = current.copyWith(
      items: items,
      currentIndex: done ? current.currentIndex : nextIndex,
      revealed: false,
      latestRatings: ratings,
      againRequeued: againRequeued,
      completed: done,
      cardShownAt: done ? null : DateTime.now(),
      clearCardShownAt: done,
    );

    state = next;
    await _service.updateReviewedCount(next.sessionId, ratings.length);
    if (done) {
      await _service.completeSession(next);
    }
  }

  void goPrevious() {
    final current = state;
    if (current == null || current.completed) return;
    if (current.currentIndex <= 0) return;
    final prevIndex = current.currentIndex - 1;
    final prevItem = current.items[prevIndex];
    final alreadyRated = current.latestRatings.containsKey(prevItem.studyPinId);
    state = current.copyWith(
      currentIndex: prevIndex,
      revealed: alreadyRated,
      cardShownAt: DateTime.now(),
    );
  }

  void goNext() {
    final current = state;
    if (current == null || current.completed) return;
    final item = current.currentItem;
    if (item == null) return;
    // Forward without a new rating only when this card was already rated
    // (e.g. after navigating back).
    if (!current.latestRatings.containsKey(item.studyPinId)) return;
    final nextIndex = current.currentIndex + 1;
    if (nextIndex >= current.items.length) {
      state = current.copyWith(completed: true, clearCardShownAt: true);
      _service.completeSession(state!);
      return;
    }
    final nextItem = current.items[nextIndex];
    final alreadyRated = current.latestRatings.containsKey(nextItem.studyPinId);
    state = current.copyWith(
      currentIndex: nextIndex,
      revealed: alreadyRated,
      cardShownAt: DateTime.now(),
    );
  }

  void clear() {
    state = null;
  }
}
