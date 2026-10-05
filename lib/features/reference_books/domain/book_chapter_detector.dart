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
    final usable = outline.where((e) => e.level <= maxLevel).toList();
    final cleaned = _cleanOutline(usable);
    final fromOutline = fromEntries(cleaned.entries, pageCount);
    final enoughChapters = fromOutline.where((c) => c.level == 0).length >= 2;
    if (!cleaned.dirty && enoughChapters) return fromOutline;
    final fromHeadings = fromEntries(headings(pageText), pageCount);
    if (fromHeadings.length >= 2) return fromHeadings;
    if (enoughChapters) return fromOutline;
    return blocks(pageCount);
  }

  /// Bookmark titles that carry no structure, e.g. "Page 154".
  static final _junkTitle = RegExp(
    r'^(page|pg|p)\.?\s*\d+\s*$',
    caseSensitive: false,
  );

  /// Drops useless bookmark entries. The outline is [dirty] when anything had
  /// to be removed — a sign the whole outline is untrustworthy.
  static ({List<OutlineEntry> entries, bool dirty}) _cleanOutline(
    List<OutlineEntry> raw,
  ) {
    var dirty = false;
    final siblingPages = <String>{};
    final result = <OutlineEntry>[];
    for (final e in raw) {
      if (e.title.trim().isEmpty) continue;
      if (_junkTitle.hasMatch(e.title.trim())) {
        dirty = true;
        continue;
      }
      // Two entries at the same level can't share a start page (a deeper
      // entry starting on its parent's page is normal).
      if (!siblingPages.add('${e.level}:${e.page}')) {
        dirty = true;
        continue;
      }
      result.add(e);
    }
    return (entries: result, dirty: dirty);
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

  /// Standalone divider pages like "APPENDIX" or "Index".
  static final _divider = RegExp(
    r'^\s*(appendix|index)\s*$',
    caseSensitive: false,
  );

  static final _contentsPage = RegExp(
    r'^\s*(table of )?contents\.?\s*$',
    caseSensitive: false,
  );

  static final _sentenceTail = RegExp(r'^[),;\]]');

  static final _caption = RegExp(
    r'^(figure|table|exhibit|learning objectives)\b',
    caseSensitive: false,
  );

  static final _connector = RegExp(
    r'(\b(?:and|or|of|the|a|an|to|for|in|on|with)|[&,\-])\s*$',
    caseSensitive: false,
  );

  /// The line(s) after a title-page heading holding the chapter's name,
  /// e.g. "Managing Project Resources" under "CHAPTER 7". Joins the next
  /// line when the name is split across two ("...Stakeholders and" /
  /// "Communication").
  static String? _subtitle(List<String> lines, int from) {
    var sub = '';
    for (var i = from; i < lines.length && i < from + 4; i++) {
      final line = lines[i];
      if (_heading.hasMatch(line) ||
          _divider.hasMatch(line) ||
          _caption.hasMatch(line)) {
        break;
      }
      if (sub.isNotEmpty &&
          !_connector.hasMatch(sub) &&
          !_startsLower.hasMatch(line)) {
        break;
      }
      sub = sub.isEmpty ? line : '$sub $line';
    }
    if (sub.isEmpty) return null;
    return sub.length > 120 ? '${sub.substring(0, 120).trimRight()}…' : sub;
  }

  static final _startsLower = RegExp('^[a-z]');

  /// "Chapter 7 Risk Management" at the top of a page.
  static List<OutlineEntry> headings(Map<int, String> pageText) {
    final candidates = <_HeadingHit>[];
    final pages = pageText.keys.toList()..sort();
    for (final page in pages) {
      final lines = pageText[page]!
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      if (_contentsPage.hasMatch(lines.first)) continue;
      // A table-of-contents page lists several headings; a chapter's first
      // page mentions only its own. Distinct keys because a running header
      // may repeat the same one.
      final keysOnPage = <String>{};
      for (final line in lines.take(10)) {
        final match = _heading.firstMatch(line);
        if (match != null) {
          keysOnPage.add(
            '${match.group(1)!.toLowerCase()} ${match.group(2)!.toLowerCase()}',
          );
        }
      }
      if (keysOnPage.length >= 2) continue;
      for (var li = 0; li < lines.length && li < 3; li++) {
        final line = lines[li];
        final divider = _divider.firstMatch(line);
        if (divider != null) {
          final kind = divider.group(1)!.toLowerCase();
          var title = _capital(kind);
          if (kind == 'appendix') {
            final sub = _subtitle(lines, li + 1);
            if (sub != null) title = '$title: $sub';
          }
          candidates.add(_HeadingHit(page, kind, null, title));
          break;
        }
        final match = _heading.firstMatch(line);
        if (match == null) continue;
        var rest = match.group(3)!.trim();
        // Sentence punctuation means the name continues a sentence
        // ("...in Chapter 7).", "Chapter 6, milestones"): body text.
        if (rest.isNotEmpty && _sentenceTail.hasMatch(rest)) continue;
        // A bare "Chapter 7." is body text ("...discussed in Chapter 7.");
        // real title pages write it in caps ("CHAPTER 7"), with the
        // chapter's name on the following line.
        if (rest.isEmpty) {
          if (line != line.toUpperCase()) break;
          rest = _subtitle(lines, li + 1) ?? '';
        }
        final kind = match.group(1)!.toLowerCase();
        final numText = match.group(2)!;
        candidates.add(
          _HeadingHit(
            page,
            kind,
            int.tryParse(numText) ?? _romanToInt(numText),
            rest.isEmpty
                ? '${_capital(kind)} $numText'
                : '${_capital(kind)} $numText: $rest',
          ),
        );
        break;
      }
    }
    // Out-of-order numbers mean the page is a table of contents or a
    // cross-reference, not a real chapter start. Keep the longest
    // increasing run per kind so early false hits can't steal a number.
    final kept = <_HeadingHit>[];
    for (final kind in {'chapter', 'part'}) {
      kept.addAll(
        _longestIncreasing(
          candidates.where((c) => c.kind == kind && c.number != null).toList(),
        ),
      );
    }
    kept.addAll(candidates.where((c) => c.number == null));
    kept.sort((a, b) => a.page.compareTo(b.page));
    final seen = <String>{};
    final entries = <OutlineEntry>[];
    final hasParts = kept.any((c) => c.kind == 'part');
    for (final c in kept) {
      final key = c.number == null ? c.kind : '${c.kind} ${c.number}';
      if (!seen.add(key)) continue;
      entries.add(
        OutlineEntry(c.title, c.kind == 'chapter' && hasParts ? 1 : 0, c.page),
      );
    }
    return entries;
  }

  /// The longest strictly increasing subsequence of [hits] by [number],
  /// preserving page order and preferring the earliest pages. Out-of-order
  /// and duplicate numbers are dropped.
  static List<_HeadingHit> _longestIncreasing(List<_HeadingHit> hits) {
    final n = hits.length;
    if (n == 0) return const [];
    final ends = List<int>.filled(n, 1);
    final starts = List<int>.filled(n, 1);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < i; j++) {
        if (hits[j].number! < hits[i].number! && ends[j] + 1 > ends[i]) {
          ends[i] = ends[j] + 1;
        }
      }
    }
    for (var i = n - 1; i >= 0; i--) {
      for (var j = i + 1; j < n; j++) {
        if (hits[j].number! > hits[i].number! && starts[j] + 1 > starts[i]) {
          starts[i] = starts[j] + 1;
        }
      }
    }
    final total = ends.reduce((a, b) => a > b ? a : b);
    final result = <_HeadingHit>[];
    var lastNum = -1 << 30;
    var lastIdx = -1;
    for (var need = 1; need <= total; need++) {
      for (var i = lastIdx + 1; i < n; i++) {
        if (ends[i] == need &&
            hits[i].number! > lastNum &&
            ends[i] + starts[i] - 1 >= total) {
          result.add(hits[i]);
          lastNum = hits[i].number!;
          lastIdx = i;
          break;
        }
      }
    }
    return result;
  }

  static int _romanToInt(String s) {
    const values = {'i': 1, 'v': 5, 'x': 10, 'l': 50, 'c': 100};
    var total = 0;
    var prev = 0;
    for (final unit in s.toLowerCase().split('').reversed) {
      final v = values[unit] ?? 0;
      total += v < prev ? -v : v;
      prev = v > prev ? v : prev;
    }
    return total;
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

class _HeadingHit {
  const _HeadingHit(this.page, this.kind, this.number, this.title);
  final int page;
  final String kind;
  final int? number;
  final String title;
}
