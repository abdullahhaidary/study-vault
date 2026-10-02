import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../data/pdf_ai_material_providers.dart';
import '../domain/pdf_ai_material_models.dart';
import 'pdf_ai_material_reader_screen.dart';

Future<void> showPdfAiMaterialsSheet(
  BuildContext context, {
  required String materialId,
  required String title,
  required String filePath,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PdfAiMaterialsSheet(
      materialId: materialId,
      title: title,
      filePath: filePath,
    ),
  );
}

class PdfAiMaterialsSheet extends ConsumerStatefulWidget {
  const PdfAiMaterialsSheet({
    super.key,
    required this.materialId,
    required this.title,
    required this.filePath,
  });

  final String materialId;
  final String title;
  final String filePath;

  @override
  ConsumerState<PdfAiMaterialsSheet> createState() =>
      _PdfAiMaterialsSheetState();
}

class _PdfAiMaterialsSheetState extends ConsumerState<PdfAiMaterialsSheet> {
  final Set<PdfAiMaterialType> _generating = {};

  Future<void> _generate(
    PdfAiMaterialType type, {
    PdfAiMaterial? current,
  }) async {
    if (_generating.contains(type)) return;
    final instruction = current == null
        ? await _confirmInitialGeneration(type)
        : await _regenerationInstruction(type);
    if (instruction == null || !mounted) return;

    setState(() => _generating.add(type));
    try {
      final generated = await ref
          .read(pdfAiMaterialServiceProvider)
          .generate(
            materialId: widget.materialId,
            title: widget.title,
            filePath: widget.filePath,
            type: type,
            customInstruction: instruction,
          );
      if (!mounted) return;
      await _open(type, generated.id);
    } on AiException catch (error) {
      _showError(error.message);
    } on Object catch (error) {
      final raw = error.toString();
      _showError(
        raw.contains('no extractable text')
            ? 'This PDF has no extractable text. OCR is not available yet.'
            : 'Could not generate ${type.shortName.toLowerCase()}. '
                  'Your existing versions are unchanged.',
      );
    } finally {
      if (mounted) setState(() => _generating.remove(type));
    }
  }

  Future<String?> _confirmInitialGeneration(PdfAiMaterialType type) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generate ${type.displayName}?'),
        content: const Text(
          'The complete PDF text will be sent to DeepSeek. This consumes API '
          'tokens and may take a while for large documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<String?> _regenerationInstruction(PdfAiMaterialType type) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generate a new ${type.shortName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'The current version will remain in History. Generating consumes '
              'API tokens.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Optional instructions',
                hintText: 'Focus more on formulas and examples.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _open(PdfAiMaterialType type, String generationId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfAiMaterialReaderScreen(
          materialId: widget.materialId,
          pdfTitle: widget.title,
          filePath: widget.filePath,
          type: type,
          initialGenerationId: generationId,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(pdfAiMaterialsProvider(widget.materialId));
    final fingerprint = ref
        .watch(
          pdfSourceFingerprintProvider((
            title: widget.title,
            filePath: widget.filePath,
          )),
        )
        .valueOrNull;
    final theme = Theme.of(context);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Study Materials', style: theme.textTheme.titleLarge),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final type in PdfAiMaterialType.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _MaterialTypeCard(
                          type: type,
                          current: _latestFor(materials, type),
                          generating: _generating.contains(type),
                          stale: _isStale(
                            _latestFor(materials, type),
                            fingerprint,
                          ),
                          onGenerate: () => _generate(
                            type,
                            current: _latestFor(materials, type),
                          ),
                          onOpen: _latestFor(materials, type) == null
                              ? null
                              : () => _open(
                                  type,
                                  _latestFor(materials, type)!.id,
                                ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Generated materials are saved locally and can be read '
                      'offline. Generation uses locally extracted PDF text; '
                      'the PDF file itself is not uploaded.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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

  bool _isStale(PdfAiMaterial? material, String? fingerprint) {
    return material != null &&
        fingerprint != null &&
        material.sourceFingerprint != fingerprint;
  }
}

class _MaterialTypeCard extends StatelessWidget {
  const _MaterialTypeCard({
    required this.type,
    required this.current,
    required this.generating,
    required this.stale,
    required this.onGenerate,
    required this.onOpen,
  });

  final PdfAiMaterialType type;
  final PdfAiMaterial? current;
  final bool generating;
  final bool stale;
  final VoidCallback onGenerate;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(type), color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.shortName, style: theme.textTheme.titleMedium),
                      Text(
                        type.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (current == null)
              Text('Not generated', style: theme.textTheme.bodySmall)
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    'Generated ${DateFormat.yMMMd().format(current!.generatedAt.toLocal())}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Version ${current!.version}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (stale)
                    Text(
                      'Older PDF version',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onOpen != null)
                  TextButton(onPressed: onOpen, child: const Text('Open')),
                const SizedBox(width: AppSpacing.xs),
                FilledButton.tonalIcon(
                  onPressed: generating ? null : onGenerate,
                  icon: generating
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          current == null ? Icons.auto_awesome : Icons.refresh,
                        ),
                  label: Text(
                    generating
                        ? 'Generating…'
                        : current == null
                        ? 'Generate'
                        : 'Regenerate',
                  ),
                ),
              ],
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
  };
}
