import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/transient_snack_bar.dart';
import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/desktop_frame.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../data/study_schedule_providers.dart';
import '../domain/schedule_day.dart';
import '../domain/schedule_models.dart';
import 'schedule_actions.dart';

/// Dedicated spaced-review list: today's plan, the rest of what is due,
/// upcoming reviews and paused lessons.
class StudyScheduleScreen extends ConsumerWidget {
  const StudyScheduleScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.studySchedule);

  Future<void> _addPending(
    BuildContext context,
    WidgetRef ref,
    List<Lesson> lessons,
    int limit,
  ) async {
    final added = await ref
        .read(studyScheduleRepositoryProvider)
        .enrollMany(lessons, dailyLimit: limit == 0 ? lessons.length : limit);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      TransientSnackBar(
        content: Text(
          'Added $added lesson${added == 1 ? '' : 's'}; first reviews are '
          'spread over the coming days.',
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How the Study Schedule works'),
        content: const SingleChildScrollView(
          child: Text(
            '• Marking a lesson Reviewed adds it here automatically. Its first '
            'review is tomorrow (a week for Mastered lessons).\n\n'
            '• In each review, write what you remember before looking, then '
            'compare with the summary and rate yourself. Trying to recall is '
            'what strengthens memory; rereading alone does much less.\n\n'
            '• Remembered well: the gap grows — about 3 days, 1 week, 3 weeks, '
            '2 months, 4 months. Forgot: back to tomorrow. A late review that '
            'you still remember counts for the time that passed.\n\n'
            '• Set a subject’s exam date and reviews are fitted before it.\n\n'
            '• The daily limit keeps the list manageable. Extra reviews can '
            'wait a day.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(schedulePlanProvider);
    final limit =
        ref.watch(scheduleDailyLimitProvider).valueOrNull ??
        ScheduleDailyLimit.defaultValue;
    final pending =
        ref.watch(unscheduledReviewedLessonsProvider).valueOrNull ??
        const <Lesson>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Schedule'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Daily limit',
            icon: const Icon(Icons.tune),
            onSelected: (value) => setScheduleDailyLimit(ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem<int>(
                enabled: false,
                child: Text('Reviews in today’s plan'),
              ),
              for (final option in ScheduleDailyLimit.options)
                CheckedPopupMenuItem(
                  value: option,
                  checked: option == limit,
                  child: Text(ScheduleDailyLimit.label(option)),
                ),
            ],
          ),
          IconButton(
            tooltip: 'How it works',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: planAsync.when(
        loading: () => const AppLoading(),
        error: (_, _) =>
            const AppErrorState(message: 'Could not load the Study Schedule.'),
        data: (plan) {
          if (plan.isEmpty) {
            return EmptyState(
              icon: Icons.event_repeat,
              title: 'Nothing scheduled yet',
              message:
                  'Mark a lesson as Reviewed and it is added here '
                  'automatically, with its first review tomorrow.',
              action: pending.isEmpty
                  ? null
                  : FilledButton.icon(
                      onPressed: () =>
                          _addPending(context, ref, pending, limit),
                      icon: const Icon(Icons.playlist_add),
                      label: Text(
                        'Add ${pending.length} reviewed '
                        'lesson${pending.length == 1 ? '' : 's'}',
                      ),
                    ),
            );
          }
          final today = ScheduleDay.today();
          final page = AppSpacing.pageInsets(context);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppSpacing.contentWidth(context),
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  page.left,
                  AppSpacing.md,
                  page.right,
                  AppSpacing.xxl,
                ),
                children: [
                  _Summary(plan: plan, today: today),
                  const SizedBox(height: AppSpacing.lg),
                  if (plan.today.isNotEmpty)
                    _Section(title: 'Today', entries: plan.today, today: today),
                  if (plan.overflow.isNotEmpty)
                    _Section(
                      title: 'Also due',
                      note:
                          'Over your daily limit of $limit. These can wait '
                          'until tomorrow.',
                      entries: plan.overflow,
                      today: today,
                    ),
                  if (plan.upcoming.isNotEmpty)
                    _Section(
                      title: 'Upcoming',
                      entries: plan.upcoming,
                      today: today,
                    ),
                  if (plan.paused.isNotEmpty)
                    _Section(
                      title: 'Paused',
                      entries: plan.paused,
                      today: today,
                    ),
                  if (pending.isNotEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.playlist_add),
                        title: Text(
                          '${pending.length} reviewed lesson'
                          '${pending.length == 1 ? ' is' : 's are'} not '
                          'scheduled',
                        ),
                        subtitle: const Text(
                          'Marked Reviewed before the schedule existed.',
                        ),
                        trailing: TextButton(
                          onPressed: () =>
                              _addPending(context, ref, pending, limit),
                          child: const Text('Add'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.today});

  final SchedulePlan plan;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = plan.today.length;
    final String headline;
    final String detail;
    if (count > 0) {
      headline = '$count review${count == 1 ? '' : 's'} today';
      detail = plan.overflow.isEmpty
          ? 'Recall first, then check the summary.'
          : '${plan.overflow.length} more can wait until tomorrow.';
    } else if (plan.upcoming.isNotEmpty) {
      final next = plan.upcoming.first.dueOn;
      headline = 'All caught up';
      detail =
          'Next review ${ScheduleDay.relative(next, today: today).toLowerCase()} '
          '(${ScheduleDay.short(next, today: today)}).';
    } else {
      headline = 'All caught up';
      detail = 'Every scheduled lesson is paused.';
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: AppRadii.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              count > 0 ? Icons.event_available : Icons.check_circle_outline,
              color: theme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.entries,
    required this.today,
    this.note,
  });

  final String title;
  final String? note;
  final List<ScheduleEntry> entries;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: '$title (${entries.length})',
            padding: EdgeInsets.only(
              bottom: note == null ? AppSpacing.sm : AppSpacing.xxs,
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          AdaptiveItemList(
            minItemWidth: 360,
            children: [
              for (final entry in entries)
                ScheduleEntryTile(entry: entry, today: today),
            ],
          ),
        ],
      ),
    );
  }
}

/// One scheduled lesson in the list.
class ScheduleEntryTile extends StatelessWidget {
  const ScheduleEntryTile({
    super.key,
    required this.entry,
    required this.today,
  });

  final ScheduleEntry entry;
  final DateTime today;

  static String? examLabel(ScheduleEntry entry, DateTime today) {
    if (entry.examOn == null) return null;
    final days = ScheduleDay.between(today, entry.examOn!);
    if (days < 0) return null;
    if (days == 0) return 'Exam today';
    if (days == 1) return 'Exam tomorrow';
    return 'Exam in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = entry.isDue(today);
    final overdue = entry.overdueDays(today);
    final when = entry.paused
        ? 'Paused'
        : due
        ? (overdue == 0
              ? 'Due today'
              : ScheduleDay.relative(entry.dueOn, today: today))
        : '${ScheduleDay.relative(entry.dueOn, today: today)} · '
              '${ScheduleDay.short(entry.dueOn, today: today)}';
    final subtitle = [
      entry.subjectName,
      when,
      entry.reviewCount == 0
          ? 'First review'
          : 'Review ${entry.reviewCount + 1}',
      ?examLabel(entry, today),
    ].join(' · ');
    final color = entry.paused
        ? theme.colorScheme.outline
        : overdue > 0
        ? theme.colorScheme.error
        : due
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return ListTile(
      tileColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      leading: Icon(
        entry.paused
            ? Icons.pause_circle_outline
            : overdue > 0
            ? Icons.history_toggle_off
            : due
            ? Icons.event_available
            : Icons.event_outlined,
        color: color,
      ),
      title: Text(
        entry.lessonName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: due
          ? () => openScheduleReview(context, entry.lessonId)
          : () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.lessonDetails, arguments: entry.lessonId),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (due)
            FilledButton.tonal(
              onPressed: () => openScheduleReview(context, entry.lessonId),
              child: const Text('Review'),
            ),
          ScheduleEntryMenu(entry: entry),
        ],
      ),
    );
  }
}
