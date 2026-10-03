import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_execution_selection.dart';
import '../domain/ai_models.dart';
import '../domain/ai_provider.dart';
import '../domain/gemini_model_registry.dart';
import 'ai_service.dart';

/// Routes study AI calls using the request's [AiExecutionSelection].
///
/// Page images always go to Gemini (DeepSeek has no vision).
class RoutingAiService implements AiService {
  RoutingAiService({
    required this.settings,
    required this.gemini,
    required this.deepseek,
    this.newApi,
  });

  final AiSettingsStore settings;
  final AiService gemini;
  final AiService deepseek;
  final AiService? newApi;

  Future<AiService> _forProvider(AiProviderId provider) {
    return Future.value(switch (provider) {
      AiProviderId.gemini => gemini,
      AiProviderId.deepseek => deepseek,
      AiProviderId.newApi =>
        newApi ??
            (throw const AiNotConfiguredException(
              'New API is not configured.',
            )),
    });
  }

  Future<AiService> _forImage() async {
    if (!await gemini.isConfigured) {
      throw const AiNotConfiguredException(
        'Add a Gemini API key in Settings to send a page as an image.',
      );
    }
    return gemini;
  }

  Future<AiService> _activeFromSettings() async {
    final provider = await settings.getProvider();
    return _forProvider(provider);
  }

  @override
  Future<bool> get isConfigured async =>
      (await _activeFromSettings()).isConfigured;

  @override
  Future<void> testConnection({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await (await _activeFromSettings()).testConnection(timeout: timeout);
  }

  @override
  Future<AiStudyResult> run(
    AiStudyRequest request, {
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final effective = request.hasPageImage
        ? _ensureGeminiSelection(request)
        : request;
    final service = effective.hasPageImage
        ? await _forImage()
        : await _forProvider(effective.selection.provider);
    return service.run(
      effective,
      categoryNameToId: categoryNameToId,
      timeout: timeout,
    );
  }

  @override
  Future<AiQuestionsResult> generateQuestions(
    AiQuestionGenerationRequest request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final effective = request.image != null
        ? _ensureGeminiQuestionSelection(request)
        : request;
    final service = effective.image != null
        ? await _forImage()
        : await _forProvider(effective.selection.provider);
    return service.generateQuestions(effective, timeout: timeout);
  }

  AiStudyRequest _ensureGeminiSelection(AiStudyRequest request) {
    if (request.selection.provider == AiProviderId.gemini) return request;
    return request.copyWith(
      selection: AiExecutionSelection.resolve(
        provider: AiProviderId.gemini,
        requestedModelId: GeminiModelRegistry.defaultModelId,
        action: request.action,
      ),
    );
  }

  AiQuestionGenerationRequest _ensureGeminiQuestionSelection(
    AiQuestionGenerationRequest request,
  ) {
    if (request.selection.provider == AiProviderId.gemini) return request;
    return AiQuestionGenerationRequest(
      sourceText: request.sourceText,
      count: request.count,
      type: request.type,
      difficulty: request.difficulty,
      selection: AiExecutionSelection.resolve(
        provider: AiProviderId.gemini,
        requestedModelId: GeminiModelRegistry.defaultModelId,
        action: AiStudyAction.generateQuestions,
      ),
      language: request.language,
      userPreference: request.userPreference,
      pageNumber: request.pageNumber,
      image: request.image,
    );
  }
}
