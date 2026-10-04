import 'package:flutter/material.dart';

/// Compact pill shown above any selected text: Copy · AI · Translate · Note ·
/// Flashcard (· Pin). Positioned by Flutter's [TextSelectionToolbar] so it
/// flips below the selection when there is no room above.
class SelectionAiToolbar extends StatelessWidget {
  const SelectionAiToolbar({
    super.key,
    required this.anchors,
    required this.onCopy,
    required this.onAi,
    this.onTranslate,
    this.onNote,
    this.onFlashcard,
    this.onPin,
  });

  final TextSelectionToolbarAnchors anchors;
  final VoidCallback onCopy;
  final VoidCallback onAi;
  final VoidCallback? onTranslate;
  final VoidCallback? onNote;
  final VoidCallback? onFlashcard;
  final VoidCallback? onPin;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      toolbarBuilder: (context, child) => Material(
        elevation: 6,
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(height / 2),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
      children: [
        _ToolbarIcon(
          tooltip: 'Copy',
          icon: Icons.copy_outlined,
          onPressed: onCopy,
        ),
        _AiButton(onPressed: onAi),
        if (onTranslate != null)
          _ToolbarIcon(
            tooltip: 'Translate',
            icon: Icons.translate,
            onPressed: onTranslate!,
          ),
        if (onNote != null)
          _ToolbarIcon(
            tooltip: 'Save as note',
            icon: Icons.note_add_outlined,
            onPressed: onNote!,
          ),
        if (onFlashcard != null)
          _ToolbarIcon(
            tooltip: 'Make flashcard',
            icon: Icons.style_outlined,
            onPressed: onFlashcard!,
          ),
        if (onPin != null)
          _ToolbarIcon(
            tooltip: 'Add study pin',
            icon: Icons.push_pin_outlined,
            onPressed: onPin!,
          ),
      ],
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SelectionAiToolbar.height,
      width: SelectionAiToolbar.height,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _AiButton extends StatelessWidget {
  const _AiButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: SelectionAiToolbar.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('AI'),
        ),
      ),
    );
  }
}
