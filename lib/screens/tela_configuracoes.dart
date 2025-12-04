import 'package:flutter/material.dart';
import 'package:vango/services/theme_service.dart';
import 'package:vango/services/locale_service.dart';
import 'package:vango/widgets/neon_app_bar.dart';
import 'package:vango/l10n/app_localizations.dart';

class TelaConfiguracoes extends StatelessWidget {
  const TelaConfiguracoes({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NeonAppBar(
        title: l10n.settingsTitle,
        showBackButton: true,
        showMenuButton: false,
        showNotificationsButton: false,
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeService,
        builder: (context, currentMode, child) {
          return ValueListenableBuilder<Locale>(
            valueListenable: localeService,
            builder: (context, localeAtual, _) {
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  SwitchListTile(
                    title: Text(l10n.darkTheme),
                    value: currentMode == ThemeMode.dark,
                    onChanged: (isDark) {
                      themeService.toggleTheme();
                    },
                    secondary: Icon(
                      currentMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(l10n.appLanguage),
                    subtitle: Text(_labelIdioma(localeAtual.languageCode, l10n)),
                    trailing: DropdownButton<Locale>(
                      value: localeAtual,
                      underline: const SizedBox.shrink(),
                      onChanged: (novoLocale) {
                        if (novoLocale != null) {
                          localeService.setLocale(novoLocale);
                        }
                      },
                      items: LocaleService.supportedLocales
                          .map(
                            (l) => DropdownMenuItem(
                              value: l,
                              child: Text(_labelIdioma(l.languageCode, l10n)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _labelIdioma(String codigo, AppLocalizations l10n) {
    switch (codigo) {
      case 'en':
        return l10n.languageEnglish;
      case 'fr':
        return l10n.languageFrench;
      default:
        return l10n.languagePortuguese;
    }
  }
}
