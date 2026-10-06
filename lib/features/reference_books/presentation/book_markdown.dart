import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/markdown/study_markdown.dart';
import '../domain/book_prompts.dart';

/// Markdown where `[p. 12]` citations become links that open the page.
class BookMarkdown extends StatelessWidget {
  const BookMarkdown({super.key, required this.data, this.onOpenPage});

  final String data;
  final ValueChanged<int>? onOpenPage;

  static String linkCitations(String text) => text.replaceAllMapped(
    BookPrompts.citation,
    (m) => '[p. ${m[1]}${m[2] == null ? '' : '–${m[2]}'}](page:${m[1]})',
  );

  @override
  Widget build(BuildContext context) {
    final style = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return StudyMarkdown(
      data: onOpenPage == null ? data : linkCitations(data),
      styleSheet: style,
      onTapLink: (_, href, _) {
        final page = href != null && href.startsWith('page:')
            ? int.tryParse(href.substring(5))
            : null;
        if (page != null) onOpenPage?.call(page);
      },
    );
  }
}
