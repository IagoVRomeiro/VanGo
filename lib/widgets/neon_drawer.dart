import 'package:flutter/material.dart';

typedef DrawerAction = Future<void> Function();

class NeonDrawerItem {
  final IconData icon;
  final String label;
  final DrawerAction onTap;

  const NeonDrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class NeonDrawer extends StatelessWidget {
  final List<NeonDrawerItem> items;
  final DrawerAction onSettings;
  final DrawerAction onLogout;
  final String title;

  const NeonDrawer({
    super.key,
    required this.items,
    required this.onSettings,
    required this.onLogout,
    this.title = 'Menu',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuItems = items;

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
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: menuItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return ListTile(
                      leading: Icon(item.icon, color: theme.colorScheme.primary),
                      title: Text(item.label),
                      onTap: () async {
                        Navigator.pop(context);
                        await item.onTap();
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configurações'),
                onTap: () async {
                  Navigator.pop(context);
                  await onSettings();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Sair'),
                onTap: () async {
                  Navigator.pop(context);
                  await onLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
