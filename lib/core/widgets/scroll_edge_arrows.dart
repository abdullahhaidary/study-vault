import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// How long the arrows stay visible after the last scroll / reveal.
const kScrollEdgeArrowsHideDelay = Duration(milliseconds: 500);

/// Jump-to-start / jump-to-end arrows that fade in while the content scrolls.
///
/// Wrap the scrollable subtree with this widget. It listens to the first-level
/// [ScrollNotification]s bubbling up from [child], shows an up arrow at the
/// top-right and a down arrow at the bottom-right, and hides them again
/// [kScrollEdgeArrowsHideDelay] after scrolling stops. Arrows are only shown
/// when the content is actually scrollable.
class ScrollEdgeArrows extends StatefulWidget {
  const ScrollEdgeArrows({
    super.key,
    required this.child,
    this.topPadding = 0,
    this.bottomPadding = 0,
    this.showOnMount = true,
  });

  final Widget child;

  /// Extra inset above the up arrow (e.g. to clear a [SliverAppBar]).
  final double topPadding;

  /// Extra inset below the down arrow (e.g. to clear a FAB or dock).
  final double bottomPadding;

  /// Briefly reveal the arrows when the widget first appears.
  final bool showOnMount;

  @override
  State<ScrollEdgeArrows> createState() => _ScrollEdgeArrowsState();
}

class _ScrollEdgeArrowsState extends State<ScrollEdgeArrows> {
  ScrollPosition? _position;
  ScrollMetrics? _metrics;
  int _revealTick = 0;
  bool _seenMetrics = false;

  bool _track(BuildContext? context, ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != Axis.vertical) return false;
    final scrollable = context == null ? null : Scrollable.maybeOf(context);
    _position = scrollable?.position ?? _position;
    _metrics = metrics;
    return true;
  }

  bool _onScroll(ScrollNotification notification) {
    if (!_track(
      notification.context,
      notification.metrics,
      notification.depth,
    )) {
      return false;
    }
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification ||
        notification is OverscrollNotification) {
      setState(() => _revealTick++);
    }
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (!_track(
      notification.context,
      notification.metrics,
      notification.depth,
    )) {
      return false;
    }
    // First layout: optionally flash the arrows so the user knows they exist.
    final first = !_seenMetrics;
    _seenMetrics = true;
    setState(() {
      if (first && widget.showOnMount) _revealTick++;
    });
    return false;
  }

  Future<void> _jumpTo({required bool start}) async {
    final position = _position;
    if (position == null || !position.hasContentDimensions) return;
    await position.animateTo(
      start ? position.minScrollExtent : position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    final scrollable =
        metrics != null &&
        metrics.hasContentDimensions &&
        metrics.maxScrollExtent > metrics.minScrollExtent;
    final atStart =
        metrics != null && metrics.pixels <= metrics.minScrollExtent + 1;
    final atEnd =
        metrics != null && metrics.pixels >= metrics.maxScrollExtent - 1;

    return EdgeArrowsOverlay(
      revealKey: _revealTick == 0 ? null : _revealTick,
      canGoStart: scrollable && !atStart,
      canGoEnd: scrollable && !atEnd,
      onGoStart: () => _jumpTo(start: true),
      onGoEnd: () => _jumpTo(start: false),
      topPadding: widget.topPadding,
      bottomPadding: widget.bottomPadding,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Low-level arrow overlay for content that is not a Flutter [Scrollable]
/// (e.g. the PDF viewer). Each time [revealKey] changes the arrows are shown
/// and a hide timer restarts.
class EdgeArrowsOverlay extends StatefulWidget {
  const EdgeArrowsOverlay({
    super.key,
    required this.child,
    required this.revealKey,
    required this.canGoStart,
    required this.canGoEnd,
    required this.onGoStart,
    required this.onGoEnd,
    this.topPadding = 0,
    this.bottomPadding = 0,
    this.startTooltip = 'Go to start',
    this.endTooltip = 'Go to end',
  });

  final Widget child;

  /// Any value; whenever it changes (and is non-null) the arrows are revealed.
  final Object? revealKey;
  final bool canGoStart;
  final bool canGoEnd;
  final VoidCallback onGoStart;
  final VoidCallback onGoEnd;
  final double topPadding;
  final double bottomPadding;
  final String startTooltip;
  final String endTooltip;

  @override
  State<EdgeArrowsOverlay> createState() => _EdgeArrowsOverlayState();
}

class _EdgeArrowsOverlayState extends State<EdgeArrowsOverlay> {
  Timer? _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.revealKey != null) {
      _visible = true;
      _hideTimer = Timer(kScrollEdgeArrowsHideDelay, () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant EdgeArrowsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealKey != null && widget.revealKey != oldWidget.revealKey) {
      _reveal();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _reveal() {
    _hideTimer?.cancel();
    _hideTimer = Timer(kScrollEdgeArrowsHideDelay, () {
      if (mounted) setState(() => _visible = false);
    });
    if (!_visible) setState(() => _visible = true);
  }

  void _tap(VoidCallback action) {
    action();
    _reveal();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          top: widget.topPadding + AppSpacing.xs,
          right: AppSpacing.xs,
          child: _EdgeArrowButton(
            visible: _visible && widget.canGoStart,
            icon: Icons.keyboard_double_arrow_up_rounded,
            tooltip: widget.startTooltip,
            onPressed: () => _tap(widget.onGoStart),
          ),
        ),
        Positioned(
          bottom: widget.bottomPadding + AppSpacing.xs,
          right: AppSpacing.xs,
          child: _EdgeArrowButton(
            visible: _visible && widget.canGoEnd,
            icon: Icons.keyboard_double_arrow_down_rounded,
            tooltip: widget.endTooltip,
            onPressed: () => _tap(widget.onGoEnd),
          ),
        ),
      ],
    );
  }
}

class _EdgeArrowButton extends StatelessWidget {
  const _EdgeArrowButton({
    required this.visible,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool visible;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: tooltip,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            iconSize: 20,
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
