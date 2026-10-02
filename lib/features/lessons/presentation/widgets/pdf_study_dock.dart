import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../study_pins/domain/pin_display_mode.dart';

/// Actions available from the PDF study dock's overflow menu.
enum PdfStudyDockAction { reviewPins, hidePins, showPinDots, showPinText }

/// A movable PDF tool palette that can collapse into a small restore button.
class PdfStudyDock extends StatefulWidget {
  const PdfStudyDock({
    super.key,
    required this.bookmarked,
    required this.annotating,
    required this.pinDisplayMode,
    required this.onOpenNavigation,
    required this.onToggleBookmark,
    required this.onToggleAnnotating,
    required this.onOpenAi,
    required this.onAction,
    this.bookmarkEnabled = true,
  });

  final bool bookmarked;
  final bool bookmarkEnabled;
  final bool annotating;
  final PinDisplayMode pinDisplayMode;
  final VoidCallback onOpenNavigation;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleAnnotating;
  final VoidCallback onOpenAi;
  final ValueChanged<PdfStudyDockAction> onAction;

  @override
  State<PdfStudyDock> createState() => _PdfStudyDockState();
}

class _PdfStudyDockState extends State<PdfStudyDock> {
  static const _xKey = 'pdf_study_dock_x_v1';
  static const _yKey = 'pdf_study_dock_y_v1';
  static const _collapsedKey = 'pdf_study_dock_collapsed_v1';
  static const _edge = 8.0;
  static const _expandedHeight = 56.0;
  static const _collapsedSize = 52.0;

