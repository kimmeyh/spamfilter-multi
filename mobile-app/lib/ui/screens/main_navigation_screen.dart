import 'dart:io';
import 'package:flutter/material.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import 'account_selection_screen.dart';
import 'no_rule_review_screen.dart';
import '../widgets/app_bar_with_exit.dart';

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

  // Navigation destinations with accessibility labels
  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.email_outlined, semanticLabel: 'Accounts tab'),
      selectedIcon: Icon(Icons.email, semanticLabel: 'Accounts tab selected'),
      label: 'Accounts',
      tooltip: 'Manage email accounts',
    ),
    NavigationDestination(
      icon: Icon(Icons.rule_outlined, semanticLabel: 'Rules tab'),
      selectedIcon: Icon(Icons.rule, semanticLabel: 'Rules tab selected'),
      label: 'Rules',
      tooltip: 'Manage spam filtering rules',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined, semanticLabel: 'Settings tab'),
      selectedIcon: Icon(Icons.settings, semanticLabel: 'Settings tab selected'),
      label: 'Settings',
      tooltip: 'App settings',
    ),
  ];

  // Screen widgets for each tab
  final List<Widget> _screens = [
    const AccountSelectionScreen(),
    const _PlaceholderScreen(
      title: 'Rules',
      message: 'Manage rules from the Account Details screen.',
      icon: Icons.rule,
    ),
    // [UPDATED] ISSUE #123: Settings now requires accountId
    // Access from Account Details > Settings button instead
    const _PlaceholderScreen(
      title: 'Settings',
      message: 'Configure account settings from Account Details screen',
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
      // F135 (Sprint 52): on desktop, the DEFAULT screen is Review "No Rule"
      // Items when at least one account is configured -- Harold: "If one or
      // more accounts exist, the new 'default' screen will be the Review 'No
      // Rules' Items screen". With ZERO accounts there is nothing to review, so
      // Account Selection is shown instead (the plan's stated assumption, not
      // separately overridden at approval).
      //
      // Resolved asynchronously because the account list lives in the secure
      // credential store. While it resolves we show the same neutral spinner
      // the app already uses during rule loading, rather than flashing Account
      // Selection and then replacing it.
      return const _DesktopDefaultScreen();
    }
  }
}

/// Picks the desktop default screen based on whether any account exists
/// (F135, Sprint 52 retro IMP-3).
///
/// Deliberately a separate widget rather than a `FutureBuilder` inline in
/// [MainNavigationScreen.build]: that build method runs on every rebuild, and
/// re-reading the credential store each time would both cost IO and risk
/// flipping the user off their current screen mid-session.
class _DesktopDefaultScreen extends StatefulWidget {
  const _DesktopDefaultScreen();

  @override
  State<_DesktopDefaultScreen> createState() => _DesktopDefaultScreenState();
}

class _DesktopDefaultScreenState extends State<_DesktopDefaultScreen> {
  /// null = still resolving; true = at least one account exists.
  bool? _hasAccounts;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    bool hasAccounts = false;
    try {
      final accounts = await SecureCredentialsStore().getSavedAccounts();
      hasAccounts = accounts.isNotEmpty;
    } catch (_) {
      // Credential-store failure -> fall back to Account Selection. That screen
      // surfaces the error state per-account and offers delete/re-add, which is
      // exactly what a user with a broken store needs to see. Defaulting to the
      // No-Rule screen here would show an empty list with no way to fix it.
      hasAccounts = false;
    }
    if (mounted) setState(() => _hasAccounts = hasAccounts);
  }

  @override
  Widget build(BuildContext context) {
    final hasAccounts = _hasAccounts;
    if (hasAccounts == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return hasAccounts
        ? const NoRuleReviewScreen()
        : const AccountSelectionScreen();
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
      appBar: AppBarWithExit(
        title: Text(title),
      ),
      body: SelectionArea(
        child: Center(
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
      ),
    );
  }
}
