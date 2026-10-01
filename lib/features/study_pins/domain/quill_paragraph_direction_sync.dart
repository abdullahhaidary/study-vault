import 'package:flutter/painting.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/text/text_direction_utils.dart';

/// Keeps Quill block `direction` attributes aligned with paragraph content.
///
/// Uses first-strong-character detection. Manual toolbar toggles may be
/// overwritten on the next edit when content direction clearly changes —
/// automatic detection is the preferred default for mixed study notes.
abstract final class QuillParagraphDirectionSync {
  static bool _busy = false;

  /// Apply RTL/LTR block direction from each paragraph's plain text.
  ///
  /// Pass [force] when preparing a read-only document for display.
  static void sync(QuillController controller, {bool force = false}) {
    if (_busy || (controller.readOnly && !force)) return;
    _busy = true;
    try {
      final plain = controller.document.toPlainText();
      final lines = plain.split('\n');
      if (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }

      var offset = 0;
      for (final line in lines) {
        final lineLen = line.length;
        final newlineIndex = offset + lineLen;
        final desired = TextDirectionUtils.resolve(line);
        final wantRtl = desired == TextDirection.rtl;

        final attrs = controller.document.collectStyle(newlineIndex, 0);
        final current = attrs.attributes[Attribute.direction.key]?.value;
        final isRtl = current == 'rtl';

        if (wantRtl && !isRtl) {
          controller.document.format(newlineIndex, 0, Attribute.rtl);
        } else if (!wantRtl && isRtl) {
          controller.document.format(
            newlineIndex,
            0,
            Attribute.clone(Attribute.direction, null),
          );
        }

        offset = newlineIndex + 1;
      }
    } finally {
      _busy = false;
    }
  }
}
