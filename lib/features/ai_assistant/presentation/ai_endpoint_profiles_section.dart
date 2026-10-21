import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_model_catalog_providers.dart';
import '../data/ai_providers.dart';
import '../domain/ai_endpoint_profile.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_model_ref.dart';
import '../domain/gemini_model_registry.dart';
import '../../ai_generation_queue/data/ai_generation_providers.dart';

/// Settings → AI API Profiles. Keys are written to secure storage and never
/// shown again after save.
class AiEndpointProfilesSection extends ConsumerWidget {
  const AiEndpointProfilesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profilesAsync = ref.watch(aiEndpointProfilesProvider);
    final settingsAsync = ref.watch(aiSettingsStateProvider);
    final globalId = settingsAsync.valueOrNull?.globalModelId;
    final global = globalId == null ? null : AiModelRef.parse(globalId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('AI API Profiles', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Each profile has its own server, key, and model list. '
          'Keys stay on this device.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        profilesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Could not load API profiles: $error'),
          data: (profiles) => Column(
            children: [
              for (final profile in profiles)
                _ProfileCard(
                  profile: profile,
                  isGlobalDefault:
                      global is EndpointAiModelRef &&
                      global.profileId == profile.id,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => _addProfile(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add API profile'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile, required this.isGlobalDefault});

  final AiEndpointProfile profile;
  final bool isGlobalDefault;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final suffix = profile.keySuffix.isEmpty
        ? 'not saved'
        : '••••${profile.keySuffix}';
    final refreshed = profile.modelsRefreshedAt;
    final refreshedLabel = refreshed == null
        ? 'Not refreshed'
        : _clock(refreshed.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(profile.name, style: theme.textTheme.titleMedium),
                ),
                if (isGlobalDefault)
                  Text(
                    'Global default',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(profile.host),
            Text('Key $suffix'),
            Text(
              profile.defaultModelId.isEmpty
                  ? 'Default model: not set'
                  : 'Default model: ${profile.defaultModelId}',
            ),
            Text(
              '${profile.cachedModelIds.length} cached models · ${profile.modelListLabel}',
            ),
            Text('Last refresh: $refreshedLabel'),
            Text(
              profile.connectionDetail == null
                  ? 'Connection: ${profile.connectionStatus.label}'
                  : 'Connection: ${profile.connectionStatus.label} — ${profile.connectionDetail}',
            ),
            if (profile.warnsInsecureHttp)
              Text(
                'This profile uses HTTP on a local address.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => _editProfile(context, ref, profile),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => _test(context, ref, profile),
                  child: const Text('Test'),
                ),
                TextButton(
                  onPressed: () => _refresh(context, ref, profile),
                  child: const Text('Refresh models'),
                ),
                TextButton(
                  onPressed: () =>
                      _delete(context, ref, profile, isGlobalDefault),
                  child: const Text('Delete'),
                ),
                if (!isGlobalDefault)
                  TextButton(
                    onPressed: profile.defaultModelId.isEmpty
                        ? null
                        : () => _makeGlobal(ref, profile),
                    child: const Text('Use as global default'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _clock(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

Future<void> _reload(WidgetRef ref) async {
  ref.invalidate(aiEndpointProfilesProvider);
  ref.invalidate(aiSettingsStateProvider);
  ref.invalidate(aiConfiguredProvider);
  ref.invalidate(availableAiModelsProvider);
}

Future<void> _addProfile(BuildContext context, WidgetRef ref) async {
  final created = await _showProfileDialog(context);
  if (created == null) return;
  try {
    await ref
        .read(aiEndpointProfileRepositoryProvider)
        .create(
          name: created.name,
          baseUrl: created.baseUrl,
          apiKey: created.apiKey,
        );
    await _reload(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile saved. Test the connection, then refresh models.',
          ),
        ),
      );
    }
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _editProfile(
  BuildContext context,
  WidgetRef ref,
  AiEndpointProfile profile,
) async {
  final edited = await _showProfileDialog(context, existing: profile);
  if (edited == null) return;
  try {
    await ref
        .read(aiEndpointProfileRepositoryProvider)
        .update(
          id: profile.id,
          name: edited.name,
          baseUrl: edited.baseUrl,
          replacementApiKey: edited.apiKey,
          defaultModelId: edited.defaultModelId,
        );
    await _reload(ref);
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _test(
  BuildContext context,
  WidgetRef ref,
  AiEndpointProfile profile,
) async {
  try {
    await ref.read(newApiClaudeServiceProvider).testProfile(profile.id);
    await _reload(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connected to ${profile.name}.')));
    }
  } on AiException catch (error) {
    await _reload(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _refresh(
  BuildContext context,
  WidgetRef ref,
  AiEndpointProfile profile,
) async {
  try {
    final models = await ref
        .read(newApiClaudeServiceProvider)
        .refreshCachedModels(profile.id);
    if (!context.mounted) return;
    final selected = await _pickModel(
      context,
      models: models,
      current: profile.defaultModelId,
      title: profile.name,
    );
    if (selected != null) {
      await ref
          .read(aiEndpointProfileRepositoryProvider)
          .update(id: profile.id, defaultModelId: selected);
    }
    await _reload(ref);
  } on AiException catch (error) {
    await _reload(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _makeGlobal(WidgetRef ref, AiEndpointProfile profile) async {
  await ref
      .read(aiSettingsStoreProvider)
      .setGlobalModelRef(
        EndpointAiModelRef(
          profileId: profile.id,
          modelId: profile.defaultModelId,
        ),
      );
  await _reload(ref);
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  AiEndpointProfile profile,
  bool isGlobalDefault,
) async {
  final profiles = await ref.read(aiEndpointProfilesProvider.future);
  if (!context.mounted) return;
  AiModelRef replacement = BuiltinGeminiModelRef(
    GeminiModelRegistry.defaultModelId,
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text('Delete ${profile.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generated materials remain. Existing history remains readable. '
              'Queued or retry operations that use this profile will need another '
              'profile. The local secure key will be deleted.',
            ),
            if (isGlobalDefault) ...[
              const SizedBox(height: 12),
              const Text(
                'This profile is the global default. Choose a replacement.',
              ),
              const SizedBox(height: 8),
              DropdownButton<AiModelRef>(
                isExpanded: true,
                value: replacement,
                items: [
                  DropdownMenuItem(
                    value: BuiltinGeminiModelRef(
                      GeminiModelRegistry.defaultModelId,
                    ),
                    child: const Text('Gemini'),
                  ),
                  for (final other in profiles)
                    if (other.id != profile.id &&
                        other.defaultModelId.isNotEmpty)
                      DropdownMenuItem(
                        value: EndpointAiModelRef(
                          profileId: other.id,
                          modelId: other.defaultModelId,
                        ),
                        child: Text(other.name),
                      ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setLocal(() => replacement = value);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  await ref
      .read(aiGenerationCoordinatorProvider)
      .markProfileUnavailable(profile.id);
  await ref
      .read(aiEndpointProfileRepositoryProvider)
      .delete(
        profile.id,
        replacementDefault: isGlobalDefault ? replacement : null,
      );
  await _reload(ref);
}

class _ProfileDraft {
  const _ProfileDraft({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    this.defaultModelId,
  });

  final String name;
  final String baseUrl;
  final String apiKey;
  final String? defaultModelId;
}

Future<_ProfileDraft?> _showProfileDialog(
  BuildContext context, {
  AiEndpointProfile? existing,
}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final url = TextEditingController(text: existing?.baseUrl ?? '');
  final key = TextEditingController();
  final model = TextEditingController(text: existing?.defaultModelId ?? '');
  return showDialog<_ProfileDraft>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(existing == null ? 'Add API profile' : 'Edit API profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Profile name'),
            ),
            TextField(
              controller: url,
              decoration: const InputDecoration(
                labelText: 'Server base URL',
                hintText: 'https://your-server.example/v1',
              ),
            ),
            TextField(
              controller: key,
              obscureText: true,
              decoration: InputDecoration(
                labelText: existing == null ? 'API key' : 'Replacement API key',
                helperText: existing == null
                    ? 'Saved in secure storage. It is not shown again.'
                    : 'Leave blank to keep the saved key.',
              ),
            ),
            if (existing != null)
              TextField(
                controller: model,
                decoration: const InputDecoration(
                  labelText: 'Default model ID',
                  helperText:
                      'You can type a model if the server has no model list.',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final draft = _ProfileDraft(
              name: name.text,
              baseUrl: url.text,
              apiKey: key.text,
              defaultModelId: existing == null ? null : model.text,
            );
            key.clear();
            Navigator.pop(context, draft);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(() {
    name.dispose();
    url.dispose();
    key.dispose();
    model.dispose();
  });
}

Future<String?> _pickModel(
  BuildContext context, {
  required List<String> models,
  required String current,
  required String title,
}) {
  final manual = TextEditingController();
  var query = '';
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) {
        final visible = [
          for (final id in models)
            if (query.isEmpty || id.toLowerCase().contains(query.toLowerCase()))
              id,
        ];
        final missing = current.isNotEmpty && !models.contains(current);
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                if (models.length >= 8)
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Filter models',
                    ),
                    onChanged: (value) => setLocal(() => query = value),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      if (missing)
                        ListTile(
                          title: Text(current),
                          subtitle: const Text(
                            'Previously selected — unavailable',
                          ),
                          onTap: () => Navigator.pop(context, current),
                        ),
                      for (final id in visible)
                        ListTile(
                          title: Text(id),
                          onTap: () => Navigator.pop(context, id),
                        ),
                    ],
                  ),
                ),
                TextField(
                  controller: manual,
                  decoration: const InputDecoration(
                    labelText: 'Or enter a model ID',
                  ),
                  onChanged: (value) => setLocal(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: manual.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, manual.text.trim()),
              child: const Text('Use entered model'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(manual.dispose);
}
