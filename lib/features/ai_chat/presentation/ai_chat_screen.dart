import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/navigation/shell_tab.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../../ai_assistant/presentation/ai_missing_key_dialog.dart';
import '../../ai_assistant/presentation/widgets/voice_input_button.dart';
import '../data/chat_appearance_providers.dart';
import '../data/ai_chat_providers.dart';
import '../domain/chat_appearance.dart';
import '../domain/ai_chat_models.dart';
import '../services/ai_chat_service.dart';
import '../../ai_assistant/presentation/widgets/ai_usage_indicator.dart';
import 'ai_chat_history_screen.dart';
import 'chat_appearance_sheet.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import 'gemini_model_selector.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_mention_picker.dart';
import 'widgets/message_bubble.dart';

/// Study AI chat. It can be shown full-screen or inside the global workspace.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key, this.embedded = false, this.onClose});

  final bool embedded;
  final VoidCallback? onClose;

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _composer = TextEditingController();
  final _composerKey = GlobalKey<ChatComposerState>();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  final Map<String, double> _chatScrollOffsets = {};
  bool _sending = false;
  String? _streamingText;
  String? _errorBanner;
  Timer? _draftTimer;
  bool _draftHydrated = false;
  List<AiContextItem> _attachments = [];
  bool _mentionPickerOpen = false;
  String? _highlightMessageId;
  Timer? _highlightTimer;
  String? _pendingScrollRestoreChatId;

  @override
  void initState() {
    super.initState();
    _composer.addListener(_onComposerChanged);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _highlightTimer?.cancel();
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleFocusMessage(String messageId, List<AiChatMessage> messages) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Rough jump so ListView.builder materializes the target item.
      if (_scrollController.hasClients) {
        final extent = _scrollController.position.maxScrollExtent;
        final estimated = (index * 140.0).clamp(0.0, extent);
        await _scrollController.animateTo(
          estimated,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }

      if (!mounted) return;
      final key = _messageKeys[messageId];
      final targetContext = key?.currentContext;
      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      }

      if (!mounted) return;
      setState(() => _highlightMessageId = messageId);
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() => _highlightMessageId = null);
      });
    });
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
        .saveDraft(chatId, _composer.text, draftAttachments: _attachments);
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

  Future<void> _returnToApp() async {
    await _persistDraft();
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    ref.read(shellTabProvider.notifier).state = ShellTab.home;
  }

  Future<void> _selectModel(String currentId) async {
    final selected = await showAiModelSelector(
      context,
      selected: AiExecutionSelection.fromModelId(currentId),
    );
    if (selected == null || !mounted) return;

    final chatId = ref.read(activeAiChatIdProvider);
    if (chatId == null) {
      ref.read(pendingAiChatModelIdProvider.notifier).state =
          selected.requestedModelId;
      return;
    }
    await ref
        .read(aiChatServiceProvider)
        .setChatModel(chatId, selected.requestedModelId);
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
        final pendingModelId = ref.read(pendingAiChatModelIdProvider);
        final chat = await ref
            .read(aiChatServiceProvider)
            .createChat(modelId: pendingModelId);
        chatId = chat.id;
        ref.read(activeAiChatIdProvider.notifier).state = chatId;
        ref.read(pendingAiChatModelIdProvider.notifier).state = null;
      }

      if (preset == null) {
        _composer.clear();
      }

      await for (final partial
          in ref
              .read(aiChatServiceProvider)
              .streamSend(
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

  Future<void> _editAndResend(AiChatMessage message) async {
    if (_sending) return;
    final edited = await showAiPromptDialog(
      context,
      title: 'Edit and resend',
      hint: 'Update your message',
      confirmLabel: 'Resend',
      initialText: message.content,
      minLines: 3,
      maxLines: 8,
    );
    if (edited == null || !mounted) return;

    setState(() {
      _sending = true;
      _errorBanner = null;
    });
    try {
      await ref
          .read(aiChatServiceProvider)
          .editAndResend(
            chatId: message.chatId,
            messageId: message.id,
            userText: edited,
          );
      _scrollToBottom();
    } on AiException catch (error) {
      if (mounted) setState(() => _errorBanner = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorBanner = 'Could not edit and resend that message.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleReadAloud(String content) async {
    try {
      await ref.read(chatSpeechServiceProvider).toggle(content);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text-to-speech is not available.')),
      );
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

  void _restoreChatScroll(String chatId) {
    if (_pendingScrollRestoreChatId != chatId) return;
    _pendingScrollRestoreChatId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final saved = _chatScrollOffsets[chatId];
      _scrollController.jumpTo(
        (saved ?? position.maxScrollExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
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
    final appearance =
        ref.watch(chatAppearanceProvider).valueOrNull ??
        ChatAppearance.defaults;
    final speech = ref.watch(chatSpeechServiceProvider);
    final settingsAsync = ref.watch(aiSettingsStateProvider);
    final pendingModelId = ref.watch(pendingAiChatModelIdProvider);
    final chatAsync = chatId == null
        ? null
        : ref.watch(aiChatByIdProvider(chatId));
    final messagesAsync = chatId == null
        ? null
        : ref.watch(aiChatMessagesProvider(chatId));

    final modelId =
        chatAsync?.valueOrNull?.modelId ??
        pendingModelId ??
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
    final isActive =
        widget.embedded || ref.watch(shellTabProvider) == ShellTab.aiChat;
    final drawerWidth = (MediaQuery.sizeOf(context).width * 0.86).clamp(
      280.0,
      360.0,
    );

    ref.listen<String?>(activeAiChatIdProvider, (previous, next) {
      if (previous == next) return;
      if (previous != null && _scrollController.hasClients) {
        _chatScrollOffsets[previous] = _scrollController.offset;
      }
      _pendingScrollRestoreChatId = next;
      _draftHydrated = false;
      _composer.clear();
      setState(() {
        _attachments = [];
        _highlightMessageId = null;
      });
      _messageKeys.clear();
    });

    ref.listen<String?>(aiChatFocusMessageIdProvider, (previous, next) {
      if (next == null || next == previous) return;
      final chatId = ref.read(activeAiChatIdProvider);
      if (chatId == null) return;
      final messages = ref.read(aiChatMessagesProvider(chatId)).valueOrNull;
      if (messages == null) return;
      ref.read(aiChatFocusMessageIdProvider.notifier).state = null;
      _scheduleFocusMessage(next, messages);
    });

    // Apply pending focus once messages finish loading for the active chat.
    final pendingFocus = ref.watch(aiChatFocusMessageIdProvider);
    if (pendingFocus != null &&
        chatId != null &&
        messagesAsync?.hasValue == true) {
      final messages = messagesAsync!.value!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(aiChatFocusMessageIdProvider) != pendingFocus) return;
        ref.read(aiChatFocusMessageIdProvider.notifier).state = null;
        _scheduleFocusMessage(pendingFocus, messages);
      });
    }

    final scaffold = Scaffold(
      drawerEdgeDragWidth: 72,
      drawer: Drawer(
        width: drawerWidth,
        child: const AiChatHistoryScreen(asDrawer: true),
      ),
      appBar: widget.embedded
          ? null
          : AppBar(
              centerTitle: false,
              titleSpacing: 0,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
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
              title: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _selectModel(modelId),
                  borderRadius: AppRadii.smAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            modelLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: modelKnown
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: widget.embedded
                      ? 'Minimize workspace'
                      : 'Leave chat',
                  onPressed: _returnToApp,
                  icon: Icon(widget.embedded ? Icons.minimize : Icons.logout),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    switch (value) {
                      case 'new_chat':
                        if (!_sending) _newChat();
                      case 'appearance':
                        showChatAppearanceSheet(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'new_chat',
                      enabled: !_sending,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_square),
                        title: Text('New chat'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'appearance',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.palette_outlined),
                        title: Text('Customize chat'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: _ChatBackground(
        appearance: appearance,
        child: Column(
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
                        _restoreChatScroll(chatId);
                        if (messages.isEmpty && _streamingText == null) {
                          return _EmptyChat(onPrompt: _send);
                        }
                        final showStream =
                            _streamingText != null &&
                            (_streamingText!.isNotEmpty || _sending);
                        final fullWidth =
                            appearance.layout == ChatMessageLayout.fullWidth;
                        return ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            fullWidth ? 0 : AppSpacing.xxs,
                            AppSpacing.md,
                            fullWidth ? 0 : AppSpacing.xxs,
                            AppSpacing.md,
                          ),
                          itemCount: messages.length + (showStream ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (showStream && index == messages.length) {
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 760,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md,
                                    ),
                                    child: MessageBubble(
                                      role: AiChatRole.assistant,
                                      content: _streamingText!,
                                      isStreaming: true,
                                      appearance: appearance,
                                    ),
                                  ),
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
                            final key = _messageKeys.putIfAbsent(
                              message.id,
                              GlobalKey.new,
                            );
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: Padding(
                                  key: key,
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: MessageBubble(
                                    role: message.role,
                                    content: message.content,
                                    status: message.status,
                                    attachments: attachments,
                                    onRetry: isLastError ? _retry : null,
                                    highlighted:
                                        message.id == _highlightMessageId,
                                    appearance: appearance,
                                    onEditAndResend:
                                        message.role == AiChatRole.user &&
                                            !_sending
                                        ? () => _editAndResend(message)
                                        : null,
                                    onRegenerate:
                                        message.role == AiChatRole.assistant &&
                                            index == messages.length - 1 &&
                                            message.status !=
                                                AiChatMessageStatus.error &&
                                            !_sending
                                        ? _retry
                                        : null,
                                    onToggleReadAloud:
                                        message.role == AiChatRole.assistant
                                        ? () =>
                                              _toggleReadAloud(message.content)
                                        : null,
                                    isSpeaking: speech.isSpeaking(
                                      message.content,
                                    ),
                                    usage: message.role == AiChatRole.assistant
                                        ? aiTokenUsageFromColumns(
                                            promptTokens: message.promptTokens,
                                            completionTokens:
                                                message.completionTokens,
                                            totalTokens: message.totalTokens,
                                            cacheHitTokens:
                                                message.cacheHitTokens,
                                            cacheMissTokens:
                                                message.cacheMissTokens,
                                            model: message.aiModel,
                                            provider: message.aiProvider,
                                            durationMs:
                                                message.requestDurationMs,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
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
      ),
    );

    if (widget.embedded) return scaffold;
    return PopScope(
      // Full-screen chat lives in the shell rather than a pushed route.
      canPop: !isActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !isActive) return;
        await _returnToApp();
      },
      child: scaffold,
    );
  }
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground({required this.appearance, required this.child});

  final ChatAppearance appearance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = switch (appearance.backgroundKind) {
      ChatBackgroundKind.theme => ColoredBox(
        color: theme.scaffoldBackgroundColor,
      ),
      ChatBackgroundKind.solid => ColoredBox(
        color: Color(
          appearance.backgroundColorValue ??
              theme.scaffoldBackgroundColor.toARGB32(),
        ),
      ),
      ChatBackgroundKind.gradient => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(appearance.gradientStartValue ?? 0xffeef3ff),
              Color(appearance.gradientEndValue ?? 0xfffff1f5),
            ],
          ),
        ),
      ),
      ChatBackgroundKind.image => _BackgroundImage(
        path: appearance.backgroundImagePath,
        opacity: appearance.backgroundImageOpacity,
        blur: appearance.backgroundImageBlur,
      ),
    };

    return Stack(fit: StackFit.expand, children: [background, child]);
  }
}

class _BackgroundImage extends StatelessWidget {
  const _BackgroundImage({
    required this.path,
    required this.opacity,
    required this.blur,
  });

  final String? path;
  final double opacity;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = path == null ? null : File(path!);
    if (file == null || !file.existsSync()) {
      return ColoredBox(color: theme.scaffoldBackgroundColor);
    }

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Opacity(
            opacity: opacity,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: theme.scaffoldBackgroundColor),
            ),
          ),
        ),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 22,
                  color: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'What can I help with?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ask about your studies, or type @ to add your own material.',
                style: theme.textTheme.bodyMedium?.copyWith(
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
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
