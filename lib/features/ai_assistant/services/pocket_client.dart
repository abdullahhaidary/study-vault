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

/// One browser conversation Pocket can reopen by id.
class PocketBrowserChat {
  const PocketBrowserChat({
    required this.id,
    required this.app,
    required this.title,
    required this.account,
  });

  final String id;
  final String app;
  final String title;
  final String account;
}

/// One reply from the local Pocket chat server.
class PocketReply {
  const PocketReply({
    required this.text,
    required this.app,
    this.delta = '',
    this.done = true,
    this.replaces = false,
    this.chatId,
  });

  /// The full assistant text so far, including any saved picture lines.
  final String text;

  /// Characters added since the previous event.
  final String delta;

  final String app;

  /// False while the reply is still growing.
  final bool done;

  /// True when [text] replaces everything already streamed.
  final bool replaces;

  /// Browser conversation this reply belongs to. Send it back to continue.
  final String? chatId;
}

/// Posts one message to the Pocket window on this computer.
///
/// A [chatId] reopens that browser conversation. [newChat] starts another
/// page and returns a new id. Study actions pass [newChat] so they stay out
/// of the conversation the chat screen is continuing.
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
          ]
          .where((account) => account.id.isNotEmpty && account.name.isNotEmpty)
          .toList();
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

  Future<List<PocketBrowserChat>> listChats({
    String? app,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final base = await _baseUrl();
    final query = app == null || app.trim().isEmpty
        ? ''
        : '?app=${Uri.encodeQueryComponent(app.trim())}';
    try {
      final response = await _http
          .get(Uri.parse('$base/chats$query'))
          .timeout(timeout);
      final body = _decodeMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failure(body, response.statusCode);
      }
      final rows = body['chats'];
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map && row['id'] is String && row['app'] is String)
            PocketBrowserChat(
              id: (row['id'] as String).trim(),
              app: (row['app'] as String).trim(),
              title: row['title'] is String
                  ? (row['title'] as String).trim()
                  : 'Chat',
              account: row['account'] is String
                  ? (row['account'] as String).trim()
                  : '',
            ),
      ].where((chat) => chat.id.isNotEmpty && chat.app.isNotEmpty).toList();
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

  Future<void> forgetChat(
    String id, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final chatId = id.trim();
    if (chatId.isEmpty) return;
    final base = await _baseUrl();
    try {
      final response = await _http
          .delete(Uri.parse('$base/chats/$chatId'))
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
    String? chatId,
    bool newChat = false,
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
        chatId: chatId,
        newChat: newChat,
      ),
    );
    try {
      final response = await _http
          .send(request)
          .timeout(timeout + const Duration(seconds: 30));
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
      var full = '';
      var sawDone = false;
      var seenChatId = _cleanId(chatId);
      await for (final chunk
          in response.stream
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
            if (payload == '[DONE]') {
              if (!sawDone) {
                if (full.trim().isEmpty) {
                  throw const AiServerException(
                    'Pocket ended the stream before a reply.',
                  );
                }
                yield PocketReply(
                  text: full,
                  delta: '',
                  app: app,
                  chatId: seenChatId,
                );
              }
              return;
            }
            final body = _decodeMap(payload);
            if (body['error'] != null && body['choices'] == null) {
              throw _failure(body, 502);
            }
            final incomingChatId = _cleanId(body['chat_id']);
            if (incomingChatId != null) seenChatId = incomingChatId;
            final piece = _deltaContent(body);
            final reason = _finishReason(body);
            final canonical = _messageContent(body);
            final finishing = reason != null || canonical != null;
            var pending = '';
            if (piece != null && piece.isNotEmpty) {
              full += piece;
              pending = piece;
            }
            if (!finishing) {
              if (pending.isNotEmpty) {
                yield PocketReply(
                  text: full,
                  delta: pending,
                  app: app,
                  done: false,
                  chatId: seenChatId,
                );
              }
              continue;
            }
            final resolved = _resolveFinal(
              streamed: full,
              canonical: canonical,
              images: _imagePaths(body),
            );
            full = resolved.text;
            sawDone = true;
            yield PocketReply(
              text: resolved.text,
              delta: resolved.replaces
                  ? resolved.delta
                  : '$pending${resolved.delta}',
              app: app,
              replaces: resolved.replaces,
              chatId: seenChatId,
            );
          }
        }
      }
      if (!sawDone) {
        if (full.trim().isEmpty) {
          throw const AiServerException(
            'Pocket ended the stream before a reply.',
          );
        }
        yield PocketReply(text: full, delta: '', app: app, chatId: seenChatId);
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
    String? chatId,
    bool newChat = false,
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
        chatId: chatId,
        newChat: newChat,
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
    String? chatId,
    bool newChat = false,
  }) {
    final continueId = _cleanId(chatId);
    return {
      'app': model.appId,
      'message': message,
      'timeout': seconds,
      if (newChat || continueId == null) 'new_chat': newChat,
      if (!newChat && continueId != null) 'chat_id': continueId,
      if (stream) 'stream': true,
      if (files.isNotEmpty) 'files': files,
      if (model.accountId != null) 'account': model.accountId!,
    };
  }

  String? _cleanId(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
    final message = _errorMessage(body);
    if (statusCode == 408 || message.toLowerCase().contains('timed out')) {
      return const AiTimeoutException();
    }
    return AiServerException(message);
  }

  String _errorMessage(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map && error['message'] is String) {
      final message = (error['message'] as String).trim();
      if (message.isNotEmpty) return message;
    }
    if (error is String && error.trim().isNotEmpty) return error.trim();
    return 'Pocket could not complete the request.';
  }

  PocketReply _reply(Map<String, dynamic> body, String app) {
    final text = (_messageContent(body) ?? '').trim();
    final resolved = _resolveFinal(
      streamed: '',
      canonical: text,
      images: _imagePaths(body),
    );
    if (resolved.text.trim().isEmpty) {
      throw const AiEmptyResultException('Pocket returned an empty reply.');
    }
    return PocketReply(
      text: resolved.text,
      delta: resolved.text,
      app: app,
      chatId: _cleanId(body['chat_id']),
    );
  }

  String? _deltaContent(Map<String, dynamic> body) {
    final choice = _firstChoice(body);
    if (choice == null) return null;
    final delta = choice['delta'];
    if (delta is Map && delta['content'] is String) {
      return delta['content'] as String;
    }
    return null;
  }

  String? _messageContent(Map<String, dynamic> body) {
    final choice = _firstChoice(body);
    if (choice != null) {
      final message = choice['message'];
      if (message is Map && message['content'] is String) {
        return message['content'] as String;
      }
    }
    final reply = body['reply'];
    if (reply is String) return reply;
    return null;
  }

  String? _finishReason(Map<String, dynamic> body) {
    final choice = _firstChoice(body);
    final reason = choice?['finish_reason'];
    if (reason is String && reason.isNotEmpty) return reason;
    return null;
  }

  Map<String, dynamic>? _firstChoice(Map<String, dynamic> body) {
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return null;
    }
    return (choices.first as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  List<String> _imagePaths(Map<String, dynamic> body) {
    final images = body['images'];
    if (images is! List) return const [];
    final paths = <String>[];
    for (final item in images) {
      if (item is Map && item['path'] is String) {
        final path = (item['path'] as String).trim();
        if (path.isNotEmpty) paths.add(path);
      }
    }
    return paths;
  }

  ({String text, String delta, bool replaces}) _resolveFinal({
    required String streamed,
    required String? canonical,
    required List<String> images,
  }) {
    var text = streamed;
    var delta = '';
    var replaces = false;
    if (canonical != null) {
      if (canonical.startsWith(text)) {
        delta = canonical.substring(text.length);
        text = canonical;
      } else {
        text = canonical;
        delta = canonical;
        replaces = streamed.isNotEmpty;
      }
    }
    final pictured = _withImages(text, images);
    if (pictured != text) {
      if (replaces) {
        delta = pictured;
      } else {
        delta += pictured.substring(text.length);
      }
      text = pictured;
    }
    if (text.trim().isEmpty) {
      throw const AiEmptyResultException('Pocket returned an empty reply.');
    }
    return (text: text, delta: delta, replaces: replaces);
  }

  String _withImages(String text, List<String> paths) {
    if (paths.isEmpty) return text;
    final picture = paths.map((path) => 'Saved picture: $path').join('\n');
    return text.isEmpty ? picture : '$text\n\n$picture';
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
