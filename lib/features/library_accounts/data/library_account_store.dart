import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/library_account.dart';

abstract interface class LibraryAccountStore {
  Future<LibraryAccounts> load();
  Future<void> save(LibraryAccount account);
  Future<void> setActive(String id);

  /// Permanently deletes a non-default account and its local library.
  Future<void> delete(LibraryAccount account);

  /// Library root for [account]; `null` means the app documents directory.
  Directory? libraryRoot(LibraryAccount account);
}

/// Device-local account registry kept beside the libraries it describes:
///
/// - `{documents}/study_vault_accounts/default.json` — default account name
/// - `{documents}/study_vault_accounts/active` — open account id
/// - `{documents}/study_vault_accounts/{uuid}/account.json` — other accounts,
///   whose database and files live in the same folder
///
/// Each account describes itself, so one damaged file never hides the others.
class FileLibraryAccountStore implements LibraryAccountStore {
  FileLibraryAccountStore(Directory documents)
    : root = Directory(p.join(documents.path, 'study_vault_accounts'));

  final Directory root;

  static final _accountId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  File get _defaultFile => File(p.join(root.path, 'default.json'));
  File get _activeFile => File(p.join(root.path, 'active'));

  Directory _folder(String id) {
    if (!_accountId.hasMatch(id)) {
      throw LibraryAccountException('Invalid account id: $id');
    }
    return Directory(p.join(root.path, id));
  }

  File _metadataFile(LibraryAccount account) => account.isDefault
      ? _defaultFile
      : File(p.join(_folder(account.id).path, 'account.json'));

  Future<LibraryAccount?> _read(File file) async {
    try {
      return LibraryAccount.tryParse(jsonDecode(await file.readAsString()));
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeAtomically(File file, String contents) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<LibraryAccounts> load() async {
    final stored = await _read(_defaultFile);
    final primary = LibraryAccount(
      id: LibraryAccount.defaultId,
      name: stored?.name ?? LibraryAccount.defaultName,
      colorIndex: stored?.colorIndex ?? 0,
      createdAt: stored?.createdAt ?? DateTime.utc(2000),
    );
    final others = <LibraryAccount>[];
    if (await root.exists()) {
      await for (final entity in root.list(followLinks: false)) {
        final id = p.basename(entity.path);
        if (entity is! Directory || !_accountId.hasMatch(id)) continue;
        final account = await _read(File(p.join(entity.path, 'account.json')));
        if (account != null && account.id == id) others.add(account);
      }
    }
    others.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final accounts = [primary, ...others];
    String? activeId;
    try {
      activeId = (await _activeFile.readAsString()).trim();
    } on FileSystemException {
      activeId = null;
    }
    return LibraryAccounts(
      accounts: accounts,
      activeId: accounts.any((a) => a.id == activeId)
          ? activeId!
          : LibraryAccount.defaultId,
    );
  }

  @override
  Future<void> save(LibraryAccount account) =>
      _writeAtomically(_metadataFile(account), jsonEncode(account.toJson()));

  @override
  Future<void> setActive(String id) => _writeAtomically(_activeFile, id);

  @override
  Future<void> delete(LibraryAccount account) async {
    if (account.isDefault) {
      throw const LibraryAccountException(
        'The default account cannot be removed.',
      );
    }
    final folder = _folder(account.id);
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  @override
  Directory? libraryRoot(LibraryAccount account) =>
      account.isDefault ? null : _folder(account.id);
}

/// Non-persistent registry with only the default library; used by tests and
/// whenever the app is built without the account root.
class MemoryLibraryAccountStore implements LibraryAccountStore {
  final _accounts = <String, LibraryAccount>{
    LibraryAccount.defaultId: LibraryAccount(
      id: LibraryAccount.defaultId,
      name: LibraryAccount.defaultName,
      colorIndex: 0,
      createdAt: DateTime.utc(2000),
    ),
  };
  String _activeId = LibraryAccount.defaultId;

  @override
  Future<LibraryAccounts> load() async =>
      LibraryAccounts(accounts: _accounts.values.toList(), activeId: _activeId);

  @override
  Future<void> save(LibraryAccount account) async =>
      _accounts[account.id] = account;

  @override
  Future<void> setActive(String id) async => _activeId = id;

  @override
  Future<void> delete(LibraryAccount account) async =>
      _accounts.remove(account.id);

  @override
  Directory? libraryRoot(LibraryAccount account) => null;
}
