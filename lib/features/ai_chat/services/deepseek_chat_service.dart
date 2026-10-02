import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../ai_assistant/data/ai_credential_store.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/deepseek_model_registry.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../domain/ai_chat_models.dart';
import 'gemini_chat_service.dart';

/// DeepSeek OpenAI-compatible chat transport (`/chat/completions`).
class HttpDeepSeekChatService implements AiChatTransport {
  HttpDeepSeekChatService({
    required this.credentials,
    required this.settings,
    http.Client? httpClient,
    this.baseUrl = 'https://api.deepseek.com',
  }) : _http = httpClient ?? http.Client();

  final AiCredentialStore credentials;
  final AiSettingsStore settings;
  final http.Client _http;
  final String baseUrl;

  static const maxContextChars = 80000;
  static const maxContextMessages = 40;
  static const _provider = AiProviderId.deepseek;

  @override
  Future<bool> get isConfigured => credentials.hasApiKeyFor(_provider);

  @override
  Future<List<AiSelectableModel>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    // Prefer static allowlist; optionally verify via /models.
    try {
      final key = await credentials.readApiKeyFor(_provider);
      if (key == null || key.isEmpty) return _fallbackModels();
      final uri = Uri.parse('$baseUrl/models');
      final response = await _http
          .get(uri, headers: {'Authorization': 'Bearer $key'})
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackModels();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return _fallbackModels();
      final data = decoded['data'];
      if (data is! List) return _fallbackModels();
      final ids = <String>{};
      for (final item in data) {
        if (item is Map && item['id'] is String) {
          ids.add((item['id'] as String).toLowerCase());
        }
      }
      final matched = DeepSeekModelRegistry.selectableModels()
          .where((m) => ids.contains(m.id) || ids.contains('deepseek-v4-flash'))
          .map(AiSelectableModel.fromDeepSeek)
          .toList(growable: false);
      return matched.isEmpty ? _fallbackModels() : matched;
    } on Object {
      return _fallbackModels();
    }
  }

  List<AiSelectableModel> _fallbackModels() =>
      DeepSeekModelRegistry.selectableModels()
          .map(AiSelectableModel.fromDeepSeek)
          .toList(growable: false);

  @override
  Future<AiChatCompletion> complete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final key = await _requireKey();
    if (!await settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }
    final model = DeepSeekModelRegistry.normalize(modelId);
    final thinking = await settings.getThinkingMode();
    final preference = await settings.getStudyPreference();
    final messages = _buildMessages(history, preference);
    final text = await _postChat(
      apiKey: key,
      model: model,
      messages: messages,
      thinking: thinking,
      stream: false,
      timeout: timeout,
    );
    return AiChatCompletion(text: text, modelId: model);
  }

  @override
  Stream<String> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 120),
  }) async* {
    final key = await _requireKey();
    if (!await settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }
    final model = DeepSeekModelRegistry.normalize(modelId);
    final thinking = await settings.getThinkingMode();
    final preference = await settings.getStudyPreference();
    final messages = _buildMessages(history, preference);

    final uri = Uri.parse('$baseUrl/chat/completions');
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
      'max_tokens': 4096,
      ..._thinkingPayload(thinking),
    };

    late http.StreamedResponse response;
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        })
        ..body = jsonEncode(body);
      response = await _http.send(request).timeout(timeout);
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw const AiOfflineException();
    } on http.ClientException {
      throw const AiOfflineException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = await response.stream.bytesToString();
      _throwForStatus(status: response.statusCode, body: raw, model: model);
    }

    final full = StringBuffer();
    var lineBuffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      lineBuffer += chunk;
      while (true) {
        final idx = lineBuffer.indexOf('\n');
        if (idx < 0) break;
        final line = lineBuffer.substring(0, idx).trimRight();
        lineBuffer = lineBuffer.substring(idx + 1);
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;
        final delta = _extractContentDelta(payload);
        if (delta == null || delta.isEmpty) continue;
        full.write(delta);
        yield delta;
      }
    }

    if (full.isEmpty) {
      throw const AiEmptyResultException();
    }
  }

  List<Map<String, String>> _buildMessages(
    List<AiChatTurn> history,
    String? studyPreference,
  ) {
    final trimmed = _trimHistory(history);
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'You are Study Vault AI Assistant for university students.\n'
            'Ground answers in any study material the user shares.\n'
            'Preserve formulas, code, variable names, and technical terminology.\n'
            'Keep responses useful for studying.\n'
            '${(studyPreference == null || studyPreference.trim().isEmpty) ? '' : 'User study preference: ${studyPreference.trim()}\n'}',
      },
    ];
    for (final turn in trimmed) {
      final role = switch (turn.role) {
        AiChatRole.assistant => 'assistant',
        AiChatRole.system => 'system',
        _ => 'user',
      };
      messages.add({'role': role, 'content': turn.content});
    }
    return messages;
  }

  List<AiChatTurn> _trimHistory(List<AiChatTurn> history) {
    if (history.isEmpty) return history;
    var slice = history.length > maxContextMessages
        ? history.sublist(history.length - maxContextMessages)
        : List<AiChatTurn>.of(history);
    var total = slice.fold<int>(0, (sum, t) => sum + t.content.length);
    while (slice.length > 2 && total > maxContextChars) {
      total -= slice.first.content.length;
      slice = slice.sublist(1);
    }
    return slice;
  }

  Map<String, dynamic> _thinkingPayload(AiThinkingMode mode) {
    final effort = switch (mode) {
      AiThinkingMode.low => 'low',
      AiThinkingMode.high => 'high',
      AiThinkingMode.max => 'max',
      AiThinkingMode.auto => 'low',
    };
    return {
      'thinking': {'type': 'enabled'},
      'reasoning_effort': effort,
    };
  }

  Future<String> _postChat({
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    required AiThinkingMode thinking,
    required bool stream,
    required Duration timeout,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': stream,
      'max_tokens': 4096,
      ..._thinkingPayload(thinking),
    };

    late http.Response response;
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwForStatus(
        status: response.statusCode,
        body: response.body,
        model: model,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const AiMalformedOutputException();
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AiEmptyResultException();
      }
      final message = choices.first is Map
          ? (choices.first as Map)['message']
          : null;
      if (message is! Map) throw const AiMalformedOutputException();
      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const AiEmptyResultException();
      }
      return content.trim();
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException();
    }
  }

  String? _extractContentDelta(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final delta = choices.first is Map
          ? (choices.first as Map)['delta']
          : null;
      if (delta is! Map) return null;
      // Ignore reasoning_content deltas.
      final content = delta['content'];
      return content is String ? content : null;
    } on Object {
      return null;
    }
  }

  void _throwForStatus({
    required int status,
    required String body,
    required String model,
  }) {
    final message = _errorMessage(body).toLowerCase();
    if (status == 401 || status == 403) {
      throw const AiInvalidKeyException(
        'The DeepSeek API key appears to be invalid.',
      );
    }
    if (status == 404 || message.contains('model')) {
      throw AiUnsupportedModelException(
        'Model "$model" is not available. Pick DeepSeek Flash in Settings.',
      );
    }
    if (status == 402 ||
        message.contains('balance') ||
        message.contains('quota') ||
        message.contains('insufficient')) {
      throw const AiQuotaException();
    }
    if (status == 429) throw const AiRateLimitException();
    throw AiServerException('DeepSeek chat error ($status). Please try again.');
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

  Future<String> _requireKey() async {
    final key = await credentials.readApiKeyFor(_provider);
    if (key == null || key.isEmpty) {
      throw const AiNotConfiguredException(
        'DeepSeek is not configured yet. Add an API key in Settings.',
      );
    }
    return key;
  }
}

