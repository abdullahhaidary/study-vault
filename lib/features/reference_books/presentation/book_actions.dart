import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../data/book_providers.dart';
import 'book_indexer.dart';
import 'book_reader_screen.dart';

/// Pick a PDF → title/subjects → import → open the book (indexing continues
/// in the background).
Future<void> addBook(
  BuildContext context,
  WidgetRef ref, {
  String? subjectId,
}) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    withData: false,
    dialogTitle: 'Add reference book',
  );
  final path = picked?.files.single.path;
  if (path == null || !context.mounted) return;
  final details = await showDialog<_BookDetails>(
    context: context,
    builder: (_) => _BookDetailsDialog(
      initialTitle: p.basenameWithoutExtension(path),
      initialSubjects: {?subjectId},
    ),
  );
  if (details == null || !context.mounted) return;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Adding the book…')),
        ],
      ),
    ),
  );
  try {
    final book = await ref
        .read(bookImportServiceProvider)
        .importBook(
          sourcePath: path,
          title: details.title,
          author: details.author,
          subjectIds: details.subjects.toList(),
        );
    navigator.pop();
    ref
        .read(bookIndexerProvider.notifier)
        .ensureIndexed(book, detectHeadings: true);
    navigator.pushNamed(AppRoutes.bookDetails, arguments: book.id);
  } on Object catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Could not add the book: ${aiErrorMessage(e)}')),
    );
  }
}

Future<void> editBookDetails(
  BuildContext context,
  WidgetRef ref,
  ReferenceBook book,
) async {
  final repository = ref.read(bookRepositoryProvider);
  final linked = await repository.subjectsForBook(book.id);
  if (!context.mounted) return;
  final details = await showDialog<_BookDetails>(
    context: context,
    builder: (_) => _BookDetailsDialog(
      initialTitle: book.title,
      initialAuthor: book.author,
      initialSubjects: {for (final s in linked) s.id},
      editing: true,
    ),
  );
  if (details == null) return;
  await repository.renameBook(book, details.title, details.author);
  final before = {for (final s in linked) s.id};
  for (final id in before.union(details.subjects)) {
    final want = details.subjects.contains(id);
    if (want != before.contains(id)) {
      await repository.setSubjectLinked(
        bookId: book.id,
        subjectId: id,
        linked: want,
      );
    }
  }
}

Future<void> openBookReader(
  BuildContext context,
  ReferenceBook book, {
  int? page,
  ReferenceBookChapter? chapter,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BookReaderScreen(
        bookId: book.id,
        initialPage: page ?? chapter?.startPage,
      ),
    ),
  );
}

class _BookDetails {
  const _BookDetails(this.title, this.author, this.subjects);
  final String title;
  final String? author;
  final Set<String> subjects;
}

class _BookDetailsDialog extends ConsumerStatefulWidget {
  const _BookDetailsDialog({
    required this.initialTitle,
    this.initialAuthor,
    required this.initialSubjects,
    this.editing = false,
  });

  final String initialTitle;
  final String? initialAuthor;
  final Set<String> initialSubjects;
  final bool editing;

  @override
  ConsumerState<_BookDetailsDialog> createState() => _BookDetailsDialogState();
}

class _BookDetailsDialogState extends ConsumerState<_BookDetailsDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _author = TextEditingController(text: widget.initialAuthor ?? '');
  late final Set<String> _subjects = {...widget.initialSubjects};
  List<(StudyClass, List<Subject>)> _tree = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final classes = await db.watchAllClasses().first;
    final tree = [
      for (final c in classes) (c, await db.watchSubjectsForClass(c.id).first),
    ];
    if (mounted) setState(() => _tree = tree);
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.editing ? 'Book details' : 'Add reference book'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _author,
                decoration: const InputDecoration(
                  labelText: 'Author (optional)',
                ),
              ),
              const SizedBox(height: 16),
              Text('Show on subjects', style: theme.textTheme.titleSmall),
              Text(
                'Optional — the book is always on the Books shelf.',
                style: theme.textTheme.bodySmall,
              ),
              for (final (cls, subjects) in _tree)
                if (subjects.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(cls.name, style: theme.textTheme.labelLarge),
                  ),
                  for (final s in subjects)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _subjects.contains(s.id),
                      title: Text(s.name),
                      onChanged: (v) => setState(
                        () => v == true
                            ? _subjects.add(s.id)
                            : _subjects.remove(s.id),
                      ),
                    ),
                ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            final author = _author.text.trim();
            Navigator.pop(
              context,
              _BookDetails(title, author.isEmpty ? null : author, _subjects),
            );
          },
          child: Text(widget.editing ? 'Save' : 'Add book'),
        ),
      ],
    );
  }
}
