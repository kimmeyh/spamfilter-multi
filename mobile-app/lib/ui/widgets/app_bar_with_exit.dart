import 'dart:io';
import 'package:flutter/material.dart';

/// Custom AppBar with optional Exit button for Windows Desktop
///
/// Issue: Windows 11 X button and window controls not working
/// Solution: Add Exit button to AppBar on Windows platform
class AppBarWithExit extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final IconThemeData? iconTheme;
  final double? elevation;

  const AppBarWithExit({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.backgroundColor,
    this.iconTheme,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    // Combine user-provided actions with Exit button (Windows only)
    final List<Widget> allActions = [
      ...(actions ?? []),
      if (Platform.isWindows)
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Exit Application',
          onPressed: () => _exitApplication(context),
        ),
    ];

    return AppBar(
      title: title,
      actions: allActions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      backgroundColor: backgroundColor,
      iconTheme: iconTheme,
      elevation: elevation,
    );
  }

  /// Exit application with confirmation dialog
  Future<void> _exitApplication(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Application?'),
        content: const Text('Are you sure you want to exit the application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      exit(0);
    }
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );
}
