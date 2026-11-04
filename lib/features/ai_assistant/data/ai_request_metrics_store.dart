import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/ai_token_usage.dart';

/// Bounded, device-local diagnostics. Never stores keys, prompts, or responses.
class AiRequestMetric {
  const AiRequestMetric({
    required this.modelId,
    required this.at,
    required this.succeeded,
    required this.usage,
  });
  final String modelId;
  final DateTime at;
  final bool succeeded;
  final AiTokenUsage usage;
  Map<String, Object?> toJson() => {
    'model': modelId,
    'at': at.millisecondsSinceEpoch,
    'ok': succeeded,
    'input': usage.promptTokens,
    'output': usage.completionTokens,
    'hit': usage.cacheHitTokens,
    'miss': usage.cacheMissTokens,
    'write': usage.cacheWriteTokens,
    'uncached': usage.uncachedInputTokens,
    'firstTokenMs': usage.timeToFirstTokenMs,
    'durationMs': usage.durationMs,
    'provider': usage.provider,
  };
  factory AiRequestMetric.fromJson(Map<String, dynamic> json) =>
      AiRequestMetric(
        modelId: json['model'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
        succeeded: json['ok'] == true,
        usage: AiTokenUsage(
          promptTokens: json['input'] as int?,
          completionTokens: json['output'] as int?,
          cacheHitTokens: json['hit'] as int?,
          cacheMissTokens: json['miss'] as int?,
          cacheWriteTokens: json['write'] as int?,
          uncachedInputTokens: json['uncached'] as int?,
          timeToFirstTokenMs: json['firstTokenMs'] as int?,
          durationMs: json['durationMs'] as int?,
          provider: json['provider'] as String?,
        ),
      );
}

class AiRequestMetricsStore {
  AiRequestMetricsStore({this.persist = true});
  static const storageKey = 'ai_request_metrics_v1';
  static const limit = 100;
  final bool persist;
  List<AiRequestMetric>? _rows;
  Future<void> _writes = Future.value();
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  void dispose() => _changes.close();

  Future<List<AiRequestMetric>> list() async {
    if (_rows == null) {
      final raw = persist
          ? (await SharedPreferences.getInstance()).getString(storageKey)
          : null;
      try {
        _rows = raw == null
            ? []
            : [
                for (final row in jsonDecode(raw) as List)
                  AiRequestMetric.fromJson(
                    (row as Map).cast<String, dynamic>(),
                  ),
              ];
      } on Object {
        _rows = [];
      }
    }
    return List.unmodifiable(_rows!);
  }

  Future<void> add(AiRequestMetric row) {
    final run = _writes.then((_) async {
      final previous = await list();
      _rows = [row, ...previous.take(limit - 1)];
      if (persist) {
        await (await SharedPreferences.getInstance()).setString(
          storageKey,
          jsonEncode([for (final entry in _rows!) entry.toJson()]),
        );
      }
      if (!_changes.isClosed) _changes.add(null);
    });
    _writes = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }
}
