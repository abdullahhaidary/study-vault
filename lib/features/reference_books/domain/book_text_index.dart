import 'dart:math' as math;

/// One page of extracted book text.
class BookPage {
  const BookPage(this.page, this.text);
  final int page;
  final String text;
}

class BookSearchHit {
  const BookSearchHit({
    required this.page,
    required this.score,
    required this.snippet,
  });

  final int page;
  final double score;
  final String snippet;
}

/// In-memory BM25 index over book pages. Pure Dart, so it behaves the same on
/// Android and Linux and needs no SQLite extensions.
class BookTextIndex {
  BookTextIndex._(this._pages, this._postings, this._lengths, this._average);

  factory BookTextIndex.build(List<BookPage> pages) {
    final postings = <String, Map<int, int>>{};
    final lengths = <int, int>{};
    var total = 0;
    for (final page in pages) {
      final terms = tokenize(page.text);
      lengths[page.page] = terms.length;
      total += terms.length;
      for (final term in terms) {
        final perPage = postings.putIfAbsent(term, () => {});
        perPage[page.page] = (perPage[page.page] ?? 0) + 1;
      }
    }
    return BookTextIndex._(
      {for (final p in pages) p.page: p.text},
      postings,
      lengths,
      pages.isEmpty ? 0 : total / pages.length,
    );
  }

  final Map<int, String> _pages;
  final Map<String, Map<int, int>> _postings;
  final Map<int, int> _lengths;
  final double _average;

  static const _k1 = 1.2;
  static const _b = 0.75;

  int get pageCount => _pages.length;

  String? textOf(int page) => _pages[page];

  /// Ranks pages for [query]. [within] restricts results to a page range.
  List<BookSearchHit> search(
    String query, {
    int limit = 20,
    ({int start, int end})? within,
  }) {
    final terms = tokenize(query).toSet();
    if (terms.isEmpty || _pages.isEmpty) return const [];
    final n = _pages.length;
    final scores = <int, double>{};
    for (final term in terms) {
      final perPage = _postings[term];
      if (perPage == null) continue;
      final idf = math.log(
        1 + (n - perPage.length + 0.5) / (perPage.length + 0.5),
      );
      for (final entry in perPage.entries) {
        if (within != null &&
            (entry.key < within.start || entry.key > within.end)) {
          continue;
        }
        final tf = entry.value;
        final length = _lengths[entry.key] ?? 0;
        final norm =
            _k1 * (1 - _b + _b * length / (_average == 0 ? 1 : _average));
        scores[entry.key] =
            (scores[entry.key] ?? 0) + idf * tf * (_k1 + 1) / (tf + norm);
      }
    }
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in ranked.take(limit))
        BookSearchHit(
          page: e.key,
          score: e.value,
          snippet: snippet(_pages[e.key]!, terms),
        ),
    ];
  }

  static String snippet(String text, Set<String> terms, {int radius = 140}) {
    final lower = text.toLowerCase();
    var at = -1;
    for (final term in terms) {
      final i = lower.indexOf(term);
      if (i >= 0 && (at < 0 || i < at)) at = i;
    }
    if (at < 0) at = 0;
    final start = math.max(0, at - radius);
    final end = math.min(text.length, at + radius);
    final body = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
    return '${start > 0 ? '…' : ''}${body.trim()}${end < text.length ? '…' : ''}';
  }

  static final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static const _stopwords = {
    'the',
    'and',
    'for',
    'are',
    'but',
    'not',
    'you',
    'all',
    'any',
    'can',
    'her',
    'was',
    'one',
    'our',
    'out',
    'has',
    'his',
    'how',
    'its',
    'may',
    'who',
    'did',
    'yes',
    'she',
    'him',
    'this',
    'that',
    'with',
    'from',
    'they',
    'will',
    'what',
    'when',
    'which',
    'there',
    'their',
    'then',
    'than',
    'them',
    'these',
    'those',
    'into',
    'have',
    'been',
    'were',
    'also',
    'such',
    'each',
    'other',
    'some',
    'more',
    'most',
    'only',
    'very',
    'about',
    'would',
    'could',
    'should',
    'does',
    'between',
    'where',
    'why',
    'explain',
    'please',
    'tell',
    'give',
    'book',
    'page',
    'pages',
    'chapter',
  };

  /// Lowercased words without stopwords, lightly stemmed so "risks",
  /// "risked" and "risking" match "risk".
  static List<String> tokenize(String text) {
    final result = <String>[];
    for (final match in _word.allMatches(text.toLowerCase())) {
      final word = match.group(0)!;
      if (word.length < 2 || _stopwords.contains(word)) continue;
      result.add(stem(word));
    }
    return result;
  }

  static String stem(String word) {
    if (word.length <= 4) return word;
    for (final suffix in const [
      'ations',
      'ation',
      'ings',
      'ing',
      'ies',
      'ied',
    ]) {
      if (word.endsWith(suffix) && word.length - suffix.length >= 3) {
        final base = word.substring(0, word.length - suffix.length);
        return suffix.startsWith('i') && suffix != 'ing' && suffix != 'ings'
            ? '${base}y'
            : base;
      }
    }
    for (final suffix in const ['es', 'ed', 'ly', 's']) {
      if (word.endsWith(suffix) &&
          !word.endsWith('ss') &&
          word.length - suffix.length >= 3) {
        return word.substring(0, word.length - suffix.length);
      }
    }
    return word;
  }
}

/// Reciprocal-rank fusion of several ranked page lists.
List<int> fuseRankings(List<List<int>> rankings, {int k = 60, int limit = 20}) {
  final scores = <int, double>{};
  for (final ranking in rankings) {
    for (var i = 0; i < ranking.length; i++) {
      scores[ranking[i]] = (scores[ranking[i]] ?? 0) + 1 / (k + i + 1);
    }
  }
  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in ranked.take(limit)) e.key];
}

double cosine(List<double> a, List<double> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na == 0 || nb == 0 ? 0 : dot / math.sqrt(na * nb);
}
