import 'package:flutter/material.dart';

/// Comfortable multiline editor for Study Pin full explanations.
///
/// Uses plain text for reliable Android + Linux desktop support. The API is
/// kept simple so a rich-text editor can replace this screen later.
class FullExplanationScreen extends StatefulWidget {
  const FullExplanationScreen({
    super.key,
    this.initialText = '',
    this.readOnly = false,
    this.title = 'Full Explanation',
  });

  final String initialText;
  final bool readOnly;
  final String title;

  @override
  State<FullExplanationScreen> createState() => _FullExplanationScreenState();
}

class _FullExplanationScreenState extends State<FullExplanationScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    if (!widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!widget.readOnly)
            TextButton(
              onPressed: _save,
              child: const Text('Done'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: widget.readOnly
                    ? 'No full explanation yet.'
                    : 'Write a longer explanation…\n\n'
                        'You can paste notes from ChatGPT or Gemini here later.',
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
