import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'cloud_sync_models.dart';

class CloudApiException implements Exception {
  const CloudApiException(
    this.message, {
    this.status,
    this.code,
    this.retryAfter,
  });
  final String message;
  final int? status;
  final String? code;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

class CloudSession {
  const CloudSession({
    required this.token,
    required this.accountId,
    required this.username,
    required this.expiresAt,
  });

  final String token;
  final String accountId;
  final String username;
  final DateTime expiresAt;

  factory CloudSession.fromJson(Map<String, dynamic> json) {
    final account = json['account'];
    final token = json['token'];
    final expires = DateTime.tryParse('${json['expiresAt']}');
    if (account is! Map ||
        account['id'] is! String ||
        account['username'] is! String ||
        token is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token) ||
        expires == null) {
      throw const CloudApiException('Invalid account response.');
    }
    return CloudSession(
      token: token,
      accountId: account['id'] as String,
      username: account['username'] as String,
      expiresAt: expires,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'account': {'id': accountId, 'username': username},
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

class CloudApi implements CloudSyncRemote {
  CloudApi({http.Client? client}) : _client = client ?? http.Client();

  static final origin = Uri.parse('https://187.127.69.22:9443');
  final http.Client _client;

  Future<CloudSession> login({
    required String username,
    required String password,
    required String deviceName,
  }) async {
    final result = await _request(
      'POST',
      '/v1/login',
      body: {
        'username': username.trim(),
        'password': password,
        'deviceName': deviceName,
      },
    );
    final session = CloudSession.fromJson(result);
    if (!session.expiresAt.isAfter(DateTime.now())) {
      throw const CloudApiException('The server returned an expired session.');
    }
    return session;
  }

  Future<void> verify(CloudSession session) async {
    final result = await _request('GET', '/v1/me', token: session.token);
    final account = result['account'];
    if (account is! Map || account['id'] != session.accountId) {
      throw const CloudApiException(
        'Account verification failed.',
        status: 401,
      );
    }
  }

  Future<void> logout(CloudSession session) async {
    await _request('POST', '/v1/logout', token: session.token);
  }

  @override
  Future<CloudSnapshot> snapshot(String token) async => CloudSnapshot.fromJson(
    await _request(
      'GET',
      '/v2/snapshot',
      token: token,
      maximumBytes: 64 * 1024 * 1024,
      timeout: const Duration(minutes: 5),
    ),
  );

  @override
  Future<void> commit(String token, Map<String, dynamic> body) async {
    if (utf8.encode(jsonEncode(body)).length > 60 * 1024 * 1024) {
      throw const CloudApiException(
        'This sync exceeds the 60 MiB metadata limit. No records were sent.',
      );
    }
    await _request(
      'POST',
      '/v2/sync',
      token: token,
      body: body,
      maximumBytes: 4 * 1024 * 1024,
      timeout: const Duration(minutes: 5),
    );
  }

  Duration? _retryAfter(http.StreamedResponse response) =>
      response.statusCode != 429
      ? null
      : Duration(
          seconds: (int.tryParse(response.headers['retry-after'] ?? '') ?? 60)
              .clamp(1, 300)
              .toInt(),
        );

  Uri _fileUri(String digest) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const CloudApiException('Invalid file checksum.');
    }
    return origin.resolve('/v1/files/$digest');
  }

  @override
  Future<bool> hasFile(String token, String digest) async {
    final request = http.Request('HEAD', _fileUri(digest))
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer $token';
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    await response.stream.drain<void>();
    if (response.statusCode == 404) return false;
    if (response.statusCode != 200) {
      throw CloudApiException(
        'Could not check the private file.',
        status: response.statusCode,
        retryAfter: _retryAfter(response),
      );
    }
    return true;
  }

  @override
  Future<void> uploadFile(String token, String digest, File file) async {
    final size = await file.length();
    if (size > 256 * 1024 * 1024) {
      throw const CloudApiException('A file exceeds the 256 MiB upload limit.');
    }
    final abort = Completer<void>();
    final request =
        http.AbortableStreamedRequest(
            'PUT',
            _fileUri(digest),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..contentLength = size
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Content-Type'] = 'application/octet-stream';
    try {
      final responseFuture = _client.send(request).then((response) {
        if (response.statusCode != 201) {
          throw CloudApiException(
            response.statusCode == 413
                ? 'The file or private storage quota is too large.'
                : 'File upload failed; your local file was kept.',
            status: response.statusCode,
            retryAfter: _retryAfter(response),
          );
        }
        return response;
      });
      final writing = file.openRead().pipe(request.sink);
      final result = await Future.wait<Object?>([
        responseFuture,
        writing,
      ], eagerError: true).timeout(const Duration(minutes: 5));
      final response = result.first as http.StreamedResponse;
      await response.stream.timeout(const Duration(seconds: 30)).drain<void>();
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  @override
  Future<void> downloadFile(
    String token,
    String digest,
    int bytes,
    File target,
  ) async {
    if (bytes < 0 || bytes > 256 * 1024 * 1024) {
      throw const CloudApiException('Invalid cloud file size.');
    }
    if (await target.exists()) {
      throw const CloudApiException(
        'The download target must be a new temporary file.',
      );
    }
    final request = http.Request('GET', _fileUri(digest))
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer $token';
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw CloudApiException(
        'Could not download the private file.',
        status: response.statusCode,
        retryAfter: _retryAfter(response),
      );
    }
    await target.parent.create(recursive: true);
    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        received += chunk.length;
        if (received > bytes) {
          throw const CloudApiException(
            'The downloaded file exceeds its declared size.',
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received != bytes ||
        (await sha256.bind(target.openRead()).first).toString() != digest) {
      throw const CloudApiException(
        'The downloaded file failed its checksum check.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    int maximumBytes = 65536,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final request = http.Request(method, origin.resolve(path))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client.send(request).timeout(timeout);
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > maximumBytes) {
          throw const CloudApiException('The server response is too large.');
        }
        bytes.add(chunk);
      }
      final responseBytes = bytes.takeBytes();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? code;
        if (response.statusCode == 409) {
          try {
            final payload = jsonDecode(utf8.decode(responseBytes));
            if (payload is Map && payload['code'] is String) {
              code = payload['code'] as String;
            }
          } on FormatException {
            code = null;
          }
        }
        throw CloudApiException(
          switch (response.statusCode) {
            401 =>
              'Incorrect credentials, or the session has expired. Sign in again.',
            409 =>
              'The cloud library changed. Sync again to review the latest changes.',
            413 =>
              'This library exceeds the current sync size or storage limit.',
            422 =>
              'The library contains missing files or inconsistent related records. Nothing was committed.',
            429 => 'Too many attempts. Please wait before trying again.',
            >= 300 && < 400 => 'Unexpected server redirect. Login was stopped.',
            _ => 'The server could not complete the request. Please retry.',
          },
          status: response.statusCode,
          retryAfter: _retryAfter(response),
          code: code,
        );
      }
      if (response.statusCode == 204) return {};
      final decoded = jsonDecode(utf8.decode(responseBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const CloudApiException('Invalid server response.');
      }
      return decoded;
    } on TimeoutException {
      throw const CloudApiException(
        'Connection timed out. Your local study data is unchanged.',
      );
    } on http.ClientException {
      throw const CloudApiException(
        'Cannot securely connect to the server. Check your connection and device clock.',
      );
    } on FormatException {
      throw const CloudApiException('Invalid server response.');
    }
  }

  void close() => _client.close();
}
