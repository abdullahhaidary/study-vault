import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Focused Study Vault formatting toolbar for [QuillController].
///
/// Uses Quill's built-in horizontal arrow scroller (`multiRowsDisplay: false`).
/// Do not wrap in another [SingleChildScrollView] — that gives unbounded width
/// and breaks [QuillToolbarArrowIndicatedButtonList] on mobile.
class StudyNoteToolbar extends StatelessWidget {
  const StudyNoteToolbar({super.key, required this.controller});

  final QuillController controller;

  static const QuillSimpleToolbarConfig config = QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showDividers: true,
    // Text style
    showHeaderStyle: true,
    headerStyleType: HeaderStyleType.original,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: true,
    showInlineCode: true,
    // Structure
    showListBullets: true,
    showListNumbers: true,
    showQuote: true,
    showCodeBlock: true,
    // History / cleanup
    showUndo: true,
    showRedo: true,
    showClearFormat: true,
    // Hidden — keep the bar compact for studying
    showFontFamily: false,
    showFontSize: false,
    showColorButton: false,
    showBackgroundColorButton: false,
    showAlignmentButtons: false,
    showListCheck: false,
    showIndent: false,
    showLink: false,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
    showDirection: false,
    showLineHeightButton: false,
    showSmallButton: false,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: QuillSimpleToolbar(controller: controller, config: config),
      ),
    );
  }
}
