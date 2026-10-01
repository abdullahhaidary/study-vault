import 'package:flutter/material.dart';

import '../features/classes/presentation/class_details_screen.dart';
import '../features/classes/presentation/home_screen.dart';
import '../features/subjects/presentation/subject_details_screen.dart';

/// Named route constants.
abstract final class AppRoutes {
  static const home = '/';
  static const classDetails = '/class';
  static const subjectDetails = '/subject';
}

/// Central route generator — keeps navigation in one place.
Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const HomeScreen(),
      );

    case AppRoutes.classDetails:
      final classId = settings.arguments as String;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => ClassDetailsScreen(classId: classId),
      );

    case AppRoutes.subjectDetails:
      final subjectId = settings.arguments as String;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => SubjectDetailsScreen(subjectId: subjectId),
      );

    default:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const HomeScreen(),
      );
  }
}
