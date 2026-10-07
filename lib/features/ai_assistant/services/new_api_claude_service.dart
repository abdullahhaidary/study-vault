import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/ai_credential_store.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_execution_selection.dart';
import '../domain/ai_models.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_token_usage.dart';
import 'ai_output_validator.dart';
import 'ai_prompt_builder.dart';
import 'ai_service.dart';

class NewApiClaudeService implements AiService {
  NewApiClaudeService({
    required this.credentials,
    required this.settings,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final AiCredentialStore credentials;
  final AiSettingsStore settings;
  final http.Client _http;

  @override
  Future<bool> get isConfigured async =>
      await credentials.hasApiKeyFor(AiProviderId.newApi) &&
      (await settings.getNewApiBaseUrl()).isNotEmpty &&
      (await settings.getModelIdFor(AiProviderId.newApi)).length > 7;

  Future<({Uri uri, String key})> connection() async {
    final key = await credentials.readApiKeyFor(AiProviderId.newApi);
    final base = await settings.getNewApiBaseUrl();
    if (key == null || base.isEmpty) {
      throw const AiNotConfiguredException(
        'Add a New API key and HTTPS server URL in Settings.',
      );
    }
    final url = normalizeNewApiBaseUrl(base);
    return (
      uri: Uri.parse('$url${url.endsWith('/v1') ? '' : '/v1'}/messages'),
      key: key,
    );
  }

  Future<List<String>> listAvailableModels({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final conn = await connection();
    final uri = conn.uri.replace(
      path: conn.uri.path.replaceFirst(RegExp(r'/messages$'), '/models'),
    );
    late http.Response response;
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['Authorization'] = 'Bearer ${conn.key}';
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw const AiOfflineException();
    } on http.ClientException {
      throw const AiOfflineException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiInvalidKeyException('The New API key was rejected.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServerException(
        'Could not load models (HTTP ${response.statusCode}). Check the New API server URL.',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const AiServerException(
          'The server did not return a model list.',
        );
      }
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((entry) => entry['id'])
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } on AiException {
      rethrow;
    } on FormatException {
      throw const AiServerException('The server did not return a model list.');
    }
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final message = (decoded['error'] as Map)['message'];
        return message is String ? message : '';
      }
    } on FormatException {
      return '';
    }
    return '';
  }

  String modelName(String id) {
    final name = normalizeNewApiModelId(id).substring(7);
    if (name.isEmpty) {
      throw const AiNotConfiguredException(
        'Enter the Claude model ID available on your New API server in Settings.',
      );
    }
    return name;
  }

  Map<String, String> headers(String key, {bool stream = false}) => {
    'Content-Type': 'application/json',
    'anthropic-version': '2023-06-01',
    'Authorization': 'Bearer $key',
    if (stream) 'Accept': 'text/event-stream',
  };

  Map<String, Object> payload({
    required String model,
    required List<Map<String, String>> messages,
    required int maxTokens,
    required bool stream,
  }) {
    final system = messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content'] ?? '')
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    final turns = messages
        .where((m) => m['role'] != 'system')
        .map((m) => {'role': m['role'], 'content': m['content']})
        .toList();
    return {
      'model': modelName(model),
      'max_tokens': maxTokens,
      'messages': turns,
      if (system.isNotEmpty) 'system': system,
      'stream': stream,
    };
  }

  void checkStatus(int status, String body, String model) {
    if (status == 401 || status == 403) {
      throw const AiInvalidKeyException('The New API key was rejected.');
    }
    final error = _errorMessage(body).toLowerCase();
    if ((status == 400 || status == 404) &&
        (error.contains('model') || error.contains('no available channel'))) {
      throw AiUnsupportedModelException(
        'Model "${modelName(model)}" is not available for this key on your New API server. Choose an ID from Available Models in Settings.',
      );
    }
    if (status == 404) {
      throw const AiServerException(
        'New API endpoint not found (HTTP 404). Check the server base URL in Settings.',
      );
    }
    if (status == 402 ||
        body.toLowerCase().contains('quota') ||
        body.toLowerCase().contains('balance')) {
      throw const AiQuotaException();
    }
    if (status == 429) throw const AiRateLimitException();
    if (status < 200 || status >= 300) {
      throw AiServerException(
        'New API request failed (HTTP $status). Check your server URL and model.',
      );
    }
  }

