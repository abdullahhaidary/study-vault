import '../data/ai_settings_store.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_models.dart';
import '../domain/ai_provider.dart';
import 'ai_service.dart';

/// Routes study AI calls to the user-selected provider without leaking
/// `if (gemini)` / `if (deepseek)` into feature UI.
///
/// Page images always go to Gemini (DeepSeek has no vision).
class RoutingAiService implements AiService {
  RoutingAiService({
    required this.settings,
    required this.gemini,
    required this.deepseek,
  });

  final AiSettingsStore settings;
  final AiService gemini;
  final AiService deepseek;

  Future<AiService> _active() async {
    final provider = await settings.getProvider();
    return switch (provider) {
      AiProviderId.gemini => gemini,
      AiProviderId.deepseek => deepseek,
    };
  }

  Future<AiService> _forImage() async {
    if (!await gemini.isConfigured) {
      throw const AiNotConfiguredException(
        'Add a Gemini API key in Settings to send a page as an image.',
      );
    }
    return gemini;
  }

  @override
  Future<bool> get isConfigured async => (await _active()).isConfigured;

  @override
  Future<void> testConnection({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await (await _active()).testConnection(timeout: timeout);
  }

  @override
  Future<AiStudyResult> run(
    AiStudyRequest request, {
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final service = request.hasPageImage ? await _forImage() : await _active();
    return service.run(
      request,
      categoryNameToId: categoryNameToId,
      timeout: timeout,
    );
  }

  @override
  Future<AiQuestionsResult> generateQuestions(
    AiQuestionGenerationRequest request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final service = request.image != null ? await _forImage() : await _active();
    return service.generateQuestions(request, timeout: timeout);
  }
}
