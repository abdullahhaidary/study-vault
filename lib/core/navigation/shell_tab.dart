import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';

/// Top-level destinations in the application shell.
enum ShellTab { home, aiChat, favorites, settings }

final shellTabProvider = StateProvider<ShellTab>((ref) => ShellTab.home);

/// Optional Settings deep-link (e.g. AI section).
final settingsSectionProvider = StateProvider<String?>((ref) => null);

/// Navigate to a shell tab, popping detail routes so the shell is visible.
abstract final class ShellNavigation {
  static void go(
    BuildContext context,
    WidgetRef ref,
    ShellTab tab, {
    String? settingsSection,
  }) {
    ref.read(settingsSectionProvider.notifier).state = settingsSection;
    ref.read(shellTabProvider.notifier).state = tab;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  /// Open Settings, optionally focusing a section. Uses the shell when possible.
  static void openSettings(
    BuildContext context,
    WidgetRef ref, {
    String? section,
  }) {
    go(context, ref, ShellTab.settings, settingsSection: section);
  }

  static ShellTab? tabForRoute(String? routeName) => switch (routeName) {
    AppRoutes.home => ShellTab.home,
    AppRoutes.aiChat => ShellTab.aiChat,
    AppRoutes.favorites => ShellTab.favorites,
    AppRoutes.settings => ShellTab.settings,
    _ => null,
  };
}
