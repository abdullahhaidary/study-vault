import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/database/app_database.dart';
import '../../../study_pins/data/study_pins_providers.dart';
import '../../../study_pins/domain/pin_type.dart';

class MaterialOutlinePanel extends StatefulWidget {
  const MaterialOutlinePanel({
    super.key,
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
  State<MaterialOutlinePanel> createState() => _MaterialOutlinePanelState();
}

class _MaterialOutlinePanelState extends State<MaterialOutlinePanel> {
  late final Future<List<PdfOutlineNode>> _outline;

  @override
  void initState() {
    super.initState();
    _outline = _loadOutline();
  }

  Future<List<PdfOutlineNode>> _loadOutline() async {
    return await widget.controller.useDocument(
          (document) => document.loadOutline(),
        ) ??
        const <PdfOutlineNode>[];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Outline'),
              Tab(text: 'Bookmarks'),
              Tab(text: 'Annotations'),
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

  List<_OutlineEntry> _flatten(List<PdfOutlineNode> nodes, [int depth = 0]) {
    return [
      for (final node in nodes) ...[
        _OutlineEntry(node, depth),
        ..._flatten(node.children, depth + 1),
      ],
    ];
  }
}

class _OutlineEntry {
  const _OutlineEntry(this.node, this.depth);
  final PdfOutlineNode node;
  final int depth;
}
