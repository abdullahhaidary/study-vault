import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_chat/data/ai_chat_providers.dart';
import '../data/ai_credential_store.dart';
import '../data/ai_providers.dart';
import '../data/ai_model_catalog_providers.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_provider.dart';
import '../domain/deepseek_model_registry.dart';
import '../domain/deepseek_pricing_period.dart';

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
  bool _loadingModels = false;
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
          SnackBar(
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
          const SnackBar(content: Text('Gemini API key saved securely.')),
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

  Future<void> _browseNewApiModels() async {
    setState(() => _loadingModels = true);
    try {
      final models = await ref
          .read(newApiClaudeServiceProvider)
          .listAvailableModels();
      if (!mounted) return;
      if (models.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This key has no available models on the server.'),
          ),
        );
        return;
      }
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose a Claude-compatible model'),
          content: SizedBox(
            width: 400,
            height: 360,
            child: ListView.builder(
              itemCount: models.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(models[index]),
                onTap: () => Navigator.pop(context, models[index]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      await ref
          .read(aiSettingsStoreProvider)
          .setModelIdFor(AiProviderId.newApi, selected);
      await _refresh();
    } on AiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load models from the New API server.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _editNewApiConfig(AiSettingsState state) async {
    final url = TextEditingController(text: state.newApiBaseUrl);
    final model = TextEditingController(
      text: state.modelId.replaceFirst(RegExp(r'^newapi:'), ''),
    );
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New API Claude server'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'HTTPS server base URL',
                  hintText: 'https://your-server.example/v1',
                ),
              ),
              TextField(
                controller: model,
                decoration: const InputDecoration(
                  labelText: 'Claude model ID',
                  hintText: 'Model ID enabled on your server',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (save != true) return;
      if (model.text.trim().isEmpty || url.text.trim().isEmpty) {
        throw const FormatException('Enter a server URL and model ID.');
      }
      await ref.read(aiSettingsStoreProvider).setNewApiBaseUrl(url.text);
      await ref
          .read(aiSettingsStoreProvider)
          .setModelIdFor(AiProviderId.newApi, model.text);
      await _refresh();
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      url.dispose();
      model.dispose();
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
                if (provider == AiProviderId.newApi) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Server: ${state.newApiBaseUrl.isEmpty ? 'Not set' : state.newApiBaseUrl}',
                  ),
                  Text(
                    'Model: ${state.modelId.length <= 7 ? 'Not set' : state.modelId.substring(7)}',
                  ),
                  TextButton(
                    onPressed: () => _editNewApiConfig(state),
                    child: const Text('Edit server and model'),
                  ),
                  TextButton(
                    onPressed:
                        _loadingModels ||
                            !state.newApiConfigured ||
                            state.newApiBaseUrl.isEmpty
                        ? null
                        : _browseNewApiModels,
                    child: Text(
                      _loadingModels
                          ? 'Loading models…'
                          : 'Browse available models',
                    ),
                  ),
                  const Text(
                    'Use your own New API server URL, not the documentation URL.',
                  ),
                ],
                if (provider == AiProviderId.deepseek) ...[
                  const SizedBox(height: 12),
                  const _DeepSeekPricingPeriodBanner(),
                ],
                const SizedBox(height: 16),
                Text(
                  provider == AiProviderId.gemini
                      ? 'Gemini API keys'
                      : '${provider.displayName} API Key',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (provider == AiProviderId.gemini) ...[
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

/// Live DeepSeek peak / off-peak pricing indicator (Afghanistan-friendly copy).
class _DeepSeekPricingPeriodBanner extends StatelessWidget {
  const _DeepSeekPricingPeriodBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = DeepSeekPricingSchedule.now();
    final isPeak = period == DeepSeekPricingPeriod.peak;
    final scheme = theme.colorScheme;
    final accent = isPeak ? scheme.tertiary : scheme.primary;
    final bg = accent.withValues(alpha: 0.12);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPeak ? Icons.trending_up : Icons.savings_outlined,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DeepSeek pricing: ${period.label}',
                    style: theme.textTheme.titleSmall?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              period.shortHint,
              style: theme.textTheme.labelMedium?.copyWith(color: accent),
            ),
            const SizedBox(height: 6),
            Text(
              DeepSeekPricingSchedule.afghanistanPeakHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
