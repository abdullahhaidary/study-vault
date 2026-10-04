import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CloudApiException implements Exception {
  const CloudApiException(this.message, {this.status});
  final String message;
  final int? status;

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

class CloudApi {
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

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
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
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > 65536) {
          throw const CloudApiException('The server response is too large.');
        }
        bytes.addAll(chunk);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CloudApiException(switch (response.statusCode) {
          401 =>
            'Incorrect credentials, or the session has expired. Sign in again.',
          429 => 'Too many attempts. Please wait before trying again.',
          >= 300 && < 400 => 'Unexpected server redirect. Login was stopped.',
          _ => 'The server could not complete the request. Please retry.',
        }, status: response.statusCode);
      }
      if (response.statusCode == 204) return {};
      final decoded = jsonDecode(utf8.decode(bytes));
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
