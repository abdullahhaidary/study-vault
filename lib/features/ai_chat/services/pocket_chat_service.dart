import '../../ai_assistant/data/ai_settings_store.dart';
import '../../ai_assistant/domain/ai_model_ref.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/ai_selectable_model.dart';
import '../../ai_assistant/domain/ai_token_usage.dart';
import '../../ai_assistant/services/pocket_client.dart';
import '../domain/ai_chat_models.dart';
import 'gemini_chat_service.dart';

/// Study Vault chat turns typed into the Pocket window.
class PocketChatService implements AiChatTransport {
  PocketChatService({required AiSettingsStore settings, PocketClient? client})
    : _client = client ?? PocketClient(settings: settings);

  final PocketClient _client;

  @override
  Future<bool> get isConfigured async => true;

  @override
  Future<List<AiSelectableModel>> listAvailableChatModels({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final accounts = await _client.listAccounts(timeout: timeout);
      return pocketSelectableModels(
        accounts: [
          for (final account in accounts)
            PocketAccountChoice(id: account.id, name: account.name),
        ],
      );
    } on Object {
      return pocketSelectableModels();
    }
  }

  @override
  Future<AiChatCompletion> complete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final reply = await _client.send(
      modelId: modelId,
      message: transcriptForPocket(history),
      timeout: timeout,
    );
    return AiChatCompletion(
      text: reply.text,
      modelId: PocketModelRef.normalize(modelId).storageValue,
      usage: AiTokenUsage(
        model: PocketModelRef.normalize(modelId).storageValue,
        provider: AiProviderId.pocket.storageValue,
      ),
    );
  }

  @override
  Stream<AiChatStreamEvent> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(minutes: 3),
  }) async* {
    final storage = PocketModelRef.normalize(modelId).storageValue;
    final usage = AiTokenUsage(
      model: storage,
      provider: AiProviderId.pocket.storageValue,
    );
    var previous = '';
    await for (final reply in _client.watch(
      modelId: modelId,
      message: transcriptForPocket(history),
      timeout: timeout,
    )) {
      final text = reply.text;
      if (!text.startsWith(previous)) {
        if (reply.done) {
          yield AiChatStreamEvent(textDelta: '', usage: usage);
        }
        continue;
      }
      final delta = text.substring(previous.length);
      previous = text;
      if (delta.isEmpty && !reply.done) continue;
      yield AiChatStreamEvent(
        textDelta: delta,
        usage: reply.done ? usage : null,
      );
    }
  }
}

/// One Pocket message that carries the Study Vault conversation.
String transcriptForPocket(List<AiChatTurn> history) {
  final turns = [
    for (final turn in history)
      if (turn.content.trim().isNotEmpty) turn,
  ];
  if (turns.isEmpty) return '';
  if (turns.length == 1 && turns.single.role != AiChatRole.assistant) {
    return turns.single.content.trim();
  }
  final buffer = StringBuffer();
  for (final turn in turns) {
    final label = switch (turn.role) {
      AiChatRole.assistant => 'Assistant',
      AiChatRole.system => 'System',
      _ => 'User',
    };
    buffer.writeln('$label:');
    buffer.writeln(turn.content.trim());
    buffer.writeln();
  }
  buffer.writeln(
    'Reply as the assistant to the latest user message. '
    'Do not repeat these labels.',
  );
  return buffer.toString();
}
