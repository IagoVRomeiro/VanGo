import 'package:flutter/material.dart';

class VoiceSettingsService extends ValueNotifier<bool> {
  VoiceSettingsService() : super(true);

  void toggle() {
    value = !value;
  }

  void setEnabled(bool enabled) {
    value = enabled;
  }
}

final voiceSettingsService = VoiceSettingsService();
