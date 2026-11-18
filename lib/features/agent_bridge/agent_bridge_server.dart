import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'agent_library_tools.dart';

/// Authenticated, same-device HTTP transport for the Termux stdio adapter.
/// Never binds to LAN interfaces, and never exposes a database/SQL endpoint.
class AgentBridgeServer {
  AgentBridgeServer(this.tools, {required this.clientSource});
  final AgentLibraryTools tools;
  final String clientSource;
  HttpServer? _server;
  String? _token;
  Timer? _expiry;
  bool _busy = false;
  bool allowWrites = false;
  Directory? _staging;
  final _uploads = <String, File>{};
  final _replies = <String, ({String digest, Object result})>{};
  void Function()? onStopped;
  String? get token => _token;
  int? get port => _server?.port;
  bool get running => _token != null;
  String get url => 'http://127.0.0.1:$port';

  Future<void> start({
    bool writes = false,
    int port = 0,
    Duration lifetime = const Duration(hours: 8),
  }) async {
    if (running) return;
    final staging = await Directory.systemTemp.createTemp('study_vault_agent_');
    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
    } catch (_) {
      await staging.delete(recursive: true);
      rethrow;
    }
    _staging = staging;
    allowWrites = writes;
    _token = base64Url
        .encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');
    _server!.idleTimeout = const Duration(seconds: 20);
    _server!.listen((request) {
      unawaited(
        _handle(request).catchError((Object _) {
          // Disconnects and Stop may close a response while a tool finishes.
          request.response.close().catchError((Object _) {});
        }),
      );
    });
    _expiry = Timer(lifetime, () => unawaited(stop()));
  }

  Future<void> stop() async {
    _token = null; // Revoke synchronously, including sockets already accepted.
    _expiry?.cancel();
    final server = _server;
    _server = null;
    await server?.close(force: true);
    _replies.clear();
    final staging = _staging;
    _staging = null;
    _uploads.clear();
    if (staging != null && await staging.exists()) {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        /* Request may still be finishing. */
      }
    }
    onStopped?.call();
  }

  static bool _equal(String a, String b) {
    final x = sha256.convert(utf8.encode(a)).bytes;
    final y = sha256.convert(utf8.encode(b)).bytes;
    var difference = 0;
    for (var i = 0; i < x.length; i++) {
      difference |= x[i] ^ y[i];
    }
    return difference == 0;
  }

  Future<void> _json(HttpRequest request, int status, Object body) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('Cache-Control', 'no-store');
    final encoded = jsonEncode(body);
    if (encoded.length > 4 * 1024 * 1024) {
      request.response.statusCode = 413;
      request.response.write(
        jsonEncode({
          'error':
              'Result too large. Use a smaller limit and paginate with offset.',
        }),
      );
    } else {
      request.response.write(encoded);
    }
    await request.response.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final sessionToken = _token;
    // Browser origins are deliberately unsupported. The only client is a
    // native adapter using a bearer token obtained explicitly from Settings.
    final host = request.headers.host;
    if (sessionToken == null ||
        request.headers.value('origin') != null ||
        !['127.0.0.1', 'localhost'].contains(host) ||
        !_equal(
          request.headers.value('authorization') ?? '',
          'Bearer $sessionToken',
        )) {
      await _json(request, 401, {
        'error': 'Bridge disabled or authentication required.',
      });
      return;
    }
    if (_busy) {
      await _json(request, 409, {
        'error': 'Another operation is running. Retry later.',
      });
      return;
    }
    _busy = true;
    try {
      switch ((request.method, request.uri.path)) {
        case ('GET', '/client.py'):
          request.response.headers.contentType = ContentType.text;
          request.response.headers.set('Cache-Control', 'no-store');
          request.response.write(
            clientSource
                .replaceFirst(
                  'DEFAULT_URL = ""',
                  'DEFAULT_URL = ${jsonEncode(url)}',
                )
                .replaceFirst(
                  'DEFAULT_TOKEN = ""',
                  'DEFAULT_TOKEN = ${jsonEncode(sessionToken)}',
                ),
          );
          await request.response.close();
        case ('GET', '/tools'):
          await _json(request, 200, {
            'tools': AgentLibraryTools.definitions,
            'allow_writes': allowWrites,
          });
        case ('POST', '/upload'):
          if (!allowWrites) {
            throw const FormatException(
              'Writes are disabled in StudyDesk Settings.',
            );
          }
          // Bound both individual files and total unclaimed staging space.
          if (_uploads.length >= 4) {
            throw const FormatException(
              'Too many unclaimed uploads. Restart the bridge to clear them.',
            );
          }
          if (request.contentLength < 0 ||
              request.contentLength > AgentLibraryTools.maxFileBytes) {
            throw const FormatException(
              'Upload requires Content-Length, up to 256 MiB.',
            );
          }
          final id = const Uuid().v4();
          final file = File('${_staging!.path}/$id');
          final output = file.openWrite();
          var count = 0;
          try {
            await for (final chunk in request.timeout(
              const Duration(seconds: 30),
            )) {
              count += chunk.length;
              if (count > AgentLibraryTools.maxFileBytes ||
                  _token != sessionToken) {
                throw const FormatException('Upload cancelled or too large.');
              }
              output.add(chunk);
            }
            await output.close();
            if (count != request.contentLength || _token != sessionToken) {
              throw const FormatException('Upload incomplete.');
            }
            _uploads[id] = file;
          } catch (_) {
            await output.close();
            if (await file.exists()) await file.delete();
            rethrow;
          }
          await _json(request, 200, {'upload_id': id});
        case ('GET', '/file'):
          final file = await tools.fileFor(request.uri.queryParameters);
          request.response.headers.contentType = ContentType.binary;
          request.response.headers.set('Cache-Control', 'no-store');
          request.response.headers.set(
            'X-Study-Vault-Filename',
            Uri.encodeComponent(file.name),
          );
          request.response.contentLength = await file.file.length();
          await request.response.addStream(file.file.openRead());
          await request.response.close();
        case ('POST', '/call'):
          final bytes = <int>[];
          await for (final chunk in request.timeout(
            const Duration(seconds: 30),
          )) {
            if (bytes.length + chunk.length > 2 * 1024 * 1024) {
              throw const FormatException('Tool request exceeds 2 MiB.');
            }
            bytes.addAll(chunk);
          }
          if (_token != sessionToken) {
            throw const FormatException('Bridge session revoked.');
          }
          final body = jsonDecode(utf8.decode(bytes));
          if (body is! Map ||
              body['name'] is! String ||
              body['arguments'] is! Map ||
              body['request_id'] is! String) {
            throw const FormatException('Invalid tool request.');
          }
          final id = AgentLibraryTools.text(body, 'request_id', max: 100);
          final digest = sha256.convert(bytes).toString();
          final cached = _replies[id];
          if (cached != null) {
            if (cached.digest != digest) {
              throw const FormatException(
                'Request ID reused for a different operation.',
              );
            }
            await _json(request, 200, cached.result);
            return;
          }
          final name = body['name'] as String;
          final args = Map<String, dynamic>.from(body['arguments'] as Map);
          if (AgentLibraryTools.writeTools.contains(name) &&
              args['apply'] == true &&
              !allowWrites) {
            throw const FormatException(
              'Writes are disabled in StudyDesk Settings.',
            );
          }
          File? upload;
          if (name == 'attach_file' && args['apply'] == true) {
            upload = _uploads[args['upload_id']];
            if (upload == null) throw const FormatException('Upload missing.');
          }
          final result = {
            'result': await tools.call(name, args, upload: upload),
          };
          if (AgentLibraryTools.writeTools.contains(name) &&
              args['apply'] == true) {
            _replies[id] = (digest: digest, result: result);
            if (_replies.length > 128) _replies.remove(_replies.keys.first);
          }
          if (upload != null) {
            _uploads.remove(args['upload_id']);
            try {
              await upload.delete();
            } on FileSystemException {
              /* Already stopped. */
            }
          }
          await _json(request, 200, result);
        default:
          await _json(request, 404, {'error': 'Unknown bridge route.'});
      }
    } on FormatException catch (e) {
      await _json(request, 400, {'error': e.message});
    } on Object {
      // Paths, SQL, keys and internal exceptions never leave the app.
      try {
        await _json(request, 500, {
          'error':
              'Operation failed. Check the library before retrying a write.',
        });
      } on Object {
        /* Connection closed. */
      }
    } finally {
      _busy = false;
    }
  }
}
