import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_chat/data/ai_chat_providers.dart';
import '../data/ai_providers.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_provider.dart';
import '../domain/deepseek_model_registry.dart';

/// Settings → AI Assistant section (multi-provider).
class AiSettingsSection extends ConsumerStatefulWidget {
  const AiSettingsSection({super.key});

  @override
  ConsumerState<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<AiSettingsSection> {
  final _keyController = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(aiSettingsStateProvider);
    ref.invalidate(aiConfiguredProvider);
    ref.invalidate(availableChatModelsProvider);
  }

  Future<void> _saveKey(AiProviderId provider) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(aiCredentialStoreProvider)
          .saveApiKeyFor(provider, _keyController.text);
      _keyController.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${provider.displayName} API key saved securely.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeKey(AiProviderId provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${provider.displayName} API key?'),
        content: Text(
          'AI features using ${provider.displayName} will stop until you add '
          'a key again. Your notes, pins, and flashcards are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Key'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(aiCredentialStoreProvider).removeApiKeyFor(provider);
    await _refresh();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      await ref.read(aiServiceProvider).testConnection();
      final provider = await ref.read(aiSettingsStoreProvider).getProvider();
      setState(() {
        _testOk = true;
        _testMessage = '✓ Connected to ${provider.displayName}';
      });
    } on AiException catch (e) {
      setState(() {
        _testOk = false;
        _testMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _testOk = false;
        _testMessage = 'Connection failed.';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _showReplaceKeyDialog(AiProviderId provider) async {
    _keyController.clear();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Replace ${provider.displayName} Key'),
        content: TextField(
          controller: _keyController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'New ${provider.displayName} API key',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveKey(provider);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(aiSettingsStateProvider);

    return stateAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) =>
          Card(child: ListTile(title: Text('AI settings error: $e'))),
      data: (state) {
        final provider = state.provider;
        final configured = state.configured;
        final modelItems = AiModels.selectableIds(provider);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('AI Assistant', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'AI helps only when you ask. Study data stays local unless '
                  'you run an AI action.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Default Provider', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                DropdownButtonFormField<AiProviderId>(
                  initialValue: provider,
                  items: [
                    for (final p in AiProviderId.values)
                      DropdownMenuItem(value: p, child: Text(p.displayName)),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await ref.read(aiSettingsStoreProvider).setProvider(value);
                    setState(() {
                      _testMessage = null;
                    });
                    await _refresh();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  provider.privacyLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${provider.displayName} API Key',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (configured) ...[
                  Text('••••••••••••••••', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      const Text('Key configured'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: _testing ? null : _test,
                        child: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Test Connection'),
                      ),
                      OutlinedButton(
                        onPressed: () => _showReplaceKeyDialog(provider),
                        child: const Text('Replace Key'),
                      ),
                      TextButton(
                        onPressed: () => _removeKey(provider),
                        child: const Text('Remove Key'),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    '${provider.displayName} API key required',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Enter API key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saving ? null : () => _saveKey(provider),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add API Key'),
                  ),
                ],
                if (_testMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _testMessage!,
                    style: TextStyle(
                      color: _testOk
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Default Model', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  key: ValueKey('model-${provider.name}-${state.modelId}'),
                  initialValue: modelItems.contains(state.modelId)
                      ? state.modelId
                      : modelItems.first,
                  items: [
                    for (final id in modelItems)
                      DropdownMenuItem(
                        value: id,
                        child: Text(AiModels.label(provider, id)),
                      ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await ref
                        .read(aiSettingsStoreProvider)
                        .setModelIdFor(provider, value);
                    await _refresh();
                  },
                ),
                if (provider == AiProviderId.deepseek) ...[
                  const SizedBox(height: 16),
                  Text('Thinking', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<AiThinkingMode>(
                    initialValue: state.thinkingMode,
                    items: [
                      for (final mode in AiThinkingMode.values)
                        DropdownMenuItem(value: mode, child: Text(mode.label)),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await ref
                          .read(aiSettingsStoreProvider)
                          .setThinkingMode(value);
                      await _refresh();
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thinking improves difficult answers. Reasoning traces '
                    'are never shown. Auto uses Low for quick study actions '
                    'and High for quizzes / hard tasks. '
                    'Flash default: ${DeepSeekModelRegistry.byId(DeepSeekModelRegistry.flash)?.displayName}; '
                    'Pro for harder work when Model is Auto.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Default Language', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                DropdownButtonFormField<AiLanguage>(
                  initialValue: state.language,
                  items: [
                    for (final lang in AiLanguage.values)
                      DropdownMenuItem(value: lang, child: Text(lang.label)),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await ref.read(aiSettingsStoreProvider).setLanguage(value);
                    await _refresh();
                  },
                ),
                const SizedBox(height: 16),
                Text('AI Study Preference', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: state.studyPreference ?? '',
                  maxLength: 240,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText:
                        'Explain simply and preserve English technical terms…',
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) async {
                    await ref
                        .read(aiSettingsStoreProvider)
                        .setStudyPreference(value);
                    await _refresh();
                  },
                  onChanged: (_) {},
                  onSaved: (value) async {
                    await ref
                        .read(aiSettingsStoreProvider)
                        .setStudyPreference(value);
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final controller = TextEditingController(
                        text: state.studyPreference ?? '',
                      );
                      final saved = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('AI Study Preference'),
                          content: TextField(
                            controller: controller,
                            maxLength: 240,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, controller.text),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      if (saved != null) {
                        await ref
                            .read(aiSettingsStoreProvider)
                            .setStudyPreference(saved);
                        await _refresh();
                      }
                    },
                    child: const Text('Edit preference'),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('AI privacy consent'),
                  subtitle: Text(
                    state.privacyConsent
                        ? 'Accepted — reset to show the notice again'
                        : 'Not accepted yet',
                  ),
                  value: state.privacyConsent,
                  onChanged: (value) async {
                    await ref
                        .read(aiSettingsStoreProvider)
                        .setPrivacyConsentAccepted(value);
                    await _refresh();
                  },
                ),
                if (state.geminiConfigured || state.deepseekConfigured) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Configured keys: '
                    '${[if (state.geminiConfigured) 'Gemini', if (state.deepseekConfigured) 'DeepSeek'].join(', ')}. Switching provider keeps each key.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear all AI chats?'),
                        content: const Text(
                          'Every Study AI conversation on this device will be '
                          'deleted. This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear chats'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await ref.read(aiChatServiceProvider).deleteAllChats();
                    ref.read(activeAiChatIdProvider.notifier).state = null;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI chat history cleared.'),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Clear chat history',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
