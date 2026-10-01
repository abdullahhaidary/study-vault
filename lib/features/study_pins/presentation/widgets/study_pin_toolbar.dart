import 'package:flutter/material.dart';

import '../../domain/pin_display_mode.dart';

/// Compact Study Pin controls for PDF / image viewers.
class StudyPinToolbar extends StatelessWidget {
  const StudyPinToolbar({
    super.key,
    required this.addPinMode,
    required this.displayMode,
    required this.onAddPinModeChanged,
    required this.onDisplayModeChanged,
  });

  final bool addPinMode;
  final PinDisplayMode displayMode;
  final ValueChanged<bool> onAddPinModeChanged;
  final ValueChanged<PinDisplayMode> onDisplayModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              selected: addPinMode,
              label: Text(addPinMode ? 'Annotate: ON' : 'Annotate: OFF'),
              avatar: Icon(
                addPinMode ? Icons.edit_note : Icons.menu_book_outlined,
                size: 18,
              ),
              onSelected: onAddPinModeChanged,
            ),
            Text(
              'Show:',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SegmentedButton<PinDisplayMode>(
              segments: const [
                ButtonSegment(
                  value: PinDisplayMode.hidden,
                  label: Text('Hidden'),
                  icon: Icon(Icons.visibility_off_outlined, size: 16),
                ),
                ButtonSegment(
                  value: PinDisplayMode.dotsOnly,
                  label: Text('Dots'),
                  icon: Icon(Icons.circle, size: 12),
                ),
                ButtonSegment(
                  value: PinDisplayMode.dotsAndText,
                  label: Text('Dots + Text'),
                  icon: Icon(Icons.short_text, size: 16),
                ),
              ],
              selected: {displayMode},
              onSelectionChanged: (values) {
                if (values.isNotEmpty) {
                  onDisplayModeChanged(values.first);
                }
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
