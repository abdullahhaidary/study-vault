import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

/// Unicode-aware text direction helpers for mixed LTR/RTL study content.
///
/// Does **not** force the whole app into RTL — only resolves direction for
/// a specific piece of user content (notes, titles, selected PDF text, …).
abstract final class TextDirectionUtils {
  /// Resolves paragraph/content direction from the first strong character.
  ///
  /// - First strong RTL (Arabic/Persian/Hebrew, …) → [TextDirection.rtl]
  /// - First strong LTR (Latin, …) → [TextDirection.ltr]
  /// - Only numbers/punctuation/neutral → [fallback] (app default LTR)
  static TextDirection resolve(
    String? text, {
    TextDirection fallback = TextDirection.ltr,
  }) {
    final value = text?.trim();
    if (value == null || value.isEmpty) return fallback;

    if (intl.Bidi.startsWithRtl(value)) return TextDirection.rtl;
    if (intl.Bidi.startsWithLtr(value)) return TextDirection.ltr;
    return fallback;
  }

  /// True when [text] should be laid out as an RTL paragraph.
  static bool isRtl(String? text) => resolve(text) == TextDirection.rtl;

  /// Text alignment that matches resolved direction (`start` semantics).
  static TextAlign alignFor(String? text) {
    return isRtl(text) ? TextAlign.right : TextAlign.left;
  }
}
