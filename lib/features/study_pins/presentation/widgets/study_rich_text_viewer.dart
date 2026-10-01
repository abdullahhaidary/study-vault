import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../domain/quill_paragraph_direction_sync.dart';
import '../../domain/study_note_codec.dart';
import 'study_rich_text_editor.dart';

/// Efficient read-only renderer for a stored Full Note value.
///
/// Instantiates a Quill controller only while this widget is mounted —
/// suitable for the Study Pin reader, not for scrolling PDF overlays.
/// Applies paragraph direction so Persian/Arabic notes display correctly.
class StudyRichTextViewer extends StatefulWidget {
  const StudyRichTextViewer({
    super.key,
    required this.storedValue,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final String storedValue;
  final EdgeInsetsGeometry padding;

  @override
  State<StudyRichTextViewer> createState() => _StudyRichTextViewerState();
}

class _StudyRichTextViewerState extends State<StudyRichTextViewer> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.storedValue);
  }

  @override
  void didUpdateWidget(covariant StudyRichTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storedValue != widget.storedValue) {
      _controller.dispose();
      _controller = _buildController(widget.storedValue);
    }
  }

  QuillController _buildController(String storedValue) {
    final controller = QuillController(
      document: StudyNoteCodec.decode(storedValue),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    QuillParagraphDirectionSync.sync(controller, force: true);
    return controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudyRichTextEditor(
      controller: _controller,
      readOnly: true,
      showToolbar: false,
      expands: false,
      scrollable: false,
      placeholder: '',
      padding: widget.padding,
    );
  }
}
