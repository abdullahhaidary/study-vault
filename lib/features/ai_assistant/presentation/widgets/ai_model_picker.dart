import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/ai_model_catalog_providers.dart';
import '../../data/ai_providers.dart';
import '../../domain/ai_actions.dart';
import '../../domain/ai_endpoint_profile.dart';
import '../../domain/ai_execution_selection.dart';
import '../../domain/ai_model_ref.dart';
import '../../domain/ai_provider.dart';
import '../../domain/ai_selectable_model.dart';
import '../../domain/deepseek_model_registry.dart';
import '../../domain/gemini_model_registry.dart';
import 'deepseek_pricing_banner.dart';

/// Opens the shared provider/model picker and returns an execution selection.
Future<AiExecutionSelection?> showAiModelSelector(
  BuildContext context, {
  required AiExecutionSelection selected,
  AiStudyAction? action,
  AiExecutionConstraints constraints = AiExecutionConstraints.none,
  String title = 'Choose AI',
  String? subtitle,
}) {
  return showModalBottomSheet<AiExecutionSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AiModelSelectorSheet(
      selected: selected,
      action: action,
      constraints: constraints,
      title: title,
      subtitle:
          subtitle ??
          (constraints.visionOnly
              ? 'Page images go to a Gemini vision model or a Pocket chat.'
              : 'Pick Gemini, DeepSeek, Pocket, or a model from one of your API profiles.'),
    ),
  );
}

/// Compact control that shows the current selection and opens the picker.
class AiModelPickerButton extends StatelessWidget {
  const AiModelPickerButton({
    super.key,
    required this.selection,
    required this.onChanged,
    this.action,
    this.constraints = AiExecutionConstraints.none,
    this.compact = false,
  });

  final AiExecutionSelection selection;
  final ValueChanged<AiExecutionSelection> onChanged;
  final AiStudyAction? action;
  final AiExecutionConstraints constraints;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _displayName(selection);
    final isDeepSeek = selection.provider == AiProviderId.deepseek;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final next = await showAiModelSelector(
              context,
              selected: selection,
              action: action,
              constraints: constraints,
            );
            if (next != null) onChanged(next);
          },
          icon: Icon(
            selection.provider == AiProviderId.gemini
                ? Icons.auto_awesome
                : Icons.psychology_outlined,
            size: compact ? 16 : 18,
          ),
          label: Text(
            compact ? label : '${_providerLabel(selection)} · $label',
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            textStyle: theme.textTheme.labelMedium,
          ),
        ),
        DeepSeekPricingBanner(
          visible: isDeepSeek,
          style: DeepSeekPricingBannerStyle.chip,
        ),
      ],
    );
  }
}

String _providerLabel(AiExecutionSelection selection) {
  if (selection.provider != AiProviderId.newApi) {
    return selection.provider.displayName;
  }
  return 'Custom API';
}

String _displayName(AiExecutionSelection selection) {
  if (selection.provider == AiProviderId.deepseek &&
      DeepSeekModelIds.isAuto(selection.requestedModelId)) {
    return 'Auto → ${DeepSeekModelRegistry.normalize(selection.resolvedModelId)}';
  }
  if (selection.provider == AiProviderId.gemini) {
    final def = GeminiModelRegistry.byId(selection.resolvedModelId);
    return def?.displayName ?? selection.resolvedModelId;
  }
  if (selection.provider == AiProviderId.newApi) {
    final bare = newApiBareModelId(selection.resolvedModelId);
    return bare.isEmpty ? 'Model not set' : bare;
  }
  if (selection.provider == AiProviderId.pocket) {
    return PocketModelRef.normalize(selection.resolvedModelId).chatLabel;
  }
  final def = DeepSeekModelRegistry.byId(selection.resolvedModelId);
  return def?.displayName ?? selection.resolvedModelId;
}

class _AiModelSelectorSheet extends ConsumerStatefulWidget {
  const _AiModelSelectorSheet({
    required this.selected,
    required this.action,
    required this.constraints,
    required this.title,
    required this.subtitle,
  });

  final AiExecutionSelection selected;
  final AiStudyAction? action;
  final AiExecutionConstraints constraints;
  final String title;
  final String subtitle;

  @override
  ConsumerState<_AiModelSelectorSheet> createState() =>
      _AiModelSelectorSheetState();
}

