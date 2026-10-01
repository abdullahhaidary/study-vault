import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/responsive_grid.dart';
import '../data/subjects_providers.dart';

/// Basic subject page with placeholder sections for future features.
class SubjectDetailsScreen extends ConsumerWidget {
  const SubjectDetailsScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectByIdProvider(subjectId));
    final theme = Theme.of(context);

    return subjectAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                sliver: SliverToBoxAdapter(
                  child: ResponsiveGrid(
                    children: const [
                      _PlaceholderCard(
                        icon: Icons.auto_stories_outlined,
                        title: 'Lessons',
                        subtitle: 'Coming soon — organize lesson content here.',
                      ),
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
        );
      },
    );
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
