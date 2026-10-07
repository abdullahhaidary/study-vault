import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../study_workspace/data/study_workspace_providers.dart';
import '../data/ai_chat_providers.dart';
import '../domain/ai_chat_models.dart';

/// Opens an existing Study AI chat and focuses a specific message.
abstract final class AiChatNavigation {
  static void openAtMessage(
    BuildContext context,
    WidgetRef ref, {
    required String chatId,
    required String messageId,
  }) {
    ref.read(activeAiChatIdProvider.notifier).state = chatId;
    ref.read(aiChatFocusMessageIdProvider.notifier).state = messageId;
    ref.read(studyWorkspaceProvider.notifier).open();
  }

  static void openChat(
    BuildContext context,
    WidgetRef ref, {
    required String chatId,
  }) {
    ref.read(activeAiChatIdProvider.notifier).state = chatId;
    ref.read(aiChatFocusMessageIdProvider.notifier).state = null;
    ref.read(studyWorkspaceProvider.notifier).open();
  }

  /// Starts a new chat with one Study Vault reference in the draft.
  ///
  /// Reference metadata is always saved. When [attachment] already includes
  /// [AiContextItem.packedText], that body is kept so send-time resolution
  /// does not replace it with a different extract.
  static Future<void> openNewWithAttachment(
    BuildContext context,
    WidgetRef ref, {
    required AiContextItem attachment,
    String draftText = '',
  }) async {
    final service = ref.read(aiChatServiceProvider);
    final chat = await service.createChat();
    await service.saveDraft(chat.id, draftText, draftAttachments: [attachment]);
    if (!context.mounted) return;
    ref.read(activeAiChatIdProvider.notifier).state = chat.id;
    ref.read(aiChatFocusMessageIdProvider.notifier).state = null;
    ref.read(studyWorkspaceProvider.notifier).open();
  }
}
