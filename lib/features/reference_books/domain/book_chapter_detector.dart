/// A chapter or section with its page range (1-based, inclusive).
class DetectedChapter {
  const DetectedChapter({
    required this.title,
    required this.level,
    required this.startPage,
    required this.endPage,
  });

  final String title;
  final int level;
  final int startPage;
  final int endPage;
}

/// Outline entry flattened from the PDF's bookmarks.
class OutlineEntry {
  const OutlineEntry(this.title, this.level, this.page);
  final String title;
  final int level;
  final int page;
}

/// Builds chapters from PDF bookmarks, falling back to "Chapter N" headings
/// in page text, then to fixed page blocks.
abstract final class BookChapterDetector {
  static const maxLevel = 1;
  static const fallbackBlock = 25;

  static List<DetectedChapter> detect({
    required int pageCount,
    required List<OutlineEntry> outline,
    required Map<int, String> pageText,
  }) {
    final fromOutline = fromEntries(
      outline.where((e) => e.level <= maxLevel).toList(),
      pageCount,
    );
    if (fromOutline.where((c) => c.level == 0).length >= 2) return fromOutline;
    final fromHeadings = fromEntries(headings(pageText), pageCount);
    if (fromHeadings.length >= 2) return fromHeadings;
    return blocks(pageCount);
  }

  /// End pages run until the next entry at the same or a higher level.
  static List<DetectedChapter> fromEntries(
    List<OutlineEntry> raw,
    int pageCount,
  ) {
    final entries = [
      for (final e in raw)
        if (e.page >= 1 && e.page <= pageCount && e.title.trim().isNotEmpty) e,
    ]..sort((a, b) => a.page.compareTo(b.page));
    final result = <DetectedChapter>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      var end = pageCount;
      for (var j = i + 1; j < entries.length; j++) {
        if (entries[j].level <= e.level) {
          end = entries[j].page > e.page ? entries[j].page - 1 : e.page;
          break;
        }
      }
      result.add(
        DetectedChapter(
          title: e.title.trim().replaceAll(RegExp(r'\s+'), ' '),
          level: e.level,
          startPage: e.page,
          endPage: end < e.page ? e.page : end,
        ),
      );
    }
    return result;
  }

  static final _heading = RegExp(
    r'^\s*(chapter|part)\s+([0-9]+|[ivxlc]+)\b[\s.:—–-]*(.{0,80})',
    caseSensitive: false,
  );

  /// "Chapter 7 Risk Management" at the top of a page.
  static List<OutlineEntry> headings(Map<int, String> pageText) {
    final result = <OutlineEntry>[];
    final seen = <String>{};
    final pages = pageText.keys.toList()..sort();
    for (final page in pages) {
      final lines = pageText[page]!
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .take(3);
      for (final line in lines) {
        final match = _heading.firstMatch(line);
        if (match == null) continue;
        final key =
            '${match.group(1)!.toLowerCase()} ${match.group(2)!.toLowerCase()}';
        if (!seen.add(key)) break;
        final rest = match.group(3)!.trim();
        result.add(
          OutlineEntry(
            rest.isEmpty
                ? '${_capital(match.group(1)!)} ${match.group(2)}'
                : '${_capital(match.group(1)!)} ${match.group(2)}: $rest',
            match.group(1)!.toLowerCase() == 'part' ? 0 : 0,
            page,
          ),
        );
        break;
      }
    }
    return result;
  }

  static List<DetectedChapter> blocks(int pageCount) => [
    for (var start = 1; start <= pageCount; start += fallbackBlock)
      DetectedChapter(
        title:
            'Pages $start–${(start + fallbackBlock - 1).clamp(1, pageCount)}',
        level: 0,
        startPage: start,
        endPage: (start + fallbackBlock - 1).clamp(1, pageCount),
      ),
  ];

  static String _capital(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
}
