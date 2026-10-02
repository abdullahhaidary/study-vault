import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../ai_assistant/data/ai_credential_store.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../domain/ai_chat_models.dart';

/// Multi-turn Gemini chat networking.
abstract class GeminiChatService {
  Future<bool> get isConfigured;

  Future<List<GeminiModelDefinition>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  });

  Future<AiChatCompletion> complete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 90),
  });

  Stream<String> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 120),
  });
}

/// Gemini REST client using generateContent / streamGenerateContent.
class HttpGeminiChatService implements GeminiChatService {
  HttpGeminiChatService({
    required this.credentials,
    required this.settings,
    http.Client? httpClient,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _http = httpClient ?? http.Client();

  final AiCredentialStore credentials;
  final AiSettingsStore settings;
  final http.Client _http;
  final String baseUrl;

  static const maxContextChars = 80000;
  static const maxContextMessages = 40;

  @override
  Future<bool> get isConfigured => credentials.hasApiKey;

  @override
  Future<List<GeminiModelDefinition>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final key = await _requireKey();
    try {
      final uri = Uri.parse('$baseUrl/models');
      final response = await _http
          .get(uri, headers: {'x-goog-api-key': key})
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return GeminiModelRegistry.fallbackChatModels();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return GeminiModelRegistry.fallbackChatModels();
      }
      final models = decoded['models'];
      if (models is! List) {
        return GeminiModelRegistry.fallbackChatModels();
      }

      final ids = <String>{};
      for (final item in models) {
        if (item is! Map) continue;
        final name = item['name'];
        if (name is! String) continue;
        final methods = item['supportedGenerationMethods'];
        if (methods is List &&
            !methods.contains('generateContent') &&
            !methods.contains('streamGenerateContent')) {
          continue;
        }
        ids.add(name.contains('/') ? name.split('/').last : name);
      }
      return GeminiModelRegistry.resolveAvailable(serverModelIds: ids);
    } on TimeoutException {
      return GeminiModelRegistry.fallbackChatModels();
    } on SocketException {
      return GeminiModelRegistry.fallbackChatModels();
    } on http.ClientException {
      return GeminiModelRegistry.fallbackChatModels();
    } on Object {
      return GeminiModelRegistry.fallbackChatModels();
    }
  }

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
    final model = GeminiModelRegistry.normalize(modelId);
    final preference = await settings.getStudyPreference();
    final body = _buildRequestBody(
      history: history,
      modelId: model,
      studyPreference: preference,
    );
    final text = await _postGenerate(
      model: model,
      apiKey: key,
      body: body,
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
    final model = GeminiModelRegistry.normalize(modelId);
    final preference = await settings.getStudyPreference();
    final body = _buildRequestBody(
      history: history,
      modelId: model,
      studyPreference: preference,
    );
    final uri = Uri.parse(
      '$baseUrl/models/$model:streamGenerateContent?alt=sse',
    );

    late http.StreamedResponse response;
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'x-goog-api-key': key,
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
        final delta = _extractTextDelta(payload);
        if (delta == null || delta.isEmpty) continue;
        full.write(delta);
        yield delta;
      }
    }

    if (full.isEmpty) {
      throw const AiEmptyResultException();
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required List<AiChatTurn> history,
    required String modelId,
    String? studyPreference,
  }) {
    final trimmed = _trimHistory(history);
    final contents = <Map<String, dynamic>>[];
    for (final turn in trimmed) {
      if (turn.role == AiChatRole.system) continue;
      final role = turn.role == AiChatRole.assistant ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': turn.content},
        ],
      });
    }
    if (contents.isEmpty) {
      throw const AiServerException('Nothing to send to Gemini.');
    }

    final generationConfig = <String, dynamic>{'maxOutputTokens': 8192};
    final def = GeminiModelRegistry.byId(modelId);
    if (def?.supportsThinkingLevel == true) {
      generationConfig['thinkingConfig'] = {'thinkingLevel': 'medium'};
    }

    final preferenceNote =
        (studyPreference != null && studyPreference.trim().isNotEmpty)
        ? ' User study preference: ${studyPreference.trim()}.'
        : '';

    return {
      'systemInstruction': {
        'parts': [
          {
            'text':
                'You are Study AI, a helpful study assistant inside Study Vault. '
                'Be clear, accurate, and concise. Prefer structured explanations '
                'with headings and lists when helpful. Support English and '
                'Persian/Dari as needed.$preferenceNote',
          },
        ],
      },
      'contents': contents,
      'generationConfig': generationConfig,
    };
  }

  List<AiChatTurn> _trimHistory(List<AiChatTurn> history) {
    if (history.isEmpty) return history;
    final recent = history.length > maxContextMessages
        ? history.sublist(history.length - maxContextMessages)
        : List<AiChatTurn>.from(history);

    var total = 0;
    final kept = <AiChatTurn>[];
    for (var i = recent.length - 1; i >= 0; i--) {
      final turn = recent[i];
      total += turn.content.length;
      if (total > maxContextChars && kept.isNotEmpty) break;
      kept.add(turn);
    }
    return kept.reversed.toList();
  }

  Future<String> _requireKey() async {
    final key = await credentials.readApiKey();
    if (key == null || key.isEmpty) {
      throw const AiNotConfiguredException();
    }
    return key;
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
      final text = _extractCandidateText(decoded);
      if (text == null || text.isEmpty) {
        throw const AiEmptyResultException();
      }
      return text;
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException();
    }
  }

  Never _throwForStatus({
    required int status,
    required String body,
    required String model,
  }) {
    final apiMessage = _errorMessage(body);
    final lower = apiMessage.toLowerCase();

    if (status == 400 || status == 403) {
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
          'Choose another model in Study AI.',
        );
      }
      throw AiServerException(
        _friendlyApiFailure(status: status, message: apiMessage),
      );
    }
    if (status == 404) {
      throw AiUnsupportedModelException(
        'Model "$model" was not found. Choose another model in Study AI.',
      );
    }
    if (status == 429) {
      if (lower.contains('quota')) throw const AiQuotaException();
      throw const AiRateLimitException();
    }
    throw AiServerException(
      _friendlyApiFailure(status: status, message: apiMessage),
    );
  }

  String? _extractTextDelta(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return _extractCandidateText(decoded);
    } on Object {
      return null;
    }
  }

  String? _extractCandidateText(Map<dynamic, dynamic> decoded) {
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final block = decoded['promptFeedback'];
      if (block is Map) {
        throw const AiServerException(
          'Gemini blocked this request. Try different text.',
        );
      }
      return null;
    }
    final candidate = candidates.first;
    if (candidate is! Map) return null;
    final content = candidate['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) return null;
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      if (part['text'] is String) buffer.write(part['text']);
    }
    return buffer.toString();
  }

  String _friendlyApiFailure({required int status, required String message}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Gemini request failed (HTTP $status). Check model and API key.';
    }
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