  AiTokenUsage? usage(Object? data, String model) {
    if (data is! Map || data['usage'] is! Map) return null;
    final u = data['usage'] as Map;
    final input = u['input_tokens'];
    final output = u['output_tokens'];
    final cached = u['cache_read_input_tokens'];
    final created = u['cache_creation_input_tokens'];
    final prompt = input is int
        ? input + (cached is int ? cached : 0) + (created is int ? created : 0)
        : null;
    return AiTokenUsage(
      promptTokens: prompt,
      completionTokens: output is int ? output : null,
      totalTokens: prompt != null && output is int ? prompt + output : null,
      cacheHitTokens: cached is int ? cached : null,
      cacheMissTokens: input is int
          ? input + (created is int ? created : 0)
          : null,
      model: model,
      provider: AiProviderId.newApi.storageValue,
    );
  }

  Future<({String text, AiTokenUsage? usage})> completeMessages({
    required String model,
    required List<Map<String, String>> messages,
    required int maxTokens,
    Duration timeout = const Duration(seconds: 90),
    bool requireConsent = true,
  }) async {
    if (requireConsent && !await settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }
    final conn = await connection();
    late http.Response response;
    try {
      final request = http.Request('POST', conn.uri)
        ..followRedirects = false
        ..headers.addAll(headers(conn.key, stream: false))
        ..body = jsonEncode(
          payload(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            stream: false,
          ),
        );
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw const AiOfflineException();
    } on http.ClientException {
      throw const AiOfflineException();
    }
    checkStatus(response.statusCode, response.body, model);
    try {
      final data = jsonDecode(response.body);
      if (data is! Map || data['content'] is! List) {
        throw const AiMalformedOutputException();
      }
      if (data['stop_reason'] == 'max_tokens') {
        throw const AiMalformedOutputException(
          'New API reached the output limit. Try a shorter request.',
        );
      }
      final text = (data['content'] as List)
          .whereType<Map>()
          .where((b) => b['type'] == 'text' && b['text'] is String)
          .map((b) => b['text'] as String)
          .join('\n')
          .trim();
      if (text.isEmpty) throw const AiEmptyResultException();
      return (text: text, usage: usage(data, model));
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException();
    }
  }

