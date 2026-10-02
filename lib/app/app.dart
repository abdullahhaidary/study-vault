import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/system_bottom_inset.dart';
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
      builder: (context, child) {
        // Keep all routes above the system navigation / home indicator.
        // Fill the inset with surface so it matches the bottom NavigationBar.
        return ColoredBox(
          color: AppColors.surface,
          child: SystemBottomSafeArea(child: child ?? const SizedBox.shrink()),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}
