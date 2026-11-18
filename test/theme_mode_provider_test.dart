import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/theme/theme_mode_provider.dart';

void main() {
  test('parse maps saved names and falls back to system', () {
    expect(AppThemeMode.parse('light'), ThemeMode.light);
    expect(AppThemeMode.parse('dark'), ThemeMode.dark);
    expect(AppThemeMode.parse('system'), ThemeMode.system);
    expect(AppThemeMode.parse(null), ThemeMode.system);
    expect(AppThemeMode.parse('nope'), ThemeMode.system);
  });

  test('prefs key stores ThemeMode.name', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppThemeMode.key, ThemeMode.dark.name);
    expect(
      AppThemeMode.parse(prefs.getString(AppThemeMode.key)),
      ThemeMode.dark,
    );
  });
}
