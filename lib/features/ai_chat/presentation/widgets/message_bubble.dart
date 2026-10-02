import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/text/text_direction_utils.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/ai_chat_models.dart';

/// User / assistant message bubble with markdown + BiDi.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.status,
    this.attachments = const [],
    this.onRetry,
    this.isStreaming = false,
  });

  final String role;
  final String content;
  final String? status;
  final List<AiContextItem> attachments;
  final VoidCallback? onRetry;
  final bool isStreaming;

  bool get _isUser => role == AiChatRole.user;
  bool get _isError => status == AiChatMessageStatus.error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final direction = TextDirectionUtils.resolve(content);
    final bg = _isUser
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : theme.colorScheme.surface;
    final border = _isError
        ? theme.colorScheme.error.withValues(alpha: 0.45)
        : theme.colorScheme.outlineVariant;

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        child: Card(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdAll,
            side: BorderSide(color: border),
          ),
          child: InkWell(
            onLongPress: content.trim().isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: content));
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Copied')));
                    }
                  },
            borderRadius: AppRadii.mdAll,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (attachments.isNotEmpty) ...[
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final item in attachments)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            avatar: Icon(
                              _iconFor(item.kind),
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              item.chipLabel,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Directionality(
                    textDirection: direction,
                    child: _isUser
                        ? SelectableText(
                            content,
                            style: theme.textTheme.bodyMedium,
                            textDirection: direction,
                          )
                        : MarkdownBody(
                            data: content.isEmpty && isStreaming
                                ? '…'
                                : content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                .copyWith(
                                  p: theme.textTheme.bodyMedium,
                                  code: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    backgroundColor:
                                        theme.colorScheme.surfaceContainerHigh,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: AppRadii.smAll,
                                  ),
                                ),
                            onTapLink: (_, _, _) {},
                          ),
                  ),
                  if (_isError && onRetry != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