  double _xFraction = 0.5;
  double _yFraction = 0.92;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  Future<void> _restoreState() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _xFraction = (preferences.getDouble(_xKey) ?? 0.5).clamp(0, 1);
      _yFraction = (preferences.getDouble(_yKey) ?? 0.92).clamp(0, 1);
      _collapsed = preferences.getBool(_collapsedKey) ?? false;
    });
  }

  Future<void> _savePosition() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setDouble(_xKey, _xFraction),
      preferences.setDouble(_yKey, _yFraction),
    ]);
  }

  void _snapToNearestEdge() {
    final distances = [_xFraction, 1 - _xFraction, _yFraction, 1 - _yFraction];
    final nearest = distances.indexOf(distances.reduce(math.min));
    setState(() {
      switch (nearest) {
        case 0:
          _xFraction = 0;
        case 1:
          _xFraction = 1;
        case 2:
          _yFraction = 0;
        case 3:
          _yFraction = 1;
      }
    });
    _savePosition();
  }

  Future<void> _setCollapsed(bool value) async {
    setState(() => _collapsed = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_collapsedKey, value);
  }

  void _move({required Offset delta, required Size area, required Size dock}) {
    final xRange = math.max(1.0, area.width - dock.width - (_edge * 2));
    final yRange = math.max(1.0, area.height - dock.height - (_edge * 2));
    final left = (_edge + (_xFraction * xRange) + delta.dx).clamp(
      _edge,
      _edge + xRange,
    );
    final top = (_edge + (_yFraction * yRange) + delta.dy).clamp(
      _edge,
      _edge + yRange,
    );
    setState(() {
      _xFraction = (left - _edge) / xRange;
      _yFraction = (top - _edge) / yRange;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        final expandedWidth = math.min(320.0, constraints.maxWidth - 16);
        final dock = Size(
          _collapsed ? _collapsedSize : expandedWidth,
          _collapsed ? _collapsedSize : _expandedHeight,
        );
        final xRange = math.max(0.0, area.width - dock.width - (_edge * 2));
        final yRange = math.max(0.0, area.height - dock.height - (_edge * 2));
        final left = _edge + (_xFraction * xRange);
        final top = _edge + (_yFraction * yRange);

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: dock.width,
              height: dock.height,
              child: _collapsed
                  ? _CollapsedDockButton(
                      onTap: () => _setCollapsed(false),
                      onPanUpdate: (details) =>
                          _move(delta: details.delta, area: area, dock: dock),
                      onPanEnd: _snapToNearestEdge,
                    )
                  : _ExpandedDock(
                      bookmarked: widget.bookmarked,
                      bookmarkEnabled: widget.bookmarkEnabled,
                      annotating: widget.annotating,
                      pinDisplayMode: widget.pinDisplayMode,
                      onOpenNavigation: widget.onOpenNavigation,
                      onToggleBookmark: widget.onToggleBookmark,
                      onToggleAnnotating: widget.onToggleAnnotating,
                      onOpenAi: widget.onOpenAi,
                      onAction: widget.onAction,
                      onCollapse: () => _setCollapsed(true),
                      onPanUpdate: (details) =>
                          _move(delta: details.delta, area: area, dock: dock),
                      onPanEnd: _snapToNearestEdge,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpandedDock extends StatelessWidget {
  const _ExpandedDock({
    required this.bookmarked,
    required this.bookmarkEnabled,
    required this.annotating,
    required this.pinDisplayMode,
    required this.onOpenNavigation,
    required this.onToggleBookmark,
    required this.onToggleAnnotating,
    required this.onOpenAi,
    required this.onAction,
    required this.onCollapse,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final bool bookmarked;
  final bool bookmarkEnabled;
  final bool annotating;
  final PinDisplayMode pinDisplayMode;
  final VoidCallback onOpenNavigation;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleAnnotating;
  final VoidCallback onOpenAi;
  final ValueChanged<PdfStudyDockAction> onAction;
  final VoidCallback onCollapse;
  final GestureDragUpdateCallback onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      elevation: 5,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.28),
      shape: StadiumBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: onPanUpdate,
            onPanEnd: (_) => onPanEnd(),
            child: Tooltip(
              message: 'Drag toolbar',
              child: SizedBox(
                width: 30,
                height: double.infinity,
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: _DockButton(
              tooltip: 'Document navigation',
              icon: Icons.toc_outlined,
              onPressed: onOpenNavigation,
            ),
          ),
          Expanded(
            child: _DockButton(
              tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark page',
              icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
              selected: bookmarked,
              onPressed: bookmarkEnabled ? onToggleBookmark : null,
            ),
          ),
          Expanded(
            child: _DockButton(
              tooltip: annotating ? 'Stop annotating' : 'Annotate',
              icon: annotating ? Icons.edit_note : Icons.edit_note_outlined,
              selected: annotating,
              onPressed: onToggleAnnotating,
            ),
          ),
          Expanded(
            child: IconButton.filled(
              tooltip: 'AI tools',
              visualDensity: VisualDensity.compact,
              onPressed: onOpenAi,
              icon: const Icon(Icons.auto_awesome, size: 20),
            ),
          ),
          Expanded(
            child: PopupMenuButton<PdfStudyDockAction>(
              tooltip: 'More study tools',
              icon: const Icon(Icons.more_horiz, size: 21),
              onSelected: onAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: PdfStudyDockAction.reviewPins,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.school_outlined),
                    title: Text('Review pins'),
                  ),
                ),
                const PopupMenuDivider(),
                _pinDisplayItem(
                  action: PdfStudyDockAction.hidePins,
                  mode: PinDisplayMode.hidden,
                  current: pinDisplayMode,
                  icon: Icons.visibility_off_outlined,
                  label: 'Hide pins',
                ),
                _pinDisplayItem(
                  action: PdfStudyDockAction.showPinDots,
                  mode: PinDisplayMode.dotsOnly,
                  current: pinDisplayMode,
                  icon: Icons.fiber_manual_record,
                  label: 'Show pin dots',
                ),
                _pinDisplayItem(
                  action: PdfStudyDockAction.showPinText,
                  mode: PinDisplayMode.dotsAndText,
                  current: pinDisplayMode,
                  icon: Icons.short_text,
                  label: 'Show pin text',
                ),
              ],
            ),
          ),
          Expanded(
            child: _DockButton(
              tooltip: 'Collapse toolbar',
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: onCollapse,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<PdfStudyDockAction> _pinDisplayItem({
    required PdfStudyDockAction action,
    required PinDisplayMode mode,
    required PinDisplayMode current,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem(
      value: action,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        trailing: mode == current ? const Icon(Icons.check) : null,
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      style: selected
          ? IconButton.styleFrom(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            )
          : null,
      icon: Icon(icon, size: 21),
    );
  }
}

class _CollapsedDockButton extends StatelessWidget {
  const _CollapsedDockButton({
    required this.onTap,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final VoidCallback onTap;
  final GestureDragUpdateCallback onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onPanEnd(),
      child: Material(
        color: theme.colorScheme.primary,
        elevation: 6,
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.3),
        shape: const CircleBorder(),
        child: Icon(
          Icons.tune_rounded,
          color: theme.colorScheme.onPrimary,
          size: 23,
        ),
      ),
    );
  }
}
