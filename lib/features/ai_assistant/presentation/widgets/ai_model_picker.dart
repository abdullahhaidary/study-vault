import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/ai_model_catalog_providers.dart';
import '../../data/ai_providers.dart';
import '../../domain/ai_actions.dart';
import '../../domain/ai_execution_selection.dart';
import '../../domain/ai_provider.dart';
import '../../domain/ai_selectable_model.dart';
import '../../domain/deepseek_model_registry.dart';
import '../../domain/gemini_model_registry.dart';

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
              ? 'Page images require a Gemini vision model.'
              : 'Pick Gemini or DeepSeek for this request.'),
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

    return OutlinedButton.icon(
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
        compact ? label : '${selection.provider.displayName} · $label',
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        textStyle: theme.textTheme.labelMedium,
      ),
    );
  }
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
  final def = DeepSeekModelRegistry.byId(selection.resolvedModelId);
  return def?.displayName ?? selection.resolvedModelId;
}

class _AiModelSelectorSheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(availableAiModelsProvider(constraints));
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
              models: _fallback(constraints),
              selected: selected,
              action: action,
            ),
            data: (models) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: _ModelList(
                    models: models,
                    selected: selected,
                    action: action,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    ];
  }
}

class _ModelList extends StatelessWidget {
  const _ModelList({
    required this.models,
    required this.selected,
    required this.action,
  });

  final List<AiSelectableModel> models;
  final AiExecutionSelection selected;
  final AiStudyAction? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byProvider = <AiProviderId, List<AiSelectableModel>>{};
    for (final model in models) {
      byProvider.putIfAbsent(model.provider, () => []).add(model);
    }
    final order = [
      AiProviderId.gemini,
      AiProviderId.deepseek,
      ...byProvider.keys.where(
        (id) => id != AiProviderId.gemini && id != AiProviderId.deepseek,
      ),
    ];

    return ListView(
      children: [
        for (final provider in order)
          if (byProvider[provider] case final items?) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                provider.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final model in items)
              ListTile(
                enabled: model.enabled,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected.requestedModelId == model.id ||
                          selected.resolvedModelId == model.id
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color:
                      selected.requestedModelId == model.id ||
                          selected.resolvedModelId == model.id
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
                        final thinking = provider == AiProviderId.deepseek
                            ? null
                            : null;
                        Navigator.pop(
                          context,
                          AiExecutionSelection.resolve(
                            provider: provider,
                            requestedModelId: model.id,
                            action: action,
                            thinkingMode: thinking,
                          ),
                        );
                      },
              ),
          ],
      ],
    );
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
