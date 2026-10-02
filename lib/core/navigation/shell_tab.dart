import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';

/// Surfaces hosted inside [AppShell] (Home + AI Chat).
enum ShellTab { home, aiChat }

final shellTabProvider = StateProvider<ShellTab>((ref) => ShellTab.home);

/// Navigate to a shell surface, popping detail routes so the shell is visible.
abstract final class ShellNavigation {
  static void go(
    BuildContext context,
    WidgetRef ref,
    ShellTab tab,
  ) {
    ref.read(shellTabProvider.notifier).state = tab;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  /// Open Settings as a pushed route, optionally focusing a section.
  static void openSettings(
    BuildContext context, {
    String? section,
  }) {
    Navigator.of(context).pushNamed(
      AppRoutes.settings,
      arguments: section == null ? null : {'section': section},
    );
  }

  static void openFavorites(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.favorites);
  }

  static ShellTab? tabForRoute(String? routeName) => switch (routeName) {
    AppRoutes.home => ShellTab.home,
    AppRoutes.aiChat => ShellTab.aiChat,
    _ => null,
  };
}
