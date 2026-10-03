import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../ai_assistant/data/ai_credential_store.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/deepseek_model_registry.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../../ai_assistant/domain/deepseek_usage.dart';
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
    final result = await _postChat(
      apiKey: key,
      model: model,
      messages: messages,
      thinking: thinking,
      stream: false,
      timeout: timeout,
    );
    return AiChatCompletion(
      text: result.text,
      modelId: model,
      usage: result.usage,
    );
  }

  @override
  Stream<AiChatStreamEvent> streamComplete({
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
      'stream_options': {'include_usage': true},
      ..._thinkingPayload(thinking),
    };

    final started = DateTime.now();

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
    AiTokenUsage? usage;
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
        final decoded = _tryDecodeJson(payload);
        final chunkUsage = AiTokenUsage.fromProviderResponse(
          decoded,
          model: model,
          provider: 'deepseek',
        );
        if (chunkUsage != null) usage = chunkUsage;
        final delta = _extractContentDelta(payload);
        if (delta == null || delta.isEmpty) continue;
        full.write(delta);
        yield AiChatStreamEvent(textDelta: delta);
      }
    }

    final durationMs = DateTime.now().difference(started).inMilliseconds;
    final finalUsage = usage?.copyWith(
      model: model,
      provider: 'deepseek',
      durationMs: durationMs,
    );
    logDeepSeekUsage(model: model, usage: finalUsage, durationMs: durationMs);
    if (finalUsage != null) {
      yield AiChatStreamEvent(usage: finalUsage);
    }

    if (full.isEmpty) {
      throw const AiEmptyResultException();
    }
  }

  List<Map<String, String>> _buildMessages(
    List<AiChatTurn> history,
    String? studyPreference,
  ) {
    final trimmed = trimHistoryPreservingDocument(history);
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

  /// Public for tests: keep system/document prefix, drop oldest Q/A first.
  static List<AiChatTurn> trimHistoryPreservingDocument(
    List<AiChatTurn> history, {
    int maxMessages = maxContextMessages,
    int maxChars = maxContextChars,
  }) {
    if (history.isEmpty) return history;

    final pinned = <AiChatTurn>[];
    final rest = <AiChatTurn>[];
    var seenDocument = false;
    for (final turn in history) {
      if (turn.role == AiChatRole.system) {
        pinned.add(turn);
        continue;
      }
      if (!seenDocument &&
          turn.role == AiChatRole.user &&
          (turn.pinForCache || _looksLikeDocumentTurn(turn.content))) {
        pinned.add(turn);
        seenDocument = true;
        continue;
      }
      // First user turn is treated as the document/context anchor when no
      // explicit pin is present (covers pasted study material).
      if (!seenDocument && turn.role == AiChatRole.user) {
        pinned.add(turn);
        seenDocument = true;
        continue;
      }
      rest.add(turn);
    }

    var conversational = List<AiChatTurn>.of(rest);
    var total =
        pinned.fold<int>(0, (s, t) => s + t.content.length) +
        conversational.fold<int>(0, (s, t) => s + t.content.length);

    // Prefer dropping conversational turns; never drop pinned prefix while
    // any conversational turn remains.
    while (conversational.isNotEmpty &&
        (pinned.length + conversational.length > maxMessages ||
            total > maxChars)) {
      final removed = conversational.removeAt(0);
      total -= removed.content.length;
      if (removed.role == AiChatRole.user &&
          conversational.isNotEmpty &&
          conversational.first.role == AiChatRole.assistant) {
        total -= conversational.first.content.length;
        conversational.removeAt(0);
      }
    }

    return [...pinned, ...conversational];
  }

  static bool _looksLikeDocumentTurn(String content) {
    return content.contains('Attached Study Vault context:') ||
        content.contains('SELECTED TEXT:') ||
        content.contains('SOURCE MATERIAL:') ||
        content.contains('--- Page ');
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

  Future<({String text, AiTokenUsage? usage})> _postChat({
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
      final durationMs = DateTime.now().difference(started).inMilliseconds;
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
      final message = choices.first is Map
          ? (choices.first as Map)['message']
          : null;
      if (message is! Map) throw const AiMalformedOutputException();
      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const AiEmptyResultException();
      }
      return (text: content.trim(), usage: usage);
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException();
    }
  }

  Object? _tryDecodeJson(String payload) {
    try {
      return jsonDecode(payload);
    } on Object {
      return null;
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
    this.newApi,
  });

  final AiSettingsStore settings;
  final AiChatTransport gemini;
  final AiChatTransport deepseek;
  final AiChatTransport? newApi;

  Future<AiChatTransport> _active() async {
    final provider = await settings.getProvider();
    return switch (provider) {
      AiProviderId.gemini => gemini,
      AiProviderId.deepseek => deepseek,
      AiProviderId.newApi => newApi ?? deepseek,
    };
  }

  /// Prefer transport matching the chat's model id when known.
  Future<AiChatTransport> _forModel(String modelId) async {
    final inferred = AiProviderIdX.fromModelId(modelId);
    final selected = await settings.getProvider();
    // Historical chats keep their original provider/model.
    if (inferred == AiProviderId.newApi) return newApi ?? deepseek;
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
      if (newApi != null) safeList(newApi!),
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
    return [
      ...geminiModels,
      ...deepseekModels,
      if (lists.length > 2) ...lists[2],
    ];
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
  Stream<AiChatStreamEvent> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 120),
  }) async* {
    yield* (await _forModel(
      modelId,
    )).streamComplete(modelId: modelId, history: history, timeout: timeout);
  }
}
