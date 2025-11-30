import 'package:flutter/material.dart';
import 'package:vango/services/theme_service.dart';
import 'package:vango/widgets/neon_app_bar.dart';

class TelaConfiguracoes extends StatelessWidget {
  const TelaConfiguracoes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NeonAppBar(
        title: 'Configurações',
        showBackButton: true,
        showMenuButton: false,
        showNotificationsButton: false,
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeService,
        builder: (context, currentMode, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              SwitchListTile(
                title: const Text('Tema Escuro'),
                value: currentMode == ThemeMode.dark,
                onChanged: (isDark) {
                  themeService.toggleTheme();
                },
                secondary: Icon(
                  currentMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
