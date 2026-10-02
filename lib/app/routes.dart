import 'package:flutter/material.dart';

import '../core/navigation/shell_tab.dart';
import '../core/widgets/app_shell.dart';
import '../features/classes/presentation/class_details_screen.dart';
import '../features/lessons/presentation/image_study_screen.dart';
import '../features/lessons/presentation/lesson_details_screen.dart';
import '../features/lessons/presentation/lesson_images_screen.dart';
import '../features/lessons/presentation/pdf_study_screen.dart';
import '../features/ai_questions/presentation/question_sets_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/flashcards/presentation/flashcard_study_screen.dart';
import '../features/flashcards/presentation/flashcards_list_screen.dart';
import '../features/notes/presentation/note_editor_screen.dart';
import '../features/notes/presentation/note_reader_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/subjects/presentation/subject_details_screen.dart';

/// Named route constants.
abstract final class AppRoutes {
  static const home = '/';
  static const classDetails = '/class';
  static const subjectDetails = '/subject';
  static const lessonDetails = '/lesson';
  static const pdfStudy = '/pdf-study';
  static const imageStudy = '/image-study';
  static const search = '/search';
  static const aiChat = '/ai-chat';
  static const favorites = '/favorites';
  static const settings = '/settings';
  static const noteReader = '/note';
  static const noteEditor = '/note/edit';
  static const flashcardsList = '/flashcards';
  static const flashcardStudy = '/flashcards/study';
  static const lessonImages = '/lesson-images';
  static const questionSets = '/ai-questions';
}

/// Central route generator — keeps navigation in one place.
Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const AppShell(initialTab: ShellTab.home),
      );

    case AppRoutes.search:
      // Global search remains available outside the shell tab bar.
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const SearchScreen(),
      );

    case AppRoutes.aiChat:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const AppShell(initialTab: ShellTab.aiChat),
      );

    case AppRoutes.favorites:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const FavoritesScreen(),
      );

    case AppRoutes.settings:
      final args = settings.arguments;
      String? section;
      if (args is Map) {
        section = args['section'] as String?;
      }
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => SettingsScreen(initialSection: section),
      );

    case AppRoutes.noteReader:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => NoteReaderScreen(noteId: settings.arguments as String),
      );

    case AppRoutes.noteEditor:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => NoteEditorScreen(noteId: settings.arguments as String),
      );

    case AppRoutes.flashcardsList:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => FlashcardsListScreen(
          scope: settings.arguments as FlashcardsListScope,
        ),
      );

    case AppRoutes.flashcardStudy:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => FlashcardStudyScreen(
          scope: settings.arguments as FlashcardsListScope,
        ),
      );

    case AppRoutes.lessonImages:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => LessonImagesScreen(
          scope: settings.arguments as LessonImagesScope,
        ),
      );

    case AppRoutes.questionSets:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) =>
            QuestionSetsScreen(scope: settings.arguments as QuestionSetsScope),
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
          focusPinId: args['focusPinId'],
          initialPage: int.tryParse(args['initialPage'] ?? ''),
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
          focusPinId: args['focusPinId'],
        ),
      );

    default:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const AppShell(initialTab: ShellTab.home),
      );
  }
}
