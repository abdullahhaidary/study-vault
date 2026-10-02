import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/ai_credential_store.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_models.dart';
import '../domain/ai_provider.dart';
import '../domain/deepseek_model_registry.dart';
import '../domain/ai_token_usage.dart';
import '../domain/deepseek_usage.dart';
import 'ai_output_validator.dart';
import 'ai_prompt_builder.dart';
import 'ai_service.dart';

/// DeepSeek OpenAI-compatible client (`POST /chat/completions`).
///
/// Reuses [AiPromptBuilder] + [AiOutputValidator]. Never exposes keys or
/// reasoning traces to callers — only final `content`.
class DeepSeekAiService implements AiService {
  DeepSeekAiService({
    required this.credentials,
    required this.settings,
    http.Client? httpClient,
    this.baseUrl = 'https://api.deepseek.com',
  }) : _http = httpClient ?? http.Client();

  final AiCredentialStore credentials;
  final AiSettingsStore settings;
  final http.Client _http;
  final String baseUrl;

  static const _provider = AiProviderId.deepseek;

  @override
  Future<bool> get isConfigured => credentials.hasApiKeyFor(_provider);

  @override
  Future<void> testConnection({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final key = await _requireKey();
    final model = await _resolveModel(action: null);
    await _chatCompletions(
      apiKey: key,
      model: model,
      messages: const [
        {'role': 'user', 'content': 'Reply with exactly: OK'},
      ],
      maxTokens: 16,
      jsonMode: false,
      thinking: AiThinkingMode.low,
      timeout: timeout,
    );
  }

  @override
  Future<AiStudyResult> run(
    AiStudyRequest request, {
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (request.image != null) {
      throw const AiMalformedOutputException(
        'Add a Gemini API key in Settings to send a page as an image.',
      );
    }
    _assertSourceSize(request.sourceText);
    if ((request.action == AiStudyAction.askAi ||
            request.action == AiStudyAction.customPrompt) &&
        (request.customPrompt == null ||
            request.customPrompt!.trim().isEmpty)) {
      throw const AiMalformedOutputException(
        'Enter a question or custom prompt first.',
      );
    }
    final key = await _requireKey();
    if (!await settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }

    final preference = await settings.getStudyPreference();
    final enriched = request.copyWith(
      userPreference: request.userPreference ?? preference,
    );
    final model = await _resolveModel(action: request.action);
    final thinking = await _resolveThinking(action: request.action);
    final structured = _isStructured(request.action);
    final messages = AiPromptBuilder.deepSeekMessages(enriched);

    final started = DateTime.now();
    final completion = await _chatCompletions(
      apiKey: key,
      model: model,
      messages: messages,
      maxTokens: structured ? 8192 : 4096,
      jsonMode: structured,
      thinking: thinking,
      timeout: timeout,
    );
    final text = completion.text;
    final usage = completion.usage;

    assert(() {
      // Never log source/PDF content or API keys — action + timing only.
      // ignore: avoid_print
      print(
        'AI ${request.action.name} provider=deepseek model=$model ok in '
        '${DateTime.now().difference(started).inMilliseconds}ms '
        'chars=${request.effectiveSourceLength} responseChars=${text.length}',
      );
      return true;
    }());

    try {
      final result = switch (request.action) {
        AiStudyAction.explain ||
        AiStudyAction.simplify ||
        AiStudyAction.rephrase ||
        AiStudyAction.fixGrammar ||
        AiStudyAction.organize ||
        AiStudyAction.summarize ||
        AiStudyAction.define ||
        AiStudyAction.giveExample ||
        AiStudyAction.translate ||
        AiStudyAction.askAi ||
        AiStudyAction.customPrompt ||
        AiStudyAction.keyConcepts ||
        AiStudyAction.examPoints => AiOutputValidator.textFromMarkdown(text),
        AiStudyAction.createAnnotation => AiOutputValidator.parseAnnotation(
          text,
          categoryNameToId: categoryNameToId,
        ),
        AiStudyAction.generateFlashcards => AiOutputValidator.parseFlashcards(
          text,
          expectedCount: request.flashcardCount,
        ),
        AiStudyAction.generateQuestions => AiOutputValidator.parseQuestions(
          text,
          expectedCount: request.questionCount,
          requestedType: request.questionType,
        ),
      };
      return switch (result) {
        AiTextResult r => r.withUsage(usage),
        AiAnnotationDraft r => r.withUsage(usage),
        AiFlashcardsResult r => r.withUsage(usage),
        AiQuestionsResult r => r.withUsage(usage),
      };
    } on AiException catch (e) {
      assert(() {
        // ignore: avoid_print
        print(
          'AI ${request.action.name} provider=deepseek PARSE FAILED: '
          '${e.message} responseChars=${text.length}',
        );
        return true;
      }());
      rethrow;
    }
  }

  @override
  Future<AiQuestionsResult> generateQuestions(
    AiQuestionGenerationRequest request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final result = await run(request.toStudyRequest(), timeout: timeout);
    if (result is! AiQuestionsResult) {
      throw const AiMalformedOutputException(
        'DeepSeek did not return quiz questions.',
      );
    }
    return result;
  }

  bool _isStructured(AiStudyAction action) => switch (action) {
    AiStudyAction.createAnnotation ||
    AiStudyAction.generateFlashcards ||
    AiStudyAction.generateQuestions => true,
    _ => false,
  };

  Future<String> _resolveModel({required AiStudyAction? action}) async {
    final stored = await settings.getModelIdFor(_provider);
    return resolveActiveModelId(
      provider: _provider,
      storedModelId: stored,
      action: action,
    );
  }

  Future<AiThinkingMode> _resolveThinking({
    required AiStudyAction action,
  }) async {
    final pref = await settings.getThinkingMode();
    if (pref != AiThinkingMode.auto) return pref;

    // Auto: cheap for inline/quick study; higher for structured/hard work.
    return switch (action) {
      AiStudyAction.explain ||
      AiStudyAction.simplify ||
      AiStudyAction.define ||
      AiStudyAction.translate ||
      AiStudyAction.summarize ||
      AiStudyAction.giveExample ||
      AiStudyAction.fixGrammar ||
      AiStudyAction.rephrase => AiThinkingMode.low,
      AiStudyAction.generateQuestions ||
      AiStudyAction.generateFlashcards ||
      AiStudyAction.createAnnotation ||
      AiStudyAction.customPrompt ||
      AiStudyAction.examPoints => AiThinkingMode.high,
      _ => AiThinkingMode.low,
    };
  }

  Future<String> _requireKey() async {
    final key = await credentials.readApiKeyFor(_provider);
    if (key == null || key.isEmpty) {
      throw const AiNotConfiguredException(
        'DeepSeek is not configured yet. Add an API key in Settings.',
      );
    }
    return key;
  }

  void _assertSourceSize(String source) {
    if (source.trim().isEmpty) {
      throw const AiEmptySelectionException();
    }
    if (source.length > kAiHardSourceLimit) {
      throw const AiSourceTooLargeException();
    }
  }

  Future<({String text, AiTokenUsage? usage})> _chatCompletions({
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    required int maxTokens,
    required bool jsonMode,
    required AiThinkingMode thinking,
    required Duration timeout,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final body = <String, dynamic>{
      'model': DeepSeekModelRegistry.normalize(model),
      'messages': messages,
      'max_tokens': maxTokens,
      'stream': false,
      ..._thinkingPayload(thinking),
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    late http.Response response;
    final started = DateTime.now();
    try {
      response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw const AiOfflineException();
    } on http.ClientException {
      throw const AiOfflineException();
    }

    return _parseCompletionResponse(
      response: response,
      model: model,
      durationMs: DateTime.now().difference(started).inMilliseconds,
    );
  }

  Map<String, dynamic> _thinkingPayload(AiThinkingMode mode) {
    // Official Chat Completions: thinking.type + reasoning_effort.
    // Never surface reasoning_content to the user.
    return switch (mode) {
      AiThinkingMode.low => {
        'thinking': {'type': 'enabled'},
        'reasoning_effort': 'low',
      },
      AiThinkingMode.high => {
        'thinking': {'type': 'enabled'},
        'reasoning_effort': 'high',
      },
      AiThinkingMode.max => {
        'thinking': {'type': 'enabled'},
        'reasoning_effort': 'max',
      },
      AiThinkingMode.auto => {
        'thinking': {'type': 'enabled'},
        'reasoning_effort': 'low',
      },
    };
  }

  ({String text, AiTokenUsage? usage}) _parseCompletionResponse({
    required http.Response response,
    required String model,
    int? durationMs,
  }) {
    final apiMessage = _errorMessage(response.body);
    final lower = apiMessage.toLowerCase();

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiInvalidKeyException(
        'The DeepSeek API key appears to be invalid.',
      );
    }
    if (response.statusCode == 400) {
      if (lower.contains('api key') ||
          lower.contains('authentication') ||
          lower.contains('unauthorized') ||
          lower.contains('invalid')) {
        throw const AiInvalidKeyException(
          'The DeepSeek API key appears to be invalid.',
        );
      }
      if (lower.contains('model')) {
        throw AiUnsupportedModelException(
          'Model "$model" is not available for this DeepSeek API key. '
          'Pick DeepSeek Flash in Settings.',
        );
      }
      throw AiServerException(
        _friendlyApiFailure(status: response.statusCode, message: apiMessage),
      );
    }
    if (response.statusCode == 404) {
      throw AiUnsupportedModelException(
        'Model "$model" was not found. Pick DeepSeek Flash in Settings.',
      );
    }
    if (response.statusCode == 402 ||
        lower.contains('insufficient') ||
        lower.contains('balance') ||
        lower.contains('quota')) {
      throw const AiQuotaException(
        'DeepSeek balance or quota exceeded. Check your DeepSeek account.',
      );
    }
    if (response.statusCode == 429) {
      if (lower.contains('quota') || lower.contains('balance')) {
        throw const AiQuotaException();
      }
      throw const AiRateLimitException();
    }
    if (response.statusCode >= 500) {
      throw AiServerException(
        _friendlyApiFailure(status: response.statusCode, message: apiMessage),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServerException(
        _friendlyApiFailure(status: response.statusCode, message: apiMessage),
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const AiMalformedOutputException();
      final usage = AiTokenUsage.fromProviderResponse(
        decoded,
        model: model,
        provider: 'deepseek',
        durationMs: durationMs,
      );
      logDeepSeekUsage(model: model, usage: usage, durationMs: durationMs);
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AiEmptyResultException();
      }
      final choice = choices.first;
      if (choice is! Map) throw const AiMalformedOutputException();
      final message = choice['message'];
      if (message is! Map) throw const AiMalformedOutputException();
      // Ignore reasoning_content — never expose chain-of-thought to UI.
      final content = message['content'];
      if (content is! String) throw const AiEmptyResultException();
      final text = content.trim();
      if (text.isEmpty) throw const AiEmptyResultException();
      return (text: text, usage: usage);
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException();
    }
  }

  String _friendlyApiFailure({required int status, required String message}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'DeepSeek request failed (HTTP $status). Check model and API key.';
    }
    final short = trimmed.length > 180
        ? '${trimmed.substring(0, 180)}…'
        : trimmed;
    return 'DeepSeek error ($status): $short';
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
        if (err is String) return err;
      }
    } on Object {
      // ignore
    }
    return '';
  }
}
