import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/auto_direction_text_field.dart';
import '../../../../core/widgets/system_bottom_inset.dart';
import '../../../ai_assistant/presentation/widgets/voice_input_button.dart';
import '../../domain/ai_chat_models.dart';

/// Multiline chat input with attach chips, @ mentions, voice, and send.
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
    this.compact = false,
    this.hintText = 'Ask anything...',
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
  final bool compact;
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
    final before = text.substring(
      0,
      selection.baseOffset.clamp(0, text.length),
    );
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
    final before = text.substring(
      0,
      selection.baseOffset.clamp(0, text.length),
    );
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
    final compact = widget.compact;

    return Material(
      color: Colors.transparent,
      child: SystemBottomSafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? AppSpacing.xxs : AppSpacing.xs,
            compact ? AppSpacing.xxs : AppSpacing.xs,
            compact ? AppSpacing.xxs : AppSpacing.xs,
            compact ? 0 : AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(compact ? 20 : 28),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(
                              alpha: 0.08,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 2 : 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Attach Study Vault content',
                              visualDensity: compact
                                  ? VisualDensity.compact
                                  : null,
                              constraints: compact
                                  ? const BoxConstraints.tightFor(
                                      width: 36,
                                      height: 36,
                                    )
                                  : null,
                              padding: compact ? EdgeInsets.zero : null,
                              onPressed: widget.enabled && !widget.sending
                                  ? widget.onAttach
                                  : null,
                              icon: const Icon(Icons.add_rounded),
                            ),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: compact ? 96 : 140,
                                ),
                                child: AutoDirectionTextField(
                                  controller: widget.controller,
                                  enabled: widget.enabled && !widget.sending,
                                  minLines: 1,
                                  maxLines: compact ? 4 : 6,
                                  textInputAction: TextInputAction.newline,
                                  keyboardType: TextInputType.multiline,
                                  decoration: InputDecoration(
                                    hintText: widget.hintText,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: compact
                                          ? AppSpacing.xxs
                                          : AppSpacing.xs,
                                      vertical: compact
                                          ? AppSpacing.xs
                                          : AppSpacing.sm,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                            if (!canSend && !widget.sending)
                              VoiceInputButton(
                                controller: widget.controller,
                                enabled: widget.enabled,
                                compact: true,
                              ),
                            IconButton.filled(
                              tooltip: 'Send',
                              visualDensity: compact
                                  ? VisualDensity.compact
                                  : null,
                              constraints: compact
                                  ? const BoxConstraints.tightFor(
                                      width: 36,
                                      height: 36,
                                    )
                                  : null,
                              padding: compact ? EdgeInsets.zero : null,
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.onSurface,
                                foregroundColor: theme.colorScheme.surface,
                                disabledBackgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                disabledForegroundColor:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: canSend ? widget.onSend : null,
                              icon: widget.sending
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.surface,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_upward_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (!compact)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    'Study AI can make mistakes. Check important information.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
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
