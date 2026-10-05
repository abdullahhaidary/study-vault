import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../data/book_providers.dart';
import '../data/book_repository.dart';
import '../domain/book_text_index.dart';
import 'book_actions.dart';
import 'book_chapter_screen.dart';
import 'book_chat_view.dart';
import 'book_course_view.dart';
import 'book_indexer.dart';
import 'book_markdown.dart';
import '../services/book_import_service.dart';

/// A book's home: chapters & search, Ask, notes, and course coverage.
class BookDetailsScreen extends ConsumerStatefulWidget {
  const BookDetailsScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends ConsumerState<BookDetailsScreen> {
  bool _started = false;

  void _ensureIndexed(ReferenceBook book) {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(bookIndexerProvider.notifier).ensureIndexed(book),
    );
  }

  Future<void> _delete(ReferenceBook book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${book.title}"?'),
        content: const Text(
          'The PDF, its chapters, AI briefs and summaries, notes, chat, lecture '
          'links and chapter quizzes are deleted on every synced device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pop();
    await ref.read(bookRepositoryProvider).deleteBook(book.id);
    await BookStorage.deleteFiles(book.id);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookProvider(widget.bookId));
    final book = async.valueOrNull;
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const AppLoading()
            : const AppErrorState(message: 'Book not found'),
      );
    }
    _ensureIndexed(book);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(book.title),
          actions: [
            FilledButton.tonalIcon(
              onPressed: () => openBookReader(context, book),
              icon: const Icon(Icons.chrome_reader_mode_outlined),
              label: const Text('Read'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    await editBookDetails(context, ref, book);
                  case 'chapters':
                    await ref
                        .read(bookImportServiceProvider)
                        .redetectChapters(book);
                  case 'delete':
                    await _delete(book);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Title, author & subjects'),
                ),
                PopupMenuItem(
                  value: 'chapters',
                  child: Text('Detect chapters again'),
                ),
                PopupMenuItem(value: 'delete', child: Text('Delete book')),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Chapters'),
              Tab(text: 'Ask'),
              Tab(text: 'Notes'),
              Tab(text: 'Courses'),
            ],
          ),
        ),
        body: Column(
          children: [
            _StatusBar(book: book),
            Expanded(
              child: TabBarView(
                children: [
                  _ChaptersTab(book: book),
                  BookChatView(
                    book: book,
                    onOpenPage: (p) => openBookReader(context, book, page: p),
                  ),
                  _NotesTab(book: book),
                  BookCourseView(book: book),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indexing / smart search status and linked subjects.
class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.book});

  final ReferenceBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final job = ref.watch(bookIndexerProvider)[book.id];
    final local =
        ref.watch(bookLocalStateProvider(book.id)).valueOrNull ??
        BookLocalState.empty;
    final subjects =
        ref.watch(bookSubjectsProvider(book.id)).valueOrNull ?? const [];
    final indexed = local.isIndexed(book);
    final smart =
        local.vectorsModel ==
        ref.read(bookSearchServiceProvider).embeddings.model;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (job != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.error ??
                          '${job.label}${job.total == 0 ? '…' : ' ${job.done} / ${job.total}'}',
                      style: TextStyle(
                        color: job.error == null
                            ? null
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                  if (job.error != null)
                    TextButton(
                      onPressed: () => ref
                          .read(bookIndexerProvider.notifier)
                          .dismiss(book.id),
                      child: const Text('Dismiss'),
                    ),
                ],
              ),
              if (job.running) LinearProgressIndicator(value: job.progress),
            ] else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: Icon(
                      indexed ? Icons.check : Icons.hourglass_empty,
                      size: 16,
                    ),
                    label: Text(
                      indexed
                          ? 'Search ready · ${book.pageCount} pages'
                          : 'Not indexed on this device',
                    ),
                  ),
                  if (!indexed)
                    TextButton(
                      onPressed: () => ref
                          .read(bookIndexerProvider.notifier)
                          .ensureIndexed(book),
                      child: const Text('Index now'),
                    )
                  else if (smart)
                    const Chip(
                      avatar: Icon(Icons.auto_awesome, size: 16),
                      label: Text('Smart search on'),
                    )
                  else
                    Tooltip(
                      message:
                          'Uses Gemini embeddings so questions match pages by '
                          'meaning, not only by words. One-time, per device.',
                      child: TextButton.icon(
                        onPressed: () async {
                          final available = await ref
                              .read(bookSearchServiceProvider)
                              .embeddings
                              .isAvailable;
                          if (!available) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Smart search needs a Gemini API key '
                                    '(Settings → AI).',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          ref
                              .read(bookIndexerProvider.notifier)
                              .buildSmartSearch(book);
                        },
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Enable smart search'),
                      ),
                    ),
                  for (final s in subjects)
                    Chip(
                      avatar: const Icon(Icons.class_outlined, size: 16),
                      label: Text(s.name),
                    ),
                  TextButton(
                    onPressed: () => editBookDetails(context, ref, book),
                    child: Text(subjects.isEmpty ? 'Link subjects' : 'Edit'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ChaptersTab extends ConsumerStatefulWidget {
  const _ChaptersTab({required this.book});

  final ReferenceBook book;

  @override
  ConsumerState<_ChaptersTab> createState() => _ChaptersTabState();
}

class _ChaptersTabState extends ConsumerState<_ChaptersTab> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<BookSearchHit>? _hits;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _search(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _hits = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final hits = await ref
            .read(bookSearchServiceProvider)
            .search(widget.book.id, text, limit: 30);
        if (mounted) setState(() => _hits = hits);
      } on Object catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(aiErrorMessage(e))));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = widget.book;
    final chapters =
        ref.watch(bookChaptersProvider(book.id)).valueOrNull ?? const [];
    final items =
        ref.watch(bookAiItemsProvider(book.id)).valueOrNull ?? const [];
    final withBrief = {
      for (final i in items)
        if (i.kind == BookAiKind.brief.storageValue) i.scopeKey,
    };
    final withSummary = {
      for (final i in items)
        if (i.kind == BookAiKind.summary.storageValue) i.scopeKey,
    };
    final hits = _hits;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TextField(
            controller: _query,
            onChanged: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search the book (offline)',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _query.clear();
                        _search('');
                      },
                    ),
            ),
          ),
        ),
        if (hits != null) ...[
          if (hits.isEmpty)
            const ListTile(title: Text('No matching pages.'))
          else
            for (final h in hits)
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  child: Text('${h.page}', style: theme.textTheme.labelSmall),
                ),
                title: Text(h.snippet, maxLines: 3),
                onTap: () => openBookReader(context, book, page: h.page),
              ),
        ] else
          for (final c in chapters)
            ListTile(
              contentPadding: EdgeInsets.only(
                left: 16.0 + 20 * c.level,
                right: 8,
              ),
              leading: Icon(
                switch (ChapterStatus.fromStorage(c.status)) {
                  ChapterStatus.done => Icons.check_circle,
                  ChapterStatus.reading => Icons.timelapse,
                  ChapterStatus.notStarted => Icons.radio_button_unchecked,
                },
                color: c.status == ChapterStatus.notStarted.storageValue
                    ? theme.colorScheme.outline
                    : theme.colorScheme.primary,
              ),
              title: Text(
                c.title,
                style: c.level == 0
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                [
                  'pp. ${c.startPage}–${c.endPage}',
                  if (withBrief.contains(c.id)) 'brief',
                  if (withSummary.contains(c.id)) 'summary',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      BookChapterScreen(bookId: book.id, chapterId: c.id),
                ),
              ),
            ),
      ],
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.book});

  final ReferenceBook book;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ReferenceBookNote note,
  ) async {
    final title = TextEditingController(text: note.title);
    final content = TextEditingController(text: note.content);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note · page ${note.pageNumber}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: content,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Note (Markdown)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && title.text.trim().isNotEmpty) {
      await ref
          .read(bookRepositoryProvider)
          .updateNote(note, title: title.text.trim(), content: content.text);
    }
    title.dispose();
    content.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(bookNotesProvider(book.id)).valueOrNull ?? const [];
    if (notes.isEmpty) {
      return const EmptyState(
        icon: Icons.sticky_note_2_outlined,
        title: 'No notes yet',
        message:
            'While reading, select text and tap Note, or bookmark a page. '
            'They appear here by page.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final n in notes)
          ListTile(
            leading: CircleAvatar(radius: 18, child: Text('${n.pageNumber}')),
            title: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: n.content.trim().isEmpty && n.selectedText == null
                ? null
                : BookMarkdown(
                    data: n.content.trim().isEmpty
                        ? '> ${n.selectedText}'
                        : n.content,
                  ),
            onTap: () => openBookReader(context, book, page: n.pageNumber),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => v == 'edit'
                  ? _edit(context, ref, n)
                  : ref.read(bookRepositoryProvider).deleteNote(n.id),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
      ],
    );
  }
}
