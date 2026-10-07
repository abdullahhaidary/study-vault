/// Pure helpers to apply an AI answer into a markdown document based on the
/// *rendered* text the user selected.
///
/// Rendered text differs from source (no `**`, `` ` ``, list markers, heading
/// hashes, table pipes, and collapsed whitespace), so matching is tolerant.
abstract final class MarkdownSelectionEditor {
  static final _ws = RegExp(r'\s+');
  static final _zw = RegExp(r'[\u200B-\u200D\uFEFF\u00AD\uFFFC]');
  static final _bulletLine = RegExp(
    r'^[ \t]*([•●▪▸►◦]|[-*+]|\d+[.)])[ \t]+',
    multiLine: true,
  );
  static const _inline = r'[*_~`]*';
  /// Markdown punctuation Flutter's renderer strips between visible words.
  static const _gap = r'[\s*_~`>#|=+\-.,:;!()\[\]{}/\\]*';

  /// Locates [selectedPlain] inside [markdown]. Returns `null` when the
  /// selection cannot be mapped back to the source.
  static ({int start, int end})? locate(String markdown, String selectedPlain) {
    final selected = _cleanSelection(selectedPlain);
    if (selected.isEmpty || markdown.isEmpty) return null;

    final exact = markdown.indexOf(selected);
    if (exact >= 0) return (start: exact, end: exact + selected.length);

    final tokens = _tokens(selected);
    if (tokens.isEmpty) return null;

    return _tokenRange(markdown, tokens) ??
        _tokenRange(markdown, tokens, caseInsensitive: true);
  }

  /// Like [locate], but if the full selection cannot be mapped, falls back to
  /// the last few visible words — enough to place an insertion.
  static ({int start, int end})? locateForInsert(
    String markdown,
    String selectedPlain,
  ) {
    final full = locate(markdown, selectedPlain);
    if (full != null) return full;

    final tokens = _tokens(_cleanSelection(selectedPlain));
    if (tokens.isEmpty) return null;
    for (final n in const [12, 8, 5, 3, 2, 1]) {
      if (tokens.length < n) continue;
      final range = _tokenRange(markdown, tokens.sublist(tokens.length - n));
      if (range != null) return range;
    }
    return null;
  }

  /// Replaces the selected passage with [replacement].
  static String? replace(
    String markdown,
    String selectedPlain,
    String replacement,
  ) {
    final range = locate(markdown, selectedPlain);
    if (range == null) return null;
    return markdown.replaceRange(range.start, range.end, replacement.trim());
  }

  /// Inserts [insertion] as a new block right after the paragraph that
  /// contains the end of the selection.
  static String? insertBelow(
    String markdown,
    String selectedPlain,
    String insertion,
  ) {
    final range = locateForInsert(markdown, selectedPlain);
    if (range == null) return null;
    final blockEnd = markdown.indexOf(RegExp(r'\n[ \t]*\n'), range.end);
    final block = '\n\n${insertion.trim()}\n';
    if (blockEnd < 0) return '${markdown.trimRight()}$block';
    return markdown.replaceRange(blockEnd, blockEnd, block);
  }

  /// Appends [insertion] as a new block at the end.
  static String append(String markdown, String insertion) {
    final body = markdown.trimRight();
    return body.isEmpty ? insertion.trim() : '$body\n\n${insertion.trim()}\n';
  }

  static String _cleanSelection(String selectedPlain) {
    return selectedPlain
        .replaceAll(_zw, '')
        .replaceAll('\u00a0', ' ')
        .replaceAll(_bulletLine, '')
        .trim();
  }

  static List<String> _tokens(String selected) {
    return selected.split(_ws).where((t) => t.isNotEmpty).toList();
  }

  static ({int start, int end})? _tokenRange(
    String markdown,
    List<String> tokens, {
    bool caseInsensitive = false,
  }) {
    if (tokens.isEmpty) return null;
    final pattern = tokens
        .map((t) => t.split('').map(RegExp.escape).join(_inline))
        .join(_gap);
    final match = RegExp(
      pattern,
      multiLine: true,
      caseSensitive: !caseInsensitive,
    ).firstMatch(markdown);
    if (match == null) return null;
    return (start: match.start, end: match.end);
  }
}
