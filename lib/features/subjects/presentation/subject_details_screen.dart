import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/desktop_frame.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_section.dart';
import '../../../core/widgets/section_header.dart';
import '../../course_review/presentation/course_review_entry_card.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../reference_books/presentation/subject_books_section.dart';
import '../../lessons/data/lesson_groups_providers.dart';
import '../../lessons/data/lessons_providers.dart';
import '../../lessons/domain/lesson_progress.dart';
import '../../lessons/presentation/create_lesson_dialog.dart';
import '../../lessons/presentation/lesson_group_dialog.dart';
import '../../study_review/domain/review_models.dart';
import '../../study_review/presentation/review_entry_button.dart';
import '../../notes/presentation/notes_list_section.dart';
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
    final confirmed = await confirmDelete(
      context,
      title: 'Delete group?',
      message:
          '"${group.name}" will be deleted. Lessons inside it will become '
          'ungrouped — they will not be deleted.',
    );
    if (confirmed) await deleteLessonGroup(ref, group.id);
  }

  Future<void> _confirmDeleteLesson(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete lesson?',
      message:
          '"${lesson.name}" and all of its PDFs, images, notes, pins, '
          'flashcards, and quizzes will be permanently deleted.',
    );
    if (confirmed) await deleteLesson(ref, lessonId: lesson.id);
  }

  Future<void> _confirmDeleteSubject(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete subject?',
      message:
          '"${subject.name}" and every lesson, attachment, note, pin, '
          'flashcard, quiz, and course review under it will be permanently '
          'deleted.',
    );
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).pop();
    await deleteSubject(ref, subjectId: subject.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectByIdProvider(subjectId));
    final lessonsAsync = ref.watch(lessonsForSubjectProvider(subjectId));
    final groupsAsync = ref.watch(lessonGroupsForSubjectProvider(subjectId));

    return subjectAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: const AppErrorState(message: 'Could not load this subject.'),
      ),
      data: (subject) {
        if (subject == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppErrorState(message: 'Subject not found'),
          );
        }

        return DetailScaffold(
          title: subject.name,
          description: subject.description,
          actions: [
            FavoriteStarButton(
              entityType: FavoriteEntityType.subject,
              entityId: subjectId,
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'group') {
                  LessonGroupDialog.show(context, subjectId: subjectId);
                } else if (value == 'delete') {
                  _confirmDeleteSubject(context, ref, subject);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'group',
                  child: Text('Add Lesson Group'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete subject',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                CreateLessonDialog.show(context, subjectId: subjectId),
            icon: const Icon(Icons.add),
            label: const Text('Add Lesson'),
          ),
          bodySlivers: [
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: AppSpacing.md,
                child: ReviewEntryButton(
                  scope: ReviewScope(
                    type: ReviewScopeType.subject,
                    id: subjectId,
                    title: subject.name,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: AppSpacing.md,
                child: CourseReviewEntryCard(subjectId: subjectId),
              ),
            ),
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: AppSpacing.md,
                child: SubjectBooksSection(subjectId: subjectId),
              ),
            ),
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: 0,
                child: const SectionHeader(title: 'Lessons'),
              ),
            ),
            ..._buildLessonContent(
              context,
              ref,
              lessonsAsync: lessonsAsync,
              groupsAsync: groupsAsync,
            ),
            SliverToBoxAdapter(
              child: DetailContent(
                bottom: 88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'Notes',
                      padding: EdgeInsets.only(
                        top: AppSpacing.lg,
                        bottom: AppSpacing.sm,
                      ),
                    ),
                    NotesListSection.subject(subjectId: subjectId),
                  ],
                ),
              ),
            ),
          ],
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
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoading(),
          ),
        ),
      ];
    }

    if (lessonsAsync.hasError) {
      return [
        const SliverToBoxAdapter(
          child: DetailContent(
            child: AppErrorState(message: 'Could not load lessons.'),
          ),
        ),
      ];
    }
    if (groupsAsync.hasError) {
      return [
        const SliverToBoxAdapter(
          child: DetailContent(
            child: AppErrorState(message: 'Could not load lesson groups.'),
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
    final theme = Theme.of(context);
    final lessonsByGroup = <String?, List<Lesson>>{};
    for (final lesson in lessonList) {
      lessonsByGroup.putIfAbsent(lesson.lessonGroupId, () => []).add(lesson);
    }
    Widget lessonTile(Lesson lesson) => GroupedItemTile(
      title: lesson.name,
      subtitle: _lessonSubtitle(lesson),
      icon: Icons.auto_stories_outlined,
      onTap: () => Navigator.of(
        context,
      ).pushNamed(AppRoutes.lessonDetails, arguments: lesson.id),
      onEdit: () => CreateLessonDialog.show(
        context,
        subjectId: subjectId,
        existing: lesson,
      ),
      onDelete: () => _confirmDeleteLesson(context, ref, lesson),
    );

    for (final group in groupList) {
      final inGroup = lessonsByGroup[group.id] ?? const <Lesson>[];
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
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'No lessons in this group',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      } else {
        children.add(
          AdaptiveItemList(children: [for (final l in inGroup) lessonTile(l)]),
        );
      }
      children.add(const SizedBox(height: AppSpacing.xs));
    }

    final ungrouped = lessonsByGroup[null] ?? const <Lesson>[];
    if (ungrouped.isNotEmpty || groupList.isNotEmpty) {
      if (groupList.isNotEmpty) {
        children.add(const GroupSectionHeader(title: 'Ungrouped'));
      }
      if (ungrouped.isEmpty && groupList.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'No ungrouped lessons',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      }
      children.add(
        AdaptiveItemList(children: [for (final l in ungrouped) lessonTile(l)]),
      );
    }

    return [
      SliverList.builder(
        itemCount: children.length,
        itemBuilder: (context, index) =>
            DetailContent(bottom: 0, child: children[index]),
      ),
    ];
  }

  String? _lessonSubtitle(Lesson lesson) {
    final progress = LessonProgressStatus.fromStorage(lesson.progressStatus);
    final last = lesson.lastStudiedAt;
    final studied = last == null
        ? null
        : 'Last studied ${last.year}/${last.month.toString().padLeft(2, '0')}/${last.day.toString().padLeft(2, '0')}';
    return [
      lesson.description,
      progress.label,
      studied,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
  }
}
