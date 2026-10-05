import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Single shared database instance for the whole app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase()..watchExternalChanges();
  ref.onDispose(db.close);
  return db;
});