  Stream<({String? text, AiTokenUsage? usage})> streamMessages({
    required String model,
    required List<Map<String, String>> messages,
    Duration timeout = const Duration(seconds: 120),
  }) async* {
    if (!await settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }
    final conn = await connection();
    late http.StreamedResponse response;
    try {
      final request = http.Request('POST', conn.uri)
        ..followRedirects = false
        ..headers.addAll(headers(conn.key, stream: true))
        ..body = jsonEncode(
          payload(
            model: model,
            messages: messages,
            maxTokens: 4096,
            stream: true,
          ),
        );
      response = await _http.send(request).timeout(timeout);
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw const AiOfflineException();
    } on http.ClientException {
      throw const AiOfflineException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      checkStatus(
        response.statusCode,
        await response.stream.bytesToString(),
        model,
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('application/json') &&
        !contentType.contains('event-stream')) {
      final body = await response.stream.bytesToString();
      final completed = _parseCompletedMessage(body, model);
      yield (text: completed.text, usage: completed.usage);
      return;
    }

    var buffer = '';
    var hasText = false;
    AiTokenUsage? combinedUsage;

    ({String? text, AiTokenUsage? usage})? interpretEvent(Object? event) {
      if (event is! Map) return null;
      if (event['type'] == 'error') {
        throw const AiServerException(
          'New API interrupted the response. Please try again.',
        );
      }
      if (event['type'] == 'message_delta' &&
          event['delta'] is Map &&
          (event['delta'] as Map)['stop_reason'] == 'max_tokens') {
        throw const AiMalformedOutputException(
          'New API reached the output limit. Try a shorter request.',
        );
      }

      final anthropicText = _anthropicStreamText(event);
      if (anthropicText != null && anthropicText.isNotEmpty) {
        return (text: anthropicText, usage: null);
      }
      final openAiText = _openAiStreamText(event);
      if (openAiText != null && openAiText.isNotEmpty) {
        return (text: openAiText, usage: null);
      }

      if (event['type'] == 'message_start' ||
          event['type'] == 'message_delta') {
        final data = event['message'] is Map ? event['message'] : event;
        final tokens = usage(data, model);
        if (tokens == null) return null;
        final input = tokens.promptTokens ?? combinedUsage?.promptTokens;
        final output =
            tokens.completionTokens ?? combinedUsage?.completionTokens;
        combinedUsage = AiTokenUsage(
          promptTokens: input,
          completionTokens: output,
          totalTokens: input != null && output != null ? input + output : null,
          cacheHitTokens:
              tokens.cacheHitTokens ?? combinedUsage?.cacheHitTokens,
          cacheMissTokens:
              tokens.cacheMissTokens ?? combinedUsage?.cacheMissTokens,
          model: model,
          provider: AiProviderId.newApi.storageValue,
        );
        return (text: null, usage: combinedUsage);
      }
      return null;
    }

    Iterable<({String? text, AiTokenUsage? usage})> eventsFromPayload(
      String payload,
    ) sync* {
      final trimmed = payload.trim();
      if (trimmed.isEmpty || trimmed == '[DONE]') return;
      Object? event;
      try {
        event = jsonDecode(trimmed);
      } on FormatException {
        return;
      }
      final handled = interpretEvent(event);
      if (handled == null) return;
      if (handled.text != null && handled.text!.isNotEmpty) {
        hasText = true;
      }
      yield handled;
    }

    await for (final chunk
        in response.stream
            .transform(utf8.decoder)
            .timeout(
              timeout,
              onTimeout: (sink) => sink.addError(const AiTimeoutException()),
            )) {
      buffer += chunk.replaceAll('\r', '');
      while (true) {
        final lineEnd = buffer.indexOf('\n');
        if (lineEnd < 0) break;
        final line = buffer.substring(0, lineEnd).trimRight();
        buffer = buffer.substring(lineEnd + 1);
        if (line.isEmpty || !line.startsWith('data:')) continue;
        for (final event in eventsFromPayload(line.substring(5))) {
          yield event;
        }
      }
    }

    final trailing = buffer.trim();
    if (trailing.startsWith('data:')) {
      for (final event in eventsFromPayload(trailing.substring(5))) {
        yield event;
      }
    } else if (trailing.startsWith('{')) {
      try {
        final completed = _parseCompletedMessage(trailing, model);
        hasText = true;
        yield (text: completed.text, usage: completed.usage);
      } on AiException {
        // Fall through to empty check.
      }
    }

    if (!hasText) throw const AiEmptyResultException();
  }

  String? _anthropicStreamText(Map event) {
    if (event['type'] == 'content_block_delta' &&
        event['delta'] is Map &&
        (event['delta'] as Map)['type'] == 'text_delta' &&
        (event['delta'] as Map)['text'] is String) {
      return (event['delta'] as Map)['text'] as String;
    }
    if (event['type'] == 'content_block_start' &&
        event['content_block'] is Map) {
      final block = event['content_block'] as Map;
      if (block['type'] == 'text' &&
          block['text'] is String &&
          (block['text'] as String).isNotEmpty) {
        return block['text'] as String;
      }
    }
    return null;
  }

  String? _openAiStreamText(Map event) {
    final choices = event['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return null;
    }
    final delta = (choices.first as Map)['delta'];
    if (delta is Map && delta['content'] is String) {
      return delta['content'] as String;
    }
    final message = (choices.first as Map)['message'];
    if (message is Map && message['content'] is String) {
      return message['content'] as String;
    }
    return null;
  }

  ({String text, AiTokenUsage? usage}) _parseCompletedMessage(
    String body,
    String model,
  ) {
    try {
      final data = jsonDecode(body);
      if (data is! Map) throw const AiMalformedOutputException();
      if (data['content'] is List) {
        final text = (data['content'] as List)
            .whereType<Map>()
            .where((b) => b['type'] == 'text' && b['text'] is String)
            .map((b) => b['text'] as String)
            .join('\n')
            .trim();
        if (text.isEmpty) throw const AiEmptyResultException();
        return (text: text, usage: usage(data, model));
      }
      final openAi = _openAiStreamText(data);
      if (openAi != null && openAi.trim().isNotEmpty) {
        return (text: openAi.trim(), usage: usage(data, model));
      }
      throw const AiMalformedOutputException();
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException();
    }
  }

  @override
  Future<void> testConnection({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final model = await settings.getModelIdFor(AiProviderId.newApi);
    await completeMessages(
      model: model,
      messages: const [
        {'role': 'user', 'content': 'Reply with exactly: OK'},
      ],
      maxTokens: 16,
      timeout: timeout,
      requireConsent: false,
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
        'Use Gemini to send a page image.',
      );
    }
    if (request.sourceText.trim().isEmpty) {
      throw const AiEmptySelectionException();
    }
    if (request.sourceText.length > kAiHardSourceLimit) {
      throw const AiSourceTooLargeException();
    }
    if ((request.action == AiStudyAction.askAi ||
            request.action == AiStudyAction.customPrompt) &&
        (request.customPrompt?.trim().isEmpty ?? true)) {
      throw const AiMalformedOutputException(
        'Enter a question or custom prompt first.',
      );
    }
    final preference = await settings.styleForSend(
      provider: AiProviderId.newApi,
    );
    final enriched = request.copyWith(
      userPreference: request.userPreference ?? preference,
    );
    final result = await completeMessages(
      model: request.selection.resolvedModelId,
      messages: AiPromptBuilder.deepSeekMessages(enriched),
      maxTokens: switch (request.action) {
        AiStudyAction.createAnnotation ||
        AiStudyAction.generateFlashcards ||
        AiStudyAction.generateQuestions => 8192,
        _ => 4096,
      },
      timeout: timeout,
    );
    final parsed = switch (request.action) {
      AiStudyAction.createAnnotation => AiOutputValidator.parseAnnotation(
        result.text,
        categoryNameToId: categoryNameToId,
      ),
      AiStudyAction.generateFlashcards => AiOutputValidator.parseFlashcards(
        result.text,
        expectedCount: request.flashcardCount,
      ),
      AiStudyAction.generateQuestions => AiOutputValidator.parseQuestions(
        result.text,
        expectedCount: request.questionCount,
        requestedType: request.questionType,
      ),
      _ => AiOutputValidator.textFromMarkdown(result.text),
    };
    return switch (parsed) {
      AiTextResult r => r.withUsage(result.usage),
      AiAnnotationDraft r => r.withUsage(result.usage),
      AiFlashcardsResult r => r.withUsage(result.usage),
      AiQuestionsResult r => r.withUsage(result.usage),
    };
  }

  @override
  Future<AiQuestionsResult> generateQuestions(
    AiQuestionGenerationRequest request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final result = await run(request.toStudyRequest(), timeout: timeout);
    if (result is! AiQuestionsResult) throw const AiMalformedOutputException();
    return result;
  }

  Future<AiTextResult> completeDocumentMessages({
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
    required AiExecutionSelection selection,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (messages.isEmpty) {
      throw const AiMalformedOutputException('The document prompt is empty.');
    }
    final result = await completeMessages(
      model: selection.resolvedModelId,
      messages: messages,
      maxTokens: maxOutputTokens,
      timeout: timeout,
    );
    return AiTextResult(markdown: result.text, usage: result.usage);
  }
}
