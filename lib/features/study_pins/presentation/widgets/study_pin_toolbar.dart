import 'package:flutter/material.dart';

import '../../domain/pin_display_mode.dart';

/// Compact, collapsible Study Pin controls for PDF / image viewers.
///
/// Collapsed (default): a slim icon row (Annotate toggle + display menu).
/// Expanded: labeled controls for Annotate and pin visibility.
class StudyPinToolbar extends StatefulWidget {
  const StudyPinToolbar({
    super.key,
    required this.addPinMode,
    required this.displayMode,
    required this.onAddPinModeChanged,
    required this.onDisplayModeChanged,
    this.initiallyExpanded = false,
  });

  final bool addPinMode;
  final PinDisplayMode displayMode;
  final ValueChanged<bool> onAddPinModeChanged;
  final ValueChanged<PinDisplayMode> onDisplayModeChanged;
  final bool initiallyExpanded;

  @override
  State<StudyPinToolbar> createState() => _StudyPinToolbarState();
}

class _StudyPinToolbarState extends State<StudyPinToolbar> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  IconData get _displayIcon => switch (widget.displayMode) {
    PinDisplayMode.hidden => Icons.visibility_off_outlined,
    PinDisplayMode.dotsOnly => Icons.fiber_manual_record,
    PinDisplayMode.dotsAndText => Icons.short_text,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded ? _buildExpanded(theme) : _buildCollapsed(theme),
        ),
      ),
    );
  }

  Widget _buildCollapsed(ThemeData theme) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: widget.addPinMode ? 'Annotate: ON' : 'Annotate: OFF',
              isSelected: widget.addPinMode,
              onPressed: () => widget.onAddPinModeChanged(!widget.addPinMode),
              icon: Icon(
                widget.addPinMode ? Icons.edit_note : Icons.menu_book_outlined,
              ),
            ),
            Flexible(
              child: Text(
                widget.addPinMode ? 'Annotate' : 'Reading',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: widget.addPinMode
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: widget.addPinMode
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            MenuAnchor(
              builder: (context, controller, child) {
                return IconButton(
                  tooltip: 'Pin display: ${widget.displayMode.label}',
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  icon: Icon(_displayIcon),
                );
              },
              menuChildren: [
                for (final mode in PinDisplayMode.values)
                  MenuItemButton(
                    leadingIcon: Icon(_iconFor(mode), size: 18),
                    trailingIcon: mode == widget.displayMode
                        ? const Icon(Icons.check, size: 18)
                        : null,
                    onPressed: () => widget.onDisplayModeChanged(mode),
                    child: Text(mode.label),
                  ),
              ],
            ),
            Flexible(
              child: Text(
                widget.displayMode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Expand annotation controls',
              onPressed: () => setState(() => _expanded = true),
              icon: const Icon(Icons.expand_more),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Annotations',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Collapse',
                onPressed: () => setState(() => _expanded = false),
                icon: const Icon(Icons.expand_less),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: widget.addPinMode,
                  label: Text(
                    widget.addPinMode ? 'Annotate: ON' : 'Annotate: OFF',
                  ),
                  avatar: Icon(
                    widget.addPinMode
                        ? Icons.edit_note
                        : Icons.menu_book_outlined,
                    size: 18,
                  ),
                  onSelected: widget.onAddPinModeChanged,
                ),
                const SizedBox(width: 12),
                SegmentedButton<PinDisplayMode>(
                  segments: [
                    for (final mode in PinDisplayMode.values)
                      ButtonSegment(
                        value: mode,
                        label: Text(mode.shortLabel),
                        icon: Icon(_iconFor(mode), size: 16),
                        tooltip: mode.label,
                      ),
                  ],
                  selected: {widget.displayMode},
                  onSelectionChanged: (values) {
                    if (values.isNotEmpty) {
                      widget.onDisplayModeChanged(values.first);
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
        ],
      ),
    );
  }

  IconData _iconFor(PinDisplayMode mode) => switch (mode) {
    PinDisplayMode.hidden => Icons.visibility_off_outlined,
    PinDisplayMode.dotsOnly => Icons.fiber_manual_record,
    PinDisplayMode.dotsAndText => Icons.short_text,
  };
}

extension on PinDisplayMode {
  String get shortLabel => switch (this) {
    PinDisplayMode.hidden => 'Hide',
    PinDisplayMode.dotsOnly => 'Dots',
    PinDisplayMode.dotsAndText => 'Text',
  };
}
