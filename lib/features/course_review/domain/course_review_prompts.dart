import 'course_review_models.dart';

/// Prompts for the condensed, already-studied Course Review depth.
abstract final class CourseReviewPrompts {
  static const defaultExampleCount = 10;
  static const minExampleCount = 3;
  static const maxExampleCount = 25;

  static const system = '''
You write a condensed COURSE REVIEW for a student who has ALREADY studied every
lecture in depth. It is used for fast end-of-course revision, not first-time
learning.

Source accuracy:
- Use only the supplied source. Never invent facts, numbers, or claims.
- Keep technical terms, formulas, notation, and definitions exactly as the source.
- If the source is unclear or incomplete, say so briefly instead of guessing.

Depth:
- Remind, do not re-teach. No long analogies, stories, or first-principles builds.
- Prefer tight bullet points, short paragraphs, and small tables.
- Every sentence must earn its place: cut filler and repetition.

Format:
- Markdown. Start headings at level 3 (`###`); the app adds lecture headings.
- Use LaTeX (`\$...\$`) for formulas when the source uses mathematics.''';

  static String sectionRequest({
    required String lessonName,
    required String pdfTitle,
  }) =>
      '''
Write the Course Review section for lecture "$pdfTitle" (lesson "$lessonName").

Return exactly three parts. Start each with its marker alone on its own line,
and write nothing before the first marker:

${_marker(CourseReviewPart.summary)}
Key points, definitions, formulas, classifications, and exam-relevant facts as
bullets. No examples. At most about 250 words.

${_marker(CourseReviewPart.explanation)}
Short reminders of how the ideas connect and why they matter — about one third
of a full lesson explanation. At most about 400 words.

${_marker(CourseReviewPart.deepExplanation)}
Compact core reasoning: key mechanisms, derivations or processes in brief,
formulas with each symbol's meaning, and 3–5 common mistakes. No long
analogies or worked examples. At most about 450 words.''';

  static String overviewRequest({
    required String subjectName,
    required int exampleCount,
  }) =>
      '''
These are the condensed review sections of every lecture in "$subjectName".

Return exactly two parts. Start each with its marker alone on its own line,
and write nothing before the first marker:

${_marker(CourseReviewPart.bigPicture)}
150–300 words: how the lectures fit together, the main themes, and the order
in which ideas build on each other.

${_marker(CourseReviewPart.examples)}
${examplesRule(exampleCount)}''';

  static String examplesRule(int count) =>
      '''
Exactly $count short real-world or worked examples for the WHOLE course, not per
lecture. Spread them across lectures, choosing the most exam-relevant ideas.
Each example: a `### Example N: <title>` heading, a line `*Lecture: <name>*`,
then 2–5 lines with the scenario and the key takeaway. No long derivations —
the student has already studied the full examples.''';

  static String _marker(CourseReviewPart part) => '<<<${part.marker}>>>';

  /// Splits a marked AI response into its parts. Throws if any is missing.
  static Map<CourseReviewPart, String> parse(
    String response,
    List<CourseReviewPart> expected,
  ) {
    final marker = RegExp(r'^[ \t]*<<<([A-Z_]+)>>>[ \t]*$', multiLine: true);
    final matches = marker.allMatches(response).toList();
    final result = <CourseReviewPart, String>{};
    for (var i = 0; i < matches.length; i++) {
      final name = matches[i].group(1);
      final part = expected.where((p) => p.marker == name).firstOrNull;
      if (part == null) continue;
      final end = i + 1 < matches.length
          ? matches[i + 1].start
          : response.length;
      final text = response.substring(matches[i].end, end).trim();
      if (text.isNotEmpty) result[part] = text;
    }
    final missing = expected.where((p) => !result.containsKey(p)).toList();
    if (missing.isNotEmpty) {
      throw FormatException(
        'The AI response is missing: '
        '${missing.map((p) => p.label).join(', ')}. Nothing was saved.',
      );
    }
    return result;
  }

  /// Compact text of the current sections, used as overview input.
  static String sectionsDocument(
    CourseReviewState state, {
    bool summariesOnly = false,
  }) {
    final buffer = StringBuffer('COURSE: ${state.subject.name}\n');
    for (final source in state.withSections) {
      buffer.writeln('\n## ${source.label}');
      for (final part in [
        CourseReviewPart.summary,
        if (!summariesOnly) CourseReviewPart.explanation,
      ]) {
        final entry = source.latest[part];
        if (entry != null) buffer.writeln('\n${entry.content}');
      }
    }
    return buffer.toString();
  }

  /// Lecture list with exact names, so external JSON matches on import.
  static String lectureList(CourseReviewState state) => [
    for (final s in state.included)
      '- lesson: "${s.lesson.name}", pdf: "${s.material.title}"'
          '${s.hasSection ? ' (already added)' : ''}',
  ].join('\n');

  /// Self-contained request for Gemini / ChatGPT / Cursor to refresh the
  /// subject-wide parts as importable JSON.
  static String externalOverviewRequest(
    CourseReviewState state, {
    required int exampleCount,
  }) {
    final subject = state.subject.name;
    return '''
$system

Below are the condensed review sections of every lecture in "$subject".
Using ONLY them, return ONE JSON object and nothing else (no code fence):

{
  "format": "study-vault-manual-entry",
  "version": 1,
  "target": { "subject": ${_json(subject)} },
  "course_review": {
    "big_picture": "<markdown>",
    "examples": "<markdown>"
  }
}

big_picture: 150–300 words on how the lectures fit together.
examples: ${examplesRule(exampleCount)}
Escape quotes and newlines inside JSON strings correctly.

${sectionsDocument(state)}''';
  }

  static String _json(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}
