import 'package:flutter/material.dart';

typedef DrawerAction = Future<void> Function();

class NeonDrawer extends StatelessWidget {
  final DrawerAction? onNotifications;
  final DrawerAction onSettings;
  final DrawerAction onLogout;
  final DrawerAction? onHistory;
  final String title;

  const NeonDrawer({
    super.key,
    this.onNotifications,
    required this.onSettings,
    required this.onLogout,
    this.onHistory,
    this.title = 'Menu',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const background = Color(0xFF15171C);
    const surface = Color(0xFF1C1F26);
    const dividerColor = Color(0xFF2A2F3A);
    const iconColor = Color(0xFFB8BEC9);
    const textColor = Color(0xFFE6E8EE);
    const subTextColor = Color(0xFF8A93A3);
    return Drawer(
      child: Container(
        color: background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_bus, color: textColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Menu',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.settings, color: iconColor),
                title: const Text('Configurações', style: TextStyle(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  await onSettings();
                },
              ),
              if (onNotifications != null)
                ListTile(
                  leading: const Icon(Icons.notifications, color: iconColor),
                  title: const Text('Notificações', style: TextStyle(color: textColor)),
                  onTap: () async {
                    Navigator.pop(context);
                    await onNotifications!();
                  },
                ),
              if (onHistory != null)
                ListTile(
                  leading: const Icon(Icons.history, color: iconColor),
                  title: const Text('Histórico de Viagens', style: TextStyle(color: textColor)),
                  onTap: () async {
                    Navigator.pop(context);
                    await onHistory!();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: iconColor),
                title: const Text('Sair', style: TextStyle(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  await onLogout();
                },
              ),
              const Divider(height: 24, color: dividerColor),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
