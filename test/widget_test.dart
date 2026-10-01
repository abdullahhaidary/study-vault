import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:study_vault/app/app.dart';
import 'package:study_vault/core/database/app_database.dart';
import 'package:study_vault/core/database/database_provider.dart';

void main() {
  testWidgets('Home screen shows Study Vault title and empty state',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const StudyVaultApp(),
      ),
    );

    // Allow the StreamProvider to deliver the first empty list.
    await tester.pump();
    await tester.pump();

    // SliverAppBar.large renders the title in both expanded and collapsed states.
    expect(find.text('Study Vault'), findsWidgets);
    expect(find.text('My Classes'), findsOneWidget);
    expect(find.text('No classes yet'), findsOneWidget);

    // Unmount and flush Drift's stream-cancellation timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
  });
}
