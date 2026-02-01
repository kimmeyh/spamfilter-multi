import 'dart:io' show Platform, exit;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/providers/rule_set_provider.dart';
import 'core/providers/email_scan_provider.dart';
import 'core/services/background_mode_service.dart';
import 'core/services/background_scan_windows_worker.dart';
import 'core/services/windows_system_tray_service.dart';
import 'core/services/windows_notification_service.dart';
import 'adapters/storage/secure_credentials_store.dart';
// import 'ui/screens/platform_selection_screen.dart'; // OLD: Direct to platform selection.
import 'ui/screens/main_navigation_screen.dart'; // NEW: Main navigation with bottom nav (Android)
import 'ui/theme/app_theme.dart';

/// Global RouteObserver for tracking navigation events
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// Global navigator key for keyboard shortcuts and programmatic navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite FFI for desktop platforms (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    Logger().i('Initialized sqflite FFI for desktop platform');
  }

  // Detect background mode from command-line arguments
  BackgroundModeService.initialize(args);

  // If running in background mode (launched by Task Scheduler), execute scan and exit
  if (BackgroundModeService.isBackgroundMode) {
    Logger().i('Running in BACKGROUND MODE - executing background scan');

    try {
      final success = await BackgroundScanWindowsWorker.executeBackgroundScan();
      Logger().i('Background scan completed: ${success ? "SUCCESS" : "FAILURE"}');

      // Exit after background scan completes
      exit(success ? 0 : 1);
    } catch (e) {
      Logger().e('Background scan failed with exception', error: e);
      exit(1);
    }
  }

  // UNIFIED STORAGE FIX: Migrate legacy token storage to unified storage (one-time migration)
  // This ensures users with old SecureTokenStore accounts are migrated to SecureCredentialsStore
  try {
    final credStore = SecureCredentialsStore();
    await credStore.migrateFromLegacyTokenStore();
  } catch (e) {
    // Migration failure should not block app startup
    Logger().w('Legacy token migration failed: $e');
  }

  // Initialize Windows system tray and notifications (Windows only)
  if (Platform.isWindows) {
    final systemTrayService = WindowsSystemTrayService();
    await systemTrayService.initialize();
    Logger().i('Windows system tray initialized');

    final notificationService = WindowsNotificationService();
    await notificationService.initialize();
    Logger().i('Windows notifications initialized');
  }

  runApp(const SpamFilterApp());
}

class SpamFilterApp extends StatelessWidget {
  const SpamFilterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize providers with multi-provider setup
    return MultiProvider(
      providers: [
        // Rule set provider for managing rules and safe senders
        ChangeNotifierProvider(
          create: (_) => RuleSetProvider(),
        ),
        // Email scan provider for managing scan progress and results
        ChangeNotifierProvider(
          create: (_) => EmailScanProvider(),
        ),
      ],
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          // Desktop keyboard shortcuts (Windows/Linux/macOS)
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...{
            // Ctrl+Q: Quit application
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyQ):
                const _QuitIntent(),
            // Ctrl+N: New scan (navigate to account selection)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
                const _NewScanIntent(),
            // Ctrl+R: Refresh current screen
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
                const _RefreshIntent(),
            // F5: Refresh (alternative)
            LogicalKeySet(LogicalKeyboardKey.f5):
                const _RefreshIntent(),
            // F1: Show keyboard shortcuts help
            LogicalKeySet(LogicalKeyboardKey.f1):
                const _ShowHelpIntent(),
          },
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _QuitIntent: _QuitAction(),
            _NewScanIntent: _NewScanAction(),
            _RefreshIntent: _RefreshAction(),
            _ShowHelpIntent: _ShowHelpAction(),
          },
          child: MaterialApp(
            title: 'Spam Filter Mobile',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system, // Follow system theme preference
            navigatorKey: navigatorKey, // Global navigator key for keyboard shortcuts
            // Track navigation events for account list refresh
            navigatorObservers: [routeObserver],
            // Initialize rules after providers are created
            home: const _AppInitializer(),
          ),
        ),
      ),
    );
  }
}

