import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/review_session_providers.dart';
import '../domain/review_models.dart';
import '../domain/study_review_item.dart';
import 'review_session_screen.dart';

/// Summary after a review session finishes.
class ReviewCompleteScreen extends ConsumerWidget {
  const ReviewCompleteScreen({super.key});

  Future<void> _reviewSubset(
    BuildContext context,
    WidgetRef ref, {
    required List<StudyReviewItem> items,
    required String titleSuffix,
  }) async {
    final current = ref.read(activeReviewSessionProvider);
    if (current == null || items.isEmpty) return;

    await ref
        .read(activeReviewSessionProvider.notifier)
        .start(
          scope: ReviewScope(
            type: current.scope.type,
            id: current.scope.id,
            title: '${current.scope.title} · $titleSuffix',
          ),
          filters: current.filters.copyWith(shuffle: false),
          presetItems: items,
        );
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ReviewSessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeReviewSessionProvider);
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Complete')),
        body: const Center(child: Text('Session unavailable.')),
      );
    }

    final counts = session.ratingCounts;
    final againItems = session.itemsWithRating(ReviewRating.again);
    final hardItems = session.itemsWithRating(ReviewRating.hard);
    final needsLook = [...againItems, ...hardItems];
    // Dedupe by pin id preserving order
    final seen = <String>{};
    final needsLookUnique = <StudyReviewItem>[];
    for (final item in needsLook) {
      if (seen.add(item.studyPinId)) needsLookUnique.add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review Complete')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 640 : double.infinity),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            children: [
              Text(
                '${session.latestRatings.length} reviewed',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              for (final rating in ReviewRating.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(rating.label),
                  subtitle: Text(rating.hint),
                  trailing: Text(
                    '${counts[rating] ?? 0}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              if (needsLookUnique.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Needs another look', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final item in needsLookUnique.take(12))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.isFavorite ? Icons.star : Icons.circle_outlined,
                      size: 18,
                    ),
                    title: Text(item.shortText, maxLines: 2),
                    subtitle: Text(
                      [
                        if (item.categoryName != null) item.categoryName!,
                        if (item.pageNumber != null) 'page ${item.pageNumber}',
                      ].join(' • '),
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              if (againItems.isNotEmpty)
                FilledButton(
                  onPressed: () => _reviewSubset(
                    context,
                    ref,
                    items: againItems,
                    titleSuffix: 'Again',
                  ),
                  child: Text('Review Again Items (${againItems.length})'),
                ),
              if (hardItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _reviewSubset(
                    context,
                    ref,
                    items: [
                      ...{
                        for (final i in [...againItems, ...hardItems])
                          i.studyPinId: i,
                      }.values,
                    ],
                    titleSuffix: 'Difficult',
                  ),
                  child: const Text('Review Difficult Items'),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.read(activeReviewSessionProvider.notifier).clear();
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
