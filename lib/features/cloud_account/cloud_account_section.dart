import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import 'cloud_account_provider.dart';
import 'cloud_api.dart';
import 'cloud_sync_models.dart';

class CloudAccountSection extends ConsumerStatefulWidget {
  const CloudAccountSection({super.key});

  @override
  ConsumerState<CloudAccountSection> createState() =>
      _CloudAccountSectionState();
}

class _CloudAccountSectionState extends ConsumerState<CloudAccountSection> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final username = _username.text;
    final password = _password.text;
    _password.clear();
    await ref.read(cloudAccountProvider.notifier).signIn(username, password);
  }

  Future<void> _syncNow() async {
    final state = ref.read(cloudAccountProvider);
    var consent = false;
    if (!state.syncEnabled) {
      consent =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enable private library sync?'),
              content: const SingleChildScrollView(
                child: Text(
                  'This uploads and downloads your classes, notes, annotations, flashcards, quizzes, '
                  'AI materials and conversations, PDFs, and images using your private account.\n\n'
                  'Items are merged by their IDs. Independently created copies may remain separate. '
                  'Later edits and deletions propagate when you press Sync now. Conflicting edits require your review.\n\n'
                  'Configured AI API keys are not included. A local recovery backup is kept before changes; these backups are not encrypted and use device storage. '
                  'Signing out does not remove your local library.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Enable & sync'),
                ),
              ],
            ),
          ) ??
          false;
      if (!consent || !mounted) return;
    }
    await ref.read(cloudAccountProvider.notifier).syncNow(consent: consent);
  }

  Future<void> _resolveConflicts() async {
    final state = ref.read(cloudAccountProvider);
    final choice = await showDialog<CloudConflictChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review ${state.conflicts.length} sync conflicts'),
        content: SizedBox(
          width: 640,
          height: 420,
          child: Column(
            children: [
              const Text(
                'Your choice applies only to conflicting items and their affected relationships. '
                'Unrelated changes still merge. Recovery copies and server history preserve the previous versions.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: state.conflicts.length,
                  itemBuilder: (context, index) {
                    final conflict = state.conflicts[index];
                    String describe(Map<String, dynamic>? row) => row == null
                        ? '(Deleted or absent)'
                        : const JsonEncoder.withIndent('  ').convert(row);
                    return ExpansionTile(
                      title: Text(conflict.label),
                      subtitle: Text(conflict.reason),
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'This device',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SelectableText(describe(conflict.device)),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Server',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SelectableText(describe(conflict.server)),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
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
          OutlinedButton(
            onPressed: () => Navigator.pop(context, CloudConflictChoice.device),
            child: const Text('Keep device conflicts'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, CloudConflictChoice.server),
            child: const Text('Keep server conflicts'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await ref
        .read(cloudAccountProvider.notifier)
        .syncNow(choice: choice, resolutionToken: state.resolutionToken);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cloudAccountProvider);
    final controller = ref.read(cloudAccountProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Private Cloud Account'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Server: ${CloudApi.origin}'),
                const SizedBox(height: 8),
                const Text(
                  'Manual, two-way library sync. Offline edits stay on this device until you press Sync now. '
                  'Signing in alone does not upload or replace your local study data.',
                ),
                const SizedBox(height: 16),
                if (state.username == null)
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _username,
                          enabled: !state.busy,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your username.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          enabled: !state.busy,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'App password',
                          ),
                          onFieldSubmitted: (_) {
                            if (!state.busy) _signIn();
                          },
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your app password.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: state.busy ? null : _signIn,
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text('Signed in as ${state.username}'),
                  if (state.lastSync != null)
                    Text(
                      'Last sync: ${state.lastSync!.toLocal().toString().split('.').first}',
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: state.busy ? null : _syncNow,
                    icon: const Icon(Icons.sync),
                    label: Text(state.syncEnabled ? 'Sync now' : 'Enable sync'),
                  ),
                  if (state.conflicts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: state.busy ? null : _resolveConflicts,
                      icon: const Icon(Icons.compare_arrows),
                      label: Text('Review ${state.conflicts.length} conflicts'),
                    ),
                  ],
                  if (state.backupPath != null)
                    TextButton.icon(
                      onPressed: state.busy ? null : controller.exportRecovery,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Export last recovery backup'),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.busy ? null : controller.checkConnection,
                    icon: const Icon(Icons.cloud_done_outlined),
                    label: const Text('Check connection'),
                  ),
                  TextButton(
                    onPressed: state.busy ? null : controller.signOut,
                    child: const Text('Sign out'),
                  ),
                ],
                if (state.busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (state.message != null) ...[
                  const SizedBox(height: 12),
                  Text(state.message!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