/// Deterministic chat networking for tests.
class FakeGeminiChatService implements GeminiChatService {
  FakeGeminiChatService({
    required this.credentials,
    required this.settings,
    this.reply = 'Fake assistant reply.',
    this.availableModels,
    this.failWith,
  });

  final AiCredentialStore credentials;
  final AiSettingsStore settings;
  final String reply;
  final List<GeminiModelDefinition>? availableModels;
  final AiException? failWith;
  final List<List<AiChatTurn>> sentHistories = [];

  @override
  Future<bool> get isConfigured => credentials.hasApiKey;

  @override
  Future<List<GeminiModelDefinition>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    return availableModels ?? GeminiModelRegistry.fallbackChatModels();
  }

  @override
  Future<AiChatCompletion> complete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!await credentials.hasApiKey) {
      throw const AiNotConfiguredException();
    }
    if (!await settings.getPrivacyConsentAccepted()) {
      throw const AiPrivacyNotAcceptedException();
    }
    if (failWith != null) throw failWith!;
    sentHistories.add(List.of(history));
    return AiChatCompletion(
      text: reply,
      modelId: GeminiModelRegistry.normalize(modelId),
    );
  }

  @override
  Stream<String> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 120),
  }) async* {
    final result = await complete(
      modelId: modelId,
      history: history,
      timeout: timeout,
    );
    // Yield in two chunks to exercise stream consumers without fake typing.
    final mid = (result.text.length / 2).floor();
    if (mid > 0) {
      yield result.text.substring(0, mid);
      yield result.text.substring(mid);
    } else {
      yield result.text;
    }
  }
}
