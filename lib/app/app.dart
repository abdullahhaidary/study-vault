import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'routes.dart';

/// Root widget for Study Vault.
class StudyVaultApp extends StatelessWidget {
  const StudyVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
