import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/section_header.dart';
import 'agent_bridge_controller.dart';

class AgentBridgeSection extends ConsumerStatefulWidget {
  const AgentBridgeSection({super.key});
  @override
  ConsumerState<AgentBridgeSection> createState() => _AgentBridgeSectionState();
}

class _AgentBridgeSectionState extends ConsumerState<AgentBridgeSection> {
  bool _writes = false;

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bridge = ref.watch(agentBridgeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Termux agent access'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  bridge.running
                      ? 'Agent access is running on this phone'
                      : 'Connect a Termux agent to this library',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Let an MCP client in Termux search and read this library, download PDFs, and add lessons, files, notes, quizzes and study materials. No PC or cloud sync is needed.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Access is limited to this phone and the active library. It expires after 8 hours and stops when you stop it, switch libraries, restore a backup, or the app process closes. Android runs a foreground service while access is active.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow agents to save changes'),
                  subtitle: const Text(
                    'Writes preview first and require apply=true. No deletion tools.',
                  ),
                  value: bridge.running ? bridge.server!.allowWrites : _writes,
                  onChanged: bridge.running || bridge.busy
                      ? null
                      : (v) => setState(() => _writes = v),
                ),
                if (bridge.error != null)
                  Text(
                    bridge.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: bridge.busy
                      ? null
                      : () => bridge.running
                            ? bridge.stop()
                            : bridge.start(_writes),
                  icon: Icon(
                    bridge.running ? Icons.stop_circle_outlined : Icons.link,
                  ),
                  label: Text(
                    bridge.busy
                        ? 'Please wait…'
                        : bridge.running
                        ? 'Stop agent access'
                        : 'Start agent access',
                  ),
                ),
                if (bridge.running) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '1. In Termux, install Python and curl: pkg install python curl\n2. Copy and run the setup command below.\n3. Add the MCP configuration to your agent and restart its MCP connection.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _copy(bridge.setupCommand, 'Termux setup copied'),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Termux setup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copy(
                      AgentBridgeController.mcpConfig,
                      'MCP configuration copied',
                    ),
                    icon: const Icon(Icons.code),
                    label: const Text('Copy MCP configuration'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The setup command and installed adapter contain a private session key. Keep them private. After restarting access, run the new setup command again. Keep StudyDesk in recent apps; battery restrictions can still interrupt access.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
