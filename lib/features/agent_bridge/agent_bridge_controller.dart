import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/storage/study_vault_paths.dart';
import 'agent_bridge_server.dart';
import 'agent_library_tools.dart';

final agentBridgeProvider = ChangeNotifierProvider<AgentBridgeController>((
  ref,
) {
  final controller = AgentBridgeController(ref.watch(databaseProvider));
  ref.onDispose(controller.shutdown);
  return controller;
});

class AgentBridgeController extends ChangeNotifier {
  AgentBridgeController(this.db);
  final AppDatabase db;
  static const _channel = MethodChannel('study_vault/agent_bridge');
  AgentBridgeServer? server;
  bool busy = false;
  bool _closed = false;
  int _generation = 0;
  Future<void>? _startTask;
  String? error;
  bool get running => server?.running ?? false;

  Future<void> _native(String method) async {
    if (Platform.isAndroid) await _channel.invokeMethod<void>(method);
  }

  Future<void> start(bool writes) {
    if (busy || running || _closed) return Future.value();
    return _startTask = _start(writes, ++_generation);
  }

  Future<void> _start(bool writes, int generation) async {
    busy = true;
    error = null;
    notifyListeners();
    AgentBridgeServer? bridge;
    try {
      final source = await rootBundle.loadString(
        'tool/study_vault_termux_mcp.py',
      );
      final root = await StudyVaultPaths.materialsDirectory();
      if (_closed || generation != _generation) return;
      bridge = AgentBridgeServer(
        AgentLibraryTools(db, root),
        clientSource: source,
      );
      await bridge.start(writes: writes);
      if (_closed || generation != _generation) {
        await bridge.stop();
        return;
      }
      server = bridge;
      bridge.onStopped = () {
        unawaited(_native('stop').catchError((Object _) {}));
        if (!_closed) notifyListeners();
      };
      await _native('start');
      if (_closed || generation != _generation) await bridge.stop();
    } on Object {
      await bridge?.stop();
      error =
          'Could not start agent access. Keep StudyDesk open and try again.';
    } finally {
      busy = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> stop() async {
    ++_generation; // Also cancels a start awaiting assets or native setup.
    busy = true;
    if (!_closed) notifyListeners();
    try {
      await _startTask;
      await server?.stop();
      await _native('stop');
    } finally {
      busy = false;
      if (!_closed) notifyListeners();
    }
  }

  String get setupCommand {
    final bridge = server!;
    return 'mkdir -p "\$HOME/.local/share/study-vault" && '
        'curl --fail --silent --show-error '
        "-H 'Authorization: Bearer ${bridge.token}' '${bridge.url}/client.py' "
        '-o "\$HOME/.local/share/study-vault/mcp.py" && '
        'chmod 600 "\$HOME/.local/share/study-vault/mcp.py"';
  }

  static String get mcpConfig => const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      'study-vault': {
        'command': 'sh',
        'args': ['-c', 'exec python "\$HOME/.local/share/study-vault/mcp.py"'],
      },
    },
  });

  void shutdown() {
    _closed = true;
    ++_generation;
    server?.onStopped = null;
    unawaited(server?.stop());
    unawaited(_native('stop').catchError((Object _) {}));
  }
}
