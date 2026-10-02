import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/shell_tab.dart';
import '../data/ai_chat_providers.dart';

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
    ShellNavigation.go(context, ref, ShellTab.aiChat);
  }

  static void openChat(
    BuildContext context,
    WidgetRef ref, {
    required String chatId,
  }) {
    ref.read(activeAiChatIdProvider.notifier).state = chatId;
    ref.read(aiChatFocusMessageIdProvider.notifier).state = null;
    ShellNavigation.go(context, ref, ShellTab.aiChat);
  }
}
