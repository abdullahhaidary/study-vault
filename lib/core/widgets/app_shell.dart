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

  void _select(int i, List<_ShellDestination> destinations) {
    ref.read(shellTabProvider.notifier).state = destinations[i].tab;
    if (destinations[i].tab != ShellTab.settings) {
      ref.read(settingsSectionProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(shellTabProvider);
    final settingsSection = ref.watch(settingsSectionProvider);
    final wide = AppSpacing.isWide(context);
    final index = tab.index;
    final theme = Theme.of(context);

    const destinations = [
      _ShellDestination(
        tab: ShellTab.home,
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _ShellDestination(
        tab: ShellTab.aiChat,
        label: 'AI Chat',
        icon: Icons.auto_awesome_outlined,
        selectedIcon: Icons.auto_awesome,
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

    final body = IndexedStack(
      index: index,
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

    if (wide) {
      return Material(
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _select(i, destinations),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
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
                selectedIndex: index,
                onDestinationSelected: (i) => _select(i, destinations),
                destinations: [
                  for (final d in destinations)
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
