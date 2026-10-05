import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../../selection_ai/domain/selection_ai_host.dart';
import '../../selection_ai/presentation/selection_ai_launcher.dart';
import '../../selection_ai/presentation/selection_ai_toolbar.dart';
import '../data/book_providers.dart';
import '../data/book_repository.dart';
import '../services/book_ai_service.dart';
import '../services/book_import_service.dart';
import 'book_chat_view.dart';
import 'book_markdown.dart';

/// Reads a reference book with a chapter panel, page AI and the shared
/// selection toolbar (AI · translate · note · flashcard).
class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({super.key, required this.bookId, this.initialPage});

  final String bookId;
  final int? initialPage;

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

enum _Side { none, chapters, ask }

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  final _controller = PdfViewerController();
  String? _path;
  bool _missing = false;
  int _page = 1;
  int? _startPage;
  _Side _side = _Side.chapters;
  Timer? _saveTimer;

  BookRepository get _repository => ref.read(bookRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _repository.saveLastPage(widget.bookId, _page);
    super.dispose();
  }

  Future<void> _load() async {
    final book = await _repository.book(widget.bookId);
    if (book == null) return;
    final path = await BookStorage.absolutePath(book);
    final exists = await File(path).exists();
    final last = (await _repository.localState(book.id)).lastPage;
    if (!mounted) return;
    setState(() {
      _path = path;
      _missing = !exists;
      _startPage = (widget.initialPage ?? last).clamp(1, book.pageCount);
      _page = _startPage!;
    });
  }

  void _onPage(int? page) {
    if (page == null) return;
    setState(() => _page = page);
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(seconds: 2),
      () => _repository.saveLastPage(widget.bookId, page),
    );
  }

  void goTo(int page) {
    if (_controller.isReady) _controller.goToPage(pageNumber: page);
  }

  ReferenceBookChapter? _chapterAt(
    List<ReferenceBookChapter> chapters, {
    bool topLevel = false,
  }) {
    ReferenceBookChapter? best;
    for (final c in chapters) {
      if (topLevel && c.level != 0) continue;
      if (_page >= c.startPage && _page <= c.endPage) {
        if (best == null || c.level >= best.level) best = c;
      }
    }
    return best;
  }

  SelectionAiHost _host(ReferenceBook book) {
    final chapters =
        ref.read(bookChaptersProvider(book.id)).valueOrNull ?? const [];
    final chapter = _chapterAt(chapters, topLevel: true);
    return SelectionAiHost(
      title: book.title,
      pageNumber: _page,
      filePath: _path,
      loadFullText: () async {
        final start =
            chapter?.startPage ?? (_page - 2).clamp(1, book.pageCount);
        final end = chapter == null
            ? (_page + 2).clamp(1, book.pageCount)
            : (chapter.endPage - chapter.startPage > 40
                  ? chapter.startPage + 40
                  : chapter.endPage);
        final pages = await _repository.pages(book.id, start: start, end: end);
        return pages.map((p) => '--- Page ${p.page} ---\n${p.text}').join('\n');
      },
      loadSummary: chapter == null
          ? null
          : () async => (await _repository.latestAiItem(
              bookId: book.id,
              kind: BookAiKind.summary,
              scopeKey: chapter.id,
            ))?.content,
    );
  }

  Future<void> _saveSelectionNote(
    ReferenceBook book,
    PdfTextSelectionDelegate selection,
  ) async {
    final text = (await selection.getSelectedText()).trim();
    if (text.isEmpty) return;
    await _repository.addNote(
      bookId: book.id,
      page: _page,
      title: text.length > 60 ? '${text.substring(0, 60)}…' : text,
      selectedText: text,
    );
    await selection.clearTextSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to book notes (p. $_page)')),
      );
    }
  }

  Widget? _contextMenu(
    ReferenceBook book,
    BuildContext context,
    PdfViewerContextMenuBuilderParams params,
  ) {
    final delegate = params.textSelectionDelegate;
    if (!params.isTextSelectionEnabled || !delegate.hasSelectedText) {
      return null;
    }
    Future<String> selected() async =>
        (await delegate.getSelectedText()).trim();
    return Align(
      alignment: Alignment.topLeft,
      child: SelectionAiToolbar(
        anchors: TextSelectionToolbarAnchors(
          primaryAnchor: params.anchorA,
          secondaryAnchor: params.anchorB,
        ),
        onCopy: () {
          params.dismissContextMenu();
          delegate.copyTextSelection();
        },
        onAi: () async {
          params.dismissContextMenu();
          final text = await selected();
          if (!mounted) return;
          await SelectionAiLauncher.open(
            this.context,
            ref,
            host: _host(book),
            selectedText: text,
          );
        },
        onTranslate: () async {
          params.dismissContextMenu();
          final text = await selected();
          if (!mounted) return;
          await SelectionAiLauncher.translate(
            this.context,
            ref,
            host: _host(book),
            selectedText: text,
          );
        },
        onNote: () {
          params.dismissContextMenu();
          _saveSelectionNote(book, delegate);
        },
        onFlashcard: () async {
          params.dismissContextMenu();
          final text = await selected();
          if (!mounted) return;
          await SelectionAiLauncher.makeFlashcard(
            this.context,
            host: _host(book),
            selectedText: text,
          );
        },
      ),
    );
  }

  Future<void> _explainPage(ReferenceBook book) async {
    final scope = BookAiService.pageScope(_page, _page);
    var item = await _repository.latestAiItem(
      bookId: book.id,
      kind: BookAiKind.explanation,
      scopeKey: scope,
    );
    if (item == null) {
      if (!mounted) return;
      final selection = await pickAiModel(
        context,
        ref,
        title: 'Explain page $_page with',
      );
      if (selection == null || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Explaining page $_page…')),
      );
      try {
        item = await ref
            .read(bookAiServiceProvider)
            .explainPages(
              book: book,
              startPage: _page,
              endPage: _page,
              selection: selection,
            );
      } on Object catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(aiErrorMessage(e))));
        return;
      }
    }
    if (!mounted) return;
    final content = item.content;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Page ${item!.startPage} explained',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            BookMarkdown(
              data: content,
              onOpenPage: (p) {
                Navigator.pop(context);
                goTo(p);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookmark(ReferenceBook book) async {
    await _repository.addNote(
      bookId: book.id,
      page: _page,
      title: 'Bookmark · page $_page',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bookmarked page $_page')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(bookProvider(widget.bookId)).valueOrNull;
    if (book == null || _startPage == null) {
      return const Scaffold(body: AppLoading());
    }
    final chapters =
        ref.watch(bookChaptersProvider(book.id)).valueOrNull ?? const [];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final current = _chapterAt(chapters);
    final panel = switch (_side) {
      _Side.chapters => _chapterPanel(chapters, current),
      _Side.ask => BookChatView(
        book: book,
        onOpenPage: goTo,
        initialChapterId: _chapterAt(chapters, topLevel: true)?.id,
        compact: true,
      ),
      _Side.none => null,
    };
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.title, overflow: TextOverflow.ellipsis),
            Text(
              'Page $_page of ${book.pageCount}'
              '${current == null ? '' : ' · ${current.title}'}',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chapters',
            isSelected: _side == _Side.chapters,
            icon: const Icon(Icons.toc),
            onPressed: () => wide
                ? setState(
                    () => _side = _side == _Side.chapters
                        ? _Side.none
                        : _Side.chapters,
                  )
                : _sheet(_chapterPanel(chapters, current)),
          ),
          IconButton(
            tooltip: 'Ask the book',
            isSelected: _side == _Side.ask,
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => wide
                ? setState(
                    () => _side = _side == _Side.ask ? _Side.none : _Side.ask,
                  )
                : _sheet(
                    BookChatView(
                      book: book,
                      onOpenPage: (p) {
                        Navigator.pop(context);
                        goTo(p);
                      },
                      initialChapterId: _chapterAt(
                        chapters,
                        topLevel: true,
                      )?.id,
                      compact: true,
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Explain this page',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => _explainPage(book),
          ),
          IconButton(
            tooltip: 'Bookmark this page',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _bookmark(book),
          ),
        ],
      ),
      body: _missing
          ? const EmptyState(
              icon: Icons.cloud_download_outlined,
              title: 'Book file not on this device',
              message:
                  'Open Settings → Private Cloud Account and press Sync now '
                  'to download it.',
            )
          : Row(
              children: [
                Expanded(
                  child: PdfViewer.file(
                    _path!,
                    controller: _controller,
                    initialPageNumber: _startPage!,
                    params: PdfViewerParams(
                      margin: 8,
                      textSelectionParams: const PdfTextSelectionParams(
                        enabled: true,
                        showContextMenuAutomatically: true,
                      ),
                      buildContextMenu: (context, params) =>
                          _contextMenu(book, context, params),
                      onPageChanged: _onPage,
                    ),
                  ),
                ),
                if (wide && panel != null) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(width: _side == _Side.ask ? 420 : 320, child: panel),
                ],
              ],
            ),
    );
  }

  void _sheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: child,
      ),
    );
  }

  Widget _chapterPanel(
    List<ReferenceBookChapter> chapters,
    ReferenceBookChapter? current,
  ) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, i) {
        final c = chapters[i];
        final status = ChapterStatus.fromStorage(c.status);
        return ListTile(
          dense: true,
          selected: c.id == current?.id,
          contentPadding: EdgeInsets.only(left: 12.0 + 16 * c.level, right: 8),
          leading: Icon(
            switch (status) {
              ChapterStatus.done => Icons.check_circle,
              ChapterStatus.reading => Icons.timelapse,
              ChapterStatus.notStarted => Icons.radio_button_unchecked,
            },
            size: 18,
            color: status == ChapterStatus.notStarted
                ? theme.colorScheme.outline
                : theme.colorScheme.primary,
          ),
          title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text('${c.startPage}', style: theme.textTheme.labelSmall),
          onTap: () {
            if (Navigator.of(context).canPop() &&
                MediaQuery.sizeOf(context).width < 900) {
              Navigator.pop(context);
            }
            goTo(c.startPage);
          },
        );
      },
    );
  }
}
