import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
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
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return classAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (classItem) {
        if (classItem == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Class not found')),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(classItem.name),
                actions: [
                  FavoriteStarButton(
                    entityType: FavoriteEntityType.class_,
                    entityId: classId,
                  ),
                  if (isWide) ...[
                    TextButton.icon(
                      onPressed: () =>
                          SubjectGroupDialog.show(context, classId: classId),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Add Subject Group'),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilledButton.icon(
                        onPressed: () =>
                            CreateSubjectDialog.show(context, classId: classId),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Subject'),
                      ),
                    ),
                  ] else
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'group') {
                          SubjectGroupDialog.show(context, classId: classId);
                        } else if (value == 'subject') {
                          CreateSubjectDialog.show(context, classId: classId);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'group',
                          child: Text('Add Subject Group'),
                        ),
                        PopupMenuItem(
                          value: 'subject',
                          child: Text('Add Subject'),
                        ),
                      ],
                    ),
                ],
              ),
              if (classItem.description != null &&
                  classItem.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      classItem.description!,
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
                    'Subjects',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              ..._buildSubjectContent(
                context,
                ref,
                subjectsAsync: subjectsAsync,
                groupsAsync: groupsAsync,
              ),
            ],
          ),
          floatingActionButton: isWide
              ? null
              : FloatingActionButton(
                  onPressed: () =>
                      CreateSubjectDialog.show(context, classId: classId),
                  child: const Icon(Icons.add),
                ),
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
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (subjectsAsync.hasError) {
      return [
        SliverFillRemaining(
          child: Center(child: Text('Error: ${subjectsAsync.error}')),
        ),
      ];
    }
    if (groupsAsync.hasError) {
      return [
        SliverFillRemaining(
          child: Center(child: Text('Error: ${groupsAsync.error}')),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No subjects in this group',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        );
      } else {
        for (final subject in inGroup) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
      children.add(const SizedBox(height: 8));
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No ungrouped subjects',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        );
      }
      for (final subject in ungrouped) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
        sliver: SliverList(delegate: SliverChildListDelegate(children)),
      ),
    ];
  }
}
