/// Pure helpers to apply an AI answer into a markdown document based on the
/// *rendered* text the user selected.
///
/// Rendered text differs from source (no `**`, `` ` ``, list markers, and
/// collapsed whitespace), so matching is tolerant: whitespace is flexible and
/// inline emphasis / code markers may appear anywhere inside the match.
abstract final class MarkdownSelectionEditor {
  static final _ws = RegExp(r'\s+');
  static const _inline = r'[*_~`]*';

  /// Locates [selectedPlain] inside [markdown]. Returns `null` when the
  /// selection cannot be mapped back to the source.
  static ({int start, int end})? locate(String markdown, String selectedPlain) {
    final selected = selectedPlain.trim();
    if (selected.isEmpty || markdown.isEmpty) return null;

    final exact = markdown.indexOf(selected);
    if (exact >= 0) return (start: exact, end: exact + selected.length);

    final tokens = selected.split(_ws).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;
    final pattern = tokens
        .map((t) => t.split('').map(RegExp.escape).join(_inline))
        .join(r'[\s*_~`]+');
    final match = RegExp(pattern, multiLine: true).firstMatch(markdown);
    if (match == null) return null;
    return (start: match.start, end: match.end);
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
    final range = locate(markdown, selectedPlain);
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
}
