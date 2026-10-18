import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Strips light markdown so TTS reads the words, not the syntax.
String chatSpeechPlainText(String markdown) {
  return markdown
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'```[a-zA-Z0-9_-]*'), '')
      .replaceAll(RegExp(r'[`*_>#]'), '')
      .trim();
}

/// Splits [text] into TTS-safe pieces under [maxChars], preferring
/// paragraph then sentence boundaries so Android's ~4k limit does not
/// cut a long assistant reply short.
List<String> chatSpeechChunks(String text, {required int maxChars}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (maxChars < 32) maxChars = 32;
  if (trimmed.length <= maxChars) return [trimmed];

  final chunks = <String>[];
  final paragraphs = trimmed.split(RegExp(r'\n\s*\n'));
  final buffer = StringBuffer();

  void flush() {
    final piece = buffer.toString().trim();
    buffer.clear();
    if (piece.isNotEmpty) chunks.add(piece);
  }

  void appendPiece(String piece) {
    final next = piece.trim();
    if (next.isEmpty) return;
    if (next.length > maxChars) {
      flush();
      for (final hard in _hardSplit(next, maxChars)) {
        chunks.add(hard);
      }
      return;
    }
    if (buffer.isEmpty) {
      buffer.write(next);
      return;
    }
    if (buffer.length + 1 + next.length <= maxChars) {
      buffer.write('\n\n');
      buffer.write(next);
      return;
    }
    flush();
    buffer.write(next);
  }

  for (final paragraph in paragraphs) {
    final p = paragraph.trim();
    if (p.isEmpty) continue;
    if (p.length <= maxChars) {
      appendPiece(p);
      continue;
    }
    for (final sentence in _splitSentences(p)) {
      appendPiece(sentence);
    }
  }
  flush();
  return chunks;
}

List<String> _splitSentences(String text) {
  final matches = RegExp(r'[^.!?]+[.!?]+|\S[^.!?]*$').allMatches(text);
  final parts = matches.map((m) => m.group(0)!.trim()).where((s) => s.isNotEmpty);
  if (parts.isEmpty) return [text];
  return parts.toList(growable: false);
}

List<String> _hardSplit(String text, int maxChars) {
  final out = <String>[];
  var i = 0;
  while (i < text.length) {
    var end = (i + maxChars).clamp(0, text.length);
    if (end < text.length) {
      final space = text.lastIndexOf(RegExp(r'\s'), end);
      if (space > i + (maxChars ~/ 4)) end = space;
    }
    out.add(text.substring(i, end).trim());
    i = end;
    while (i < text.length && text[i].trim().isEmpty) {
      i++;
    }
  }
  return out.where((s) => s.isNotEmpty).toList(growable: false);
}

class ChatSpeechService extends ChangeNotifier {
  ChatSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    // Completion/cancel are driven by awaitSpeakCompletion + session ids.
    // Do not clear speaking state on cancel — stop()-before-restart would
    // otherwise flip the Stop button off mid-reply.
    _tts.setErrorHandler((message) {
      debugPrint('[ChatSpeech] $message');
      _invalidateSession();
      _finish();
    });
  }

  final FlutterTts _tts;
  String? _speakingText;
  int _session = 0;
  bool _disposed = false;

  bool isSpeaking(String text) => _speakingText == text.trim();

  Future<void> toggle(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    if (_speakingText == normalized) {
      await stop();
      return;
    }

    final session = ++_session;
    await _tts.stop();
    if (_disposed || session != _session) return;

    _speakingText = normalized;
    notifyListeners();

    final plain = chatSpeechPlainText(normalized);
    if (plain.isEmpty) {
      _finish();
      return;
    }

    final maxChars = await _maxChunkLength();
    final chunks = chatSpeechChunks(plain, maxChars: maxChars);

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.48);
      for (final chunk in chunks) {
        if (_disposed || session != _session) return;
        await _tts.speak(chunk);
      }
      if (session == _session) _finish();
    } catch (error) {
      debugPrint('[ChatSpeech] Could not speak: $error');
      if (session == _session) _finish();
      rethrow;
    }
  }

  Future<void> stop() async {
    _invalidateSession();
    await _tts.stop();
    _finish();
  }

  void _invalidateSession() {
    _session++;
  }

  void _finish() {
    if (_speakingText == null) return;
    _speakingText = null;
    if (!_disposed) notifyListeners();
  }

  Future<int> _maxChunkLength() async {
    try {
      final max = await _tts.getMaxSpeechInputLength;
      if (max != null && max > 200) return max - 100;
    } catch (error) {
      debugPrint('[ChatSpeech] max length unavailable: $error');
    }
    return 3000;
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidateSession();
    // ignore: discarded_futures
    _tts.stop();
    super.dispose();
  }
}
