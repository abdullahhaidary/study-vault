/// Search-only Unicode normalization for Study Vault.
///
/// **Never** rewrite stored notes — only normalize query strings and
/// comparison expressions so Persian/Arabic letter variants match.
abstract final class SearchTextNormalizer {
  /// Arabic Yeh (ي U+064A) → Persian Yeh (ی U+06CC)
  static const arabicYeh = '\u064A';
  static const persianYeh = '\u06CC';

  /// Arabic Kaf (ك U+0643) → Persian Keheh (ک U+06A9)
  static const arabicKaf = '\u0643';
  static const persianKaf = '\u06A9';

  /// Normalize for case-insensitive + Persian/Arabic variant-insensitive search.
  ///
  /// Preserves meaning; does not transliterate Persian to Latin.
  static String normalize(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(arabicYeh, persianYeh);
    s = s.replaceAll(arabicKaf, persianKaf);
    return s;
  }

  /// SQLite expression that normalizes a column/expression the same way.
  ///
  /// Example: `sqlNormalizeExpr('p.short_text')`
  static String sqlNormalizeExpr(String columnExpr) {
    return "replace(replace(lower($columnExpr), '$arabicYeh', '$persianYeh'), "
        "'$arabicKaf', '$persianKaf')";
  }

  /// LIKE pattern for a user query (`%…%`, escaped).
  static String likePattern(String query) {
    final normalized = normalize(query.trim());
    return '%${escapeLike(normalized)}%';
  }

  static String escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
