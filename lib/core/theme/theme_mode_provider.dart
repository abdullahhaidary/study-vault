import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local appearance (not synced).
abstract final class AppThemeMode {
  static const key = 'study_vault_theme_mode_v1';

  static ThemeMode parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final themeModeProvider = FutureProvider<ThemeMode>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return AppThemeMode.parse(prefs.getString(AppThemeMode.key));
});

Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(AppThemeMode.key, mode.name);
  ref.invalidate(themeModeProvider);
}
