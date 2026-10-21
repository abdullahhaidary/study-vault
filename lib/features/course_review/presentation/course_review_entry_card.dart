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
        ? 'One complete review of every lecture'
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
    final document = state.document;
    if (document != null) {
      return [
        'Complete review v${document.version}',
        if (state.documentOutdated) 'Outdated',
      ].join(' · ');
    }
    if (state.included.isEmpty) {
      return 'Add PDFs or text documents to lessons to build a Course Review';
    }
    if (state.hasLegacyContent) {
      return 'Older sections can be combined into one review';
    }
    return 'No complete review yet';
  }
}
