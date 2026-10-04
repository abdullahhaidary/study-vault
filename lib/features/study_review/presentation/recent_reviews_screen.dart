import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../data/review_session_providers.dart';
import '../domain/review_models.dart';

/// Simple list of recent review sessions (no analytics).
class RecentReviewsScreen extends ConsumerWidget {
  const RecentReviewsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RecentReviewsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(recentReviewSessionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recent Reviews')),
      body: ScrollEdgeArrows(
        child: sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const EmptyState(
                icon: Icons.school_outlined,
                title: 'No reviews yet',
                message:
                    'Start a review from a lesson or material to see history here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return ListTile(
                  leading: Icon(
                    session.completedAt != null
                        ? Icons.check_circle_outline
                        : Icons.timelapse,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(session.title),
                  subtitle: Text(_subtitle(session), maxLines: 2),
                  onTap: () => _showDetail(context, ref, session),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _subtitle(StudyReviewSession session) {
    final scope = ReviewScopeType.fromStorage(session.scopeType).label;
    final when = _formatDay(session.startedAt);
    final status = session.completedAt == null
        ? 'In progress'
        : '${session.reviewedItems} reviewed';
    return '$when · $scope · $status / ${session.totalItems} items';
  }

  String _formatDay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showDetail(
    BuildContext context,
    WidgetRef ref,
    StudyReviewSession session,
  ) async {
    final db = ref.read(databaseProvider);
    final events = await db.getReviewEventsForSession(session.id);
    if (!context.mounted) return;

    final latest = <String, ReviewRating>{};
    for (final e in events) {
      latest[e.studyPinId] = ReviewRating.fromStorage(e.rating);
    }
    final latestCounts = {for (final r in ReviewRating.values) r: 0};
    for (final r in latest.values) {
      latestCounts[r] = (latestCounts[r] ?? 0) + 1;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_subtitle(session)),
              const SizedBox(height: 16),
              for (final rating in ReviewRating.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(rating.label)),
                      Text('${latestCounts[rating] ?? 0}'),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
