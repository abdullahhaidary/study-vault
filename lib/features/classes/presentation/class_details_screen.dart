import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_grid.dart';
import '../../subjects/data/subjects_providers.dart';
import '../../subjects/presentation/create_subject_dialog.dart';
import '../data/classes_providers.dart';

/// Shows a Class and its Subjects.
class ClassDetailsScreen extends ConsumerWidget {
  const ClassDetailsScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classByIdProvider(classId));
    final subjectsAsync = ref.watch(subjectsForClassProvider(classId));
    final theme = Theme.of(context);

    return classAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilledButton.icon(
                      onPressed: () => CreateSubjectDialog.show(
                        context,
                        classId: classId,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Subject'),
                    ),
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    'Subjects',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              subjectsAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $error')),
                ),
                data: (subjectList) {
                  if (subjectList.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No subjects yet',
                        message:
                            'Add a subject to start collecting lessons and notes.',
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: SliverToBoxAdapter(
                      child: ResponsiveGrid(
                        children: [
                          for (final subject in subjectList)
                            _SubjectCard(subject: subject),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRoutes.subjectDetails,
            arguments: subject.id,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subject.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
              if (subject.description != null &&
                  subject.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  subject.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
