import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/markdown/study_markdown.dart';
import '../../../core/theme/app_spacing.dart';
import '../../ai_assistant/presentation/widgets/ai_model_picker.dart';
import '../../pdf_ai_materials/presentation/pdf_ai_material_reader_screen.dart';
import '../data/ai_generation_providers.dart';
import '../domain/ai_generation_models.dart';
import '../services/ai_generation_coordinator.dart';

enum _QueueFilter { active, queued, completed, attention }

class GenerationCenterScreen extends ConsumerStatefulWidget {
  const GenerationCenterScreen({super.key, this.initialJobId});

  final String? initialJobId;

  @override
  ConsumerState<GenerationCenterScreen> createState() =>
      _GenerationCenterScreenState();
}

class _GenerationCenterScreenState
    extends ConsumerState<GenerationCenterScreen> {
  _QueueFilter _filter = _QueueFilter.active;

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(aiGenerationJobsProvider).valueOrNull ?? const [];
    final visible = [
      for (final job in jobs)
        if (_matches(job)) job,
    ].reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generation Center'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(aiGenerationCoordinatorProvider).clearCompleted(),
            child: const Text('Clear completed'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final filter in _QueueFilter.values)
                  ChoiceChip(
                    label: Text(_label(filter, jobs)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('Nothing in this section.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _JobCard(
                      job: visible[index],
                      highlighted: visible[index].id == widget.initialJobId,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _matches(AiGenerationJob job) {
    return switch (_filter) {
      _QueueFilter.active =>
        job.status == AiGenerationJobStatus.running ||
            job.status == AiGenerationJobStatus.cancelRequested ||
            job.status == AiGenerationJobStatus.waitingToRetry,
      _QueueFilter.queued => job.status == AiGenerationJobStatus.queued,
      _QueueFilter.completed => job.isSuccess,
      _QueueFilter.attention => job.needsAttention,
    };
  }

  String _label(_QueueFilter filter, List<AiGenerationJob> jobs) {
    final count = jobs.where((job) {
      return switch (filter) {
        _QueueFilter.active =>
          job.status == AiGenerationJobStatus.running ||
              job.status == AiGenerationJobStatus.cancelRequested ||
              job.status == AiGenerationJobStatus.waitingToRetry,
        _QueueFilter.queued => job.status == AiGenerationJobStatus.queued,
        _QueueFilter.completed => job.isSuccess,
        _QueueFilter.attention => job.needsAttention,
      };
    }).length;
    final name = switch (filter) {
      _QueueFilter.active => 'Active',
      _QueueFilter.queued => 'Queued',
      _QueueFilter.completed => 'Completed',
      _QueueFilter.attention => 'Needs attention',
    };
    return '$name ($count)';
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job, required this.highlighted});

  final AiGenerationJob job;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elapsed = job.elapsedAt(DateTime.now());
    final coordinator = ref.read(aiGenerationCoordinatorProvider);
    return Card(
      color: highlighted ? theme.colorScheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${job.typeLabel} · ${job.provider} · ${job.resolvedModelId}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text('${job.statusLabel} · ${job.progressLabel}'),
            Text(_elapsed(elapsed), style: theme.textTheme.bodySmall),
            if (job.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                job.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (job.warningMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(job.warningMessage!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (job.canOpen)
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PdfAiMaterialReaderScreen(
                          materialId: job.materialId,
                          pdfTitle: job.title,
                          filePath: job.filePath,
                          type: job.materialType,
                          initialGenerationId: job.resultMaterialId,
                        ),
                      ),
                    ),
                    child: const Text('Open result'),
                  ),
                if (job.canContinue) ...[
                  OutlinedButton(
                    onPressed: () => _preview(context, job.partialOutput!),
                    child: const Text('Preview partial'),
                  ),
                  FilledButton(
                    onPressed: () => coordinator.continuePartial(job.id),
                    child: const Text('Continue'),
                  ),
                ],
                if (job.needsProfileReplacement)
                  FilledButton(
                    onPressed: () async {
                      final next = await showAiModelSelector(
                        context,
                        selected: job.selection,
                        title: 'Choose a replacement model',
                        subtitle:
                            'This job’s API profile is unavailable. '
                            'Queued work keeps its original profile until you choose another.',
                      );
                      if (next == null) return;
                      await coordinator.retryWithSelection(job.id, next);
                    },
                    child: const Text('Choose profile and retry'),
                  ),
                if (job.canRetry)
                  FilledButton(
                    onPressed: () => coordinator.retry(job.id),
                    child: const Text('Retry'),
                  ),
                if (job.canRetryTranslation)
                  FilledButton(
                    onPressed: () => coordinator.retryTranslation(job.id),
                    child: const Text('Retry translation'),
                  ),
                if (job.canCopyPartial)
                  TextButton(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: job.partialOutput!),
                    ),
                    child: const Text('Copy partial'),
                  ),
                if (job.canSavePartial)
                  TextButton(
                    onPressed: () => coordinator.savePartial(job.id),
                    child: const Text('Save partial'),
                  ),
                if (job.canContinue)
                  TextButton(
                    onPressed: () => coordinator.discardPartial(job.id),
                    child: const Text('Discard'),
                  ),
                if (job.canCancel)
                  TextButton(
                    onPressed: () => _cancel(context, coordinator),
                    child: const Text('Cancel'),
                  ),
                if (job.canRemove)
                  TextButton(
                    onPressed: () => coordinator.remove(job.id),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    AiGenerationCoordinator coordinator,
  ) async {
    if (job.status == AiGenerationJobStatus.running) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel this generation?'),
          content: const Text(
            'It will stop after the current step. A request already sent to '
            'the provider may still use tokens.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel job'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await coordinator.cancel(job.id);
  }

  Future<void> _preview(BuildContext context, String markdown) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Partial result'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: StudyMarkdown(data: markdown)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _elapsed(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }
}
