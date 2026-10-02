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

  Future<void> _onTap(PdfAiMaterialType type, PdfAiMaterial? current) async {
    if (_generating.contains(type)) return;
    if (current != null) {
      await _open(type, current.id);
      return;
    }
    await _generate(type);
  }

  Future<void> _generate(PdfAiMaterialType type) async {
    if (_generating.contains(type)) return;

    setState(() => _generating.add(type));
    try {
      final generated = await ref
          .read(pdfAiMaterialServiceProvider)
          .generate(
            materialId: widget.materialId,
            title: widget.title,
            filePath: widget.filePath,
            type: type,
            customInstruction: '',
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
                          onTap: () => _onTap(
                            type,
                            _latestFor(materials, type),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tap a type to open it, or to generate it if it does not '
                      'exist yet. Materials are saved locally; generation uses '
                      'extracted PDF text (the file itself is not uploaded).',
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
    required this.onTap,
  });

  final PdfAiMaterialType type;
  final PdfAiMaterial? current;
  final bool generating;
  final bool stale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final generated = current != null;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: generating ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
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
                    const SizedBox(height: AppSpacing.xs),
                    if (generating)
                      Text(
                        'Generating…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (!generated)
                      Text(
                        'Tap to generate',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      )
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
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (generating)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!generated)
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
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
