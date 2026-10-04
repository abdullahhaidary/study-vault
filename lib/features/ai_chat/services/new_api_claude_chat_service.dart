import '../../../core/markdown/chart_spec.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/services/new_api_claude_service.dart';
import '../domain/ai_chat_models.dart';
import 'gemini_chat_service.dart';

class NewApiClaudeChatService implements AiChatTransport {
  NewApiClaudeChatService({required this.service, required this.settings});

  final NewApiClaudeService service;
  final AiSettingsStore settings;

  @override
  Future<bool> get isConfigured => service.isConfigured;

  @override
  Future<List<AiSelectableModel>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final id = await settings.getModelIdFor(AiProviderId.newApi);
    if (id.length <= 7) return [];
    return [
      AiSelectableModel(
        id: id,
        displayName: id.substring(7),
        description: 'Claude Messages via your New API server',
        recommended: false,
        group: 'Other',
        provider: AiProviderId.newApi,
      ),
    ];
  }

  List<Map<String, String>> _messages(
    List<AiChatTurn> history,
    String? preference,
  ) {
    return [
      {
        'role': 'system',
        'content':
            'You are Study Vault AI Assistant for university students. '
            'Ground answers in shared study material and preserve formulas, code and technical terminology.\n'
            '${ChartSpec.promptInstruction}'
            '${preference == null || preference.trim().isEmpty ? '' : '\nUser study preference: ${preference.trim()}'}',
      },
      for (final turn in history)
        {
          'role': turn.role == AiChatRole.assistant
              ? 'assistant'
              : turn.role == AiChatRole.system
              ? 'system'
              : 'user',
          'content': turn.content,
        },
    ];
  }

  @override
  Future<AiChatCompletion> complete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final messages = _messages(history, await settings.getStudyPreference());
    final result = await service.completeMessages(
      model: modelId,
      messages: messages,
      maxTokens: 4096,
      timeout: timeout,
    );
    return AiChatCompletion(
      text: result.text,
      modelId: modelId,
      usage: result.usage,
    );
  }

  @override
  Stream<AiChatStreamEvent> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(seconds: 120),
  }) async* {
    final messages = _messages(history, await settings.getStudyPreference());
    await for (final event in service.streamMessages(
      model: modelId,
      messages: messages,
      timeout: timeout,
    )) {
      yield AiChatStreamEvent(textDelta: event.text, usage: event.usage);
    }
  }
}
