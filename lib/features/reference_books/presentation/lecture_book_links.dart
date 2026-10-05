import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book_providers.dart';
import '../domain/reading_plan.dart';
import 'book_actions.dart';

/// Chips for the book pages matched to a lecture; tap to read them.
class LectureBookLinks extends ConsumerWidget {
  const LectureBookLinks({super.key, required this.materialId});

  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links =
        ref.watch(materialBookLinksProvider(materialId)).valueOrNull ??
        const [];
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 12, bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (link, book) in links)
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                link.done ? Icons.check : Icons.menu_book_outlined,
                size: 16,
              ),
              label: Text(
                '${book.title.length > 24 ? '${book.title.substring(0, 24)}…' : book.title} '
                'pp. ${link.startPage}–${link.endPage} · '
                '${BookLinkPriority.fromStorage(link.priority).label}',
              ),
              onPressed: () =>
                  openBookReader(context, book, page: link.startPage),
            ),
        ],
      ),
    );
  }
}
