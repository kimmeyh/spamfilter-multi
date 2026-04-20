import 'dart:io' show Directory, File, FileMode, Platform, exit;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/providers/rule_set_provider.dart';
import 'core/providers/email_scan_provider.dart';
import 'core/services/app_identity_migration.dart';
import 'core/services/background_mode_service.dart';
import 'core/services/background_scan_windows_worker.dart';
import 'core/services/windows_system_tray_service.dart';
import 'core/services/windows_notification_service.dart';
import 'core/services/windows_task_scheduler_service.dart';
import 'core/services/app_environment.dart';
import 'core/services/dev_environment_seeder.dart';
import 'core/services/background_scan_manager.dart' show ScanFrequency;
import 'core/storage/settings_store.dart';
import 'core/storage/unmatched_email_store.dart';
import 'core/storage/database_helper.dart';
import 'adapters/storage/app_paths.dart';
import 'adapters/storage/secure_credentials_store.dart';
import 'core/security/certificate_pinner.dart';
import 'util/redact.dart';
// import 'ui/screens/platform_selection_screen.dart'; // OLD: Direct to platform selection.
import 'ui/screens/main_navigation_screen.dart'; // NEW: Main navigation with bottom nav (Android)
import 'ui/theme/app_theme.dart';

/// Global RouteObserver for tracking navigation events
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// Global NavigatorKey for keyboard shortcuts refresh action
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
    // Use file-based logging since headless mode has no console
    // [UPDATED] Issue #218: Use path_provider for MSIX sandbox compatibility
    final appSupport = await getApplicationSupportDirectory();
    final envSuffix = AppEnvironment.dataDirSuffix;
    final logPrefix = AppEnvironment.logPrefix;
    final logDir = Directory('${appSupport.path}$envSuffix\\logs');
    await logDir.create(recursive: true);
    final logFile = File('${logDir.path}\\${logPrefix}background_scan_v0.5.2.log');
    Future<void> bgLog(String message) async {
      try {
        final timestamp = DateTime.now().toIso8601String();
        await logFile.parent.create(recursive: true);
        await logFile.writeAsString(
          '[$timestamp] $message\n',
          mode: FileMode.append,
        );
      } catch (_) {
        // Cannot log - silently continue
      }
    }

    await bgLog('=== Background scan started ===');
    await bgLog('Args: $args');
    await bgLog('Executable: ${Platform.resolvedExecutable}');

    try {
      await bgLog('Calling executeBackgroundScan...');
      final success = await BackgroundScanWindowsWorker.executeBackgroundScan();
      await bgLog('Background scan completed: ${success ? "SUCCESS" : "FAILURE"}');

      // Exit after background scan completes
      exit(success ? 0 : 1);
    } catch (e, stackTrace) {
      await bgLog('Background scan EXCEPTION: $e');
      await bgLog('Stack trace: $stackTrace');
      exit(1);
    }
  }

  // DEV ENVIRONMENT SEEDING: Copy production data to dev directory on first launch
  // Must run BEFORE AppPaths initialization (ADR-0035)
  if (Platform.isWindows && AppEnvironment.isDev) {
    await DevEnvironmentSeeder.seedIfNeeded();
  }

  // APP IDENTITY MIGRATION: Migrate data from old com.example directory to new
  // MyEmailSpamFilter directory after Sprint 19 identity change (Issue #182)
  // Must run BEFORE credential migration and rule loading
  if (Platform.isWindows) {
    try {
      final migrated = await AppIdentityMigration.migrateIfNeeded();
      if (migrated) {
        Logger().i('App identity migration completed successfully');
      }
    } catch (e) {
      Logger().w('App identity migration failed: $e');
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

  // SEC-14/SEC-19 (Sprint 33): Bootstrap DatabaseHelper early so the app can
  // read the persisted auth-logging preference and enforce unmatched email
  // retention before the UI is built. RuleSetProvider.initialize() also
  // calls setAppPaths on the same singleton; that call is idempotent.
  try {
    final appPaths = AppPaths();
    await appPaths.initialize();
    DatabaseHelper().setAppPaths(appPaths);

    final settingsStore = SettingsStore();

    // SEC-19: apply persisted auth-logging-disabled preference.
    try {
      final disabled = await settingsStore.getDisableAuthLogging();
      Redact.setAuthLoggingDisabled(disabled);
    } catch (e) {
      Logger().w('Failed to load auth logging preference: $e');
    }

    // SEC-14: run unmatched-email retention cleanup on startup.
    try {
      final retentionDays = await settingsStore.getUnmatchedRetentionDays();
      final deleted = await UnmatchedEmailStore(DatabaseHelper())
          .deleteOlderThan(retentionDays);
      if (deleted > 0) {
        Logger().i('Startup retention cleanup removed $deleted unmatched '
            'emails older than $retentionDays days');
      }
    } catch (e) {
      Logger().w('Unmatched email retention cleanup failed: $e');
    }

    // SEC-8 (Sprint 33): apply persisted certificate-pinning preference.
    try {
      final pinningEnabled =
          await settingsStore.getCertificatePinningEnabled();
      CertificatePinner.setEnabled(pinningEnabled);
    } catch (e) {
      Logger().w('Failed to load certificate pinning preference: $e');
    }
  } catch (e) {
    Logger().w('Early DatabaseHelper bootstrap failed: $e');
  }

  // Initialize Windows system tray and notifications (Windows only)
  if (Platform.isWindows) {
    final systemTrayService = WindowsSystemTrayService();
    await systemTrayService.initialize();
    Logger().i('Windows system tray initialized');

    final notificationService = WindowsNotificationService();
    await notificationService.initialize();
    Logger().i('Windows notifications initialized');

    // Only manage Task Scheduler in release mode and non-MSIX installs.
    // In debug mode: Platform.resolvedExecutable points to a temporary runner path.
    // In MSIX: The exe is in read-only WindowsApps dir; Task Scheduler cannot work.
    // [UPDATED] Issue #218: Skip Task Scheduler in MSIX context.
    if (kReleaseMode && !AppEnvironment.isMsixInstall) {
      // Verify and repair task scheduler executable path after rebuild
      try {
        final repaired = await WindowsTaskSchedulerService.verifyAndRepairTaskPath();
        if (repaired) {
          Logger().i('Task scheduler path repaired after app rebuild');
        }
      } catch (e) {
        Logger().w('Task scheduler path verification failed: $e');
      }

      // [FIX] ISSUE #161: Ensure scheduled task exists if background scanning is enabled
      // The task may be missing after reboot, system cleanup, or failed recreation
      try {
        final settingsStore = SettingsStore();
        final bgEnabled = await settingsStore.getBackgroundScanEnabled();
        if (bgEnabled) {
          final freqMinutes = await settingsStore.getBackgroundScanFrequency();
          final frequency = ScanFrequency.values.firstWhere(
            (f) => f.minutes == freqMinutes,
            orElse: () => ScanFrequency.every15min,
          );
          final recreated = await WindowsTaskSchedulerService.ensureTaskExists(
            frequency: frequency,
          );
          if (recreated) {
            Logger().i('Background scan task recreated (was missing from Task Scheduler)');
          }
        }
      } catch (e) {
        Logger().w('Background scan task verification failed: $e');
      }
    } else {
      if (AppEnvironment.isMsixInstall) {
        Logger().i('Skipping Task Scheduler management in MSIX install');
      } else {
        Logger().i('Skipping Task Scheduler management in debug mode');
      }
    }
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
          },
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _QuitIntent: _QuitAction(),
            _NewScanIntent: _NewScanAction(),
            _RefreshIntent: _RefreshAction(),
          },
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: AppEnvironment.windowTitle,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system, // Follow system theme preference
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
  const _AppInitializer();

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

    // [NEW] NEW: Once rules are loaded, show main navigation screen
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
    // Navigate to account selection screen
    // This is handled via global navigator key (not implemented yet)
    // For now, this is a no-op - keyboard nav requires global key setup
    Logger().i('Ctrl+N pressed: Navigate to account selection (not yet implemented)');
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
