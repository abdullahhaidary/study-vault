/// Pure helpers for inserting speech into an existing text field without
/// duplicating partial results or wiping prior content.
abstract final class VoiceDictationMerge {
  /// Joins [before], [spoken], and [after] with sensible whitespace.
  static String join({
    required String before,
    required String spoken,
    required String after,
  }) {
    final speech = spoken.trim();
    if (speech.isEmpty) return '$before$after';

    var left = before;
    var right = after;

    if (left.isNotEmpty &&
        !_endsWithWhitespace(left) &&
        !_startsWithPunctuation(speech)) {
      left = '$left ';
    }

    final combined = '$left$speech';
    if (right.isNotEmpty &&
        !_endsWithWhitespace(combined) &&
        !_startsWithWhitespace(right) &&
        !_startsWithPunctuation(right)) {
      right = ' $right';
    }

    return '$combined$right';
  }

  /// Offset of the caret after applying [spoken] between [before] and [after].
  static int caretAfter({required String before, required String spoken}) {
    final joined = join(before: before, spoken: spoken, after: '');
    return joined.length;
  }

  static bool _endsWithWhitespace(String value) =>
      value.isNotEmpty && RegExp(r'\s$').hasMatch(value);

  static bool _startsWithWhitespace(String value) =>
      value.isNotEmpty && RegExp(r'^\s').hasMatch(value);

  static bool _startsWithPunctuation(String value) =>
      value.isNotEmpty && RegExp(r'^[.,!?;:)\]}]').hasMatch(value);
}

/// Captures the text around the cursor when dictation starts, then replaces
/// only the live speech segment as partial/final results arrive.
class VoiceDictationSession {
  VoiceDictationSession.capture({
    required String text,
    required int cursorOffset,
  }) {
    final offset = cursorOffset.clamp(0, text.length);
    before = text.substring(0, offset);
    after = text.substring(offset);
  }

  late final String before;
  late final String after;
  String spoken = '';

  String get composed =>
      VoiceDictationMerge.join(before: before, spoken: spoken, after: after);

  int get caretOffset =>
      VoiceDictationMerge.caretAfter(before: before, spoken: spoken);

  void updateSpoken(String value) {
    spoken = value;
  }
}
