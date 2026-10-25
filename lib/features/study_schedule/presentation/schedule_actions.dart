import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/transient_snack_bar.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../data/study_schedule_providers.dart';
import '../domain/schedule_day.dart';
import '../domain/schedule_models.dart';
import 'schedule_review_screen.dart';

DateTime _local(DateTime day) => DateTime(day.year, day.month, day.day);

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(TransientSnackBar(content: Text(message)));
}

Future<void> openScheduleReview(BuildContext context, String lessonId) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ScheduleReviewScreen(lessonId: lessonId)),
  );
}

/// Picks or clears a subject's exam day.
Future<void> editExamDate(
  BuildContext context,
  WidgetRef ref, {
  required String subjectId,
  required String subjectName,
  DateTime? current,
}) async {
  final repo = ref.read(studyScheduleRepositoryProvider);
  final today = ScheduleDay.today();
  if (current != null) {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('$subjectName exam'),
              subtitle: Text(ScheduleDay.short(current)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Change exam date'),
              onTap: () => Navigator.pop(context, 'change'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Remove exam date'),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'clear') {
      await repo.setExamDate(subjectId, null);
      if (context.mounted) _snack(context, 'Exam date removed.');
      return;
    }
  }
  final picked = await showDatePicker(
    context: context,
    helpText: 'Exam date for $subjectName',
    initialDate: _local(
      current != null && !current.isBefore(today)
          ? current
          : ScheduleDay.add(today, 14),
    ),
    firstDate: _local(today),
    lastDate: _local(ScheduleDay.add(today, 3 * 365)),
  );
  if (picked == null) return;
  final moved = await repo.setExamDate(subjectId, ScheduleDay.of(picked));
  if (!context.mounted) return;
  _snack(
    context,
    'Exam set for ${ScheduleDay.short(ScheduleDay.of(picked))}. '
    '${moved == 0 ? 'Reviews will fit before it.' : '$moved review${moved == 1 ? '' : 's'} moved before it.'}',
  );
}

Future<void> _changeDate(
  BuildContext context,
  WidgetRef ref,
  ScheduleEntry entry,
) async {
  final today = ScheduleDay.today();
  final picked = await showDatePicker(
    context: context,
    helpText: 'Next review of ${entry.lessonName}',
    initialDate: _local(entry.dueOn.isBefore(today) ? today : entry.dueOn),
    firstDate: _local(today),
    lastDate: _local(ScheduleDay.add(today, 3 * 365)),
  );
  if (picked == null) return;
  final day = ScheduleDay.of(picked);
  await ref
      .read(studyScheduleRepositoryProvider)
      .reschedule(entry.lessonId, day);
  if (context.mounted) {
    _snack(context, 'Next review moved to ${ScheduleDay.short(day)}.');
  }
}

/// Overflow menu for a scheduled lesson.
class ScheduleEntryMenu extends ConsumerWidget {
  const ScheduleEntryMenu({
    super.key,
    required this.entry,
    this.showOpenLesson = true,
  });

  final ScheduleEntry entry;
  final bool showOpenLesson;

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final repo = ref.read(studyScheduleRepositoryProvider);
    switch (value) {
      case 'review':
        await openScheduleReview(context, entry.lessonId);
      case 'date':
        await _changeDate(context, ref, entry);
      case 'pause':
        await repo.setPaused(entry.lessonId, !entry.paused);
      case 'exam':
        await editExamDate(
          context,
          ref,
          subjectId: entry.subjectId,
          subjectName: entry.subjectName,
          current: entry.examOn,
        );
      case 'lesson':
        await Navigator.of(
          context,
        ).pushNamed(AppRoutes.lessonDetails, arguments: entry.lessonId);
      case 'remove':
        final confirmed = await confirmDelete(
          context,
          title: 'Remove from schedule?',
          message:
              '"${entry.lessonName}" will no longer appear in the Study '
              'Schedule. Its review history is kept; marking it Reviewed '
              'again adds it back.',
          confirmLabel: 'Remove',
        );
        if (confirmed) await repo.remove(entry.lessonId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Schedule options',
      onSelected: (value) => _onSelected(context, ref, value),
      itemBuilder: (context) => [
        if (!entry.paused)
          const PopupMenuItem(value: 'review', child: Text('Review now')),
        const PopupMenuItem(value: 'date', child: Text('Change date…')),
        PopupMenuItem(
          value: 'pause',
          child: Text(entry.paused ? 'Resume' : 'Pause'),
        ),
        PopupMenuItem(
          value: 'exam',
          child: Text(
            entry.examOn == null
                ? 'Set ${entry.subjectName} exam date…'
                : '${entry.subjectName} exam: ${ScheduleDay.short(entry.examOn!)}',
          ),
        ),
        if (showOpenLesson)
          const PopupMenuItem(value: 'lesson', child: Text('Open lesson')),
        PopupMenuItem(
          value: 'remove',
          child: Text(
            'Remove from schedule',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}
