import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart' as app_routes;
import '../../../core/theme/app_spacing.dart';
import '../../ai_chat/presentation/ai_chat_screen.dart';
import '../data/study_workspace_providers.dart';

class StudyWorkspaceHost extends ConsumerStatefulWidget {
  const StudyWorkspaceHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StudyWorkspaceHost> createState() => _StudyWorkspaceHostState();
}

class _StudyWorkspaceHostState extends ConsumerState<StudyWorkspaceHost> {
  static const _edgeMargin = 12.0;
  static const _minimumWidth = 340.0;
  static const _minimumHeight = 420.0;
  static const _defaultWidth = 560.0;
  static const _defaultHeight = 720.0;
  static const _launcherSize = 48.0;

  double? _left;
  double? _top;
  double? _width;
  double? _height;
  double? _launcherLeft;
  double? _launcherTop;
  BoxConstraints? _latestConstraints;
  double _keyboardInset = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyWorkspaceProvider);
    final controller = ref.read(studyWorkspaceProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        _latestConstraints = constraints;
        _keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final geometry = _geometryFor(
          constraints,
          keyboardInset: _keyboardInset,
        );
        final launcherPosition = _launcherPositionFor(
          constraints,
          keyboardInset: _keyboardInset,
        );
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (state.visible)
              Positioned(
                left: geometry.left,
                top: geometry.top,
                width: geometry.width,
                height: geometry.height,
                child: Offstage(
                  offstage: state.minimized,
                  child: _WindowOverlayNavigator(
                    onDrag: _move,
                    onResize: _resize,
                    onMinimize: controller.minimize,
                    onClose: controller.close,
                  ),
                ),
              ),
            if (!state.visible || state.minimized)
              Positioned(
                left: launcherPosition.dx,
                top: launcherPosition.dy,
                width: _launcherSize,
                height: _launcherSize,
                child: Semantics(
                  button: true,
                  label: state.minimized ? 'Resume Study AI' : 'Open Study AI',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => _moveLauncher(details.delta),
                    child: FloatingActionButton.small(
                      heroTag: 'global-study-ai',
                      onPressed: controller.restore,
                      child: const Icon(Icons.auto_awesome),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Offset _launcherPositionFor(
    BoxConstraints constraints, {
    double keyboardInset = 0,
  }) {
    final maxLeft = (constraints.maxWidth - _launcherSize - _edgeMargin).clamp(
      _edgeMargin,
      double.infinity,
    );
    final usableBottom = constraints.maxHeight - keyboardInset;
    final maxTop = (usableBottom - _launcherSize - _edgeMargin).clamp(
      _edgeMargin,
      double.infinity,
    );
    return Offset(
      (_launcherLeft ?? maxLeft).clamp(_edgeMargin, maxLeft).toDouble(),
      (_launcherTop ?? maxTop).clamp(_edgeMargin, maxTop).toDouble(),
    );
  }

  void _moveLauncher(Offset delta) {
    final constraints = _latestConstraints;
    if (constraints == null) return;
    final current = _launcherPositionFor(
      constraints,
      keyboardInset: _keyboardInset,
    );
    final usableBottom = constraints.maxHeight - _keyboardInset;
    setState(() {
      _launcherLeft = (current.dx + delta.dx)
          .clamp(
            _edgeMargin,
            constraints.maxWidth - _launcherSize - _edgeMargin,
          )
          .toDouble();
      _launcherTop = (current.dy + delta.dy)
          .clamp(_edgeMargin, usableBottom - _launcherSize - _edgeMargin)
          .toDouble();
    });
  }

  _WindowGeometry _geometryFor(
    BoxConstraints constraints, {
    double keyboardInset = 0,
  }) {
    final availableWidth = (constraints.maxWidth - (_edgeMargin * 2)).clamp(
      1.0,
      double.infinity,
    );
    final availableHeight = (constraints.maxHeight - (_edgeMargin * 2)).clamp(
      1.0,
      double.infinity,
    );
    final minimumWidth = _minimumWidth.clamp(1.0, availableWidth);
    final minimumHeight = _minimumHeight.clamp(1.0, availableHeight);
    final width = (_width ?? _defaultWidth).clamp(minimumWidth, availableWidth);
    var height = (_height ?? _defaultHeight).clamp(
      minimumHeight,
      availableHeight,
    );
    final defaultLeft = constraints.maxWidth - width - _edgeMargin;
    final defaultTop = (constraints.maxHeight - height) / 2;
    final left = (_left ?? defaultLeft).clamp(
      _edgeMargin,
      constraints.maxWidth - width - _edgeMargin,
    );
    var top = (_top ?? defaultTop).clamp(
      _edgeMargin,
      constraints.maxHeight - height - _edgeMargin,
    );
    if (keyboardInset > 0) {
      final keyboardTop = constraints.maxHeight - keyboardInset;
      final popupBottom = top + height;
      if (popupBottom > keyboardTop - _edgeMargin) {
        final shiftedTop = keyboardTop - height - _edgeMargin;
        if (shiftedTop >= _edgeMargin) {
          top = shiftedTop;
        } else {
          top = _edgeMargin;
          height = (keyboardTop - (_edgeMargin * 2)).clamp(1.0, height);
        }
      }
    }

    return _WindowGeometry(
      left: left.toDouble(),
      top: top.toDouble(),
      width: width.toDouble(),
      height: height.toDouble(),
    );
  }

  void _move(Offset delta) {
    final constraints = _latestConstraints;
    if (constraints == null) return;
    final current = _geometryFor(constraints, keyboardInset: _keyboardInset);
    final usableBottom = constraints.maxHeight - _keyboardInset;
    setState(() {
      _left = (current.left + delta.dx).clamp(
        _edgeMargin,
        constraints.maxWidth - current.width - _edgeMargin,
      );
      _top = (current.top + delta.dy).clamp(
        _edgeMargin,
        usableBottom - current.height - _edgeMargin,
      );
      _width = current.width;
      _height = current.height;
    });
  }

  void _resize(Offset delta) {
    final constraints = _latestConstraints;
    if (constraints == null) return;
    final current = _geometryFor(constraints, keyboardInset: _keyboardInset);
    final maxWidth = constraints.maxWidth - current.left - _edgeMargin;
    final maxHeight =
        constraints.maxHeight - _keyboardInset - current.top - _edgeMargin;
    final minimumWidth = _minimumWidth.clamp(1.0, maxWidth);
    final minimumHeight = _minimumHeight.clamp(1.0, maxHeight);
    setState(() {
      _left = current.left;
      _top = current.top;
      _width = (current.width + delta.dx).clamp(minimumWidth, maxWidth);
      _height = (current.height + delta.dy).clamp(minimumHeight, maxHeight);
    });
  }
}

class _WindowOverlayNavigator extends StatelessWidget {
  const _WindowOverlayNavigator({
    required this.onDrag,
    required this.onResize,
    required this.onMinimize,
    required this.onClose,
  });

  final ValueChanged<Offset> onDrag;
  final ValueChanged<Offset> onResize;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        return PageRouteBuilder<void>(
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => _FloatingChatWindow(
            onDrag: onDrag,
            onResize: onResize,
            onMinimize: onMinimize,
            onClose: onClose,
          ),
        );
      },
    );
  }
}

class _FloatingChatWindow extends StatelessWidget {
  const _FloatingChatWindow({
    required this.onDrag,
    required this.onResize,
    required this.onMinimize,
    required this.onClose,
  });

  final ValueChanged<Offset> onDrag;
  final ValueChanged<Offset> onResize;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 20,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Navigator(
              onGenerateRoute: (settings) {
                if (settings.name == Navigator.defaultRouteName) {
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) =>
                        AiChatScreen(embedded: true, onClose: onMinimize),
                  );
                }
                return app_routes.onGenerateRoute(settings);
              },
            ),
          ),
          Positioned(
            left: 44,
            right: 76,
            top: 0,
            height: 18,
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => onDrag(details.delta),
                child: Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 4,
            child: Material(
              color: theme.colorScheme.surfaceContainerLow.withValues(
                alpha: 0.92,
              ),
              borderRadius: BorderRadius.circular(18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Minimize',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onMinimize,
                    icon: const Icon(Icons.minimize, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            width: 30,
            height: 30,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeDownRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => onResize(details.delta),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.drag_handle,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowGeometry {
  const _WindowGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}
