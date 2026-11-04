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
    String? pocketChatId,
  }) async {
    final continuing = _continuing(pocketChatId);
    final reply = await _client.send(
      modelId: modelId,
      message: messageForPocket(history, continuing: continuing),
      timeout: timeout,
      chatId: continuing ? pocketChatId : null,
      newChat: !continuing,
    );
    return AiChatCompletion(
      text: reply.text,
      modelId: PocketModelRef.normalize(modelId).storageValue,
      usage: AiTokenUsage(
        model: PocketModelRef.normalize(modelId).storageValue,
        provider: AiProviderId.pocket.storageValue,
      ),
      pocketChatId: reply.chatId,
    );
  }

  @override
  Stream<AiChatStreamEvent> streamComplete({
    required String modelId,
    required List<AiChatTurn> history,
    Duration timeout = const Duration(minutes: 3),
    String? pocketChatId,
  }) async* {
    final storage = PocketModelRef.normalize(modelId).storageValue;
    final usage = AiTokenUsage(
      model: storage,
      provider: AiProviderId.pocket.storageValue,
    );
    final continuing = _continuing(pocketChatId);
    var started = false;
    await for (final reply in _client.watch(
      modelId: modelId,
      message: messageForPocket(history, continuing: continuing),
      timeout: timeout,
      chatId: continuing ? pocketChatId : null,
      newChat: !continuing,
    )) {
      if (reply.replaces) {
        if (!started && reply.text.isNotEmpty) {
          yield AiChatStreamEvent(
            textDelta: reply.text,
            usage: reply.done ? usage : null,
            pocketChatId: reply.chatId,
          );
          started = true;
        } else if (reply.done) {
          yield AiChatStreamEvent(
            textDelta: '',
            usage: usage,
            pocketChatId: reply.chatId,
          );
        }
        continue;
      }
      if (reply.delta.isEmpty && !reply.done) continue;
      if (reply.delta.isNotEmpty) started = true;
      yield AiChatStreamEvent(
        textDelta: reply.delta,
        usage: reply.done ? usage : null,
        pocketChatId: reply.chatId,
      );
    }
  }

  bool _continuing(String? pocketChatId) {
    return pocketChatId != null && pocketChatId.trim().isNotEmpty;
  }
}

/// Text sent into the Pocket browser.
///
/// A continued chat already holds the earlier turns, so only the latest user
/// message is typed. A new browser chat still receives the labeled transcript.
String messageForPocket(List<AiChatTurn> history, {required bool continuing}) {
  if (!continuing) return transcriptForPocket(history);
  for (final turn in history.reversed) {
    if (turn.role == AiChatRole.user && turn.content.trim().isNotEmpty) {
      return turn.content.trim();
    }
  }
  return transcriptForPocket(history);
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
