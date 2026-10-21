import '../../../core/markdown/chart_spec.dart';
import '../../ai_assistant/data/ai_endpoint_profile_repository.dart';
import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_endpoint_catalog.dart';
import '../../ai_assistant/domain/ai_model_ref.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/services/new_api_claude_service.dart';
import '../domain/ai_chat_models.dart';
import 'gemini_chat_service.dart';

class NewApiClaudeChatService implements AiChatTransport {
  NewApiClaudeChatService({
    required this.service,
    required this.settings,
    required this.profiles,
  });

  final NewApiClaudeService service;
  final AiSettingsStore settings;
  final AiEndpointProfileRepository profiles;

  @override
  Future<bool> get isConfigured => service.isConfigured;

  @override
  Future<List<AiSelectableModel>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    return selectableModelsForEndpointProfiles(await profiles.list());
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
            '${preference == null || preference.trim().isEmpty ? '' : '\n${preference.trim()}'}',
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
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final messages = _messages(
      history,
      await settings.styleForSend(provider: AiProviderId.newApi),
    );
    final result = await service.completeMessages(
      profileId: AiModelRef.parse(modelId).endpointProfileId,
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
    Duration timeout = const Duration(minutes: 5),
  }) async* {
    final messages = _messages(
      history,
      await settings.styleForSend(provider: AiProviderId.newApi),
    );
    await for (final event in service.streamMessages(
      profileId: AiModelRef.parse(modelId).endpointProfileId,
      model: modelId,
      messages: messages,
      timeout: timeout,
    )) {
      yield AiChatStreamEvent(textDelta: event.text, usage: event.usage);
    }
  }
}
