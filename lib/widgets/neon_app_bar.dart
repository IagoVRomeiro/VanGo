import 'package:flutter/material.dart';

class NeonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showMenuButton;
  final bool showBackButton;
  final bool showNotificationsButton;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationsPressed;

  const NeonAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showMenuButton = true,
    this.showBackButton = false,
    this.showNotificationsButton = true,
    this.onMenuPressed,
    this.onNotificationsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 72,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            )
          : showMenuButton
              ? Builder(
                  builder: (context) {
                    return IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        if (onMenuPressed != null) {
                          onMenuPressed!();
                          return;
                        }
                        final scaffoldState = Scaffold.maybeOf(context);
                        if (scaffoldState != null &&
                            (scaffoldState.hasDrawer || scaffoldState.hasEndDrawer)) {
                          scaffoldState.openDrawer();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                )
              : null,
      actions: showNotificationsButton
          ? [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  onNotificationsPressed?.call();
                },
              ),
            ]
          : null,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface.withOpacity(0.95),
              theme.scaffoldBackgroundColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
