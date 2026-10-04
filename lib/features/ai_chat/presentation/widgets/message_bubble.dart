import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/markdown/chart_markdown_builder.dart';
import '../../../../core/text/text_direction_utils.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../ai_assistant/domain/ai_token_usage.dart';
import '../../../ai_assistant/presentation/widgets/ai_usage_indicator.dart';
import '../../domain/chat_appearance.dart';
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
    this.usage,
    this.highlighted = false,
    this.appearance = ChatAppearance.defaults,
    this.onEditAndResend,
    this.onRegenerate,
    this.onToggleReadAloud,
    this.isSpeaking = false,
  });

  final String role;
  final String content;
  final String? status;
  final List<AiContextItem> attachments;
  final VoidCallback? onRetry;
  final bool isStreaming;
  final AiTokenUsage? usage;
  final bool highlighted;
  final ChatAppearance appearance;
  final VoidCallback? onEditAndResend;
  final VoidCallback? onRegenerate;
  final VoidCallback? onToggleReadAloud;
  final bool isSpeaking;

  bool get _isUser => role == AiChatRole.user;
  bool get _isError => status == AiChatMessageStatus.error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final direction = TextDirectionUtils.resolve(content);
    final customColor = _isUser
        ? appearance.userColorValue
        : appearance.assistantColorValue;
    final usesDefaultAssistantStyle = !_isUser && customColor == null;
    final bg = highlighted
        ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55)
        : customColor != null
        ? Color(customColor)
        : _isUser
        ? theme.colorScheme.surfaceContainerHigh
        : Colors.transparent;
    final border = highlighted
        ? theme.colorScheme.tertiary.withValues(alpha: 0.65)
        : _isError
        ? theme.colorScheme.error.withValues(alpha: 0.45)
        : Colors.transparent;
    final foreground = usesDefaultAssistantStyle
        ? theme.colorScheme.onSurface
        : _readableForeground(bg, theme);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: foreground,
      fontSize:
          (theme.textTheme.bodyMedium?.fontSize ?? 14) * appearance.textScale,
      height: 1.45,
    );
    final fullWidth = appearance.layout == ChatMessageLayout.fullWidth;
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: bodyStyle,
      h1: _scaledHeading(theme.textTheme.headlineMedium, foreground),
      h2: _scaledHeading(theme.textTheme.headlineSmall, foreground),
      h3: _scaledHeading(theme.textTheme.titleLarge, foreground),
      h4: _scaledHeading(theme.textTheme.titleMedium, foreground),
      h5: _scaledHeading(theme.textTheme.titleSmall, foreground),
      h6: bodyStyle?.copyWith(fontWeight: FontWeight.bold),
      listBullet: bodyStyle,
      blockquote: bodyStyle,
      code: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        color: foreground,
        fontSize:
            (theme.textTheme.bodySmall?.fontSize ?? 12) * appearance.textScale,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadii.smAll,
      ),
    );

    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: fullWidth || usesDefaultAssistantStyle
            ? BorderRadius.zero
            : BorderRadius.circular(20),
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
          padding: EdgeInsets.symmetric(
            horizontal: fullWidth
                ? AppSpacing.lg
                : usesDefaultAssistantStyle
                ? AppSpacing.xxs
                : AppSpacing.md,
            vertical: usesDefaultAssistantStyle ? AppSpacing.xs : AppSpacing.sm,
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
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        avatar: Icon(
                          _iconFor(item.kind),
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          item.chipLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: foreground,
                          ),
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
                        style: bodyStyle,
                        textDirection: direction,
                      )
                    : SelectionArea(
                        child: MarkdownBody(
                          data: content.isEmpty && isStreaming ? '…' : content,
                          selectable: false,
                          styleSheet: markdownStyle,
                          builders: chartMarkdownBuilders(markdownStyle),
                          onTapLink: (_, _, _) {},
                        ),
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
              if (!_isUser &&
                  !isStreaming &&
                  !_isError &&
                  usage != null &&
                  usage!.hasAnyMetric) ...[
                const SizedBox(height: AppSpacing.xs),
                AiUsageIndicator(usage: usage!),
              ],
              if (!isStreaming && content.trim().isNotEmpty)
                _MessageActions(
                  isUser: _isUser,
                  content: content,
                  foreground: foreground,
                  onEditAndResend: onEditAndResend,
                  onRegenerate: onRegenerate,
                  onToggleReadAloud: onToggleReadAloud,
                  isSpeaking: isSpeaking,
                ),
            ],
          ),
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: card);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isUser) const Spacer(),
        Flexible(
          flex: _isUser ? 12 : 20,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.94,
            ),
            child: card,
          ),
        ),
        if (!_isUser) const Spacer(),
      ],
    );
  }

  TextStyle? _scaledHeading(TextStyle? style, Color foreground) {
    return style?.copyWith(
      color: foreground,
      fontSize: (style.fontSize ?? 18) * appearance.textScale,
    );
  }

  Color _readableForeground(Color background, ThemeData theme) {
    if (background.a < 0.45) return theme.colorScheme.onSurface;
    return background.computeLuminance() > 0.45
        ? const Color(0xff171717)
        : Colors.white;
  }

  IconData _iconFor(AiContextKind kind) => switch (kind) {
    AiContextKind.lesson => Icons.article_outlined,
    AiContextKind.material => Icons.picture_as_pdf_outlined,
    AiContextKind.note => Icons.sticky_note_2_outlined,
    AiContextKind.studyPin => Icons.push_pin_outlined,
  };
}

class _MessageActions extends StatelessWidget {
  const _MessageActions({
    required this.isUser,
    required this.content,
    required this.foreground,
    required this.onEditAndResend,
    required this.onRegenerate,
    required this.onToggleReadAloud,
    required this.isSpeaking,
  });

  final bool isUser;
  final String content;
  final Color foreground;
  final VoidCallback? onEditAndResend;
  final VoidCallback? onRegenerate;
  final VoidCallback? onToggleReadAloud;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Wrap(
        spacing: 0,
        children: [
          if (isUser && onEditAndResend != null)
            IconButton(
              tooltip: 'Edit and resend',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: foreground.withValues(alpha: 0.72),
              onPressed: onEditAndResend,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (!isUser && onToggleReadAloud != null)
            IconButton(
              tooltip: isSpeaking ? 'Stop reading' : 'Read aloud',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: foreground.withValues(alpha: 0.72),
              onPressed: onToggleReadAloud,
              icon: Icon(
                isSpeaking
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_outlined,
              ),
            ),
          if (!isUser && onRegenerate != null)
            IconButton(
              tooltip: 'Regenerate response',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: foreground.withValues(alpha: 0.72),
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: 'Copy message',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: foreground.withValues(alpha: 0.72),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied')));
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
    );
  }
}
