import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/transient_snack_bar.dart';
import '../../ai_chat/data/ai_chat_providers.dart';
import '../data/ai_model_catalog_providers.dart';
import '../data/ai_providers.dart';
import '../domain/ai_exceptions.dart';
import '../services/pocket_client.dart';

/// Add and remove extra ChatGPT sign-ins for the Pocket window.
class PocketAccountsSection extends ConsumerStatefulWidget {
  const PocketAccountsSection({super.key});

  @override
  ConsumerState<PocketAccountsSection> createState() =>
      _PocketAccountsSectionState();
}

class _PocketAccountsSectionState extends ConsumerState<PocketAccountsSection> {
  final _name = TextEditingController();
  List<PocketAccount> _accounts = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  PocketClient _client() {
    return PocketClient(settings: ref.read(aiSettingsStoreProvider));
  }

  Future<void> _load() async {
    try {
      final accounts = await _client().listAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
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

  void _refreshPickers() {
    ref.invalidate(availableChatModelsProvider);
    ref.invalidate(availableAiModelsProvider);
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _client().addAccount(name);
      _name.clear();
      _refreshPickers();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const TransientSnackBar(
            content: Text('Window opened. Sign in to that ChatGPT account.'),
          ),
        );
      }
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(PocketAccount account) async {
    setState(() => _busy = true);
    try {
      await _client().removeAccount(account.id);
      _refreshPickers();
      await _load();
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = [
      for (final account in _accounts)
        if (account.id != 'default') account,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('ChatGPT accounts', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'The main Pocket window is one ChatGPT sign-in. Each extra account '
          'opens its own window. Sign in there, then choose it in the model list. '
          'Claude and Gemini stay in the main window.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator()
        else ...[
          Text(
            'Default — main Pocket window',
            style: theme.textTheme.bodyMedium,
          ),
          for (final account in extras)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(account.name),
              subtitle: const Text('Own ChatGPT window'),
              trailing: IconButton(
                tooltip: 'Remove ${account.name}',
                onPressed: _busy ? null : () => _remove(account),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'New account name',
                  hintText: 'Work',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _busy ? null : _add,
              child: const Text('Add'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
