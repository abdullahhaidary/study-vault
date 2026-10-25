import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/study_vault_paths.dart';
import '../domain/library_account.dart';
import 'library_account_store.dart';

/// Owns the device's library accounts. Lives outside the [ProviderScope] so
/// the scope can be rebuilt around the newly opened library on every switch.
class LibraryAccountsController extends ChangeNotifier {
  LibraryAccountsController._(this._store, this._state);

  static Future<LibraryAccountsController> open(
    LibraryAccountStore store,
  ) async {
    final controller = LibraryAccountsController._(store, await store.load());
    controller._applyLibraryRoot();
    return controller;
  }

  factory LibraryAccountsController.memory() => LibraryAccountsController._(
    MemoryLibraryAccountStore(),
    LibraryAccounts(
      accounts: [
        LibraryAccount(
          id: LibraryAccount.defaultId,
          name: LibraryAccount.defaultName,
          colorIndex: 0,
          createdAt: DateTime.utc(2000),
        ),
      ],
      activeId: LibraryAccount.defaultId,
    ),
  );

  static const paletteSize = 8;

  final LibraryAccountStore _store;
  LibraryAccounts _state;

  LibraryAccounts get state => _state;
  List<LibraryAccount> get accounts => _state.accounts;
  LibraryAccount get active => _state.active;

  void _applyLibraryRoot() =>
      StudyVaultPaths.useLibraryRoot(_store.libraryRoot(active));

  String _validName(String name, {String? exceptId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const LibraryAccountException('Enter an account name.');
    }
    if (trimmed.length > LibraryAccount.maxNameLength) {
      throw const LibraryAccountException(
        'Use at most ${LibraryAccount.maxNameLength} characters.',
      );
    }
    final taken = accounts.any(
      (a) => a.id != exceptId && a.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (taken) {
      throw LibraryAccountException('“$trimmed” already exists.');
    }
    return trimmed;
  }

  int _nextColor() {
    final used = {for (final a in accounts) a.colorIndex};
    for (var i = 0; i < paletteSize; i++) {
      if (!used.contains(i)) return i;
    }
    return accounts.length % paletteSize;
  }

  Future<LibraryAccount> add(String name) async {
    final account = LibraryAccount(
      id: const Uuid().v4(),
      name: _validName(name),
      colorIndex: _nextColor(),
      createdAt: DateTime.now().toUtc(),
    );
    await _store.save(account);
    _state = LibraryAccounts(
      accounts: [...accounts, account],
      activeId: _state.activeId,
    );
    notifyListeners();
    return account;
  }

  Future<void> rename(String id, String name) async {
    final current = _require(id);
    final renamed = current.copyWith(name: _validName(name, exceptId: id));
    await _store.save(renamed);
    _state = LibraryAccounts(
      accounts: [for (final a in accounts) a.id == id ? renamed : a],
      activeId: _state.activeId,
    );
    notifyListeners();
  }

  /// Opens [id]'s library. Listeners rebuild the app around it.
  Future<void> switchTo(String id) async {
    _require(id);
    if (id == _state.activeId) return;
    await _store.setActive(id);
    _state = LibraryAccounts(accounts: accounts, activeId: id);
    _applyLibraryRoot();
    notifyListeners();
  }

  /// Deletes another account and every study item stored in its library.
  Future<void> remove(String id) async {
    final account = _require(id);
    if (account.isDefault) {
      throw const LibraryAccountException(
        'The default account cannot be removed.',
      );
    }
    if (id == _state.activeId) {
      throw const LibraryAccountException(
        'Switch to another account before removing this one.',
      );
    }
    await _store.delete(account);
    _state = LibraryAccounts(
      accounts: [
        for (final a in accounts)
          if (a.id != id) a,
      ],
      activeId: _state.activeId,
    );
    notifyListeners();
  }

  LibraryAccount _require(String id) =>
      _state.byId(id) ??
      (throw const LibraryAccountException('That account no longer exists.'));
}

/// Overridden by `LibraryAccountsRoot`; the in-memory default keeps widget
/// tests and isolated scopes on a single library.
final libraryAccountsControllerProvider = Provider<LibraryAccountsController>((
  ref,
) {
  final controller = LibraryAccountsController.memory();
  ref.onDispose(controller.dispose);
  return controller;
});

final libraryAccountsProvider = Provider<LibraryAccounts>((ref) {
  final controller = ref.watch(libraryAccountsControllerProvider);
  void changed() => ref.state = controller.state;
  controller.addListener(changed);
  ref.onDispose(() => controller.removeListener(changed));
  return controller.state;
});

final activeLibraryAccountProvider = Provider<LibraryAccount>(
  (ref) => ref.watch(libraryAccountsProvider).active,
);
