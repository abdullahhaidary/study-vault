import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/database/app_database.dart';
import '../../../ai_chat/data/ai_chat_providers.dart';
import '../../../ai_chat/domain/ai_chat_models.dart';
import '../../../ai_chat/presentation/widgets/ai_discussions_section.dart';
import '../../../ai_questions/data/quiz_providers.dart';
import '../../../ai_questions/domain/quiz_models.dart';
import '../../../ai_questions/presentation/quiz_session_screen.dart';
import '../../../study_pins/data/study_pins_providers.dart';
import '../../../study_pins/domain/pin_type.dart';

class MaterialOutlinePanel extends ConsumerStatefulWidget {
  const MaterialOutlinePanel({
    super.key,
    required this.materialId,
    required this.controller,
    required this.bookmarks,
    required this.pins,
    required this.currentPage,
    required this.onBookmarkTap,
    required this.onBookmarkEdit,
    required this.onBookmarkDelete,
    required this.onPinTap,
    this.categoryNames = const {},
  });

  final String materialId;
  final PdfViewerController controller;
  final List<MaterialBookmark> bookmarks;
  final List<StudyPin> pins;
  final int? currentPage;
  final ValueChanged<MaterialBookmark> onBookmarkTap;
  final ValueChanged<MaterialBookmark> onBookmarkEdit;
  final ValueChanged<MaterialBookmark> onBookmarkDelete;
  final ValueChanged<StudyPin> onPinTap;
  final Map<String, String> categoryNames;

  @override
  ConsumerState<MaterialOutlinePanel> createState() =>
      _MaterialOutlinePanelState();
}

class _MaterialOutlinePanelState extends ConsumerState<MaterialOutlinePanel> {
  late final Future<List<PdfOutlineNode>> _outline;
  int? _outlineCount;

  @override
  void initState() {
    super.initState();
    _outline = _loadOutline();
  }

  Future<List<PdfOutlineNode>> _loadOutline() async {
    final nodes =
        await widget.controller.useDocument(
          (document) => document.loadOutline(),
        ) ??
        const <PdfOutlineNode>[];
    if (mounted) {
      setState(() => _outlineCount = _flatten(nodes).length);
    }
    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    final chatsCount =
        ref
            .watch(
              aiDiscussionsGroupedProvider((
                kind: AiContextKind.material,
                id: widget.materialId,
              )),
            )
            .valueOrNull
            ?.length ??
        0;
    final questionSets = ref.watch(
      questionSetsForMaterialProvider(widget.materialId),
    );
    final questionCount =
        questionSets.valueOrNull?.fold<int>(
          0,
          (total, set) => total + set.questionCount,
        ) ??
        0;

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              _CountTab(label: 'Outline', count: _outlineCount ?? 0),
              _CountTab(label: 'Bookmarks', count: widget.bookmarks.length),
              _CountTab(
                label: 'Annotations',
                count: widget.pins
                    .where((pin) => pin.pageNumber != null)
                    .length,
              ),
              _CountTab(label: 'Questions', count: questionCount),
              _CountTab(label: 'Chats', count: chatsCount),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                FutureBuilder<List<PdfOutlineNode>>(
                  future: _outline,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final nodes = snapshot.data!;
                    if (nodes.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'This PDF does not contain a table of contents.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final flat = _flatten(nodes);
                    return ListView.builder(
                      itemCount: flat.length,
                      itemBuilder: (context, index) {
                        final entry = flat[index];
                        return ListTile(
                          contentPadding: EdgeInsets.only(
                            left: 16 + entry.depth * 16.0,
                            right: 8,
                          ),
                          title: Text(
                            entry.node.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: entry.node.dest == null
                              ? null
                              : () =>
                                    widget.controller.goToDest(entry.node.dest),
                        );
                      },
                    );
                  },
                ),
                ListView.builder(
                  itemCount: widget.bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = widget.bookmarks[index];
                    return ListTile(
                      selected: bookmark.pageNumber == widget.currentPage,
                      leading: const Icon(Icons.bookmark),
                      title: Text(
                        bookmark.title ?? 'Page ${bookmark.pageNumber}',
                      ),
                      subtitle: Text('Page ${bookmark.pageNumber}'),
                      onTap: () => widget.onBookmarkTap(bookmark),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') widget.onBookmarkEdit(bookmark);
                          if (value == 'delete') {
                            widget.onBookmarkDelete(bookmark);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit title'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    );
                  },
                ),
                _annotations(),
                _questions(questionSets),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: AiDiscussionsList(
                    kind: AiContextKind.material,
                    id: widget.materialId,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _annotations() {
    final byPage = <int, List<StudyPin>>{};
    for (final pin in widget.pins) {
      if (pin.pageNumber != null) (byPage[pin.pageNumber!] ??= []).add(pin);
    }
    final pages = byPage.keys.toList()..sort();
    if (pages.isEmpty) return const Center(child: Text('No annotations yet.'));
    return ListView.builder(
      itemCount: pages.length,
      itemBuilder: (context, pageIndex) {
        final page = pages[pageIndex];
        final pins = byPage[page]!;
        return ExpansionTile(
          initiallyExpanded: page == widget.currentPage,
          title: Text('Page $page'),
          children: [
            for (final pin in pins)
              ListTile(
                leading: Icon(
                  pin.type == StudyPinType.text
                      ? Icons.format_quote
                      : Icons.location_on_outlined,
                ),
                title: Text(
                  pin.shortText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: pin.categoryId == null
                    ? null
                    : Text(
                        widget.categoryNames[pin.categoryId!] ??
                            'Uncategorized',
                      ),
                onTap: () => widget.onPinTap(pin),
              ),
          ],
        );
      },
    );
  }

  Widget _questions(AsyncValue<List<QuestionSet>> sets) {
    return sets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Could not load generated questions.')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No generated questions yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final set = items[index];
            final type = QuizQuestionTypeX.fromStorage(set.questionType);
            final difficulty = QuizDifficultyX.fromStorage(set.difficulty);
            return ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text(
                set.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${set.questionCount} questions · '
                '${type.label} · ${difficulty.label}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuizSessionScreen(questionSetId: set.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_OutlineEntry> _flatten(List<PdfOutlineNode> nodes, [int depth = 0]) {
    return [
      for (final node in nodes) ...[
        _OutlineEntry(node, depth),
        ..._flatten(node.children, depth + 1),
      ],
    ];
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineEntry {
  const _OutlineEntry(this.node, this.depth);
  final PdfOutlineNode node;
  final int depth;
}
