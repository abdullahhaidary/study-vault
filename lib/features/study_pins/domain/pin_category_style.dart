import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';

/// Resolves category color for pin visuals (theme-compatible).
abstract final class PinCategoryStyle {
  static Color colorOf(StudyPinCategory? category, ColorScheme scheme) {
    if (category == null) return scheme.primary;
    return Color(category.colorValue);
  }

  static Color highlightOf(StudyPinCategory? category, ColorScheme scheme) {
    return colorOf(category, scheme).withValues(alpha: 0.22);
  }

  static Color borderOf(StudyPinCategory? category, ColorScheme scheme) {
    return colorOf(category, scheme).withValues(alpha: 0.45);
  }

  static IconData? iconOf(StudyPinCategory? category) {
    return switch (category?.iconKey) {
      'menu_book' => Icons.menu_book_outlined,
      'priority_high' => Icons.priority_high,
      'functions' => Icons.functions,
      'help_outline' => Icons.help_outline,
      'lightbulb_outline' => Icons.lightbulb_outline,
      'school' => Icons.school_outlined,
      'psychology_alt' => Icons.psychology_alt_outlined,
      _ => null,
    };
  }

  static String labelOf(StudyPinCategory? category) {
    return category?.name ?? 'General';
  }

  static bool isBuiltIn(String? categoryId) {
    if (categoryId == null) return false;
    return BuiltInPinCategories.seeds.any((s) => s.id == categoryId);
  }
}
