import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../domain/ai_chat_models.dart';
import '../services/ai_chat_service.dart';
import '../services/deepseek_chat_service.dart';
import '../services/gemini_chat_service.dart';

final geminiChatServiceProvider = Provider<AiChatTransport>((ref) {
  return HttpGeminiChatService(
    credentials: ref.watch(aiCredentialStoreProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

final deepseekChatServiceProvider = Provider<AiChatTransport>((ref) {
  return HttpDeepSeekChatService(
    credentials: ref.watch(aiCredentialStoreProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

final aiChatTransportProvider = Provider<AiChatTransport>((ref) {
  return RoutingAiChatTransport(
    settings: ref.watch(aiSettingsStoreProvider),
    gemini: ref.watch(geminiChatServiceProvider),
    deepseek: ref.watch(deepseekChatServiceProvider),
  );
});

final aiChatServiceProvider = Provider<AiChatService>((ref) {
  return AiChatService(
    db: ref.watch(databaseProvider),
    transport: ref.watch(aiChatTransportProvider),
    settings: ref.watch(aiSettingsStoreProvider),
  );
});

/// Currently open conversation in the AI Chat tab (`null` = blank new chat).
final activeAiChatIdProvider = StateProvider<String?>((ref) => null);

final aiChatsProvider = StreamProvider<List<AiChat>>((ref) {
  return ref.watch(aiChatServiceProvider).watchChats();
});

final aiChatByIdProvider = StreamProvider.family<AiChat?, String>((ref, id) {
  return ref.watch(aiChatServiceProvider).watchChat(id);
});

final aiChatMessagesProvider =
    StreamProvider.family<List<AiChatMessage>, String>((ref, chatId) {
      return ref.watch(aiChatServiceProvider).watchMessages(chatId);
    });

final aiChatLastMessageProvider = StreamProvider.family<AiChatMessage?, String>(
  (ref, chatId) {
    return ref
        .watch(databaseProvider)
        .watchAiChatMessages(chatId)
        .map((list) => list.isEmpty ? null : list.last);
  },
);

final availableChatModelsProvider = FutureProvider<List<AiSelectableModel>>((
  ref,
) async {
  return ref.watch(aiChatTransportProvider).listAvailableChatModels();
});
