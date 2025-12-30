import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/rule_set_provider.dart';
import 'core/providers/email_scan_provider.dart';
import 'adapters/storage/secure_credentials_store.dart';
// import 'ui/screens/platform_selection_screen.dart'; // OLD: Direct to platform selection
import 'ui/screens/account_selection_screen.dart'; // NEW: Check for saved accounts first

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // UNIFIED STORAGE FIX: Migrate legacy token storage to unified storage (one-time migration)
  // This ensures users with old SecureTokenStore accounts are migrated to SecureCredentialsStore
  try {
    final credStore = SecureCredentialsStore();
    await credStore.migrateFromLegacyTokenStore();
  } catch (e) {
    // Migration failure shouldn't block app startup
    print('Legacy token migration failed: $e');
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
      child: MaterialApp(
        title: 'Spam Filter Mobile',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        // Initialize rules after providers are created
        home: const _AppInitializer(),
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
