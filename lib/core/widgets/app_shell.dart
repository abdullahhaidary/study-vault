import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_chat/presentation/ai_chat_screen.dart';
import '../../features/classes/presentation/home_screen.dart';
import '../navigation/shell_tab.dart';

/// Application shell: Home by default, AI Chat when opened from Home.
/// Favorites and Settings are pushed routes (home overflow menu).
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

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(shellTabProvider);
    final theme = Theme.of(context);
    final stackIndex = tab == ShellTab.aiChat ? 1 : 0;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: IndexedStack(
        index: stackIndex,
        children: const [
          HomeScreen(),
          AiChatScreen(),
        ],
      ),
    );
  }
}
