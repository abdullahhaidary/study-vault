import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/ai_actions.dart';

enum VoiceInputStatus { idle, initializing, listening, stopping, unavailable }

enum VoiceInputErrorKind {
  permissionDenied,
  unavailable,
  noSpeech,
  timeout,
  network,
  busy,
  unsupportedLocale,
  unknown,
}

class VoiceInputError {
  const VoiceInputError({required this.kind, required this.message});

  final VoiceInputErrorKind kind;
  final String message;
}

/// Device speech recognition — never uploads audio to DeepSeek/Gemini.
///
/// Only one listen session is active at a time app-wide.
class VoiceInputService extends ChangeNotifier {
  VoiceInputService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  VoiceInputStatus _status = VoiceInputStatus.idle;
  bool _initialized = false;
  bool _available = false;
  List<LocaleName> _locales = const [];
  VoiceInputError? _lastError;
  void Function(String words, bool isFinal)? _resultHandler;
  int _sessionId = 0;

  VoiceInputStatus get status => _status;
  bool get isListening => _status == VoiceInputStatus.listening;
  bool get isAvailable => _available;
  bool get isInitialized => _initialized;
  List<LocaleName> get locales => List.unmodifiable(_locales);
  VoiceInputError? get lastError => _lastError;

  /// Test-only: seed device locales without initializing the platform plugin.
  @visibleForTesting
  void debugSetLocales(List<LocaleName> locales) {
    _locales = List.of(locales);
    _initialized = true;
    _available = true;
  }

  Future<bool> initialize() async {
    if (_initialized) return _available;
    _setStatus(VoiceInputStatus.initializing);
    try {
      _available = await _speech.initialize(
        onError: _onPlatformError,
        onStatus: _onPlatformStatus,
        debugLogging: false,
      );
      if (_available) {
        _locales = await _speech.locales();
      }
      _initialized = true;
      _setStatus(
        _available ? VoiceInputStatus.idle : VoiceInputStatus.unavailable,
      );
      if (!_available) {
        _lastError = const VoiceInputError(
          kind: VoiceInputErrorKind.unavailable,
          message:
              'Speech recognition is not available on this device. You can still type.',
        );
        notifyListeners();
      }
      return _available;
    } catch (_) {
      _initialized = true;
      _available = false;
      _lastError = const VoiceInputError(
        kind: VoiceInputErrorKind.unavailable,
        message:
            'Speech recognition is not available on this device. You can still type.',
      );
      _setStatus(VoiceInputStatus.unavailable);
      return false;
    }
  }

  /// Picks the closest device locale for [language], or null for system default.
  String? resolveLocaleId(AiLanguage language) {
    if (_locales.isEmpty) return null;
    final preferred = switch (language) {
      AiLanguage.english => const ['en', 'en_US', 'en_GB'],
      AiLanguage.persianDari => const ['fa', 'fa_IR', 'fa_AF', 'prs', 'ps'],
      AiLanguage.auto => const <String>[],
    };
    if (preferred.isEmpty) return null;

    for (final code in preferred) {
      for (final locale in _locales) {
        final id = locale.localeId.replaceAll('-', '_');
        if (id.toLowerCase() == code.toLowerCase() ||
            id.toLowerCase().startsWith('${code.toLowerCase()}_')) {
          return locale.localeId;
        }
      }
    }
    return null;
  }

