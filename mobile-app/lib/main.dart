import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/providers/rule_set_provider.dart';
import 'core/providers/email_scan_provider.dart';
import 'core/services/background_mode_service.dart';
import 'core/services/background_scan_windows_worker.dart';
import 'adapters/storage/secure_credentials_store.dart';
// import 'ui/screens/platform_selection_screen.dart'; // OLD: Direct to platform selection.
import 'ui/screens/account_selection_screen.dart'; // NEW: Check for saved accounts first

/// Global RouteObserver for tracking navigation events
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
          // Ctrl+Q to quit (desktop platforms)
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyQ):
                const _QuitIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _QuitIntent: _QuitAction(),
          },
          child: MaterialApp(
            title: 'Spam Filter Mobile',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
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

    // ✨ NEW: Once rules are loaded, show account selection screen
    // This checks for saved accounts and shows them, or navigates to platform selection if none
    return const AccountSelectionScreen();
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
