import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_grid.dart';
import '../../../core/widgets/section_header.dart';
import '../../lessons/data/lesson_progress_providers.dart';
import '../../study_review/presentation/recent_reviews_screen.dart';
import '../data/classes_providers.dart';
import 'create_class_dialog.dart';

/// Home screen — Continue Studying + My Classes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final continueAsync = ref.watch(continueStudyingLessonsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Study Vault'),
            actions: [
              IconButton(
                tooltip: 'Search',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.search),
                icon: const Icon(Icons.search),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  switch (value) {
                    case 'add_class':
                      CreateClassDialog.show(context);
                    case 'reviews':
                      RecentReviewsScreen.open(context);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'add_class',
                    child: Text('Add Class'),
                  ),
                  PopupMenuItem(
                    value: 'reviews',
                    child: Text('Recent Reviews'),
                  ),
                ],
              ),
            ],
          ),
          continueAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (lessons) {
              if (lessons.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: ContentHomePadding(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Continue Studying'),
                      ...lessons.take(3).map((lesson) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: ListTile(
                            tileColor: theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.mdAll,
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            leading: Icon(
                              Icons.play_circle_outline,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(lesson.name),
                            subtitle: lesson.lastStudiedAt == null
                                ? null
                                : Text(
                                    'Last studied ${lesson.lastStudiedAt!.year}/'
                                    '${lesson.lastStudiedAt!.month.toString().padLeft(2, '0')}/'
                                    '${lesson.lastStudiedAt!.day.toString().padLeft(2, '0')}',
                                  ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: theme.colorScheme.outline,
                            ),
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.lessonDetails,
                              arguments: lesson.id,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: ContentHomePadding(
              child: SectionHeader(
                title: 'My Classes',
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.sm,
                ),
              ),
            ),
          ),
          classesAsync.when(
            loading: () => const SliverFillRemaining(child: AppLoading()),
            error: (error, _) => SliverFillRemaining(
              child: AppErrorState(message: 'Could not load classes.'),
            ),
            data: (classList) {
              if (classList.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No classes yet',
                    message:
                        'Create your first class to start organizing your lessons.',
                    action: FilledButton.icon(
                      onPressed: () => CreateClassDialog.show(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Class'),
                    ),
                  ),
                );
              }

              return SliverToBoxAdapter(
                child: ContentHomePadding(
                  bottom: AppSpacing.xl,
                  child: ResponsiveGrid(
                    minItemWidth: 260,
                    children: [
                      for (final classItem in classList)
                        _ClassCard(classItem: classItem),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Page padding with optional bottom inset and max width.
class ContentHomePadding extends StatelessWidget {
  const ContentHomePadding({super.key, required this.child, this.bottom = 0});

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final page = AppSpacing.pageInsets(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(page.left, 0, page.right, bottom),
          child: child,
        ),
      ),
    );
  }
}

class _ClassCard extends ConsumerWidget {
  const _ClassCard({required this.classItem});

  final StudyClass classItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync = ref.watch(subjectCountProvider(classItem.id));

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.classDetails, arguments: classItem.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      classItem.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.outline,
                    size: 20,
                  ),
                ],
              ),
              if (classItem.description != null &&
                  classItem.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  classItem.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              countAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (count) => Text(
                  count == 1 ? '1 subject' : '$count subjects',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
