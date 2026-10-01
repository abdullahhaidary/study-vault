import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();

  // Required on older Android versions so Drift can open SQLite.
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }

  runApp(
    const ProviderScope(
      child: StudyVaultApp(),
    ),
  );
}
