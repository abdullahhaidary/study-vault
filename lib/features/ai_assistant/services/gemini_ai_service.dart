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
import '../domain/gemini_model_registry.dart';
import 'ai_output_validator.dart';
import 'ai_prompt_builder.dart';
import 'ai_service.dart';

/// Gemini REST client using generateContent (official Google AI API).
class GeminiAiService implements AiService {
  GeminiAiService({
    required this.credentials,
    required this.settings,
    http.Client? httpClient,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _http = httpClient ?? http.Client();

  final AiCredentialStore credentials;
  final AiSettingsStore settings;
  final http.Client _http;
  final String baseUrl;

  static const _provider = AiProviderId.gemini;

  @override
  Future<bool> get isConfigured => credentials.hasApiKeyFor(_provider);

  @override
  Future<void> testConnection({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final key = await _requireKey();
    final model = GeminiModelRegistry.normalize(
      await settings.getModelIdFor(_provider),
    );
    final body = {
      'contents': [
        {
          'parts': [
            {'text': 'Reply with exactly: OK'},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 64,
        // 2.5 Flash thinking can consume a tiny token budget with no visible text.
        'thinkingConfig': {'thinkingBudget': 0},
      },
    };
    await _postGenerate(
      model: model,
      apiKey: key,
      body: body,
      timeout: timeout,
    );
  }

  @override
  Future<AiStudyResult> run(
    AiStudyRequest request, {
    Map<String, String> categoryNameToId = const {},
    Duration timeout = const Duration(seconds: 60),
  }) async {
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
    final model = GeminiModelRegistry.normalize(
      await settings.getModelIdFor(_provider),
    );
    final preference = await settings.getStudyPreference();
    final enriched = request.copyWith(
      userPreference: request.userPreference ?? preference,
    );

    final prompt = AiPromptBuilder.forRequest(enriched);
    final structured = _schemaFor(request.action);
    final body = <String, dynamic>{
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 8192,
        'thinkingConfig': {'thinkingBudget': 0},
        if (structured != null) ...{
          'responseMimeType': 'application/json',
          // Prefer JSON Schema field (responseSchema is deprecated).
          'responseJsonSchema': structured,
        },
      },
    };

    final started = DateTime.now();
    final text = await _postGenerate(
      model: model,
      apiKey: key,
      body: body,
      timeout: timeout,
    );
    assert(() {
      // Never log source/PDF content or API keys — action + timing only.
      // ignore: avoid_print
      print(
        'AI ${request.action.name} model=$model ok in '
        '${DateTime.now().difference(started).inMilliseconds}ms '
        'chars=${request.effectiveSourceLength} responseChars=${text.length}',
      );
      return true;
    }());

    try {
      return switch (request.action) {
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
    } on AiException catch (e) {
      assert(() {
        // ignore: avoid_print
        print(
          'AI ${request.action.name} PARSE FAILED: ${e.message} '
          'responseChars=${text.length}',
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
        'Gemini did not return quiz questions.',
      );
    }
    return result;
  }

  Map<String, dynamic>? _schemaFor(AiStudyAction action) {
    return switch (action) {
      AiStudyAction.createAnnotation => AiResponseSchemas.annotation,
      AiStudyAction.generateFlashcards => AiResponseSchemas.flashcards,
      AiStudyAction.generateQuestions => AiResponseSchemas.questions,
      _ => null,
    };
  }

  Future<String> _requireKey() async {
    final key = await credentials.readApiKeyFor(_provider);
    if (key == null || key.isEmpty) {
      throw const AiNotConfiguredException(
        'Gemini is not configured yet. Add an API key in Settings.',
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

  Future<String> _postGenerate({
    required String model,
    required String apiKey,
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    final uri = Uri.parse('$baseUrl/models/$model:generateContent');
    late http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
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

    final apiMessage = _errorMessage(response.body);
    final lower = apiMessage.toLowerCase();

    if (response.statusCode == 400 || response.statusCode == 403) {
      if (lower.contains('api key') ||
          lower.contains('api_key') ||
          lower.contains('permission') ||
          lower.contains('permission_denied') ||
          lower.contains('invalid')) {
        throw const AiInvalidKeyException();
      }
      if (lower.contains('not found') ||
          lower.contains('is not found') ||
          lower.contains('model')) {
        throw AiUnsupportedModelException(
          'Model "$model" is not available for this API key. '
          'Pick Recommended (Gemini 3.8 Flash) in Settings.',
        );
      }
      throw AiServerException(
        _friendlyApiFailure(status: response.statusCode, message: apiMessage),
      );
    }
    if (response.statusCode == 404) {
      throw AiUnsupportedModelException(
        'Model "$model" was not found. '
        'Pick Recommended (Gemini 3.8 Flash) in Settings.',
      );
    }
    if (response.statusCode == 429) {
      if (lower.contains('quota')) throw const AiQuotaException();
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
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        final block = decoded['promptFeedback'];
        if (block is Map) {
          throw const AiServerException(
            'Gemini blocked this request. Try different text.',
          );
        }
        throw const AiEmptyResultException();
      }
      final candidate = candidates.first;
      if (candidate is! Map) throw const AiMalformedOutputException();
      final finish = '${candidate['finishReason'] ?? ''}';
      final content = candidate['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List || parts.isEmpty) {
        if (finish == 'MAX_TOKENS') {
          throw const AiServerException(
            'Gemini ran out of output tokens before finishing. Try again.',
          );
        }
        throw const AiEmptyResultException();
      }
      final buffer = StringBuffer();
      for (final part in parts) {
        if (part is! Map) continue;
        // Skip thought parts if any slip through.
        if (part['thought'] == true) continue;
        if (part['text'] is String) buffer.write(part['text']);
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) throw const AiEmptyResultException();
      return text;
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException();
    }
  }

  String _friendlyApiFailure({required int status, required String message}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Gemini request failed (HTTP $status). Check model and API key.';
    }
    // Never include secrets; API messages do not contain the key value.
    final short = trimmed.length > 180
        ? '${trimmed.substring(0, 180)}…'
        : trimmed;
    return 'Gemini error ($status): $short';
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
      }
    } on Object {
      // ignore
    }
    return '';
  }
}
