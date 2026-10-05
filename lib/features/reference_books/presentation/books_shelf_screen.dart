import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_grid.dart';
import '../data/book_providers.dart';
import '../data/book_repository.dart';
import 'book_actions.dart';

/// Every reference book, whether or not it is linked to a subject.
class BooksShelfScreen extends ConsumerWidget {
  const BooksShelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reference Books')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addBook(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add book'),
      ),
      body: books.when(
        loading: () => const AppLoading(),
        error: (e, _) => const AppErrorState(message: 'Could not load books.'),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No reference books yet',
                message:
                    'Add a textbook PDF to read it with AI, find the pages each '
                    'lecture needs, and plan your reading.',
              )
            : ListView(
                padding: AppSpacing.pageInsets(
                  context,
                ).copyWith(top: AppSpacing.md, bottom: 96),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: AppSpacing.contentWidth(context),
                      ),
                      child: ResponsiveGrid(
                        minItemWidth: 300,
                        children: [for (final b in list) BookCard(book: b)],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class BookCard extends ConsumerWidget {
  const BookCard({super.key, required this.book});

  final ReferenceBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chapters =
        ref.watch(bookChaptersProvider(book.id)).valueOrNull ?? const [];
    final top = chapters.where((c) => c.level == 0).toList();
    final donePages = top
        .where((c) => c.status == ChapterStatus.done.storageValue)
        .fold<int>(0, (s, c) => s + c.endPage - c.startPage + 1);
    final progress = book.pageCount == 0 ? 0.0 : donePages / book.pageCount;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).pushNamed(AppRoutes.bookDetails, arguments: book.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.menu_book, size: 40, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      [
                        ?book.author,
                        '${book.pageCount} pages',
                        '${top.length} chapters',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 2),
                    Text(
                      '${(progress * 100).round()}% read',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