class _AiModelSelectorSheetState extends ConsumerState<_AiModelSelectorSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(
      availableAiModelsProvider(widget.constraints),
    );
    final profiles =
        ref.watch(aiEndpointProfilesProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: modelsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _ModelList(
              models: _filter(_fallback(widget.constraints)),
              selected: widget.selected,
              action: widget.action,
            ),
            data: (models) {
              final rows = _filter(_withPreviousSelection(models, profiles));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (models.length >= 8) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filter models',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: _ModelList(
                      models: rows,
                      selected: widget.selected,
                      action: widget.action,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<AiSelectableModel> _filter(List<AiSelectableModel> models) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return models;
    return [
      for (final model in models)
        if (model.displayName.toLowerCase().contains(query) ||
            model.sectionLabel.toLowerCase().contains(query) ||
            (model.endpointHost ?? '').toLowerCase().contains(query))
          model,
    ];
  }

  List<AiSelectableModel> _withPreviousSelection(
    List<AiSelectableModel> models,
    List<AiEndpointProfile> profiles,
  ) {
    final selected = widget.selected;
    if (selected.provider != AiProviderId.newApi) return models;
    final profileId = selected.endpointProfileId;
    final bare = newApiBareModelId(selected.resolvedModelId);
    if (profileId == null || bare.isEmpty) return models;
    final already = models.any(
      (model) =>
          model.endpointProfileId == profileId &&
          newApiBareModelId(model.id) == bare,
    );
    if (already) return models;
    final profile = profiles.where((item) => item.id == profileId).firstOrNull;
    final ref = EndpointAiModelRef(profileId: profileId, modelId: bare);
    return [
      ...models,
      AiSelectableModel(
        id: ref.storageValue,
        displayName: bare,
        description: profile == null
            ? 'API profile unavailable'
            : 'Previously selected — unavailable',
        recommended: false,
        group: profile?.name ?? 'API profile',
        section: profile?.name ?? 'API profile',
        provider: AiProviderId.newApi,
        enabled: profile != null && !widget.constraints.visionOnly,
        disabledReason: widget.constraints.visionOnly
            ? 'Custom API profiles are text-only. Use a Gemini vision model.'
            : profile == null
            ? 'API profile unavailable'
            : null,
        endpointProfileId: profileId,
        endpointHost: profile?.host,
        modelListStale: true,
        modelRef: ref,
      ),
    ];
  }

  List<AiSelectableModel> _fallback(AiExecutionConstraints constraints) {
    return [
      ...GeminiModelRegistry.fallbackChatModels().map(
        AiSelectableModel.fromGemini,
      ),
      if (constraints.deepSeekEnabled)
        ...DeepSeekModelRegistry.selectableModels().map(
          AiSelectableModel.fromDeepSeek,
        ),
      ...pocketSelectableModels(),
    ];
  }
}

class _ModelList extends ConsumerWidget {
  const _ModelList({
    required this.models,
    required this.selected,
    required this.action,
  });

  final List<AiSelectableModel> models;
  final AiExecutionSelection selected;
  final AiStudyAction? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sections = <String, List<AiSelectableModel>>{};
    for (final model in models) {
      sections.putIfAbsent(model.sectionLabel, () => []).add(model);
    }

    return ListView(
      children: [
        for (final entry in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (entry.value.first.endpointProfileId case final profileId?)
                  IconButton(
                    tooltip: 'Refresh models',
                    onPressed: () async {
                      await ref
                          .read(newApiClaudeServiceProvider)
                          .refreshCachedModels(profileId);
                      ref.invalidate(availableAiModelsProvider);
                    },
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          ),
          if (entry.value.first.endpointHost case final host?)
            Text(
              entry.value.first.modelListStale
                  ? '$host · cached model list is stale'
                  : host,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (entry.value.first.provider == AiProviderId.deepseek &&
              entry.value.first.endpointProfileId == null) ...[
            const DeepSeekPricingBanner(style: DeepSeekPricingBannerStyle.full),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final model in entry.value)
            ListTile(
              enabled: model.enabled,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _isSelected(model) ? Icons.check_circle : Icons.circle_outlined,
                color: _isSelected(model)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      model.displayName,
                      style: TextStyle(
                        color: model.enabled
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                      ),
                    ),
                  ),
                  if (model.recommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: AppRadii.smAll,
                      ),
                      child: Text(
                        'Recommended',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                model.enabled
                    ? model.description
                    : (model.disabledReason ?? model.description),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: !model.enabled
                  ? null
                  : () {
                      final refModel = model.modelRef;
                      Navigator.pop(
                        context,
                        refModel == null
                            ? AiExecutionSelection.resolve(
                                provider: model.provider,
                                requestedModelId: model.id,
                                action: action,
                              )
                            : AiExecutionSelection.fromModelRef(
                                refModel,
                                action: action,
                              ),
                      );
                    },
            ),
        ],
      ],
    );
  }

  bool _isSelected(AiSelectableModel model) {
    if (model.endpointProfileId != null || selected.endpointProfileId != null) {
      return model.endpointProfileId == selected.endpointProfileId &&
          newApiBareModelId(model.id) ==
              newApiBareModelId(selected.requestedModelId);
    }
    return selected.requestedModelId == model.id ||
        selected.resolvedModelId == model.id;
  }
}

/// Loads the global default selection for a sheet/screen.
Future<AiExecutionSelection> loadGlobalAiSelection(
  WidgetRef ref, {
  required AiStudyAction? action,
}) {
  return AiExecutionSelection.fromGlobal(
    ref.read(aiSettingsStoreProvider),
    action: action,
  );
}
