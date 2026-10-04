import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/widgets/scroll_edge_arrows.dart';
import '../../domain/quill_paragraph_direction_sync.dart';
import 'divider_embed_builder.dart';
import 'study_note_toolbar.dart';

/// Reusable Study Vault rich-text editor for Full Note content.
///
/// Owns nothing about persistence — the parent supplies a [QuillController]
/// and decides when to encode/save via [StudyNoteCodec].
///
/// Supports mixed LTR/RTL paragraphs (Persian/Dari/Arabic + English) via
/// Quill direction attributes synced from Unicode first-strong detection.
class StudyRichTextEditor extends StatefulWidget {
  const StudyRichTextEditor({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.autofocus = false,
    this.placeholder = 'Write a detailed study note…',
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.showToolbar = true,
    this.expands = true,
    this.scrollable = true,
  });

  final QuillController controller;
  final bool readOnly;
  final bool autofocus;
  final String placeholder;
  final EdgeInsetsGeometry padding;
  final bool showToolbar;
  final bool expands;

  /// When false, the editor participates in an outer scroll view (e.g. reader).
  final bool scrollable;

  @override
  State<StudyRichTextEditor> createState() => _StudyRichTextEditorState();
}

class _StudyRichTextEditorState extends State<StudyRichTextEditor> {
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    widget.controller.readOnly = widget.readOnly;
    widget.controller.addListener(_onDocumentChanged);
    if (!widget.readOnly) {
      QuillParagraphDirectionSync.sync(widget.controller);
    }
    if (widget.autofocus && !widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant StudyRichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onDocumentChanged);
      widget.controller.addListener(_onDocumentChanged);
      if (!widget.readOnly) {
        QuillParagraphDirectionSync.sync(widget.controller);
      }
    }
    if (oldWidget.readOnly != widget.readOnly) {
      widget.controller.readOnly = widget.readOnly;
    }
  }

  void _onDocumentChanged() {
    if (widget.readOnly) return;
    QuillParagraphDirectionSync.sync(widget.controller);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocumentChanged);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quill = QuillEditor.basic(
      controller: widget.controller,
      focusNode: _focusNode,
      scrollController: _scrollController,
      config: QuillEditorConfig(
        placeholder: widget.placeholder,
        padding: widget.padding,
        autoFocus: false,
        expands: widget.expands,
        scrollable: widget.scrollable,
        showCursor: !widget.readOnly,
        enableInteractiveSelection: true,
        embedBuilders: const [DividerEmbedBuilder()],
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            theme.textTheme.bodyLarge!.copyWith(height: 1.5),
            HorizontalSpacing.zero,
            VerticalSpacing(0, 8),
            VerticalSpacing.zero,
            null,
          ),
          h1: DefaultTextBlockStyle(
            theme.textTheme.headlineMedium!.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            HorizontalSpacing.zero,
            VerticalSpacing(16, 8),
            VerticalSpacing.zero,
            null,
          ),
          h2: DefaultTextBlockStyle(
            theme.textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            HorizontalSpacing.zero,
            VerticalSpacing(14, 6),
            VerticalSpacing.zero,
            null,
          ),
          h3: DefaultTextBlockStyle(
            theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            HorizontalSpacing.zero,
            VerticalSpacing(12, 4),
            VerticalSpacing.zero,
            null,
          ),
          quote: DefaultTextBlockStyle(
            theme.textTheme.bodyLarge!.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            HorizontalSpacing.zero,
            VerticalSpacing(6, 6),
            VerticalSpacing.zero,
            BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.45),
                  width: 3,
                ),
              ),
            ),
          ),
          code: DefaultTextBlockStyle(
            theme.textTheme.bodyMedium!.copyWith(
              fontFamily: 'monospace',
              height: 1.4,
            ),
            HorizontalSpacing.zero,
            VerticalSpacing(8, 8),
            VerticalSpacing.zero,
            BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
    final editor = widget.scrollable ? ScrollEdgeArrows(child: quill) : quill;

    if (!widget.showToolbar || widget.readOnly) {
      return editor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudyNoteToolbar(controller: widget.controller),
        Expanded(child: editor),
      ],
    );
  }
}
