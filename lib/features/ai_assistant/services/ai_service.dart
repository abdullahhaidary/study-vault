import '../domain/ai_models.dart';

/// Abstraction so UI never calls Gemini directly and tests stay offline.
abstract class AiService {
  Future<bool> get isConfigured;

  /// Minimal request to verify credentials / model / network.
  Future<void> testConnection({Duration timeout = const Duration(seconds: 20)});

  Future<AiStudyResult> run(
    AiStudyRequest request, {
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(seconds: 60),
  });
}
