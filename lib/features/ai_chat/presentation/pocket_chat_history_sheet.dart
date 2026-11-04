import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/transient_snack_bar.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/services/pocket_client.dart';
import '../data/ai_chat_providers.dart';

/// Lists Pocket browser chats and binds one to the open Study Vault chat.
Future<void> showPocketChatHistorySheet(
  BuildContext context,
  WidgetRef ref, {
  required String? studyChatId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return _PocketChatHistorySheet(studyChatId: studyChatId);
    },
  );
}

class _PocketChatHistorySheet extends ConsumerStatefulWidget {
  const _PocketChatHistorySheet({required this.studyChatId});

  final String? studyChatId;

  @override
  ConsumerState<_PocketChatHistorySheet> createState() =>
      _PocketChatHistorySheetState();
}

class _PocketChatHistorySheetState
    extends ConsumerState<_PocketChatHistorySheet> {
  List<PocketBrowserChat> _chats = const [];
  bool _loading = true;
  String? _error;
  String? _boundId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  PocketClient _client() {
    return PocketClient(settings: ref.read(aiSettingsStoreProvider));
  }

  Future<void> _load() async {
    final studyChatId = widget.studyChatId;
    try {
      final chats = await _client().listChats();
      final bound = studyChatId == null
          ? ref.read(pendingPocketChatIdProvider)
          : await ref.read(pocketChatLinksProvider).pocketIdFor(studyChatId);
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _boundId = bound == null || bound.isEmpty ? null : bound;
        _loading = false;
        _error = null;
      });
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _use(String? pocketChatId) async {
    final studyChatId = widget.studyChatId;
    final links = ref.read(pocketChatLinksProvider);
    if (studyChatId == null) {
      ref.read(pendingPocketChatIdProvider.notifier).state = pocketChatId ?? '';
    } else if (pocketChatId == null || pocketChatId.isEmpty) {
      await links.clear(studyChatId);
      ref.read(pendingPocketChatIdProvider.notifier).state = null;
    } else {
      await links.bind(studyChatId, pocketChatId);
      ref.read(pendingPocketChatIdProvider.notifier).state = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      TransientSnackBar(
        content: Text(
          pocketChatId == null || pocketChatId.isEmpty
              ? 'The next message starts a new browser chat.'
              : 'The next message continues that browser chat.',
        ),
      ),
    );
  }

  Future<void> _forget(PocketBrowserChat chat) async {
    try {
      await _client().forgetChat(chat.id);
      final studyChatId = widget.studyChatId;
      if (studyChatId != null && _boundId == chat.id) {
        await ref.read(pocketChatLinksProvider).clear(studyChatId);
      }
      if (ref.read(pendingPocketChatIdProvider) == chat.id) {
        ref.read(pendingPocketChatIdProvider.notifier).state = null;
      }
      await _load();
    } on AiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(TransientSnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Pocket chats', style: theme.textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('Start a new browser chat'),
              subtitle: const Text('The next message opens a fresh page.'),
              onTap: () => _use(null),
            ),
            const Divider(height: 1),
            Expanded(child: _body(theme)),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No browser chats yet. Send a message and it will be listed here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        final selected = chat.id == _boundId;
        return ListTile(
          selected: selected,
          leading: Icon(_appIcon(chat.app)),
          title: Text(chat.title.isEmpty ? 'Chat' : chat.title),
          subtitle: Text(_appLabel(chat.app)),
          trailing: IconButton(
            tooltip: 'Forget this chat',
            icon: const Icon(Icons.close),
            onPressed: () => _forget(chat),
          ),
          onTap: () => _use(chat.id),
        );
      },
    );
  }

  IconData _appIcon(String app) {
    return switch (app) {
      'claude' => Icons.chat_bubble_outline,
      'gemini' => Icons.auto_awesome_outlined,
      _ => Icons.forum_outlined,
    };
  }

  String _appLabel(String app) {
    return switch (app) {
      'claude' => 'Claude',
      'gemini' => 'Gemini',
      _ => 'ChatGPT',
    };
  }
}
