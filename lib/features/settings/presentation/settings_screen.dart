import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_manifest.dart';
import '../../../core/backup/backup_providers.dart';
import '../../../core/backup/backup_service.dart';
import '../../ai_assistant/presentation/ai_settings_section.dart';

/// App settings — AI Assistant + Backup & Restore.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialSection});

  /// Optional: `ai` scrolls/focuses the AI Assistant section.
  final String? initialSection;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _aiKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialSection == 'ai') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _aiKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            alignment: 0.1,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          KeyedSubtree(key: _aiKey, child: const AiSettingsSection()),
          const SizedBox(height: 28),
          Text(
            'Backup & Restore',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Protect your local Study Vault data. Backup files are not '
            'encrypted — store them somewhere safe outside this app. '
            'Gemini API keys are never included in backups.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          const _BackupRestoreCard(),
        ],
      ),
    );
  }
}

class _BackupRestoreCard extends ConsumerWidget {
  const _BackupRestoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(backupUiControllerProvider);
    final lastAsync = ref.watch(lastBackupInfoProvider);
    final busy = _isBusy(progress.phase);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            lastAsync.when(
              loading: () => const Text('Checking last backup…'),
              error: (_, _) => const Text('No backup created yet'),
              data: (info) {
                if (info == null) {
                  return Text(
                    'No backup created yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                final when = _formatDateTime(info.createdAt);
                final size = _formatBytes(info.sizeBytes);
                return Text(
                  'Last backup:\n$when\n$size'
                  '${info.materialFileCount != null ? ' • ${info.materialFileCount} materials' : ''}',
                  style: theme.textTheme.bodyMedium,
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => ref
                        .read(backupUiControllerProvider.notifier)
                        .createAndExportBackup(),
              icon: const Icon(Icons.backup_outlined),
              label: const Text('Create Full Backup'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _onRestorePressed(context, ref),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Restore Backup'),
            ),
            if (progress.phase != BackupPhase.idle) ...[
              const SizedBox(height: 16),
              _ProgressPanel(progress: progress),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onRestorePressed(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(backupUiControllerProvider.notifier);
    final manifest = await controller.pickAndValidateBackup();
    if (manifest == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RestoreConfirmDialog(manifest: manifest),
    );
    if (confirmed != true || !context.mounted) {
      controller.reset();
      return;
    }

    final ok = await controller.confirmRestorePending();
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study Vault restored successfully.')),
      );
    }
  }
}

class _RestoreConfirmDialog extends StatelessWidget {
  const _RestoreConfirmDialog({required this.manifest});

  final BackupManifest manifest;

  @override
  Widget build(BuildContext context) {
    final when = _formatDateTime(manifest.createdAt.toLocal());
    return AlertDialog(
      title: const Text('Restore Study Vault?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Backup created:\n$when'),
            const SizedBox(height: 12),
            Text(
              'App version: ${manifest.appVersion}\n'
              'Database schema: ${manifest.databaseSchemaVersion}\n'
              'Materials: ${manifest.materialFileCount}\n'
              'Platform: ${manifest.platform}',
            ),
            const SizedBox(height: 16),
            Text(
              'Restoring this backup will replace the Study Vault data '
              'currently stored on this device.\n\n'
              'This cannot be undone unless you create a backup of the '
              'current data first.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Restore'),
        ),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.progress});

  final BackupProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = progress.phase == BackupPhase.error;
    final isSuccess = progress.phase == BackupPhase.success;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isBusy(progress.phase))
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    isError
                        ? Icons.error_outline
                        : isSuccess
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progress.message.isEmpty
                        ? progress.phase.name
                        : progress.message,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (progress.materialsTotal > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Materials ${progress.materialsDone} / ${progress.materialsTotal}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress.materialsTotal == 0
                    ? null
                    : progress.materialsDone / progress.materialsTotal,
              ),
            ],
            if (progress.resultFileName != null) ...[
              const SizedBox(height: 8),
              Text(progress.resultFileName!, style: theme.textTheme.bodySmall),
            ],
            if (progress.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                progress.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _isBusy(BackupPhase phase) {
  switch (phase) {
    case BackupPhase.preparingDatabase:
    case BackupPhase.collectingFiles:
    case BackupPhase.packaging:
    case BackupPhase.exporting:
    case BackupPhase.validating:
    case BackupPhase.restoring:
      return true;
    case BackupPhase.idle:
    case BackupPhase.success:
    case BackupPhase.error:
      return false;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  final local = value.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year} • '
      '$hour12:${two(local.minute)} $ampm';
}
