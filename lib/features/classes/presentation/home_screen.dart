import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/navigation/study_navigator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_grid.dart';
import '../../favorites/data/favorites_display_providers.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../lessons/data/lesson_progress_providers.dart';
import '../../search/domain/study_search_result.dart';
import '../../study_review/presentation/recent_reviews_screen.dart';
import '../data/classes_providers.dart';
import 'create_class_dialog.dart';

/// Home screen — lists all Classes + favorites strip.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final favoritesAsync = ref.watch(homeFavoritesProvider);
    final continueAsync = ref.watch(continueStudyingLessonsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Study Vault'),
            actions: [
              IconButton(
                tooltip: 'Search',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.search);
                },
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Favorites',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.favorites);
                },
                icon: const Icon(Icons.star_outline),
              ),
              IconButton(
                tooltip: 'Recent Reviews',
                onPressed: () => RecentReviewsScreen.open(context),
                icon: const Icon(Icons.history_edu_outlined),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.settings);
                },
                icon: const Icon(Icons.settings_outlined),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: () => CreateClassDialog.show(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Class'),
                ),
              ),
            ],
          ),
          continueAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (lessons) {
              if (lessons.isEmpty)
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue Studying',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...lessons
                          .take(3)
                          .map(
                            (lesson) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.play_circle_outline),
                              title: Text(lesson.name),
                              subtitle: lesson.lastStudiedAt == null
                                  ? null
                                  : Text(
                                      'Last studied ${lesson.lastStudiedAt!.year}/${lesson.lastStudiedAt!.month}/${lesson.lastStudiedAt!.day}',
                                    ),
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutes.lessonDetails,
                                arguments: lesson.id,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
          favoritesAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (favs) {
              if (favs.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Favorites',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FavoritesScreen(),
                                ),
                              );
                            },
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: favs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = favs[index];
                            return ActionChip(
                              avatar: const Icon(Icons.star, size: 16),
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: Text(
                                  item.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              onPressed: () => StudyNavigator.openEntity(
                                context,
                                ref,
                                kind: item.kind,
                                id: item.entityId,
                                materialId: item.materialId,
                                materialTitle: item.materialTitle,
                                mimeType: item.mimeType,
                                pageNumber: item.pageNumber,
                                focusPinId:
                                    item.kind == StudyEntityKind.studyPin
                                    ? item.entityId
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(
                'My Classes',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          classesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text('Something went wrong: $error')),
            ),
            data: (classList) {
              if (classList.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No classes yet',
                    message:
                        'Create your first class to start organizing your lessons.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverToBoxAdapter(
                  child: ResponsiveGrid(
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

class _ClassCard extends ConsumerWidget {
  const _ClassCard({required this.classItem});

  final StudyClass classItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync = ref.watch(subjectCountProvider(classItem.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.classDetails, arguments: classItem.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.class_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      classItem.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
              if (classItem.description != null &&
                  classItem.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  classItem.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              countAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (count) => Text(
                  count == 1 ? '1 subject' : '$count subjects',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
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
