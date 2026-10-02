import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatSpeechService extends ChangeNotifier {
  ChatSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setCompletionHandler(_finish);
    _tts.setCancelHandler(_finish);
    _tts.setErrorHandler((message) {
      debugPrint('[ChatSpeech] $message');
      _finish();
    });
  }

  final FlutterTts _tts;
  String? _speakingText;

  bool isSpeaking(String text) => _speakingText == text;

  Future<void> toggle(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    if (_speakingText == normalized) {
      await stop();
      return;
    }

    await _tts.stop();
    _speakingText = normalized;
    notifyListeners();
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.speak(_plainText(normalized));
    } catch (error) {
      debugPrint('[ChatSpeech] Could not speak: $error');
      _finish();
      rethrow;
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _finish();
  }

  void _finish() {
    if (_speakingText == null) return;
    _speakingText = null;
    notifyListeners();
  }

  String _plainText(String markdown) {
    return markdown
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'```[a-zA-Z0-9_-]*'), '')
        .replaceAll(RegExp(r'[`*_>#]'), '')
        .trim();
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _tts.stop();
    super.dispose();
  }
}
