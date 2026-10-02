import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../services/quiz_generation_service.dart';
import '../services/quiz_session_service.dart';

final quizGenerationServiceProvider = Provider<QuizGenerationService>((ref) {
  return QuizGenerationService(
    db: ref.watch(databaseProvider),
    ai: ref.watch(aiServiceProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

final quizSessionServiceProvider = Provider<QuizSessionService>((ref) {
  return QuizSessionService(ref.watch(databaseProvider));
});

final questionSetsForLessonProvider =
    StreamProvider.family<List<QuestionSet>, String>((ref, lessonId) {
      return ref.watch(databaseProvider).watchQuestionSetsForLesson(lessonId);
    });

final questionSetsForMaterialProvider =
    StreamProvider.family<List<QuestionSet>, String>((ref, materialId) {
      return ref
          .watch(databaseProvider)
          .watchQuestionSetsForMaterial(materialId);
    });

final questionSetByIdProvider = StreamProvider.family<QuestionSet?, String>((
  ref,
  id,
) {
  return ref.watch(databaseProvider).watchQuestionSetById(id);
});
