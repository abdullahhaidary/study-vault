import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/ai_settings_store.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_model_ref.dart';

/// One ChatGPT sign-in registered with Pocket.
class PocketAccount {
  const PocketAccount({required this.id, required this.name});

  final String id;
  final String name;
}

/// One reply from the local Pocket chat server.
class PocketReply {
  const PocketReply({
    required this.text,
    required this.app,
    this.done = true,
  });

  final String text;
  final String app;

  /// False while the reply is still growing.
  final bool done;
}

/// Posts one message to the Pocket window on this computer.
///
/// Each call uses `new_chat`, so the signed-in tab starts a fresh conversation
/// and Study Vault sends the full prompt itself.
class PocketClient {
  PocketClient({required this.settings, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final AiSettingsStore settings;
  final http.Client _http;

  static const defaultBaseUrl = 'http://127.0.0.1:8765';

  Future<void> checkHealth({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final base = await _baseUrl();
    try {
      final response = await _http
          .get(Uri.parse('$base/health'))
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AiNotConfiguredException(
          'Pocket is not responding. Start it with python3 server.py.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) {
        throw const AiNotConfiguredException(
          'Pocket is not responding. Start it with python3 server.py.',
        );
      }
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw _notRunning();
    } on http.ClientException {
      throw _notRunning();
    } on FormatException {
      throw const AiServerException('Pocket returned an unreadable response.');
    }
  }

  Future<List<PocketAccount>> listAccounts({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final base = await _baseUrl();
    try {
      final response = await _http
          .get(Uri.parse('$base/accounts'))
          .timeout(timeout);
      final body = _decodeMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failure(body, response.statusCode);
      }
      final rows = body['accounts'];
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map && row['id'] is String && row['name'] is String)
            PocketAccount(
              id: (row['id'] as String).trim(),
              name: (row['name'] as String).trim(),
            ),
      ].where((account) => account.id.isNotEmpty && account.name.isNotEmpty).toList();
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw _notRunning();
    } on http.ClientException {
      throw _notRunning();
    }
  }

  Future<PocketAccount> addAccount(
    String name, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final title = name.trim();
    if (title.isEmpty) {
      throw const AiMalformedOutputException('Give the account a name.');
    }
    final base = await _baseUrl();
    try {
      final response = await _http
          .post(
            Uri.parse('$base/accounts'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'name': title}),
          )
          .timeout(timeout);
      final body = _decodeMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failure(body, response.statusCode);
      }
      final id = body['id'];
      final saved = body['name'];
      if (id is! String || saved is! String || id.isEmpty) {
        throw const AiServerException('Pocket did not save the account.');
      }
      return PocketAccount(id: id, name: saved);
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw _notRunning();
    } on http.ClientException {
      throw _notRunning();
    }
  }

  Future<void> removeAccount(
    String id, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final accountId = id.trim();
    if (accountId.isEmpty || accountId == 'default') return;
    final base = await _baseUrl();
    try {
      final response = await _http
          .delete(Uri.parse('$base/accounts/$accountId'))
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failure(_decodeMap(response.body), response.statusCode);
      }
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw _notRunning();
    } on http.ClientException {
      throw _notRunning();
    }
  }

  Stream<PocketReply> watch({
    required String modelId,
    required String message,
    List<String> files = const [],
    Duration timeout = const Duration(minutes: 2),
  }) async* {
    final text = message.trim();
    if (text.isEmpty && files.isEmpty) {
      throw const AiMalformedOutputException('The Pocket prompt is empty.');
    }
    final model = PocketModelRef.normalize(modelId);
    final app = model.appId;
    final seconds = timeout.inSeconds < 1 ? 1 : timeout.inSeconds;
    final base = await _baseUrl();
    final request = http.Request('POST', Uri.parse('$base/chat'));
    request.headers['content-type'] = 'application/json';
    request.headers['accept'] = 'text/event-stream';
    request.body = jsonEncode(
      _chatBody(
        model: model,
        message: text,
        seconds: seconds,
        files: files,
        stream: true,
      ),
    );
    try {
      final response = await _http
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final raw = await response.stream.bytesToString();
        throw _failure(_decodeMap(raw), response.statusCode);
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('text/event-stream')) {
        final raw = await response.stream.bytesToString();
        yield _reply(_decodeMap(raw), app);
        return;
      }
      var carry = '';
      var sawDone = false;
      await for (final chunk in response.stream
          .timeout(timeout + const Duration(seconds: 120))
          .transform(utf8.decoder)) {
        carry += chunk;
        while (true) {
          final split = carry.indexOf('\n\n');
          if (split < 0) break;
          final block = carry.substring(0, split);
          carry = carry.substring(split + 2);
          for (final line in const LineSplitter().convert(block)) {
            if (!line.startsWith('data:')) continue;
            final payload = line.substring(5).trim();
            if (payload.isEmpty) continue;
            final body = _decodeMap(payload);
            final error = body['error'];
            if (error is String && error.trim().isNotEmpty) {
              throw _failure(body, 502);
            }
            if (body['done'] == true) {
              sawDone = true;
              yield _reply(body, app);
              return;
            }
            final partial = body['text'];
            if (partial is String && partial.trim().isNotEmpty) {
              yield PocketReply(text: partial, app: app, done: false);
            }
          }
        }
      }
      if (!sawDone) {
        throw const AiServerException('Pocket ended the stream before a reply.');
      }
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw _notRunning();
    } on http.ClientException {
      throw _notRunning();
    }
  }

  Future<PocketReply> send({
    required String modelId,
    required String message,
    List<String> files = const [],
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final text = message.trim();
    if (text.isEmpty && files.isEmpty) {
      throw const AiMalformedOutputException('The Pocket prompt is empty.');
    }
    final model = PocketModelRef.normalize(modelId);
    final app = model.appId;
    final seconds = timeout.inSeconds < 1 ? 1 : timeout.inSeconds;
    final base = await _baseUrl();
    final body = jsonEncode(
      _chatBody(
        model: model,
        message: text,
        seconds: seconds,
        files: files,
      ),
    );
    try {
      final response = await _http
          .post(
            Uri.parse('$base/chat'),
            headers: const {'content-type': 'application/json'},
            body: body,
          )
          .timeout(timeout + const Duration(seconds: 120));
      return _read(response, app);
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw _notRunning();
    } on http.ClientException {
      throw _notRunning();
    }
  }

  Map<String, Object> _chatBody({
    required PocketModelRef model,
    required String message,
    required int seconds,
    required List<String> files,
    bool stream = false,
  }) {
    return {
      'app': model.appId,
      'message': message,
      'new_chat': true,
      'timeout': seconds,
      if (stream) 'stream': true,
      if (files.isNotEmpty) 'files': files,
      if (model.accountId != null) 'account': model.accountId!,
    };
  }

  PocketReply _read(http.Response response, String app) {
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(body, response.statusCode);
    }
    return _reply(body, app);
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      throw const AiServerException('Pocket returned an unreadable response.');
    }
    return const {};
  }

  AiException _failure(Map<String, dynamic> body, int statusCode) {
    final error = body['error'];
    final message = error is String && error.trim().isNotEmpty
        ? error.trim()
        : 'Pocket could not complete the request.';
    if (statusCode == 0 && message.toLowerCase().contains('timed out')) {
      return const AiTimeoutException();
    }
    if (message.toLowerCase().contains('timed out')) {
      return const AiTimeoutException();
    }
    return AiServerException(message);
  }

  PocketReply _reply(Map<String, dynamic> body, String app) {
    final reply = body['reply'];
    final text = reply is String ? reply.trim() : '';
    final images = body['images'];
    final paths = <String>[];
    if (images is List) {
      for (final item in images) {
        if (item is Map && item['path'] is String) {
          final path = (item['path'] as String).trim();
          if (path.isNotEmpty) paths.add(path);
        }
      }
    }
    if (text.isEmpty && paths.isEmpty) {
      throw const AiEmptyResultException('Pocket returned an empty reply.');
    }
    if (paths.isEmpty) return PocketReply(text: text, app: app);
    final picture = paths.map((path) => 'Saved picture: $path').join('\n');
    final combined = text.isEmpty ? picture : '$text\n\n$picture';
    return PocketReply(text: combined, app: app);
  }

  Future<String> _baseUrl() async {
    final raw = (await settings.getPocketBaseUrl()).trim();
    return normalizePocketBaseUrl(raw.isEmpty ? defaultBaseUrl : raw);
  }

  AiNotConfiguredException _notRunning() {
    return const AiNotConfiguredException(
      'Pocket is not running. Start it with python3 server.py, '
      'sign in to ChatGPT, Claude, or Gemini, then try again.',
    );
  }
}
