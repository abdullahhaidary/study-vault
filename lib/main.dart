import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'app/app.dart';
import 'core/storage/study_vault_paths.dart';
import 'features/library_accounts/data/library_account_store.dart';
import 'features/library_accounts/data/library_accounts_controller.dart';
import 'features/library_accounts/presentation/library_accounts_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();

  // Required on older Android versions so Drift can open SQLite.
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }

  final accounts = await LibraryAccountsController.open(
    FileLibraryAccountStore(await StudyVaultPaths.documentsDirectory()),
  );
  runApp(
    LibraryAccountsRoot(controller: accounts, child: const StudyVaultApp()),
  );
}
