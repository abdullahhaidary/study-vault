import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_assistant/domain/ai_actions.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/presentation/ai_assistant_controller.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import '../../ai_assistant/presentation/widgets/ai_usage_indicator.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/services/ai_chat_navigation.dart';
import '../data/pdf_ai_material_providers.dart';
import '../domain/pdf_ai_material_models.dart';

class PdfAiMaterialReaderScreen extends ConsumerStatefulWidget {
  const PdfAiMaterialReaderScreen({
    super.key,
    required this.materialId,
    required this.pdfTitle,
    required this.filePath,
    required this.type,
    this.initialGenerationId,
  });

  final String materialId;
  final String pdfTitle;
  final String filePath;
  final PdfAiMaterialType type;
  final String? initialGenerationId;

  @override
  ConsumerState<PdfAiMaterialReaderScreen> createState() =>
      _PdfAiMaterialReaderScreenState();
}

class _PdfAiMaterialReaderScreenState
    extends ConsumerState<PdfAiMaterialReaderScreen> {
  String? _selectedId;
  bool _generating = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialGenerationId;
  }

  Future<void> _regenerate() async {
    if (_generating) return;
    final instruction = await _showRegenerationDialog();
    if (instruction == null || !mounted) return;

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
          title: 'Regenerate with',
        ) ??
        selection;

    setState(() => _generating = true);
    try {
      final generated = await ref
          .read(pdfAiMaterialServiceProvider)
          .generate(
            materialId: widget.materialId,
            title: widget.pdfTitle,
            filePath: widget.filePath,
            type: widget.type,
            selection: selection,
            customInstruction: instruction,
          );
      if (!mounted) return;
      setState(() => _selectedId = generated.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Version ${generated.version} generated.')),
      );
    } on AiException catch (error) {
      _showError(error.message);
    } on Object catch (error) {
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<String?> _showRegenerationDialog() async {
    final controller = TextEditingController();
    final instruction = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generate a new ${widget.type.shortName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'The current version will remain available in History. '
              'Generating consumes API tokens.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Optional instructions',
                hintText: 'For example: Focus more on formulas.',
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
    return instruction;
  }

  Future<void> _delete(PdfAiMaterial selected) async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete version ${selected.version}?'),
        content: const Text(
          'This deletes only this generated version. The PDF, other versions, '
          'and AI chats will remain.',
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
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    await ref.read(pdfAiMaterialServiceProvider).deleteVersion(selected.id);
    if (!mounted) return;
    setState(() {
      _selectedId = null;
      _deleting = false;
    });
  }

  Future<void> _askAboutThis() {
    return AiChatNavigation.openNewWithAttachment(
      context,
      ref,
      attachment: AiContextItem(
        kind: AiContextKind.material,
        id: widget.materialId,
        materialId: widget.materialId,
        title: widget.pdfTitle,
      ),
      draftText: 'I have a question about this PDF.',
    );
  }

  Future<void> _showHistory(
    List<PdfAiMaterial> history,
    PdfAiMaterial selected,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          children: [
            Text(
              '${widget.type.shortName} History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < history.length; i++)
              ListTile(
                selected: history[i].id == selected.id,
                leading: const Icon(Icons.history),
                title: Text('Version ${history[i].version}'),
                subtitle: Text(
                  DateFormat.yMMMd().add_jm().format(
                    history[i].generatedAt.toLocal(),
                  ),
                ),
                trailing: i == 0 ? const Chip(label: Text('Current')) : null,
                onTap: () => Navigator.pop(context, history[i].id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedId = picked);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('no extractable text')) {
      return 'This PDF has no extractable text. OCR is not available yet.';
    }
    return 'Could not generate this study material. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(pdfAiMaterialsProvider(widget.materialId));
    final fingerprintAsync = ref.watch(
      pdfSourceFingerprintProvider((
        title: widget.pdfTitle,
        filePath: widget.filePath,
      )),
    );

    return allAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.type.displayName)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: Text(widget.type.displayName)),
        body: const Center(child: Text('Could not load saved generations.')),
      ),
      data: (all) {
        final history = [
          for (final material in all)
            if (material.type == widget.type.storageValue) material,
        ];
        if (history.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.type.displayName)),
            body: const Center(child: Text('This version no longer exists.')),
          );
        }
        final selected = history.firstWhere(
          (item) => item.id == _selectedId,
          orElse: () => history.first,
        );
        final usage = aiTokenUsageFromColumns(
          promptTokens: selected.promptTokens,
          completionTokens: selected.completionTokens,
          totalTokens: selected.totalTokens,
          cacheHitTokens: selected.cacheHitTokens,
          cacheMissTokens: selected.cacheMissTokens,
          model: selected.model,
          provider: selected.provider,
          durationMs: selected.requestDurationMs,
        );
        final currentFingerprint = fingerprintAsync.valueOrNull;
        final stale =
            currentFingerprint != null &&
            currentFingerprint != selected.sourceFingerprint;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.type.displayName),
            actions: [
              IconButton(
                tooltip: 'History',
                onPressed: () => _showHistory(history, selected),
                icon: Badge(
                  label: Text('${history.length}'),
                  child: const Icon(Icons.history),
                ),
              ),
              PopupMenuButton<String>(
                enabled: !_generating && !_deleting,
                onSelected: (value) {
                  if (value == 'delete') _delete(selected);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete this version'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (stale)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.warning_amber_rounded),
                    title: Text('Generated from an older version of this PDF'),
                  ),
                ),
              Expanded(
                child: Markdown(
                  data: selected.content,
                  selectable: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (usage != null) AiUsageIndicator(usage: usage),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Version ${selected.version} · '
                        '${DateFormat.yMMMd().format(selected.generatedAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _generating ? null : _askAboutThis,
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Ask about this'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _generating ? null : _regenerate,
                              icon: _generating
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                              label: Text(
                                _generating ? 'Generating…' : 'Regenerate',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
