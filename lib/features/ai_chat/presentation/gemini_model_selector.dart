import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../ai_assistant/domain/deepseek_model_registry.dart';
import '../../ai_assistant/domain/gemini_model_registry.dart';
import '../data/ai_chat_providers.dart';
import '../domain/ai_chat_models.dart';

Future<String?> showGeminiModelSelector(
  BuildContext context, {
  required String selectedModelId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _AiModelSelectorSheet(selectedModelId: selectedModelId),
  );
}

class _AiModelSelectorSheet extends ConsumerWidget {
  const _AiModelSelectorSheet({required this.selectedModelId});

  final String selectedModelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(availableChatModelsProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: modelsAsync.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _ModelList(
            models: [
              ...GeminiModelRegistry.fallbackChatModels().map(
                AiSelectableModel.fromGemini,
              ),
              ...DeepSeekModelRegistry.selectableModels().map(
                AiSelectableModel.fromDeepSeek,
              ),
            ],
            selectedModelId: selectedModelId,
          ),
          data: (models) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose AI Model', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: _ModelList(
                  models: models,
                  selectedModelId: selectedModelId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelList extends StatelessWidget {
  const _ModelList({required this.models, required this.selectedModelId});

  final List<AiSelectableModel> models;
  final String selectedModelId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<AiSelectableModel>>{};
    for (final model in models) {
      groups.putIfAbsent(model.group, () => []).add(model);
    }

    return ListView(
      shrinkWrap: true,
      children: [
        for (final entry in groups.entries)
          if (entry.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                entry.key,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final model in entry.value)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selectedModelId == model.id
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: selectedModelId == model.id
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(model.displayName)),
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
                  '${model.description}\n${model.id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                isThreeLine: true,
                onTap: () => Navigator.pop(context, model.id),
              ),
          ],
      ],
    );
  }
}
