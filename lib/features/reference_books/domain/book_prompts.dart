import 'dart:convert';

import '../data/book_repository.dart';
import 'book_text_index.dart';

/// Prompts for reading a reference book with AI.
abstract final class BookPrompts {
  static String system(String bookTitle) =>
      '''
You are a study companion for the reference book "$bookTitle".
- Use only the book pages supplied in this conversation. Never invent facts.
- Keep the book's terminology, notation and formulas exactly.
- Cite the pages you use as [p. N] or [p. N–M] right after the claim.
- If the supplied pages do not answer something, say so plainly and suggest
  what to search for instead.
- Answer in clear Markdown. Use LaTeX (\$...\$) for mathematics.''';

  static String pagesDocument(
    List<BookPage> pages, {
    String Function(int page)? chapterOf,
    int maxCharsPerPage = 6000,
  }) {
    final buffer = StringBuffer();
    for (final page in pages) {
      final chapter = chapterOf?.call(page.page);
      buffer.writeln(
        '--- Page ${page.page}${chapter == null ? '' : ' ($chapter)'} ---',
      );
      final text = page.text.trim();
      buffer.writeln(
        text.isEmpty
            ? '(no extractable text)'
            : text.length > maxCharsPerPage
            ? '${text.substring(0, maxCharsPerPage)}…'
            : text,
      );
    }
    return buffer.toString();
  }

  static String keywordsRequest(String question) => '''
List 5–12 search keywords or short phrases (comma-separated, nothing else)
that would find the pages of a textbook answering this question. Include
technical terms and common synonyms.

Question: $question''';

  static String askRequest(String question) => '''
Answer the question using only the SOURCE PAGES above. Cite pages as [p. N].
Start with a direct answer, then explain. If the pages only partly cover it,
say what is missing.

QUESTION: $question''';

  static String chapterRequest(BookAiKind kind, String chapterTitle) =>
      switch (kind) {
        BookAiKind.brief =>
          '''
Write a PRE-READING BRIEF for "$chapterTitle" so the student reads faster and
with purpose. About 350–600 words:
### What this chapter answers
2–4 questions the chapter answers.
### Map of the chapter
Each section in order with its page range [p. N–M] and one line on its point.
### Key terms to watch for
Bullets: term — one-line meaning.
### Read closely vs. skim
Which parts carry the core ideas (read closely) and which are examples,
history or detail you can skim, with page ranges.
### Keep in mind while reading
3 short questions to answer for yourself.''',
        BookAiKind.summary =>
          '''
Write a thorough POST-READING SUMMARY of "$chapterTitle" for revision.
Follow the chapter's own structure with headings, cite pages [p. N], and
include every definition, formula (with symbol meanings), classification,
process and key example the chapter relies on. End with "### Key takeaways"
(5–8 bullets) and "### Common confusions" (3–5 bullets). Be complete but
avoid filler.''',
        BookAiKind.explanation =>
          '''
Explain these pages from first principles for a student reading them now:
intuition first, then the exact terms; WHY before HOW; formulas symbol by
symbol with a small worked example where useful; common mistakes. Cite
pages [p. N]. Do not go beyond what the pages cover.''',
      };

  static String lectureMapRequest({
    required String lectureTitle,
    required int pageCount,
  }) =>
      '''
Find where the book covers the lecture "$lectureTitle".
Use the LECTURE content, the BOOK CONTENTS and the MATCHING PAGES above.
Return ONE JSON object only, no prose, no code fence:
{"ranges":[{"start":12,"end":30,"priority":"must","reason":"<short>"}]}
- 1–6 ranges, each a contiguous page range within 1–$pageCount.
- priority: "must" = the lecture's core topics explained; "skim" = related
  background or worked examples; "optional" = extra depth.
- Prefer tight ranges (whole sections) over entire chapters unless the whole
  chapter is the lecture's topic.
- If the book does not cover the lecture, return {"ranges":[]}.''';

  /// Self-contained request for an external AI; the answer is pasted back.
  static String external(
    BookAiKind kind, {
    required String bookTitle,
    required String chapterTitle,
    required List<BookPage> pages,
  }) =>
      '''
${system(bookTitle)}

Below are the pages of "$chapterTitle". Reply with Markdown only.

${chapterRequest(kind, chapterTitle)}

${pagesDocument(pages)}''';

  /// Page references like [p. 12], [p 12–14], [pp. 12-14].
  static final citation = RegExp(
    r'\[(?:pp?\.?)\s*(\d{1,5})(?:\s*[–-]\s*(\d{1,5}))?\]',
    caseSensitive: false,
  );

  static List<int> citedPages(String text) => {
    for (final m in citation.allMatches(text)) int.parse(m.group(1)!),
  }.toList()..sort();

  /// Parses the lecture-map JSON, keeping only valid ranges.
  static List<({int start, int end, String priority, String? reason})>
  parseRanges(String response, int pageCount) {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('The AI did not return page ranges.');
    }
    final Object? decoded;
    try {
      decoded = _decode(response.substring(start, end + 1));
    } on FormatException {
      throw const FormatException('The AI returned invalid page ranges.');
    }
    final ranges = decoded is Map ? decoded['ranges'] : null;
    if (ranges is! List) {
      throw const FormatException('The AI returned invalid page ranges.');
    }
    final result = <({int start, int end, String priority, String? reason})>[];
    for (final r in ranges.take(6)) {
      if (r is! Map) continue;
      final s = (r['start'] as num?)?.toInt();
      final e = (r['end'] as num?)?.toInt() ?? s;
      if (s == null || e == null || s < 1 || e < s || s > pageCount) continue;
      result.add((
        start: s,
        end: e > pageCount ? pageCount : e,
        priority: '${r['priority'] ?? 'skim'}',
        reason: r['reason'] is String ? r['reason'] as String : null,
      ));
    }
    return result;
  }

  static Object? _decode(String json) => jsonDecode(json);
}
