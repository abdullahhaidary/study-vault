import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desktop_frame.dart';
import '../data/library_accounts_controller.dart';

/// Gives every library account its own [ProviderScope].
///
/// Switching tears down the old scope (closing its database, sync session,
/// and AI queue) for one frame before building the new one, so the global
/// navigator key is never mounted twice.
class LibraryAccountsRoot extends StatefulWidget {
  const LibraryAccountsRoot({
    super.key,
    required this.controller,
    required this.child,
  });

  final LibraryAccountsController controller;
  final Widget child;

  @override
  State<LibraryAccountsRoot> createState() => _LibraryAccountsRootState();
}

class _LibraryAccountsRootState extends State<LibraryAccountsRoot> {
  late String _openId = widget.controller.active.id;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_accountsChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_accountsChanged);
    super.dispose();
  }

  void _accountsChanged() {
    final activeId = widget.controller.active.id;
    if (activeId == _openId || _switching) return;
    setState(() => _switching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      appRouteObserver.reset();
      setState(() {
        _openId = widget.controller.active.id;
        _switching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_switching) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: AppColors.surface,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return ProviderScope(
      key: ValueKey(_openId),
      overrides: [
        libraryAccountsControllerProvider.overrideWithValue(widget.controller),
      ],
      child: widget.child,
    );
  }
}
