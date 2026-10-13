import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/markdown/study_markdown.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/auto_direction_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../study_review/data/review_session_providers.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_review/presentation/review_setup_screen.dart';
import '../data/study_schedule_providers.dart';
import '../domain/review_scheduler.dart';
import '../domain/schedule_day.dart';
import '../domain/schedule_models.dart';

/// One scheduled lesson review: recall from memory first, then compare with
/// the summary and rate how much was remembered.
class ScheduleReviewScreen extends ConsumerStatefulWidget {
  const ScheduleReviewScreen({super.key, required this.lessonId});

  final String lessonId;

  static String ratingHint(ReviewRating rating) => switch (rating) {
    ReviewRating.again => 'Missed most of the key points',
    ReviewRating.hard => 'Got some, with important gaps',
    ReviewRating.good => 'Got the main points',
    ReviewRating.easy => 'Recalled it fully and quickly',
  };

  @override
  ConsumerState<ScheduleReviewScreen> createState() =>
      _ScheduleReviewScreenState();
}

class _ScheduleReviewScreenState extends ConsumerState<ScheduleReviewScreen> {
  final _recall = TextEditingController();
  bool _checking = false;
  bool _saving = false;
  Map<ReviewRating, ScheduleDecision> _previews = const {};

  @override
  void initState() {
    super.initState();
    ref.read(studyScheduleRepositoryProvider).previews(widget.lessonId).then((
      previews,
    ) {
      if (mounted) setState(() => _previews = previews);
    });
  }

  @override
  void dispose() {
    _recall.dispose();
    super.dispose();
  }

  Future<void> _rate(ReviewRating rating) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final limit = await ref.read(scheduleDailyLimitProvider.future);
      final next = await ref
          .read(studyScheduleRepositoryProvider)
          .recordReview(
            widget.lessonId,
            rating: rating,
            recallText: _recall.text,
            dailyLimit: limit,
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Next review ${ScheduleDay.relative(next.dueOn).toLowerCase()} '
            '(${ScheduleDay.short(next.dueOn)}).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save the review: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(scheduleEntriesProvider);
    final entry = ref.watch(lessonScheduleEntryProvider(widget.lessonId));
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: entriesAsync.isLoading
            ? const AppLoading()
            : const AppErrorState(
                message: 'This lesson is not in the Study Schedule.',
              ),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.lessonName),
            Text(entry.subjectName, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: _checking
                ? _compareStep(context, entry)
                : _recallStep(context, entry),
          ),
        ),
      ),
    );
  }

  List<Widget> _recallStep(BuildContext context, ScheduleEntry entry) {
    final theme = Theme.of(context);
    return [
      _StepLabel(
        step: 1,
        title: entry.reviewCount == 0
            ? 'First review: recall from memory'
            : 'Review ${entry.reviewCount + 1}: recall from memory',
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Without opening your notes, write the main ideas, definitions, '
        'formulas and examples you remember. A rough list is fine — the '
        'effort of recalling is what makes it stick.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      AutoDirectionTextField(
        controller: _recall,
        autofocus: true,
        minLines: 8,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          hintText: 'What do you remember about this lesson?',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.end,
        children: [
          TextButton(
            onPressed: () => setState(() => _checking = true),
            child: const Text('I can’t recall it'),
          ),
          FilledButton.icon(
            onPressed: () => setState(() => _checking = true),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Check my notes'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _compareStep(BuildContext context, ScheduleEntry entry) {
    final theme = Theme.of(context);
    final summaries = ref.watch(lessonSummariesProvider(widget.lessonId));
    final pinCount = ref
        .watch(
          reviewableCountProvider(
            ReviewScope(
              type: ReviewScopeType.lesson,
              id: widget.lessonId,
              title: entry.lessonName,
            ),
          ),
        )
        .valueOrNull;
    final recall = _recall.text.trim();
    return [
      if (recall.isNotEmpty) ...[
        Text('What you remembered', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        _Panel(child: AutoDirectionText(recall)),
        const SizedBox(height: AppSpacing.lg),
      ],
      const _StepLabel(step: 2, title: 'Compare with your notes'),
      const SizedBox(height: AppSpacing.sm),
      summaries.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Could not load the lesson summary.'),
        data: (items) => items.isEmpty
            ? _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This lesson has no summary yet. Open it and skim your '
                      'materials to see what you missed.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRoutes.lessonDetails,
                        arguments: widget.lessonId,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open lesson'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items) ...[
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: theme.textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          StudyMarkdown(data: item.markdown, selectable: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
      ),
      if (pinCount != null && pinCount > 0) ...[
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => openReviewSetup(
              context,
              scope: ReviewScope(
                type: ReviewScopeType.lesson,
                id: widget.lessonId,
                title: entry.lessonName,
              ),
            ),
            icon: const Icon(Icons.school_outlined),
            label: Text('Optional: quiz yourself on $pinCount pins'),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      Text('How much did you recall?', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      for (final rating in ReviewRating.values)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _RatingTile(
            rating: rating,
            next: _previews[rating],
            enabled: !_saving,
            onTap: () => _rate(rating),
          ),
        ),
    ];
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.step, required this.title});

  final int step;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '$step',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.rating,
    required this.next,
    required this.enabled,
    required this.onTap,
  });

  final ReviewRating rating;
  final ScheduleDecision? next;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (rating) {
      ReviewRating.again => theme.colorScheme.error,
      ReviewRating.hard => const Color(0xFFE08A00),
      ReviewRating.good => theme.colorScheme.primary,
      ReviewRating.easy => const Color(0xFF2E7D32),
    };
    final days = next?.intervalDays;
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      leading: Icon(Icons.circle, size: 14, color: color),
      title: Text(rating.label),
      subtitle: Text(ScheduleReviewScreen.ratingHint(rating)),
      trailing: days == null
          ? null
          : Text(
              days == 1 ? 'in 1 day' : 'in $days days',
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
    );
  }
}