/// Routes chat calls to the Settings-selected provider.
class RoutingAiChatTransport implements AiChatTransport {
  RoutingAiChatTransport({
    required this.settings,
    required this.gemini,
    required this.deepseek,
  });

  final AiSettingsStore settings;
  final AiChatTransport gemini;
  final AiChatTransport deepseek;

  Future<AiChatTransport> _active() async {
    final provider = await settings.getProvider();
    return switch (provider) {
      AiProviderId.gemini => gemini,
      AiProviderId.deepseek => deepseek,
    };
  }

  /// Prefer transport matching the chat's model id when known.
  Future<AiChatTransport> _forModel(String modelId) async {
    final inferred = AiProviderIdX.fromModelId(modelId);
    final selected = await settings.getProvider();
    // Historical chats keep their original provider/model.
    if (inferred != selected && DeepSeekModelRegistry.isKnown(modelId)) {
      return deepseek;
    }
    if (inferred != selected && modelId.toLowerCase().startsWith('gemini')) {
      return gemini;
    }
    return _active();
  }

  @override
  Future<bool> get isConfigured async => (await _active()).isConfigured;

  @override
  Future<List<AiSelectableModel>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    Future<List<AiSelectableModel>> safeList(AiChatTransport t) async {
      try {
        return await t.listAvailableChatModels(timeout: timeout);
      } on Object {
        return const [];
      }
    }

    final lists = await Future.wait([
      safeList(gemini),
      safeList(deepseek),
    ]);
    final geminiModels = lists[0].isEmpty
        ? GeminiModelRegistry.fallbackChatModels()
              .map(AiSelectableModel.fromGemini)
              .toList(growable: false)
        : lists[0];
    final deepseekModels = lists[1].isEmpty
        ? DeepSeekModelRegistry.selectableModels()
              .map(AiSelectableModel.fromDeepSeek)
              .toList(growable: false)
        : lists[1];
    return [...geminiModels, ...deepseekModels];
  }

  @override
  Future<AiChatCompletion> complete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    return (await _forModel(
      modelId,
    )).complete(modelId: modelId, history: history, timeout: timeout);
  }

  @override
  Stream<String> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 120),
  }) async* {
    yield* (await _forModel(
      modelId,
    )).streamComplete(modelId: modelId, history: history, timeout: timeout);
  }
}
