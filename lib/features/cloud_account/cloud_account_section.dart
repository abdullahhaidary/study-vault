import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import 'cloud_account_provider.dart';
import 'cloud_api.dart';

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
                  'Account connection only in this build. Library synchronization is not enabled yet. '
                  'Signing in does not upload or replace your local study data.',
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
