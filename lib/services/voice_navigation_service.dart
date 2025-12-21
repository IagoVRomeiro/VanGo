import 'package:flutter_tts/flutter_tts.dart';

class VoiceNavigationService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _initialized = true;
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _tts.stop();
    }
  }

  Future<void> speak(String text) async {
    if (!_enabled) return;
    if (text.trim().isEmpty) return;
    await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _tts.stop();
  }
}
