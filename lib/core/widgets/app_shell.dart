import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/classes/presentation/home_screen.dart';
import '../../features/study_workspace/data/study_workspace_providers.dart';
import '../../features/study_workspace/domain/study_workspace_models.dart';
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
  static const _exitWindow = Duration(seconds: 2);
  DateTime? _lastBackAt;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(shellTabProvider.notifier).state = ShellTab.home;
        if (initial == ShellTab.aiChat) {
          ref
              .read(studyWorkspaceProvider.notifier)
              .open(StudyWorkspaceTab.chat);
        }
      });
    }
  }

  void _onBack() {
    final now = DateTime.now();
    final previous = _lastBackAt;
    if (previous != null && now.difference(previous) <= _exitWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastBackAt = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        duration: _exitWindow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: const HomeScreen(),
      ),
    );
  }
}
