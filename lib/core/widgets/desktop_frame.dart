import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../features/study_workspace/data/study_workspace_providers.dart';
import '../theme/app_spacing.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appRouteObserver = CurrentRouteObserver();

/// Tracks the page stack so the desktop rail can highlight the open section.
class CurrentRouteObserver extends NavigatorObserver {
  final current = ValueNotifier<String?>(AppRoutes.home);
  final _pages = <Route<dynamic>>[];

  Route<dynamic>? get top => _pages.isEmpty ? null : _pages.last;

  void _changed() {
    final name = top?.settings.name;
    SchedulerBinding.instance.addPostFrameCallback((_) => current.value = name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _pages.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pages.remove(route)) _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pages.remove(route)) _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _pages.indexOf(oldRoute);
    if (newRoute is PageRoute) {
      if (index >= 0) {
        _pages[index] = newRoute;
      } else {
        _pages.add(newRoute);
      }
    } else if (index >= 0) {
      _pages.removeAt(index);
    }
    _changed();
  }
}

/// Persistent left navigation for desktop windows; passes through on phones.
class DesktopFrame extends ConsumerWidget {
  const DesktopFrame({super.key, required this.child});

  final Widget child;

  static const _sections = [
    (
      AppRoutes.home,
      Icons.library_books_outlined,
      Icons.library_books,
      'Library',
    ),
    (AppRoutes.books, Icons.menu_book_outlined, Icons.menu_book, 'Books'),
    (AppRoutes.search, Icons.search, Icons.search, 'Search'),
    (AppRoutes.favorites, Icons.star_outline, Icons.star, 'Favorites'),
    (AppRoutes.reviews, Icons.history_outlined, Icons.history, 'Reviews'),
    (AppRoutes.settings, Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  static int _indexFor(String? route) {
    final index = _sections.indexWhere((s) => s.$1 == route);
    return index < 0 ? 0 : index;
  }

  /// Returns to the main window, respecting unsaved-change prompts.
  static Future<bool> _returnHome() async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return false;
    for (var i = 0; i < 64; i++) {
      final top = appRouteObserver.top;
      if (top == null || top.isFirst) return true;
      await navigator.maybePop();
      if (identical(appRouteObserver.top, top)) return false;
    }
    return false;
  }

  static Future<void> _open(String route) async {
    if (!await _returnHome() || route == AppRoutes.home) return;
    appNavigatorKey.currentState?.pushNamed(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppSpacing.isDesktopLayout(context)) return child;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: appRouteObserver.current,
          builder: (context, route, _) => NavigationRail(
            selectedIndex: _indexFor(route),
            labelType: NavigationRailLabelType.all,
            groupAlignment: -1,
            minWidth: 88,
            backgroundColor: theme.colorScheme.surface,
            onDestinationSelected: (index) => _open(_sections[index].$1),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo/study_vault_icon_512.png',
                    width: 40,
                    height: 40,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.school,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FloatingActionButton.small(
                    heroTag: null,
                    elevation: 0,
                    onPressed: () =>
                        ref.read(studyWorkspaceProvider.notifier).open(),
                    child: const Icon(Icons.auto_awesome),
                  ),
                  Text('AI Chat', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            destinations: [
              for (final section in _sections)
                NavigationRailDestination(
                  icon: Icon(section.$2),
                  selectedIcon: Icon(section.$3),
                  label: Text(section.$4),
                ),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
        Expanded(child: child),
      ],
    );
  }
}

/// Item tiles as a vertical list on phones and a card grid on desktop.
class AdaptiveItemList extends StatelessWidget {
  const AdaptiveItemList({
    super.key,
    required this.children,
    this.minItemWidth = 340,
  });

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (AppSpacing.isDesktopLayout(context)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const spacing = AppSpacing.sm;
            final columns = (constraints.maxWidth / (minItemWidth + spacing))
                .floor()
                .clamp(1, 4);
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return SizedBox(
              width: constraints.maxWidth,
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final child in children)
                    SizedBox(width: width, child: child),
                ],
              ),
            );
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: child,
          ),
      ],
    );
  }
}
