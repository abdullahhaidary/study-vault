import 'package:flutter/material.dart';

import '../features/classes/presentation/class_details_screen.dart';
import '../features/classes/presentation/home_screen.dart';
import '../features/lessons/presentation/image_study_screen.dart';
import '../features/lessons/presentation/lesson_details_screen.dart';
import '../features/lessons/presentation/pdf_study_screen.dart';
import '../features/subjects/presentation/subject_details_screen.dart';

/// Named route constants.
abstract final class AppRoutes {
  static const home = '/';
  static const classDetails = '/class';
  static const subjectDetails = '/subject';
  static const lessonDetails = '/lesson';
  static const pdfStudy = '/pdf-study';
  static const imageStudy = '/image-study';
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

    case AppRoutes.lessonDetails:
      final lessonId = settings.arguments as String;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => LessonDetailsScreen(lessonId: lessonId),
      );

    case AppRoutes.pdfStudy:
      final args = settings.arguments as Map<String, String>;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => PdfStudyScreen(
          resourceId: args['resourceId']!,
          title: args['title']!,
          filePath: args['filePath']!,
        ),
      );

    case AppRoutes.imageStudy:
      final args = settings.arguments as Map<String, String>;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => ImageStudyScreen(
          resourceId: args['resourceId']!,
          title: args['title']!,
          filePath: args['filePath']!,
        ),
      );

    default:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const HomeScreen(),
      );
  }
}
