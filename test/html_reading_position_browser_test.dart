import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/interactive_html/data/interactive_html_files.dart';
import 'package:study_vault/features/interactive_html/services/html_page_server.dart';

/// Optional real-browser check, using a disposable Chrome profile and synthetic
/// local HTML only. Enable with STUDY_VAULT_BROWSER_TESTS=true.
void main() {
  test(
    'HTML restores window and nested scroll after a new token and delayed layout',
    () async {
      final temp = await Directory.systemTemp.createTemp('sv-html-position-');
      final pageRoot = await Directory('${temp.path}/page').create();
      final pageFile = File('${pageRoot.path}/index.html');
      await pageFile.writeAsString(_page());
      final page = PreparedHtmlPage(root: pageRoot, entryPath: 'index.html');
      var server = await HtmlPageServer.start(
        materialId: 'reader-browser-test',
        page: page,
      );
      final profile = Directory('${temp.path}/browser');
      final chrome = await Process.start('/usr/bin/google-chrome', [
        '--headless=new',
        '--no-sandbox',
        '--disable-gpu',
        '--no-first-run',
        '--disable-background-networking',
        '--remote-debugging-port=0',
        '--user-data-dir=${profile.path}',
        'about:blank',
      ]);
      final stdoutDone = chrome.stdout.drain<void>();
      final stderrDone = chrome.stderr.drain<void>();
      _Cdp? cdp;
      try {
        final portFile = File('${profile.path}/DevToolsActivePort');
        await _until(() async => portFile.exists());
        final port = int.parse((await portFile.readAsLines()).first);
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/json/list'),
        );
        final response = await request.close();
        final targets =
            jsonDecode(await response.transform(utf8.decoder).join()) as List;
        client.close(force: true);
        cdp = _Cdp(
          await WebSocket.connect(
            targets.first['webSocketDebuggerUrl'] as String,
          ),
        );
        await cdp.call('Page.enable');
        await cdp.navigate(server.entryUri);
        await cdp.evaluate(
          "window.scrollTo(0,1400); document.getElementById('pane').scrollTop=450; true",
        );
        await _until(
          () async =>
              await cdp!.evaluate(
                "Object.keys(localStorage).some(k => k.startsWith('study-vault-reading-v1:') && JSON.parse(localStorage[k]).window[1] === 1400)",
              ) ==
              true,
        );
        await cdp.call('Page.navigate', {'url': 'about:blank'});
        final oldUri = server.entryUri;
        await server.close();
        // The next document starts short. Late content must not clamp the saved
        // position to zero or replace it with the temporary short-page offset.
        await pageFile.writeAsString(_page(delayed: true));
        server = await HtmlPageServer.start(
          materialId: 'reader-browser-test',
          page: page,
        );
        expect(server.entryUri.path, isNot(oldUri.path));
        expect(server.port, oldUri.port);
        await cdp.navigate(server.entryUri);
        await _until(
          () async =>
              await cdp!.evaluate(
                "window.scrollY === 1400 && document.getElementById('pane').scrollTop === 450",
              ) ==
              true,
        );
        // Once the user scrolls deliberately, the new position must win over
        // delayed layout observers from the initial restoration.
        await cdp.evaluate(
          "dispatchEvent(new WheelEvent('wheel')); window.scrollTo(0,2100); true",
        );
        await _until(() async => await cdp!.evaluate('window.scrollY') == 2100);
        await cdp.call('Page.navigate', {'url': 'about:blank'});
        await cdp.navigate(server.entryUri);
        await _until(() async => await cdp!.evaluate('window.scrollY') == 2100);
      } finally {
        await cdp?.close();
        chrome.kill();
        await chrome.exitCode.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            chrome.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        await Future.wait([stdoutDone, stderrDone]);
        await server.close();
        await temp.delete(recursive: true);
      }
    },
    skip: Platform.environment['STUDY_VAULT_BROWSER_TESTS'] != 'true',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

String _page({bool delayed = false}) =>
    '''<!doctype html><html><head>
<meta charset="utf-8"><style>
body { margin:0; } #content { height:${delayed ? 200 : 6000}px; }
#pane { width:300px; height:200px; overflow:auto; }
#inside { height:2000px; }
</style></head><body><div id="pane"><div id="inside">Nested reader</div></div>
<div id="content">Synthetic lesson</div>
${delayed ? '<script>setTimeout(() => document.getElementById("content").style.height="6000px",350)</script>' : ''}
</body></html>''';

Future<void> _until(Future<bool> Function() condition) async {
  for (var i = 0; i < 150; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
  throw StateError(
    'Browser reading position did not reach the expected state.',
  );
}

class _Cdp {
  _Cdp(this.socket) {
    _subscription = socket.listen((message) {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final waiter = _pending.remove(data['id']);
      if (waiter == null) return;
      if (data['error'] != null) {
        waiter.completeError(StateError('${data['error']}'));
      } else {
        waiter.complete(Map<String, dynamic>.from(data['result'] as Map));
      }
    });
  }
  final WebSocket socket;
  late final StreamSubscription<dynamic> _subscription;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _next = 0;

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) {
    final id = ++_next;
    final result = Completer<Map<String, dynamic>>();
    _pending[id] = result;
    socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    return result.future.timeout(const Duration(seconds: 10));
  }

  Future<Object?> evaluate(String expression) async {
    final result = await call('Runtime.evaluate', {
      'expression': expression,
      'returnByValue': true,
      'awaitPromise': true,
    });
    if (result['exceptionDetails'] != null) {
      throw StateError('${result['exceptionDetails']}');
    }
    return (result['result'] as Map)['value'];
  }

  Future<void> navigate(Uri uri) async {
    await call('Page.navigate', {'url': uri.toString()});
    await _until(
      () async =>
          await evaluate(
            'document.readyState === "complete" && window.__studyVaultReadingPosition === true',
          ) ==
          true,
    );
  }

  Future<void> close() async {
    await socket.close();
    await _subscription.cancel();
  }
}
