import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../../ai_assistant/presentation/ai_missing_key_dialog.dart';
import '../data/ai_chat_providers.dart';
import '../domain/ai_chat_models.dart';
import '../services/ai_chat_service.dart';
import 'ai_chat_history_screen.dart';
import 'gemini_model_selector.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_mention_picker.dart';
import 'widgets/message_bubble.dart';

/// Full-screen Study AI chat for the shell tab.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _composer = TextEditingController();
  final _composerKey = GlobalKey<ChatComposerState>();
  final _scrollController = ScrollController();
  bool _sending = false;
  String? _streamingText;
  String? _errorBanner;
  Timer? _draftTimer;
  bool _draftHydrated = false;
  List<AiContextItem> _attachments = [];
  bool _mentionPickerOpen = false;

  @override
  void initState() {
    super.initState();
    _composer.addListener(_onComposerChanged);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _persistDraft);
  }

  Future<void> _persistDraft() async {
    final chatId = ref.read(activeAiChatIdProvider);
    if (chatId == null) return;
    await ref
        .read(aiChatServiceProvider)
        .saveDraft(
          chatId,
          _composer.text,
          draftAttachments: _attachments,
        );
  }

  Future<void> _ensureConfigured() async {
    final configured = await ref.read(aiConfiguredProvider.future);
    if (!configured && mounted) {
      await showAiMissingKeyDialog(context);
    }
    final consent = await ref.read(aiPrivacyConsentProvider.future);
    if (!consent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the AI privacy notice in Settings first.'),
        ),
      );
      await Navigator.of(
        context,
      ).pushNamed(AppRoutes.settings, arguments: {'section': 'ai'});
    }
  }

  Future<void> _newChat() async {
    await _persistDraft();
    _composer.clear();
    _draftHydrated = false;
    ref.read(activeAiChatIdProvider.notifier).state = null;
    setState(() {
      _streamingText = null;
      _errorBanner = null;
      _attachments = [];
    });
  }

  Future<void> _selectModel(String currentId) async {
    final selected = await showGeminiModelSelector(
      context,
      selectedModelId: currentId,
    );
    if (selected == null || !mounted) return;

    final chatId = ref.read(activeAiChatIdProvider);
    final provider = AiProviderIdX.fromModelId(selected);
    if (chatId == null) {
      await ref.read(aiSettingsStoreProvider).setProvider(provider);
      await ref.read(aiSettingsStoreProvider).setModelIdFor(provider, selected);
      ref.invalidate(aiSettingsStateProvider);
      setState(() {});
      return;
    }
    await ref.read(aiChatServiceProvider).setChatModel(chatId, selected);
    ref.invalidate(aiSettingsStateProvider);
  }

  Future<void> _addAttachment(AiContextItem item) async {
    if (_attachments.any((a) => a.kind == item.kind && a.id == item.id)) {
      return;
    }
    if (_attachments.length >= AiChatService.maxAttachmentsPerMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can attach up to ${AiChatService.maxAttachmentsPerMessage} items.',
          ),
        ),
      );
      return;
    }
    setState(() => _attachments = [..._attachments, item]);
    await _persistDraft();
  }

  Future<void> _removeAttachment(AiContextItem item) async {
    setState(() {
      _attachments = [
        for (final a in _attachments)
          if (!(a.kind == item.kind && a.id == item.id)) a,
      ];
    });
    await _persistDraft();
  }

  Future<void> _pickAttachment({String initialQuery = ''}) async {
    if (_mentionPickerOpen) return;
    _mentionPickerOpen = true;
    try {
      final selected = await showChatMentionPicker(
        context,
        initialQuery: initialQuery,
      );
      if (selected == null || !mounted) return;
      _composerKey.currentState?.clearActiveMentionToken();
      await _addAttachment(selected);
    } finally {
      _mentionPickerOpen = false;
    }
  }

  Future<void> _onMentionQuery(String? query) async {
    if (query == null) return;
    // Open picker once when `@` is typed; pass the current query.
    if (_mentionPickerOpen) return;
    await _pickAttachment(initialQuery: query);
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _composer.text).trim();
    final pendingAttachments = List<AiContextItem>.from(_attachments);
    if ((text.isEmpty && pendingAttachments.isEmpty) || _sending) return;

    await _ensureConfigured();
    final configured = await ref.read(aiConfiguredProvider.future);
    final consent = await ref.read(aiPrivacyConsentProvider.future);
    if (!configured || !consent) return;

    final sendText = text.isEmpty
        ? 'Please use the attached study content.'
        : text;

    setState(() {
      _sending = true;
      _errorBanner = null;
      _streamingText = '';
      _attachments = [];
    });

    try {
      var chatId = ref.read(activeAiChatIdProvider);
      if (chatId == null) {
        final chat = await ref.read(aiChatServiceProvider).createChat();
        chatId = chat.id;
        ref.read(activeAiChatIdProvider.notifier).state = chatId;
      }

      if (preset == null) {
        _composer.clear();
      }

      await for (final partial
          in ref.read(aiChatServiceProvider).streamSend(
            chatId: chatId,
            userText: sendText,
            attachments: pendingAttachments,
          )) {
        if (!mounted) return;
        setState(() => _streamingText = partial);
        _scrollToBottom();
      }
      if (mounted) {
        setState(() => _streamingText = null);
      }
      _scrollToBottom();
    } on AiException catch (e) {
      if (mounted) {
        setState(() {
          _errorBanner = e.message;
          _streamingText = null;
          _attachments = pendingAttachments;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorBanner = 'Something went wrong. Please try again.';
          _streamingText = null;
          _attachments = pendingAttachments;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _retry() async {
    final chatId = ref.read(activeAiChatIdProvider);
    if (chatId == null || _sending) return;
    setState(() {
      _sending = true;
      _errorBanner = null;
    });
    try {
      await ref.read(aiChatServiceProvider).retryLast(chatId: chatId);
    } on AiException catch (e) {
      if (mounted) setState(() => _errorBanner = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _hydrateDraft(AiChat? chat) {
    if (chat == null) {
      _draftHydrated = false;
      return;
    }
    if (_draftHydrated) return;
    _draftHydrated = true;
    final draft = chat.draftText;
    final draftAttachments = AiContextItem.decodeList(chat.draftContextJson);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_composer.text.isEmpty && draft != null && draft.isNotEmpty) {
        _composer.text = draft;
      }
      if (_attachments.isEmpty && draftAttachments.isNotEmpty) {
        setState(() => _attachments = draftAttachments);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatId = ref.watch(activeAiChatIdProvider);
    final settingsAsync = ref.watch(aiSettingsStateProvider);
    final chatAsync = chatId == null
        ? null
        : ref.watch(aiChatByIdProvider(chatId));
    final messagesAsync = chatId == null
        ? null
        : ref.watch(aiChatMessagesProvider(chatId));

    final modelId =
        chatAsync?.valueOrNull?.modelId ??
        settingsAsync.valueOrNull?.modelId ??
        GeminiModelRegistry.defaultModelId;
    final modelKnown = AiModels.isKnown(modelId);
    final modelLabel = AiModels.chatDisplayName(modelId);

    if (chatId == null) {
      _draftHydrated = false;
    } else {
      _hydrateDraft(chatAsync?.valueOrNull);
    }

    final theme = Theme.of(context);
    final drawerWidth = (MediaQuery.sizeOf(context).width * 0.86).clamp(
      280.0,
      360.0,
    );

    ref.listen<String?>(activeAiChatIdProvider, (previous, next) {
      if (previous == next) return;
      _draftHydrated = false;
      _composer.clear();
      setState(() => _attachments = []);
    });

    return Scaffold(
      drawerEdgeDragWidth: 72,
      drawer: Drawer(
        width: drawerWidth,
        child: const AiChatHistoryScreen(asDrawer: true),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Chat history',
            onPressed: () async {
              await _persistDraft();
              if (context.mounted) Scaffold.of(context).openDrawer();
            },
            icon: const Icon(Icons.menu),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Study AI'),
            InkWell(
              onTap: () => _selectModel(modelId),
              borderRadius: AppRadii.smAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        modelLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: modelKnown
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _sending ? null : _newChat,
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorBanner != null)
            Material(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              child: ListTile(
                dense: true,
                title: Text(
                  _errorBanner!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _errorBanner = null),
                ),
              ),
            ),
          Expanded(
            child: chatId == null
                ? _EmptyChat(onPrompt: _send)
                : messagesAsync!.when(
                    loading: () => const AppLoading(),
                    error: (_, _) => const AppErrorState(
                      message: 'Could not load messages.',
                    ),
                    data: (messages) {
                      if (messages.isEmpty && _streamingText == null) {
                        return _EmptyChat(onPrompt: _send);
                      }
                      final showStream =
                          _streamingText != null &&
                          (_streamingText!.isNotEmpty || _sending);
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        itemCount: messages.length + (showStream ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (showStream && index == messages.length) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: MessageBubble(
                                role: AiChatRole.assistant,
                                content: _streamingText!,
                                isStreaming: true,
                              ),
                            );
                          }
                          final message = messages[index];
                          final isLastError =
                              index == messages.length - 1 &&
                              message.status == AiChatMessageStatus.error;
                          final attachments = message.role == AiChatRole.user
                              ? AiContextItem.decodeList(message.contextJson)
                              : const <AiContextItem>[];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: MessageBubble(
                              role: message.role,
                              content: message.content,
                              status: message.status,
                              attachments: attachments,
                              onRetry: isLastError ? _retry : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          ChatComposer(
            key: _composerKey,
            controller: _composer,
            sending: _sending,
            attachments: _attachments,
            onSend: _send,
            onAttach: () => _pickAttachment(),
            onMentionQuery: _onMentionQuery,
            onRemoveAttachment: _removeAttachment,
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  static const _suggestions = [
    'Explain a concept',
    'Create practice questions',
    'Summarize a topic',
    'Help me revise',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Study AI', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ask anything about your studies. Type @ to attach a lesson or PDF.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: [
                  for (final prompt in _suggestions)
                    ActionChip(
                      label: Text(prompt),
                      onPressed: () => onPrompt(prompt),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
