import 'package:flutter/material.dart';

typedef DrawerAction = Future<void> Function();

class NeonDrawer extends StatelessWidget {
  final DrawerAction onSettings;
  final DrawerAction onLogout;
  final String title;

  const NeonDrawer({
    super.key,
    required this.onSettings,
    required this.onLogout,
    this.title = 'Menu',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configurações'),
                onTap: () async {
                  Navigator.pop(context);
                  await onSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Sair'),
                onTap: () async {
                  Navigator.pop(context);
                  await onLogout();
                },
              ),
              const Divider(height: 1),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
