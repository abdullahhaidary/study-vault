import '../domain/ai_models.dart';

/// Abstraction so UI never calls a provider directly and tests stay offline.
abstract class AiService {
  Future<bool> get isConfigured;

  /// Minimal request to verify credentials / model / network.
  Future<void> testConnection({Duration timeout = const Duration(seconds: 20)});

  Future<AiStudyResult> run(
    AiStudyRequest request, {
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(seconds: 60),
  });

  /// First-class quiz generation — provider returns structured question JSON.
  Future<AiQuestionsResult> generateQuestions(
    AiQuestionGenerationRequest request, {
    Duration timeout = const Duration(seconds: 90),
  });
}
