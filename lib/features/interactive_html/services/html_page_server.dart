import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../data/interactive_html_files.dart';
import '../domain/html_bundle.dart';

/// Serves one prepared page on `127.0.0.1` while it is open.
///
/// Each page gets a stable port derived from its material id, so its browser
/// storage (`localStorage`, IndexedDB) stays separate from other pages and
/// survives reopening. A random path token keeps other local programs from
/// guessing the address. Only files inside the page's own folder are served.
class HtmlPageServer {
  HtmlPageServer._(this._server, this._page, this._token);

  final HttpServer _server;
  final PreparedHtmlPage _page;
  final String _token;

  static const _firstPort = 20000;
  static const _portRange = 30000;
  static const _attempts = 8;

  /// Origin of this page, for example `http://127.0.0.1:43120`.
  String get origin => 'http://127.0.0.1:${_server.port}';

  /// Every address of this page starts with this prefix.
  String get pagePrefix => '$origin/$_token/';

  /// Address of the start page.
  Uri get entryUri => Uri.parse(
    '$origin/$_token/${_page.entryPath.split('/').map(Uri.encodeComponent).join('/')}',
  );

  int get port => _server.port;

  /// True when [uri] belongs to this page (same origin and token).
  bool owns(Uri uri) {
    return uri.scheme == 'http' &&
        uri.host == '127.0.0.1' &&
        uri.port == _server.port &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == _token;
  }

  static int preferredPort(String materialId) {
    var hash = 0;
    for (final unit in materialId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _firstPort + hash % _portRange;
  }

  static Future<HtmlPageServer> start({
    required String materialId,
    required PreparedHtmlPage page,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final token = List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final preferred = preferredPort(materialId);
    HttpServer? server;
    for (var i = 0; i < _attempts && server == null; i++) {
      final port =
          _firstPort + (preferred - _firstPort + i * 7919) % _portRange;
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      } on SocketException {
        server = null;
      }
    }
    server ??= await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = HtmlPageServer._(server, page, token);
    server.listen(instance._handle, onError: (_) {});
    return instance;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final file = _resolve(request.uri);
      if (file == null || !await file.exists()) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      response.headers
        ..set(HttpHeaders.contentTypeHeader, htmlAssetContentType(file.path))
        ..set(HttpHeaders.cacheControlHeader, 'no-store')
        ..set('X-Content-Type-Options', 'nosniff')
        ..set('Referrer-Policy', 'no-referrer');
      response.contentLength = await file.length();
      if (request.method == 'GET') {
        await response.addStream(file.openRead());
      }
    } on Object {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  File? _resolve(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty || segments.first != _token) return null;
    final rest = segments.skip(1).toList();
    if (rest.isEmpty || rest.last.isEmpty) {
      rest
        ..removeWhere((s) => s.isEmpty)
        ..add('index.html');
    }
    if (rest.any((s) => s == '..' || s == '.' || s.contains('\\'))) {
      return null;
    }
    final root = p.normalize(_page.root.absolute.path);
    final target = p.normalize(p.joinAll([root, ...rest]));
    if (!p.isWithin(root, target)) return null;
    return File(target);
  }
}
