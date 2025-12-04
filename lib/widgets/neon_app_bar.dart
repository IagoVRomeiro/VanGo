import 'package:flutter/material.dart';

class NeonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showMenuButton;
  final bool showBackButton;
  final bool showNotificationsButton;
  final Widget? notificationAction;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationsPressed;

  const NeonAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showMenuButton = true,
    this.showBackButton = false,
    this.showNotificationsButton = true,
    this.notificationAction,
    this.onMenuPressed,
    this.onNotificationsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 72,
      iconTheme: IconThemeData(color: titleColor),
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
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
                        if (scaffoldState != null && scaffoldState.hasDrawer) {
                          scaffoldState.openDrawer();
                        } else if (scaffoldState != null && scaffoldState.hasEndDrawer) {
                          scaffoldState.openEndDrawer();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                    );
                  },
                )
              : null,
      actions: showNotificationsButton
          ? [
              notificationAction ??
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
              theme.colorScheme.surface.withValues(alpha: 0.95),
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
              color: titleColor,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: subtitleColor),
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
