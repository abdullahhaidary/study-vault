import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/transient_snack_bar.dart';
import '../../../core/navigation/shell_tab.dart';
import '../../../core/widgets/desktop_frame.dart';
import '../../ai_generation_queue/data/ai_generation_providers.dart';
import '../../cloud_account/cloud_account_provider.dart';
import '../../cloud_account/cloud_api.dart';
import '../data/library_accounts_controller.dart';
import '../domain/library_account.dart';

const _palette = [
  Color(0xFF3F51B5),
  Color(0xFF00897B),
  Color(0xFFE65100),
  Color(0xFF8E24AA),
  Color(0xFF2E7D32),
  Color(0xFFC62828),
  Color(0xFF00838F),
  Color(0xFF6D4C41),
];

class LibraryAccountAvatar extends StatelessWidget {
  const LibraryAccountAvatar({
    super.key,
    required this.account,
    this.radius = 16,
    this.selected = false,
  });

  final LibraryAccount account;
  final double radius;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: _palette[account.colorIndex % _palette.length],
      foregroundColor: Colors.white,
      child: Text(
        account.initials,
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600),
      ),
    );
    if (!selected) return avatar;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: avatar,
    );
  }
}

/// Account actions shared by the switcher menu and Settings.
abstract final class LibraryAccountActions {
  /// Opens [target]'s library immediately. Asks only when switching would
  /// stop running AI generations; refuses while a sync is in progress.
  static Future<void> switchTo(
    BuildContext context,
    WidgetRef ref,
    LibraryAccount target,
  ) async {
    final controller = ref.read(libraryAccountsControllerProvider);
    if (target.id == controller.active.id) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (ref.exists(cloudAccountProvider) &&
        ref.read(cloudAccountProvider).busy) {
      messenger?.showSnackBar(
        const TransientSnackBar(
          content: Text('Wait for the cloud sync to finish, then switch.'),
        ),
      );
      return;
    }
    final queue = ref.read(generationQueueSnapshotProvider);
    final pending = queue.running + queue.queued;
    if (pending > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Switch to ${target.name}?'),
          content: Text(
            '$pending AI generation${pending == 1 ? ' is' : 's are'} still running in '
            '${controller.active.name}. Switching stops them; partial output is kept '
            'in the Generation Center when you switch back.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    if (!await DesktopFrame.returnHome()) return;
    try {
      await controller.switchTo(target.id);
    } catch (error) {
      messenger?.showSnackBar(
        TransientSnackBar(content: Text('Could not switch accounts: $error')),
      );
    }
  }

  static Future<void> add(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(libraryAccountsControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final account = await showDialog<LibraryAccount>(
      context: context,
      builder: (context) => _AccountNameDialog(
        title: 'Add account',
        action: 'Add',
        submit: controller.add,
      ),
    );
    if (account == null || !context.mounted) return;
    messenger?.showSnackBar(
      TransientSnackBar(
        content: Text('Added ${account.name}. Its library starts empty.'),
        action: SnackBarAction(
          label: 'Switch',
          onPressed: () {
            if (context.mounted) switchTo(context, ref, account);
          },
        ),
      ),
    );
  }

  static Future<void> rename(
    BuildContext context,
    WidgetRef ref,
    LibraryAccount account,
  ) {
    final controller = ref.read(libraryAccountsControllerProvider);
    return showDialog<void>(
      context: context,
      builder: (context) => _AccountNameDialog(
        title: 'Rename account',
        action: 'Save',
        initialName: account.name,
        submit: (name) => controller.rename(account.id, name),
      ),
    );
  }

  static Future<void> remove(
    BuildContext context,
    WidgetRef ref,
    LibraryAccount account,
  ) async {
    final controller = ref.read(libraryAccountsControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${account.name}?'),
        content: const Text(
          'This permanently deletes this account’s classes, lessons, notes, '
          'files, and AI materials from this device. Anything already synced '
          'to its cloud account stays on the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _signOutCloud(account);
      await controller.remove(account.id);
      messenger?.showSnackBar(
        TransientSnackBar(content: Text('Removed ${account.name}.')),
      );
    } catch (error) {
      messenger?.showSnackBar(
        TransientSnackBar(
          content: Text('Could not remove ${account.name}: $error'),
        ),
      );
    }
  }

  static Future<void> _signOutCloud(LibraryAccount account) async {
    final store = SecureCloudSessionStore(account.id);
    final session = await store.read();
    if (session == null) return;
    final api = CloudApi();
    try {
      await api.logout(session);
    } catch (_) {
      // The server session still expires on its own.
    } finally {
      api.close();
    }
    await store.clear();
  }
}

sealed class _AccountMenuChoice {
  const _AccountMenuChoice();
}

final class _SwitchChoice extends _AccountMenuChoice {
  const _SwitchChoice(this.account);
  final LibraryAccount account;
}

final class _AddChoice extends _AccountMenuChoice {
  const _AddChoice();
}

final class _ManageChoice extends _AccountMenuChoice {
  const _ManageChoice();
}

/// Active account avatar; its menu switches to another account in one tap.
///
/// The desktop rail sits above the navigator, so the menu and every follow-up
/// dialog are shown through the app navigator rather than [context].
class AccountSwitcherButton extends ConsumerWidget {
  const AccountSwitcherButton({super.key, this.showName = false});

  final bool showName;

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final navigator =
        appNavigatorKey.currentState ?? Navigator.maybeOf(context);
    final button = context.findRenderObject();
    final overlay = navigator?.overlay?.context.findRenderObject();
    if (navigator == null || button is! RenderBox || overlay is! RenderBox) {
      return;
    }
    final origin = overlay.localToGlobal(Offset.zero);
    final anchor = (button.localToGlobal(Offset.zero) & button.size).shift(
      -origin,
    );
    final accounts = ref.read(libraryAccountsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final choice = await showMenu<_AccountMenuChoice>(
      context: navigator.context,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      items: [
        for (final account in accounts.accounts)
          PopupMenuItem(
            value: _SwitchChoice(account),
            child: Row(
              children: [
                LibraryAccountAvatar(account: account, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(account.name, overflow: TextOverflow.ellipsis),
                ),
                if (account.id == accounts.activeId)
                  Icon(Icons.check, color: primary),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AddChoice(),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_add_alt_1_outlined),
            title: Text('Add account'),
          ),
        ),
        const PopupMenuItem(
          value: _ManageChoice(),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.manage_accounts_outlined),
            title: Text('Manage accounts'),
          ),
        ),
      ],
    );
    if (choice == null || !navigator.mounted) return;
    final target = navigator.context;
    if (!target.mounted) return;
    switch (choice) {
      case _SwitchChoice(:final account):
        await LibraryAccountActions.switchTo(target, ref, account);
      case _AddChoice():
        await LibraryAccountActions.add(target, ref);
      case _ManageChoice():
        ShellNavigation.openSettings(target, section: 'accounts');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeLibraryAccountProvider);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Account: ${active.name}. Switch account',
      child: InkWell(
        customBorder: showName ? null : const CircleBorder(),
        borderRadius: showName ? BorderRadius.circular(12) : null,
        onTap: () => _openMenu(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: showName
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LibraryAccountAvatar(account: active),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 96,
                      child: Text(
                        active.name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                )
              : LibraryAccountAvatar(account: active),
        ),
      ),
    );
  }
}

class _AccountNameDialog<T> extends StatefulWidget {
  const _AccountNameDialog({
    required this.title,
    required this.action,
    required this.submit,
    this.initialName = '',
  });

  final String title;
  final String action;
  final String initialName;
  final Future<T> Function(String name) submit;

  @override
  State<_AccountNameDialog<T>> createState() => _AccountNameDialogState<T>();
}

class _AccountNameDialogState<T> extends State<_AccountNameDialog<T>> {
  late final _name = TextEditingController(text: widget.initialName);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await widget.submit(_name.text);
      if (mounted) Navigator.pop(context, result);
    } on LibraryAccountException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: LibraryAccount.maxNameLength,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Account name',
          hintText: 'e.g. University, Work, Sara',
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
