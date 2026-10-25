import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/transient_snack_bar.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../classes/data/classes_providers.dart';
import '../data/class_roadmap_providers.dart';
import '../domain/roadmap_models.dart';

/// Teacher-style ordered syllabus for a class: add lessons and walk them
/// in sequence.
class ClassRoadmapScreen extends ConsumerWidget {
  const ClassRoadmapScreen({super.key, required this.classId});

  final String classId;

  static Future<void> open(BuildContext context, String classId) =>
      Navigator.of(
        context,
      ).pushNamed(AppRoutes.classRoadmap, arguments: classId);

  Future<void> _addLessons(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(classRoadmapRepositoryProvider);
    final available = await repo.availableLessons(classId);
    if (!context.mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const TransientSnackBar(
          content: Text(
            'Every lesson in this class is already on the roadmap.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddLessonsSheet(candidates: available),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;

    final added = await repo.addLessons(classId, selected);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      TransientSnackBar(
        content: Text(
          added == 1
              ? 'Added 1 lesson to the roadmap'
              : 'Added $added lessons to the roadmap',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classByIdProvider(classId));
    final stepsAsync = ref.watch(classRoadmapProvider(classId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          classAsync.valueOrNull?.name == null
              ? 'Class Roadmap'
              : '${classAsync.valueOrNull!.name} roadmap',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLessons(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add lessons'),
      ),
      body: stepsAsync.when(
        loading: () => const AppLoading(),
        error: (_, _) =>
            const AppErrorState(message: 'Could not load the roadmap.'),
        data: (steps) {
          if (steps.isEmpty) {
            return const EmptyState(
              icon: Icons.route_outlined,
              title: 'No roadmap yet',
              message:
                  'Add lessons from this class to build a study order you can '
                  'follow from start to finish.',
            );
          }

          final current = ref
              .read(classRoadmapRepositoryProvider)
              .currentStep(steps);
          final doneCount = steps.where((s) => s.isDone).length;

          final page = AppSpacing.pageInsets(context);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              page.left,
              AppSpacing.md,
              page.right,
              96,
            ),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppSpacing.contentWidth(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$doneCount of ${steps.length} done',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (current != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Material(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: AppRadii.mdAll,
                        child: InkWell(
                          borderRadius: AppRadii.mdAll,
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.lessonDetails,
                            arguments: current.lessonId,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Continue',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                      ),
                                      Text(
                                        current.lessonName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        current.subjectName,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer
                                                  .withValues(alpha: 0.8),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    const SectionHeader(title: 'Lessons'),
                    const SizedBox(height: AppSpacing.xs),
                    for (var i = 0; i < steps.length; i++)
                      _RoadmapStepTile(
                        index: i + 1,
                        step: steps[i],
                        isFirst: i == 0,
                        isLast: i == steps.length - 1,
                        isCurrent: current?.id == steps[i].id,
                        onOpen: () => Navigator.of(context).pushNamed(
                          AppRoutes.lessonDetails,
                          arguments: steps[i].lessonId,
                        ),
                        onMoveUp: () => ref
                            .read(classRoadmapRepositoryProvider)
                            .moveUp(classId, steps[i].id),
                        onMoveDown: () => ref
                            .read(classRoadmapRepositoryProvider)
                            .moveDown(classId, steps[i].id),
                        onRemove: () => ref
                            .read(classRoadmapRepositoryProvider)
                            .removeEntry(steps[i].id),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoadmapStepTile extends StatelessWidget {
  const _RoadmapStepTile({
    required this.index,
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    required this.onOpen,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final RoadmapStep step;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final VoidCallback onOpen;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = step.isDone
        ? theme.colorScheme.tertiary
        : isCurrent
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: BorderSide(
            color: isCurrent
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: step.isDone
                      ? Icon(Icons.check, size: 16, color: statusColor)
                      : Text(
                          '$index',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.lessonName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: step.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${step.subjectName} · ${step.progress.label}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Options',
                  onSelected: (value) {
                    switch (value) {
                      case 'up':
                        onMoveUp();
                      case 'down':
                        onMoveDown();
                      case 'remove':
                        onRemove();
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isFirst)
                      const PopupMenuItem(value: 'up', child: Text('Move up')),
                    if (!isLast)
                      const PopupMenuItem(
                        value: 'down',
                        child: Text('Move down'),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'Remove from roadmap',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddLessonsSheet extends StatefulWidget {
  const _AddLessonsSheet({required this.candidates});

  final List<RoadmapCandidate> candidates;

  @override
  State<_AddLessonsSheet> createState() => _AddLessonsSheetState();
}

class _AddLessonsSheetState extends State<_AddLessonsSheet> {
  late final Set<String> _selected = {
    for (final c in widget.candidates) c.lessonId,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bySubject = <String, List<RoadmapCandidate>>{};
    for (final c in widget.candidates) {
      bySubject.putIfAbsent(c.subjectName, () => []).add(c);
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add lessons', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick lessons from this class to append to the roadmap.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in bySubject.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.sm,
                        bottom: AppSpacing.xs,
                      ),
                      child: Text(
                        entry.key,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final c in entry.value)
                      CheckboxListTile(
                        value: _selected.contains(c.lessonId),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(c.lessonId);
                            } else {
                              _selected.remove(c.lessonId);
                            }
                          });
                        },
                        title: Text(c.lessonName),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected.toList()),
              child: Text(
                _selected.length == 1
                    ? 'Add 1 lesson'
                    : 'Add ${_selected.length} lessons',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
