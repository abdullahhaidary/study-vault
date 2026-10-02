import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/auto_direction_text_field.dart';
import '../../../../core/widgets/system_bottom_inset.dart';
import '../../domain/ai_chat_models.dart';

/// Multiline chat input with attach chips, @ mentions, and send.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onMentionQuery,
    this.attachments = const [],
    this.onRemoveAttachment,
    this.enabled = true,
    this.sending = false,
    this.hintText = 'Ask anything about your studies…',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;

  /// Called when the user types `@query` — [query] is text after `@`.
  /// Null [query] means the mention trigger closed.
  final ValueChanged<String?>? onMentionQuery;

  final List<AiContextItem> attachments;
  final ValueChanged<AiContextItem>? onRemoveAttachment;
  final bool enabled;
  final bool sending;
  final String hintText;

  @override
  State<ChatComposer> createState() => ChatComposerState();
}

class ChatComposerState extends State<ChatComposer> {
  static final _mentionRegex = RegExp(r'@([^\s@]*)$');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final callback = widget.onMentionQuery;
    if (callback == null) return;
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      callback(null);
      return;
    }
    final before = text.substring(0, selection.baseOffset.clamp(0, text.length));
    final match = _mentionRegex.firstMatch(before);
    if (match == null) {
      callback(null);
      return;
    }
    callback(match.group(1) ?? '');
  }

  /// Removes the trailing `@query` token from the composer.
  void clearActiveMentionToken() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid) return;
    final before = text.substring(0, selection.baseOffset.clamp(0, text.length));
    final match = _mentionRegex.firstMatch(before);
    if (match == null) return;
    final start = match.start;
    final newText =
        text.substring(0, start) + text.substring(selection.baseOffset);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start),
    );
    widget.onMentionQuery?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: SystemBottomSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    right: AppSpacing.xs,
                    bottom: AppSpacing.xs,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final item in widget.attachments)
                        InputChip(
                          label: Text(item.chipLabel),
                          avatar: Icon(
                            _iconFor(item.kind),
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          onDeleted: widget.enabled && !widget.sending
                              ? () => widget.onRemoveAttachment?.call(item)
                              : null,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final canSend =
                      widget.enabled &&
                      !widget.sending &&
                      (widget.controller.text.trim().isNotEmpty ||
                          widget.attachments.isNotEmpty);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Attach Study Vault content',
                        onPressed: widget.enabled && !widget.sending
                            ? widget.onAttach
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: AutoDirectionTextField(
                            controller: widget.controller,
                            enabled: widget.enabled && !widget.sending,
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText: widget.hintText,
                              filled: true,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: canSend ? widget.onSend : null,
                        icon: widget.sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AiContextKind kind) => switch (kind) {
    AiContextKind.lesson => Icons.article_outlined,
    AiContextKind.material => Icons.picture_as_pdf_outlined,
    AiContextKind.note => Icons.sticky_note_2_outlined,
    AiContextKind.studyPin => Icons.push_pin_outlined,
  };
}
