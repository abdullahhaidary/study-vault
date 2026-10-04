import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/presentation/ai_assistant_controller.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import '../data/pdf_ai_material_providers.dart';
import '../domain/pdf_ai_material_models.dart';
import 'pdf_ai_material_reader_screen.dart';

class PdfAiMaterialsPanel extends ConsumerWidget {
  const PdfAiMaterialsPanel({
    super.key,
    required this.materialId,
    required this.title,
    required this.filePath,
    required this.onClose,
  });

  final String materialId;
  final String title;
  final String filePath;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(pdfAiMaterialsProvider(materialId));
    final selectedType = ref.watch(
      pdfAiMaterialSelectedTypeProvider(materialId),
    );
    final theme = Theme.of(context);

    return Material(
      elevation: 16,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Row(
                      children: [
                        for (final type in PdfAiMaterialType.values)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xxs,
                            ),
                            child: _ExplanationTabButton(
                              label: type.shortName,
                              selected: selectedType == type,
                              onPressed: () =>
                                  ref
                                          .read(
                                            pdfAiMaterialSelectedTypeProvider(
                                              materialId,
                                            ).notifier,
                                          )
                                          .state =
                                      type,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close AI explanations',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: materialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('Could not load AI study materials.'),
              ),
              data: (materials) {
                return _MaterialTypeView(
                  key: ValueKey('$materialId-${selectedType.name}'),
                  materialId: materialId,
                  title: title,
                  filePath: filePath,
                  type: selectedType,
                  current: _latestFor(materials, selectedType),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PdfAiMaterial? _latestFor(
    List<PdfAiMaterial> materials,
    PdfAiMaterialType type,
  ) {
    for (final material in materials) {
      if (material.type == type.storageValue) return material;
    }
    return null;
  }
}

class _ExplanationTabButton extends StatelessWidget {
  const _ExplanationTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialTypeView extends ConsumerStatefulWidget {
  const _MaterialTypeView({
    super.key,
    required this.materialId,
    required this.title,
    required this.filePath,
    required this.type,
    required this.current,
  });

  final String materialId;
  final String title;
  final String filePath;
  final PdfAiMaterialType type;
  final PdfAiMaterial? current;

  @override
  ConsumerState<_MaterialTypeView> createState() => _MaterialTypeViewState();
}

class _MaterialTypeViewState extends ConsumerState<_MaterialTypeView> {
  bool _generating = false;

  Future<void> _generate() async {
    if (_generating) return;
    if (!await AiAssistantController.ensureReady(context, ref)) return;
    if (!mounted) return;

    var selection = await AiExecutionSelection.fromGlobal(
      ref.read(aiSettingsStoreProvider),
      action: AiStudyAction.customPrompt,
    );
    if (!mounted) return;
    selection =
        await showAiModelSelector(
          context,
          selected: selection,
          action: AiStudyAction.customPrompt,
          title: 'Generate with',
        ) ??
        selection;

    setState(() => _generating = true);
    try {
      await ref
          .read(pdfAiMaterialServiceProvider)
          .generate(
            materialId: widget.materialId,
            title: widget.title,
            filePath: widget.filePath,
            type: widget.type,
            selection: selection,
            customInstruction: '',
          );
    } on AiException catch (error) {
      _showError(error.message);
    } on Object catch (error) {
      final text = error.toString();
      _showError(
        text.contains('no extractable text')
            ? 'This PDF has no extractable text. OCR is not available yet.'
            : 'Could not generate ${widget.type.shortName.toLowerCase()}.',
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    if (current != null) {
      return PdfAiMaterialReaderScreen(
        materialId: widget.materialId,
        pdfTitle: widget.title,
        filePath: widget.filePath,
        type: widget.type,
        initialGenerationId: current.id,
        embedded: true,
      );
    }

    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(widget.type),
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${widget.type.shortName} has not been generated yet.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating ? 'Generating…' : 'Generate'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(PdfAiMaterialType type) => switch (type) {
    PdfAiMaterialType.summary => Icons.summarize_outlined,
    PdfAiMaterialType.explanation => Icons.school_outlined,
    PdfAiMaterialType.deepExplanation => Icons.psychology_outlined,
    PdfAiMaterialType.realWorldExamples => Icons.public_outlined,
    PdfAiMaterialType.slideshow => Icons.slideshow_outlined,
  };
}
