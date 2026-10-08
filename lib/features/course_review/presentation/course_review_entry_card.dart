import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../data/course_review_providers.dart';
import '../domain/course_review_models.dart';

/// Subject-page entry point showing how complete the Course Review is.
class CourseReviewEntryCard extends ConsumerWidget {
  const CourseReviewEntryCard({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(courseReviewProvider(subjectId)).valueOrNull;
    final subtitle = state == null
        ? 'Condensed summary, explanation and examples of every lecture'
        : _subtitle(state);
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.auto_stories_outlined,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Course Review'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).pushNamed(AppRoutes.courseReview, arguments: subjectId),
      ),
    );
  }

  static String _subtitle(CourseReviewState state) {
    final total = state.included.length;
    if (total == 0) {
      return 'Add PDFs or text documents to lessons to build a Course Review';
    }
    final added = state.withSections.length;
    final pending =
        state.count(CourseReviewSourceStatus.notAdded) +
        state.count(CourseReviewSourceStatus.outdated);
    return [
      '$added of $total lectures added',
      if (pending > 0) '$pending need attention',
    ].join(' · ');
  }
}
