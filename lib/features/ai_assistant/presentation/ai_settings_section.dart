import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/transient_snack_bar.dart';
import '../../ai_chat/data/ai_chat_providers.dart';
import '../data/ai_credential_store.dart';
import '../data/ai_providers.dart';
import '../data/ai_model_catalog_providers.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_model_ref.dart';
import 'ai_endpoint_profiles_section.dart';
import 'ai_style_memory_settings.dart';
import '../domain/deepseek_model_registry.dart';
import 'pocket_accounts_section.dart';
import 'widgets/deepseek_pricing_banner.dart';

/// Settings → AI Assistant section (multi-provider).
class AiSettingsSection extends ConsumerStatefulWidget {
  const AiSettingsSection({super.key});

  @override
  ConsumerState<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<AiSettingsSection> {
  final _keyController = TextEditingController();
  final _pocketUrlController = TextEditingController();
  final _pocketUrlFocus = FocusNode();
  bool _saving = false;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void dispose() {
    _keyController.dispose();
    _pocketUrlController.dispose();
    _pocketUrlFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(aiSettingsStateProvider);
    ref.invalidate(aiConfiguredProvider);
    ref.invalidate(availableChatModelsProvider);
    ref.invalidate(availableAiModelsProvider);
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
          TransientSnackBar(
            content: Text('${provider.displayName} API key saved securely.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addGeminiKeys() async {
    final raw = _keyController.text;
    if (GeminiApiKeys.split(raw).isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(aiCredentialStoreProvider)
          .addApiKeyFor(AiProviderId.gemini, raw);
      _keyController.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const TransientSnackBar(
            content: Text('Gemini API key saved securely.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeGeminiKeyAt(int index, String suffix) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this Gemini key?'),
        content: Text(
          'Key ending in $suffix will be removed. Other Gemini keys stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(aiCredentialStoreProvider)
        .removeApiKeyAt(AiProviderId.gemini, index);
    await _refresh();
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

  Future<void> _savePocketUrl() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(aiSettingsStoreProvider)
          .setPocketBaseUrl(_pocketUrlController.text);
      _pocketUrlFocus.unfocus();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const TransientSnackBar(content: Text('Pocket address saved.')),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _testOk = false;
          _testMessage = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        if (!_pocketUrlFocus.hasFocus &&
            _pocketUrlController.text != state.pocketBaseUrl) {
          final next = state.pocketBaseUrl;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _pocketUrlFocus.hasFocus) return;
            if (_pocketUrlController.text != next) {
              _pocketUrlController.text = next;
            }
          });
        }

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
                    final store = ref.read(aiSettingsStoreProvider);
                    if (value == AiProviderId.newApi) {
                      final profiles = await ref
                          .read(aiEndpointProfileRepositoryProvider)
                          .list();
                      final active = await store.getActiveEndpointProfileId();
                      final profile =
                          profiles
                              .where((item) => item.id == active)
                              .firstOrNull ??
                          profiles
                              .where((item) => item.defaultModelId.isNotEmpty)
                              .firstOrNull;
                      if (profile != null &&
                          profile.defaultModelId.isNotEmpty) {
                        await store.setGlobalModelRef(
                          EndpointAiModelRef(
                            profileId: profile.id,
                            modelId: profile.defaultModelId,
                          ),
                        );
                      } else {
                        await store.setProvider(value);
                      }
                    } else {
                      await store.setGlobalModelRef(
                        AiModelRef.parse(await store.getModelIdFor(value)),
                      );
                    }
                    if (!mounted) return;
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
                if (provider == AiProviderId.newApi) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a profile below as the global default. Each profile keeps its own server, key, and models.',
                  ),
                ],
                if (provider == AiProviderId.deepseek) ...[
                  const SizedBox(height: 12),
                  const DeepSeekPricingBanner(
                    style: DeepSeekPricingBannerStyle.full,
                  ),
                ],
                const SizedBox(height: 16),
                if (provider != AiProviderId.pocket) ...[
                  Text(
                    provider == AiProviderId.gemini
                        ? 'Gemini API keys'
                        : '${provider.displayName} API Key',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                ],
                if (provider == AiProviderId.pocket) ...[
                  Text('Pocket window', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Chat, study actions, quizzes, book questions, document '
                    'generation, and Persian translation are typed into the '
                    'signed-in Pocket tab. Start Pocket and sign in first. '
                    'Each request opens a new chat in that tab.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pocketUrlController,
                    focusNode: _pocketUrlFocus,
                    decoration: const InputDecoration(
                      labelText: 'Pocket address',
                      hintText: 'http://127.0.0.1:8765',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _savePocketUrl(),
                  ),
                  const SizedBox(height: 8),
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
                        onPressed: _saving ? null : _savePocketUrl,
                        child: const Text('Save address'),
                      ),
                    ],
                  ),
                  const PocketAccountsSection(),
                ] else if (provider == AiProviderId.gemini) ...[
                  if (state.geminiKeyCount == 0)
                    Text(
                      'Gemini API key required',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    )
                  else ...[
                    Text(
                      state.geminiKeyCount == 1
                          ? '1 key configured. Add more free-account keys and '
                                'requests will try the next one if this key '
                                'hits quota or rate limits.'
                          : '${state.geminiKeyCount} keys configured. Each '
                                'request tries the next key if one fails.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < state.geminiKeySuffixes.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          'Key ${i + 1}  ••••${state.geminiKeySuffixes[i]}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove this key',
                          onPressed: () =>
                              _removeGeminiKeyAt(i, state.geminiKeySuffixes[i]),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
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
                        TextButton(
                          onPressed: () => _removeKey(provider),
                          child: const Text('Remove all keys'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    minLines: 1,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Add Gemini API key',
                      hintText: 'Paste one key, or several separated by lines',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saving ? null : _addGeminiKeys,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            state.geminiKeyCount == 0
                                ? 'Add API Key'
                                : 'Add another key',
                          ),
                  ),
                ] else if (provider == AiProviderId.newApi) ...[
                  Text(
                    'API keys are saved on each profile below and are not shown again.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else if (configured) ...[
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
                        onPressed:
                            _testing ||
                                (provider == AiProviderId.newApi &&
                                    (state.newApiBaseUrl.isEmpty ||
                                        state.modelId.length <= 7))
                            ? null
                            : _test,
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
                const AiEndpointProfilesSection(),
                const SizedBox(height: 16),
                if (provider != AiProviderId.newApi) ...[
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
                ],
                const SizedBox(height: 16),
                Text(
                  'Gemini automatic retries',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: state.geminiRetryCount,
                  items: [
                    for (
                      var count = 0;
                      count <= AiSettingsStore.maxGeminiRetryCount;
                      count++
                    )
                      DropdownMenuItem(
                        value: count,
                        child: Text(
                          count == 0
                              ? 'Off'
                              : count == 1
                              ? '1 retry'
                              : '$count retries',
                        ),
                      ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await ref
                        .read(aiSettingsStoreProvider)
                        .setGeminiRetryCount(value);
                    await _refresh();
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'If a Gemini key hits rate limits or quota, the next saved '
                  'key is tried immediately. After every key has failed, this '
                  'retry count repeats the whole list with a short delay.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                AiStyleMemorySettings(
                  items: state.styleMemoryItems,
                  onChanged: _refresh,
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
                if (state.geminiConfigured ||
                    state.deepseekConfigured ||
                    state.newApiConfigured) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Configured keys: '
                    '${[if (state.geminiConfigured) state.geminiKeyCount > 1 ? 'Gemini (${state.geminiKeyCount})' : 'Gemini', if (state.deepseekConfigured) 'DeepSeek', if (state.newApiConfigured) 'New API'].join(', ')}. Switching provider keeps each key.',
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
                        const TransientSnackBar(
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