  Future<void> start({
    String? localeId,
    required void Function(String words, bool isFinal) onResult,
  }) async {
    _lastError = null;
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        notifyListeners();
        return;
      }
    }
    if (!_available) {
      _lastError = const VoiceInputError(
        kind: VoiceInputErrorKind.unavailable,
        message:
            'Speech recognition is not available on this device. You can still type.',
      );
      notifyListeners();
      return;
    }

    if (isListening) {
      await stop();
    }

    _resultHandler = onResult;
    final session = ++_sessionId;
    _setStatus(VoiceInputStatus.listening);

    try {
      final started = await _speech.listen(
        onResult: (result) {
          if (session != _sessionId) return;
          final words = result.recognizedWords.trim();
          _resultHandler?.call(words, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: localeId,
          // Prefer on-device when the platform supports it; otherwise the
          // plugin falls back to the normal device recognizer.
          onDevice: true,
        ),
      );
      if (!started) {
        // Retry without forcing on-device (many devices lack offline models).
        final retry = await _speech.listen(
          onResult: (result) {
            if (session != _sessionId) return;
            final words = result.recognizedWords.trim();
            _resultHandler?.call(words, result.finalResult);
          },
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            listenMode: ListenMode.dictation,
            localeId: localeId,
            onDevice: false,
          ),
        );
        if (!retry) {
          _resultHandler = null;
          _lastError = const VoiceInputError(
            kind: VoiceInputErrorKind.permissionDenied,
            message:
                'Microphone permission is required for voice input. You can still type.',
          );
          _setStatus(VoiceInputStatus.idle);
        }
      }
    } catch (_) {
      _resultHandler = null;
      _lastError = const VoiceInputError(
        kind: VoiceInputErrorKind.unknown,
        message: 'Could not start voice input. You can still type.',
      );
      _setStatus(VoiceInputStatus.idle);
    }
  }

  Future<void> stop() async {
    if (!isListening && _status != VoiceInputStatus.stopping) {
      return;
    }
    _setStatus(VoiceInputStatus.stopping);
    try {
      await _speech.stop();
    } catch (_) {
      // Ignore stop failures; always return to idle.
    }
    _resultHandler = null;
    _setStatus(VoiceInputStatus.idle);
  }

  Future<void> cancel() async {
    _sessionId++;
    _resultHandler = null;
    try {
      await _speech.cancel();
    } catch (_) {
      // Ignore cancel failures.
    }
    _setStatus(VoiceInputStatus.idle);
  }

  void _onPlatformError(SpeechRecognitionError error) {
    _lastError = VoiceInputError(
      kind: _mapError(error.errorMsg),
      message: _userMessage(error.errorMsg),
    );
    _resultHandler = null;
    if (_status == VoiceInputStatus.listening ||
        _status == VoiceInputStatus.stopping) {
      _setStatus(VoiceInputStatus.idle);
    } else {
      notifyListeners();
    }
  }

  void _onPlatformStatus(String status) {
    // speech_to_text emits: listening, notListening, done
    if (status == 'done' || status == 'notListening') {
      if (_status == VoiceInputStatus.listening ||
          _status == VoiceInputStatus.stopping) {
        _resultHandler = null;
        _setStatus(VoiceInputStatus.idle);
      }
    }
  }

  VoiceInputErrorKind _mapError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('permission')) return VoiceInputErrorKind.permissionDenied;
    if (msg.contains('no_match') || msg.contains('no_speech')) {
      return VoiceInputErrorKind.noSpeech;
    }
    if (msg.contains('timeout') || msg.contains('speech_timeout')) {
      return VoiceInputErrorKind.timeout;
    }
    if (msg.contains('network')) return VoiceInputErrorKind.network;
    if (msg.contains('busy')) return VoiceInputErrorKind.busy;
    if (msg.contains('language')) return VoiceInputErrorKind.unsupportedLocale;
    if (msg.contains('unavailable') || msg.contains('disabled')) {
      return VoiceInputErrorKind.unavailable;
    }
    return VoiceInputErrorKind.unknown;
  }

  String _userMessage(String raw) {
    return switch (_mapError(raw)) {
      VoiceInputErrorKind.permissionDenied =>
        'Microphone permission is required for voice input. You can still type.',
      VoiceInputErrorKind.unavailable =>
        'Speech recognition is not available on this device. You can still type.',
      VoiceInputErrorKind.noSpeech =>
        'No speech detected. Try again or type your question.',
      VoiceInputErrorKind.timeout =>
        'Listening timed out. Tap the mic to try again.',
      VoiceInputErrorKind.network =>
        'Speech recognition needs a network connection on this device.',
      VoiceInputErrorKind.busy =>
        'Speech recognition is busy. Wait a moment and try again.',
      VoiceInputErrorKind.unsupportedLocale =>
        'That language is not available for speech recognition on this device.',
      VoiceInputErrorKind.unknown =>
        'Voice input failed. You can still type your question.',
    };
  }

  void _setStatus(VoiceInputStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionId++;
    _resultHandler = null;
    // Cancel any active listen; SpeechToText itself is not disposed.
    // ignore: discarded_futures
    _speech.cancel();
    super.dispose();
  }
}
