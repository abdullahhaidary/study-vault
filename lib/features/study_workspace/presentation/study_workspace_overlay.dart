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

  double? _left;
  double? _top;
  double? _width;
  double? _height;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyWorkspaceProvider);
    final controller = ref.read(studyWorkspaceProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _geometryFor(constraints);
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
                  child: _FloatingChatWindow(
                    onDrag: (delta) => _move(delta, constraints, geometry),
                    onResize: (delta) => _resize(delta, constraints, geometry),
                    onMinimize: controller.minimize,
                    onClose: controller.close,
                  ),
                ),
              ),
            if (!state.visible || state.minimized)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: SafeArea(
                  child: FloatingActionButton.extended(
                    heroTag: 'global-study-ai',
                    onPressed: controller.restore,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(state.minimized ? 'Resume AI' : 'Study AI'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  _WindowGeometry _geometryFor(BoxConstraints constraints) {
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
    final height = (_height ?? _defaultHeight).clamp(
      minimumHeight,
      availableHeight,
    );
    final defaultLeft = constraints.maxWidth - width - _edgeMargin;
    final defaultTop = (constraints.maxHeight - height) / 2;
    final left = (_left ?? defaultLeft).clamp(
      _edgeMargin,
      constraints.maxWidth - width - _edgeMargin,
    );
    final top = (_top ?? defaultTop).clamp(
      _edgeMargin,
      constraints.maxHeight - height - _edgeMargin,
    );

    return _WindowGeometry(
      left: left.toDouble(),
      top: top.toDouble(),
      width: width.toDouble(),
      height: height.toDouble(),
    );
  }

  void _move(
    Offset delta,
    BoxConstraints constraints,
    _WindowGeometry current,
  ) {
    setState(() {
      _left = (current.left + delta.dx).clamp(
        _edgeMargin,
        constraints.maxWidth - current.width - _edgeMargin,
      );
      _top = (current.top + delta.dy).clamp(
        _edgeMargin,
        constraints.maxHeight - current.height - _edgeMargin,
      );
      _width = current.width;
      _height = current.height;
    });
  }

  void _resize(
    Offset delta,
    BoxConstraints constraints,
    _WindowGeometry current,
  ) {
    final maxWidth = constraints.maxWidth - current.left - _edgeMargin;
    final maxHeight = constraints.maxHeight - current.top - _edgeMargin;
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

class _FloatingChatWindow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
          Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => onDrag(details.delta),
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.drag_indicator,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Study AI',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Minimize',
                            onPressed: onMinimize,
                            icon: const Icon(Icons.minimize),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: onClose,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
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
            ],
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
