import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../ai_assistant/services/markdown_to_quill.dart';
import '../domain/selection_ai_host.dart';

/// Applies AI markdown into a live [QuillController] (keeps undo history).
///
/// Content is inserted as plain text, matching [applyPreviewToQuill]; the
/// read-mode viewer re-parses markdown-looking text for formatting.
abstract final class QuillSelectionApply {
  static String _plain(String markdown) =>
      MarkdownToQuill.toDocument(markdown).toPlainText().trimRight();

  /// Replaces the current selection. Returns `false` when nothing is selected.
  static bool replace(QuillController controller, String markdown) {
    final sel = controller.selection;
    if (sel.isCollapsed) return false;
    final text = _plain(markdown);
    controller.replaceText(
      sel.start,
      sel.end - sel.start,
      text,
      TextSelection.collapsed(offset: sel.start + text.length),
    );
    return true;
  }

  /// Inserts after the paragraph containing the end of the selection.
  static bool insertBelow(QuillController controller, String markdown) {
    final plainDoc = controller.document.toPlainText();
    final sel = controller.selection;
    var index = plainDoc.indexOf('\n', sel.end.clamp(0, plainDoc.length));
    if (index < 0) index = plainDoc.length - 1;
    final text = '\n${_plain(markdown)}';
    controller.replaceText(
      index,
      0,
      text,
      TextSelection.collapsed(offset: index + text.length),
    );
    return true;
  }

  /// Appends at the end of the document.
  static bool append(QuillController controller, String markdown) {
    final end = controller.document.length;
    final text = '\n${_plain(markdown)}';
    controller.replaceText(
      end - 1,
      0,
      text,
      TextSelection.collapsed(offset: end - 1 + text.length),
    );
    return true;
  }

  /// Builds a [SelectionAiHost] for an editable Quill document.
  static SelectionAiHost host(
    QuillController controller, {
    required String title,
    String? lessonId,
    String? materialId,
    bool readOnly = false,
  }) {
    return SelectionAiHost(
      title: title,
      lessonId: lessonId,
      materialId: materialId,
      documentText: controller.document.toPlainText(),
      onReplaceSelection: readOnly
          ? null
          : (_, md) async => replace(controller, md),
      onInsertBelow: readOnly
          ? null
          : (_, md) async => insertBelow(controller, md),
      onAppendToEnd: readOnly ? null : (_, md) async => append(controller, md),
    );
  }
}
