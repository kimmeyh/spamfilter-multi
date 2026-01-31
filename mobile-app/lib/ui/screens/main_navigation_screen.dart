import 'dart:io';
import 'package:flutter/material.dart';
import 'account_selection_screen.dart';

/// Main navigation screen with bottom navigation bar (Android only)
///
/// Provides bottom navigation for primary app sections:
/// - Accounts: Account selection and management
/// - Rules: Rule management (placeholder for F3)
/// - Settings: App settings (placeholder for F2)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Navigation destinations
  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.email_outlined),
      selectedIcon: Icon(Icons.email),
      label: 'Accounts',
    ),
    NavigationDestination(
      icon: Icon(Icons.rule_outlined),
      selectedIcon: Icon(Icons.rule),
      label: 'Rules',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  // Screen widgets for each tab
  final List<Widget> _screens = [
    const AccountSelectionScreen(),
    const _PlaceholderScreen(
      title: 'Rules',
      message: 'Rule management coming in Sprint 12-13 (F3)',
      icon: Icons.rule,
    ),
    const _PlaceholderScreen(
      title: 'Settings',
      message: 'App settings coming in Sprint 12-13 (F2)',
      icon: Icons.settings,
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only use bottom navigation on Android
    // Windows/Desktop will use traditional navigation
    if (Platform.isAndroid) {
      return Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: _destinations,
        ),
      );
    } else {
      // On non-Android platforms, just show the account selection screen
      return const AccountSelectionScreen();
    }
  }
}

/// Placeholder screen for future features
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _PlaceholderScreen({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
