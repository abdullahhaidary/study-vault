import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../data/book_providers.dart';
import 'book_actions.dart';

/// Reference books linked to a subject, on the subject page.
class SubjectBooksSection extends ConsumerWidget {
  const SubjectBooksSection({super.key, required this.subjectId});

  final String subjectId;

  Future<void> _linkExisting(
    BuildContext context,
    WidgetRef ref,
    List<ReferenceBook> linked,
  ) async {
    final all = await ref.read(bookRepositoryProvider).watchBooks().first;
    final candidates = [
      for (final b in all)
        if (!linked.any((l) => l.id == b.id)) b,
    ];
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      await addBook(context, ref, subjectId: subjectId);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add a reference book'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '__new__'),
            child: const ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Add a new PDF…'),
            ),
          ),
          for (final b in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, b.id),
              child: ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(b.title),
                subtitle: Text('${b.pageCount} pages · link to this subject'),
              ),
            ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == '__new__') {
      await addBook(context, ref, subjectId: subjectId);
    } else {
      await ref
          .read(bookRepositoryProvider)
          .setSubjectLinked(bookId: choice, subjectId: subjectId, linked: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final books =
        ref.watch(booksForSubjectProvider(subjectId)).valueOrNull ?? const [];
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.menu_book, color: theme.colorScheme.primary),
            title: const Text('Reference books'),
            subtitle: Text(
              books.isEmpty
                  ? 'Read a textbook with AI and see which pages each lecture needs'
                  : '${books.length} book(s)',
            ),
            trailing: TextButton.icon(
              onPressed: () => _linkExisting(context, ref, books),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
          for (final b in books)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 72, right: 16),
              title: Text(b.title),
              subtitle: Text('${b.pageCount} pages'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.bookDetails, arguments: b.id),
            ),
        ],
      ),
    );
  }
}
