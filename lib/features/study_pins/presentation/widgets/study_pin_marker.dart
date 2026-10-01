import 'package:flutter/material.dart';

import '../../domain/pin_display_mode.dart';

/// Visual Study Pin marker (dot, optionally with short text).
class StudyPinMarker extends StatelessWidget {
  const StudyPinMarker({
    super.key,
    required this.shortText,
    required this.displayMode,
    this.selected = false,
  });

  final String shortText;
  final PinDisplayMode displayMode;
  final bool selected;

  static const double dotSize = 14;

  @override
  Widget build(BuildContext context) {
    if (displayMode == PinDisplayMode.hidden) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    final showText = displayMode == PinDisplayMode.dotsAndText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.onPrimary,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  shortText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
