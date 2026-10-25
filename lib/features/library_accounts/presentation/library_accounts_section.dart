import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../data/library_accounts_controller.dart';
import '../domain/library_account.dart';
import 'account_switcher.dart';

enum _AccountAction { rename, remove }

class LibraryAccountsSection extends ConsumerWidget {
  const LibraryAccountsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(libraryAccountsProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Accounts'),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Each account has its own classes, books, notes, files, and '
                  'cloud sign-in on this device. Tap an account to switch to it.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              for (final account in accounts.accounts)
                _AccountTile(
                  account: account,
                  active: account.id == accounts.activeId,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () => LibraryAccountActions.add(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add account'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.active});

  final LibraryAccount account;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final removable = !active && !account.isDefault;
    return ListTile(
      leading: LibraryAccountAvatar(account: account, selected: active),
      title: Text(account.name),
      subtitle: Text(active ? 'Open now' : 'Tap to switch'),
      selected: active,
      onTap: active
          ? null
          : () => LibraryAccountActions.switchTo(context, ref, account),
      trailing: PopupMenuButton<_AccountAction>(
        tooltip: 'Account options',
        onSelected: (action) => switch (action) {
          _AccountAction.rename => LibraryAccountActions.rename(
            context,
            ref,
            account,
          ),
          _AccountAction.remove => LibraryAccountActions.remove(
            context,
            ref,
            account,
          ),
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _AccountAction.rename,
            child: Text('Rename'),
          ),
          if (removable)
            const PopupMenuItem(
              value: _AccountAction.remove,
              child: Text('Remove from this device'),
            ),
        ],
      ),
    );
  }
}
