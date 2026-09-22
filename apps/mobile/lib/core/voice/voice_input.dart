import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Device speech → text. Failures are soft: caller falls back to typing.
class VoiceInput {
  VoiceInput();

  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  bool _listening = false;
  void Function(bool listening)? _onListeningChanged;

  bool get isListening => _listening;
  bool get isAvailable => _ready;

  void _setListening(bool value) {
    if (_listening == value) return;
    _listening = value;
    _onListeningChanged?.call(value);
  }

  Future<bool> ensureReady() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onError: (_) {
          _setListening(false);
        },
        onStatus: (status) {
          if (status == 'done' ||
              status == 'notListening' ||
              status == 'notlistening') {
            _setListening(false);
          } else if (status == 'listening') {
            _setListening(true);
          }
        },
      );
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<void> start({
    required void Function(String words) onWords,
    void Function(String message)? onError,
    void Function(bool listening)? onListeningChanged,
  }) async {
    _onListeningChanged = onListeningChanged;
    final ok = await ensureReady();
    if (!ok) {
      onError?.call(
        'Voice input isn’t available on this device. Type instead.',
      );
      return;
    }
    if (_listening) {
      await stop();
    }
    try {
      _setListening(true);
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) onWords(words);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      _setListening(false);
      onError?.call(
        kIsWeb
            ? 'Couldn’t start the microphone. Type instead.'
            : 'Couldn’t start listening. Allow the mic, or type instead.',
      );
    }
  }

  Future<void> stop() async {
    if (!_listening && !_speech.isListening) return;
    try {
      await _speech.stop();
    } catch (_) {}
    _setListening(false);
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
    _setListening(false);
  }

  void dispose() {
    cancel();
  }
}
