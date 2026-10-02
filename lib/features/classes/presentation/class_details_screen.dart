import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
import '../../../core/widgets/section_header.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../subjects/data/subject_groups_providers.dart';
import '../../subjects/data/subjects_providers.dart';
import '../../subjects/presentation/create_subject_dialog.dart';
import '../../subjects/presentation/subject_group_dialog.dart';
import '../data/classes_providers.dart';

/// Shows a Class and its Subjects, organized by optional subject groups.
class ClassDetailsScreen extends ConsumerWidget {
  const ClassDetailsScreen({super.key, required this.classId});

  final String classId;

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    SubjectGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          '"${group.name}" will be deleted. Subjects inside it will become '
          'ungrouped — they will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteSubjectGroup(ref, group.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classByIdProvider(classId));
    final subjectsAsync = ref.watch(subjectsForClassProvider(classId));
    final groupsAsync = ref.watch(subjectGroupsForClassProvider(classId));

    return classAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: const AppErrorState(message: 'Could not load this class.'),
      ),
      data: (classItem) {
        if (classItem == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppErrorState(message: 'Class not found'),
          );
        }

        return DetailScaffold(
          title: classItem.name,
          description: classItem.description,
          actions: [
            FavoriteStarButton(
              entityType: FavoriteEntityType.class_,
              entityId: classId,
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'group') {
                  SubjectGroupDialog.show(context, classId: classId);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'group', child: Text('Add Subject Group')),
              ],
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                CreateSubjectDialog.show(context, classId: classId),
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
          ),
          bodySlivers: [
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: 0,
                child: const SectionHeader(title: 'Subjects'),
              ),
            ),
            ..._buildSubjectContent(
              context,
              ref,
              subjectsAsync: subjectsAsync,
              groupsAsync: groupsAsync,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildSubjectContent(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<List<Subject>> subjectsAsync,
    required AsyncValue<List<SubjectGroup>> groupsAsync,
  }) {
    if (subjectsAsync.isLoading || groupsAsync.isLoading) {
      return [const SliverFillRemaining(child: AppLoading())];
    }

    if (subjectsAsync.hasError) {
      return [
        const SliverFillRemaining(
          child: AppErrorState(message: 'Could not load subjects.'),
        ),
      ];
    }
    if (groupsAsync.hasError) {
      return [
        const SliverFillRemaining(
          child: AppErrorState(message: 'Could not load subject groups.'),
        ),
      ];
    }

    final subjectList = subjectsAsync.requireValue;
    final groupList = groupsAsync.requireValue;

    if (subjectList.isEmpty && groupList.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No subjects yet',
            message:
                'Add a subject or subject group to start organizing lessons.',
          ),
        ),
      ];
    }

    final children = <Widget>[];
    final theme = Theme.of(context);

    for (final group in groupList) {
      final inGroup = subjectList
          .where((s) => s.subjectGroupId == group.id)
          .toList();
      children.add(
        GroupSectionHeader(
          title: group.name,
          subtitle: group.description,
          onEdit: () => SubjectGroupDialog.show(
            context,
            classId: classId,
            existing: group,
          ),
          onDelete: () => _confirmDeleteGroup(context, ref, group),
        ),
      );
      if (inGroup.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'No subjects in this group',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      } else {
        for (final subject in inGroup) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: GroupedItemTile(
                title: subject.name,
                subtitle: subject.description,
                icon: Icons.menu_book_outlined,
                onTap: () {
                  Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.subjectDetails, arguments: subject.id);
                },
                onEdit: () => CreateSubjectDialog.show(
                  context,
                  classId: classId,
                  existing: subject,
                ),
              ),
            ),
          );
        }
      }
      children.add(const SizedBox(height: AppSpacing.xs));
    }

    final ungrouped = subjectList
        .where((s) => s.subjectGroupId == null)
        .toList();
    if (ungrouped.isNotEmpty || groupList.isNotEmpty) {
      if (groupList.isNotEmpty) {
        children.add(const GroupSectionHeader(title: 'Ungrouped'));
      }
      if (ungrouped.isEmpty && groupList.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'No ungrouped subjects',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      }
      for (final subject in ungrouped) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: GroupedItemTile(
              title: subject.name,
              subtitle: subject.description,
              icon: Icons.menu_book_outlined,
              onTap: () {
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.subjectDetails, arguments: subject.id);
              },
              onEdit: () => CreateSubjectDialog.show(
                context,
                classId: classId,
                existing: subject,
              ),
            ),
          ),
        );
      }
    }

    return [
      SliverToBoxAdapter(
        child: DetailContent(
          bottom: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ];
  }
}