/// Widget to initialize rule provider before showing UI
class _AppInitializer extends StatefulWidget {
  const _AppInitializer({super.key});

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  @override
  void initState() {
    super.initState();
    // Initialize the rule set provider
    Future.microtask(() async {
      if (mounted) {
        final ruleProvider = context.read<RuleSetProvider>();
        await ruleProvider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    final ruleProvider = context.watch<RuleSetProvider>();
    
    if (ruleProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading spam filter rules...'),
            ],
          ),
        ),
      );
    }

    if (ruleProvider.isError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Error: ${ruleProvider.error}'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final provider = context.read<RuleSetProvider>();
                  provider.initialize();
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // ✨ NEW: Once rules are loaded, show main navigation screen
    // On Android: Shows bottom navigation with Accounts/Rules/Settings tabs
    // On other platforms: Shows account selection screen directly
    return const MainNavigationScreen();
  }
}

/// Intent for quitting the application (desktop platforms only)
class _QuitIntent extends Intent {
  const _QuitIntent();
}

/// Action for quitting the application
class _QuitAction extends Action<_QuitIntent> {
  @override
  Object? invoke(_QuitIntent intent) {
    // Exit the application gracefully
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      SystemNavigator.pop();
    }
    return null;
  }
}

/// Intent for starting a new scan (Ctrl+N)
class _NewScanIntent extends Intent {
  const _NewScanIntent();
}

/// Action for starting a new scan - navigates to account selection
class _NewScanAction extends Action<_NewScanIntent> {
  @override
  Object? invoke(_NewScanIntent intent) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      Logger().w('Ctrl+N: Navigator context not available');
      return null;
    }

    // Navigate to account selection screen (popping to root first)
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );

    Logger().i('Ctrl+N: Navigated to account selection');
    return null;
  }
}

/// Intent for refreshing current screen (Ctrl+R or F5)
class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

/// Action for refreshing current screen
class _RefreshAction extends Action<_RefreshIntent> {
  @override
  Object? invoke(_RefreshIntent intent) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      Logger().w('Ctrl+R/F5: Navigator context not available');
      return null;
    }

    // Trigger a rebuild of the current route by popping and re-pushing
    // This is a simple refresh mechanism - each screen should implement
    // its own refresh logic if needed
    final currentRoute = ModalRoute.of(context);
    if (currentRoute != null) {
      // Simple approach: Pop and immediately push back
      // Screens with refresh logic can listen to didPopNext
      navigatorKey.currentState?.popAndPushNamed(currentRoute.settings.name ?? '/');
      Logger().i('Ctrl+R/F5: Refreshed current screen');

      // Show visual feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 8),
              Text('Screen refreshed'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return null;
  }
}
/// Intent for showing keyboard shortcuts help
class _ShowHelpIntent extends Intent {
  const _ShowHelpIntent();
}

/// Action for showing keyboard shortcuts help dialog
class _ShowHelpAction extends Action<_ShowHelpIntent> {
  @override
  Object? invoke(_ShowHelpIntent intent) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      Logger().w('F1: Navigator context not available');
      return null;
    }

    showDialog(
      context: context,
      builder: (context) => const KeyboardShortcutsHelpDialog(),
    );

    Logger().i('F1: Showed keyboard shortcuts help');
    return null;
  }
}

/// Dialog showing all available keyboard shortcuts
class KeyboardShortcutsHelpDialog extends StatelessWidget {
  const KeyboardShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.keyboard,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShortcutRow(
              context,
              'Ctrl+N',
              'Start new scan (return to account selection)',
            ),
            const SizedBox(height: 12),
            _buildShortcutRow(
              context,
              'Ctrl+R or F5',
              'Refresh current screen',
            ),
            const SizedBox(height: 12),
            _buildShortcutRow(
              context,
              'Ctrl+Q',
              'Quit application',
            ),
            const SizedBox(height: 12),
            _buildShortcutRow(
              context,
              'F1',
              'Show this help dialog',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildShortcutRow(BuildContext context, String keys, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            keys,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
