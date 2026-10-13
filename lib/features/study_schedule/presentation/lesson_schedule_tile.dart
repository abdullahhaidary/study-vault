import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/study_schedule_providers.dart';
import '../domain/schedule_day.dart';
import 'schedule_actions.dart';
import 'study_schedule_screen.dart';

/// Lesson page row showing when the lesson is next reviewed.
class LessonScheduleTile extends ConsumerWidget {
  const LessonScheduleTile({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(lessonScheduleEntryProvider(lessonId));
    if (entry == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final today = ScheduleDay.today();
    final due = entry.isDue(today);
    final status = entry.paused
        ? 'Paused'
        : due
        ? (entry.overdueDays(today) == 0
              ? 'Review due today'
              : 'Review ${ScheduleDay.relative(entry.dueOn, today: today).toLowerCase()}')
        : 'Next review ${ScheduleDay.relative(entry.dueOn, today: today).toLowerCase()} '
              '(${ScheduleDay.short(entry.dueOn, today: today)})';
    final exam = ScheduleEntryTile.examLabel(entry, today);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        tileColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        leading: Icon(Icons.event_repeat, color: theme.colorScheme.primary),
        title: const Text('Study Schedule'),
        subtitle: Text(exam == null ? status : '$status · $exam'),
        onTap: () => StudyScheduleScreen.open(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (due)
              FilledButton.tonal(
                onPressed: () => openScheduleReview(context, lessonId),
                child: const Text('Review'),
              ),
            ScheduleEntryMenu(entry: entry, showOpenLesson: false),
          ],
        ),
      ),
    );
  }
}
