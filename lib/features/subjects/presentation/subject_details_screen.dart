import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
import '../../../core/widgets/responsive_grid.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../lessons/data/lesson_groups_providers.dart';
import '../../lessons/data/lessons_providers.dart';
import '../../lessons/presentation/create_lesson_dialog.dart';
import '../../lessons/presentation/lesson_group_dialog.dart';
import '../data/subjects_providers.dart';

/// Subject page with lessons organized by optional lesson groups.
class SubjectDetailsScreen extends ConsumerWidget {
  const SubjectDetailsScreen({super.key, required this.subjectId});

  final String subjectId;

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    LessonGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          '"${group.name}" will be deleted. Lessons inside it will become '
          'ungrouped — they will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteLessonGroup(ref, group.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectByIdProvider(subjectId));
    final lessonsAsync = ref.watch(lessonsForSubjectProvider(subjectId));
    final groupsAsync = ref.watch(lessonGroupsForSubjectProvider(subjectId));
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return subjectAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (subject) {
        if (subject == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Subject not found')),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(subject.name),
                actions: [
                  FavoriteStarButton(
                    entityType: FavoriteEntityType.subject,
                    entityId: subjectId,
                  ),
                  if (isWide) ...[
                    TextButton.icon(
                      onPressed: () =>
                          LessonGroupDialog.show(context, subjectId: subjectId),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Add Lesson Group'),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilledButton.icon(
                        onPressed: () => CreateLessonDialog.show(
                          context,
                          subjectId: subjectId,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Lesson'),
                      ),
                    ),
                  ] else
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'group') {
                          LessonGroupDialog.show(context, subjectId: subjectId);
                        } else if (value == 'lesson') {
                          CreateLessonDialog.show(
                            context,
                            subjectId: subjectId,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'group',
                          child: Text('Add Lesson Group'),
                        ),
                        PopupMenuItem(
                          value: 'lesson',
                          child: Text('Add Lesson'),
                        ),
                      ],
                    ),
                ],
              ),
              if (subject.description != null &&
                  subject.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      subject.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Text(
                    'Lessons',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              ..._buildLessonContent(
                context,
                ref,
                lessonsAsync: lessonsAsync,
                groupsAsync: groupsAsync,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Coming later',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
                sliver: SliverToBoxAdapter(
                  child: ResponsiveGrid(
                    children: const [
                      _PlaceholderCard(
                        icon: Icons.menu_book_outlined,
                        title: 'Reference Books',
                        subtitle:
                            'Coming soon — attach PDFs and textbooks here.',
                      ),
                      _PlaceholderCard(
                        icon: Icons.sticky_note_2_outlined,
                        title: 'Notes',
                        subtitle: 'Coming soon — keep study notes here.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: isWide
              ? null
              : FloatingActionButton(
                  onPressed: () =>
                      CreateLessonDialog.show(context, subjectId: subjectId),
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  List<Widget> _buildLessonContent(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<List<Lesson>> lessonsAsync,
    required AsyncValue<List<LessonGroup>> groupsAsync,
  }) {
    if (lessonsAsync.isLoading || groupsAsync.isLoading) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    if (lessonsAsync.hasError) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: ${lessonsAsync.error}'),
          ),
        ),
      ];
    }
    if (groupsAsync.hasError) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: ${groupsAsync.error}'),
          ),
        ),
      ];
    }

    final lessonList = lessonsAsync.requireValue;
    final groupList = groupsAsync.requireValue;

    if (lessonList.isEmpty && groupList.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: SizedBox(
            height: 180,
            child: EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'No lessons yet',
              message:
                  'Add a lesson or lesson group to start organizing content.',
            ),
          ),
        ),
      ];
    }

    final children = <Widget>[];

    for (final group in groupList) {
      final inGroup = lessonList
          .where((l) => l.lessonGroupId == group.id)
          .toList();
      children.add(
        GroupSectionHeader(
          title: group.name,
          subtitle: group.description,
          onEdit: () => LessonGroupDialog.show(
            context,
            subjectId: subjectId,
            existing: group,
          ),
          onDelete: () => _confirmDeleteGroup(context, ref, group),
        ),
      );
      if (inGroup.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No lessons in this group',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        );
      } else {
        for (final lesson in inGroup) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GroupedItemTile(
                title: lesson.name,
                subtitle: lesson.description,
                icon: Icons.auto_stories_outlined,
                onTap: () {
                  Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.lessonDetails, arguments: lesson.id);
                },
                onEdit: () => CreateLessonDialog.show(
                  context,
                  subjectId: subjectId,
                  existing: lesson,
                ),
              ),
            ),
          );
        }
      }
      children.add(const SizedBox(height: 8));
    }

    final ungrouped = lessonList.where((l) => l.lessonGroupId == null).toList();
    if (ungrouped.isNotEmpty || groupList.isNotEmpty) {
      if (groupList.isNotEmpty) {
        children.add(const GroupSectionHeader(title: 'Ungrouped'));
      }
      if (ungrouped.isEmpty && groupList.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No ungrouped lessons',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        );
      }
      for (final lesson in ungrouped) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GroupedItemTile(
              title: lesson.name,
              subtitle: lesson.description,
              icon: Icons.auto_stories_outlined,
              onTap: () {
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.lessonDetails, arguments: lesson.id);
              },
              onEdit: () => CreateLessonDialog.show(
                context,
                subjectId: subjectId,
                existing: lesson,
              ),
            ),
          ),
        );
      }
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        sliver: SliverList(delegate: SliverChildListDelegate(children)),
      ),
    ];
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
