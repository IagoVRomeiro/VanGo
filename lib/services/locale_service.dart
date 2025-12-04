import 'package:flutter/material.dart';

class LocaleService extends ValueNotifier<Locale> {
  LocaleService() : super(const Locale('pt', 'BR'));

  static const supportedLocales = [
    Locale('pt', 'BR'),
    Locale('en', 'US'),
    Locale('fr', 'FR'),
  ];

  void setLocale(Locale nova) {
    if (supportedLocales.any((l) => l.languageCode == nova.languageCode)) {
      value = nova;
    }
  }
}

final localeService = LocaleService();
