import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_chat/presentation/ai_chat_screen.dart';
import '../../features/classes/presentation/home_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../navigation/shell_tab.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'system_bottom_inset.dart';

/// Responsive application chrome: bottom nav on phones, rail on wide screens.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initialTab});

  final ShellTab? initialTab;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Bottom-nav / rail destinations only. AI Chat stays in [ShellTab] and the
  /// IndexedStack, and is opened from Home (next to Search) or deep links.
  static const _destinations = <_ShellDestination>[
    _ShellDestination(
      tab: ShellTab.home,
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _ShellDestination(
      tab: ShellTab.favorites,
      label: 'Favorites',
      icon: Icons.star_outline,
      selectedIcon: Icons.star,
    ),
    _ShellDestination(
      tab: ShellTab.settings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(shellTabProvider.notifier).state = initial;
      });
    }
  }

  void _select(int i) {
    if (i < 0 || i >= _destinations.length) return;
    ref.read(shellTabProvider.notifier).state = _destinations[i].tab;
    if (_destinations[i].tab != ShellTab.settings) {
      ref.read(settingsSectionProvider.notifier).state = null;
    }
  }

  int _selectedDestinationIndex(ShellTab tab) {
    final i = _destinations.indexWhere((d) => d.tab == tab);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(shellTabProvider);
    final settingsSection = ref.watch(settingsSectionProvider);
    final wide = AppSpacing.isWide(context);
    final theme = Theme.of(context);
    final selectedIndex = _selectedDestinationIndex(tab);

    final body = IndexedStack(
      index: tab.index,
      children: [
        const HomeScreen(),
        const AiChatScreen(),
        const FavoritesScreen(embeddedInShell: true),
        SettingsScreen(
          key: ValueKey('settings-${settingsSection ?? 'root'}'),
          embeddedInShell: true,
          initialSection: settingsSection,
        ),
      ],
    );

    // Chat owns its full mobile-style chrome (drawer, header, and composer).
    // Keeping shell navigation visible here makes the conversation feel like
    // one tab inside a dashboard and takes valuable space from the keyboard.
    if (tab == ShellTab.aiChat) {
      return Material(color: theme.scaffoldBackgroundColor, child: body);
    }

    if (wide) {
      return Material(
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(child: body),
          // Background fills any remaining system inset; interactive nav stays
          // above the system navigation buttons / home indicator.
          Material(
            color: AppColors.surface,
            elevation: 0,
            child: SystemBottomSafeArea(
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: _select,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final ShellTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
