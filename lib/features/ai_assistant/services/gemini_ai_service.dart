import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/ai_credential_store.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_models.dart';
import 'ai_output_validator.dart';
import 'ai_prompt_builder.dart';
import 'ai_service.dart';

/// Gemini REST client using generateContent (official Google AI API).
class GeminiAiService implements AiService {
  GeminiAiService({
    required AiCredentialStore credentials,
    required AiSettingsStore settings,
    http.Client? httpClient,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _credentials = credentials,
       _settings = settings,
       _http = httpClient ?? http.Client();

  final AiCredentialStore _credentials;
  final AiSettingsStore _settings;
  final http.Client _http;
  final String baseUrl;

  @override
  Future<bool> get isConfigured => _credentials.hasApiKey;

  @override
  Future<void> testConnection({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final key = await _requireKey();
    final model = await _settings.getModelId();
    final body = {
      'contents': [
        {
          'parts': [
            {'text': 'Reply with exactly: OK'},
          ],
        },
      ],
      'generationConfig': {'maxOutputTokens': 16},
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
    final key = await _requireKey();
    if (!await _settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }
    final model = await _settings.getModelId();
    final preference = await _settings.getStudyPreference();
    final enriched = AiStudyRequest(
      action: request.action,
      sourceText: request.sourceText,
      language: request.language,
      rephraseMode: request.rephraseMode,
      organizeMode: request.organizeMode,
      summarizeMode: request.summarizeMode,
      questionType: request.questionType,
      flashcardCount: request.flashcardCount,
      categoryNames: request.categoryNames,
      userPreference: request.userPreference ?? preference,
      selectedText: request.selectedText,
      shortDescription: request.shortDescription,
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
        if (structured != null) ...{
          'responseMimeType': 'application/json',
          'responseSchema': structured,
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
    // Technical log only — no prompt/response content.
    assert(() {
      // ignore: avoid_print
      print(
        'AI ${request.action.name} ok in '
        '${DateTime.now().difference(started).inMilliseconds}ms',
      );
      return true;
    }());

    return switch (request.action) {
      AiStudyAction.explain ||
      AiStudyAction.simplify ||
      AiStudyAction.rephrase ||
      AiStudyAction.fixGrammar ||
      AiStudyAction.organize ||
      AiStudyAction.summarize =>
        AiOutputValidator.textFromMarkdown(text),
      AiStudyAction.createAnnotation => AiOutputValidator.parseAnnotation(
        text,
        categoryNameToId: categoryNameToId,
      ),
      AiStudyAction.generateFlashcards => AiOutputValidator.parseFlashcards(
        text,
        expectedCount: request.flashcardCount,
      ),
      AiStudyAction.generateQuestions => AiOutputValidator.parseQuestions(text),
    };
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
    final key = await _credentials.readApiKey();
    if (key == null || key.isEmpty) {
      throw const AiNotConfiguredException();
    }
    return key;
  }

  void _assertSourceSize(String source) {
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

    if (response.statusCode == 400 || response.statusCode == 403) {
      final msg = _errorMessage(response.body).toLowerCase();
      if (msg.contains('api key') ||
          msg.contains('permission') ||
          msg.contains('invalid')) {
        throw const AiInvalidKeyException();
      }
      if (msg.contains('not found') || msg.contains('model')) {
        throw const AiUnsupportedModelException();
      }
      throw AiServerException('Gemini rejected the request.');
    }
    if (response.statusCode == 404) {
      throw const AiUnsupportedModelException();
    }
    if (response.statusCode == 429) {
      final msg = _errorMessage(response.body).toLowerCase();
      if (msg.contains('quota')) throw const AiQuotaException();
      throw const AiRateLimitException();
    }
    if (response.statusCode >= 500) {
      throw const AiServerException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AiServerException();
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const AiMalformedOutputException();
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const AiEmptyResultException();
      }
      final content = candidates.first['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List || parts.isEmpty) {
        throw const AiEmptyResultException();
      }
      final buffer = StringBuffer();
      for (final part in parts) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text']);
        }
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
