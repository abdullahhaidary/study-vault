import '../domain/ai_models.dart';

/// Extracts a controlled window of page text around a selection.
abstract final class SurroundingTextExtractor {
  /// Returns surrounding context with the selection clearly marked, or null
  /// when [pageText] / [selectedText] is empty or no useful window exists.
  static String? extract({
    required String pageText,
    required String selectedText,
    int maxCharsBefore = 600,
    int maxCharsAfter = 600,
    int maxTotal = kAiSurroundingContextLimit,
  }) {
    final page = _normalize(pageText);
    final selected = _normalize(selectedText);
    if (page.isEmpty || selected.isEmpty) return null;

    var index = page.indexOf(selected);
    if (index < 0) {
      index = page.toLowerCase().indexOf(selected.toLowerCase());
    }
    if (index < 0) {
      // Selection not found — give a short page lead-in only.
      final lead = page.length <= maxTotal
          ? page
          : '${page.substring(0, maxTotal)}…';
      return 'PAGE EXCERPT (selection not located exactly):\n$lead';
    }

    final end = index + selected.length;
    var beforeStart = (index - maxCharsBefore).clamp(0, page.length);
    var afterEnd = (end + maxCharsAfter).clamp(0, page.length);

    beforeStart = _snapBackward(page, beforeStart, index);
    afterEnd = _snapForward(page, afterEnd, end);

    var before = page.substring(beforeStart, index).trim();
    var after = page.substring(end, afterEnd).trim();

    // Keep total under budget while preferring equal trim of sides.
    final budget = maxTotal - selected.length - 80;
    if (budget > 0 && before.length + after.length > budget) {
      final half = budget ~/ 2;
      if (before.length > half) {
        before = '…${before.substring(before.length - half)}';
      }
      if (after.length > half) {
        after = '${after.substring(0, half)}…';
      }
    }

    final buffer = StringBuffer();
    if (before.isNotEmpty) {
      buffer.writeln('BEFORE:');
      buffer.writeln(before);
      buffer.writeln();
    }
    buffer.writeln('>>> SELECTED <<<');
    buffer.writeln(selected);
    if (after.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('AFTER:');
      buffer.writeln(after);
    }
    return buffer.toString().trim();
  }

  static String _normalize(String input) {
    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static int _snapBackward(String text, int start, int limit) {
    if (start <= 0) return 0;
    final paragraph = text.lastIndexOf('\n\n', limit - 1);
    if (paragraph >= start && paragraph < limit) return paragraph + 2;
    final sentence = text.lastIndexOf(RegExp(r'[.!?]\s'), limit - 1);
    if (sentence >= start && sentence < limit) {
      return (sentence + 2).clamp(start, limit);
    }
    return start;
  }

  static int _snapForward(String text, int end, int from) {
    if (end >= text.length) return text.length;
    final paragraph = text.indexOf('\n\n', from);
    if (paragraph >= from && paragraph <= end) return paragraph;
    final match = RegExp(r'[.!?]\s').firstMatch(text.substring(from, end));
    if (match != null) {
      return from + match.end;
    }
    return end;
  }
}
