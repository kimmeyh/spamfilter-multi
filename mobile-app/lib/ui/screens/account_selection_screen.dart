import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart';
import '../../main.dart' show routeObserver;
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_display.dart';
import '../widgets/app_bar_with_exit.dart';
import 'platform_selection_screen.dart';
import 'scan_progress_screen.dart';
import 'settings_screen.dart';

/// Display data for an account in the account selection list.
class AccountDisplayData {
  final String email;
  final String platformId;

  AccountDisplayData({
    required this.email,
    required this.platformId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountDisplayData &&
          runtimeType == other.runtimeType &&
          email == other.email &&
          platformId == other.platformId;

  @override
  int get hashCode => email.hashCode ^ platformId.hashCode;
}

/// Screen to select existing account or add new one
/// 
/// This screen provides:
/// - List of saved email accounts with platform icons
/// - Account selection to proceed to scanning
/// - Account deletion with confirmation
/// - "Add New Account" button for setting up additional accounts
/// - Auto-navigation to platform selection if no accounts exist
/// 
/// [WARNING] IMPORTANT: Credentials are platform-specific!
/// - Windows: Stored in Windows Credential Manager
/// - Android: Stored in Android Keystore  
/// - iOS: Stored in iOS Keychain
/// - Accounts must be set up separately on each device/platform
/// 
/// [NEW] PHASE 2 SPRINT 3: Account persistence between app runs
class AccountSelectionScreen extends StatefulWidget {
  const AccountSelectionScreen({super.key});

  @override
  State<AccountSelectionScreen> createState() => _AccountSelectionScreenState();
}

class _AccountSelectionScreenState extends State<AccountSelectionScreen> with WidgetsBindingObserver, RouteAware {
  final _credStore = SecureCredentialsStore();
  final _logger = Logger();
  List<String> _savedAccounts = [];
  bool _isLoading = true;
  String? _error;
  DateTime _lastReloadTime = DateTime.now().subtract(const Duration(seconds: 5));

  // Cache for account display data to prevent flicker on rebuild
  final Map<String, AccountDisplayData?> _accountDataCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedAccounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events to detect when we navigate back to this screen
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route as ModalRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when another screen is popped and we become visible again
  @override
  void didPopNext() {
    _logger.i('[PENDING] Navigated back to Account Selection - refreshing account list');
    _loadSavedAccounts();
  }

  /// Reload accounts when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logger.i('[PENDING] App resumed - refreshing account list');
      _loadSavedAccounts();
    }
  }

  /// Load saved accounts from secure storage
  Future<void> _loadSavedAccounts() async {
    try {
      // Small delay to ensure credentials are fully synced in storage
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      final accounts = await _credStore.getSavedAccounts();
      
      if (!mounted) return;
      
      setState(() {
        _savedAccounts = accounts;
        _isLoading = false;
        _error = null; // Clear any previous errors
      });
      _logger.i('[OK] Loaded ${accounts.length} saved accounts');
    } catch (e) {
      _logger.e('[FAIL] Failed to load accounts: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load accounts: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Get account details from storage
  /// 
  /// accountId is the email address
  /// platformId is retrieved separately from storage
  Future<Map<String, String>> _getAccountDetails(String accountId) async {
    final platformId = await _credStore.getPlatformId(accountId);
    return {
      'email': accountId, // accountId is the email
      'platformId': platformId ?? 'unknown',
    };
  }

  /// Load account display data with caching to prevent flicker
  ///
  /// Returns cached data immediately if available, then refreshes in background.
  /// For new accounts, fetches data and caches it.
  Future<AccountDisplayData?> _loadAccountDisplayData(String accountId) async {
    // Return cached data if available
    if (_accountDataCache.containsKey(accountId)) {
      // Refresh in background but return cached immediately
      _refreshAccountDataInBackground(accountId);
      return _accountDataCache[accountId];
    }

    // Initial load - fetch and cache
    final data = await _fetchAccountDisplayData(accountId);
    _accountDataCache[accountId] = data;
    return data;
  }

  /// Refresh account data in background (non-blocking)
  ///
  /// Updates cache if data has changed, triggering a rebuild.
  void _refreshAccountDataInBackground(String accountId) async {
    final data = await _fetchAccountDisplayData(accountId);

    // Only update if mounted and data has actually changed
    if (mounted && data != _accountDataCache[accountId]) {
      setState(() {
        _accountDataCache[accountId] = data;
      });
    }
  }

  /// Fetch account display data from secure storage (no caching)
  ///
  /// Retrieves the actual email address and platform from credentials storage.
  /// This handles both old format accounts (accountId = platformId) and new format
  /// accounts (accountId = email).
  Future<AccountDisplayData?> _fetchAccountDisplayData(String accountId) async {
    try {
      // Try to retrieve full credentials which includes the email address
      final creds = await _credStore.getCredentials(accountId);

      if (creds == null) {
        _logger.w('[WARNING] No credentials found for account: $accountId');
        return null;
      }

      // Email is the most reliable source of truth
      String email = creds.email;

      // If email is empty or just the platformId (old format), try to infer from storage
      if (email.isEmpty || !email.contains('@')) {
        // This is likely an old account where accountId was just the platformId
        // Try to infer email from accountId or use a placeholder
        email = accountId.contains('@') ? accountId : 'Account (email not set)';
        _logger.w('[WARNING] Email not properly stored for account: $accountId, using fallback: $email');
      }

      // Get platformId from storage or infer from email domain
      String platformId = await _credStore.getPlatformId(accountId) ?? 'unknown';

      // If platformId is still unknown, try to infer from email domain
      if (platformId == 'unknown' && email.contains('@')) {
        if (email.contains('@gmail.com')) {
          platformId = 'gmail';
        } else if (email.contains('@aol.com')) {
          platformId = 'aol';
        } else if (email.contains('@yahoo.com')) {
          platformId = 'yahoo';
        } else if (email.contains('@outlook.com') || email.contains('@hotmail.com')) {
          platformId = 'outlook';
        } else if (email.contains('@icloud.com')) {
          platformId = 'icloud';
        }
      }

      // Last resort: if platformId still unknown, try to parse from accountId
      if (platformId == 'unknown' && !accountId.contains('@')) {
        // accountId might be just the platformId (old format)
        platformId = accountId;
      }

      _logger.d('[OK] Loaded account data: email=$email, platformId=$platformId for accountId=$accountId');

      return AccountDisplayData(
        email: email,
        platformId: platformId,
      );
    } catch (e) {
      _logger.e('[FAIL] Error loading account display data for $accountId: $e');
      // Return null instead of throwing to prevent FutureBuilder from crashing
      return null;
    }
  }

  /// Get platform display name from platformId
  String _getPlatformName(String platformId) {
    // Try to get from registry first
    final platform = PlatformRegistry.getPlatform(platformId);
    if (platform != null) {
      return platform.displayName;
    }
    
    // Fallback to friendly names for common platforms
    return switch (platformId.toLowerCase()) {
      'gmail' => 'Gmail',
      'aol' => 'AOL Mail',
      'yahoo' => 'Yahoo Mail',
      'outlook' => 'Outlook.com',
      'icloud' => 'iCloud Mail',
      'unknown' => 'Unknown Provider',
      _ => platformId,
    };
  }

  /// Get icon for platform
  IconData _getPlatformIcon(String platformId) {
    switch (platformId.toLowerCase()) {
      case 'aol':
        return Icons.email;
      case 'gmail':
      case 'gmail-imap':
        return Icons.mail;
      case 'outlook':
        return Icons.email_outlined;
      case 'yahoo':
        return Icons.alternate_email;
      case 'icloud':
        return Icons.cloud;
      default:
        return Icons.email;
    }
  }

  /// Get display name for platform
  String _getPlatformDisplayName(String platformId) {
    switch (platformId.toLowerCase()) {
      case 'aol':
        return 'AOL Mail';
      case 'gmail':
        return 'Gmail';
      case 'gmail-imap':
        return 'Gmail (IMAP)';
      case 'outlook':
        return 'Outlook.com';
      case 'yahoo':
        return 'Yahoo Mail';
      case 'icloud':
        return 'iCloud Mail';
      default:
        return platformId.toUpperCase();
    }
  }

  /// Get color for platform
  Color _getPlatformColor(String platformId) {
    switch (platformId.toLowerCase()) {
      case 'aol':
        return Colors.blue;
      case 'gmail':
      case 'gmail-imap':
        return Colors.red;
      case 'outlook':
        return Colors.lightBlue;
      case 'yahoo':
        return Colors.purple;
      case 'icloud':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  /// Get auth method display name for platform
  String _getAuthMethodDisplay(String platformId) {
    try {
      final platform = PlatformRegistry.getPlatform(platformId);
      if (platform != null) {
        final authMethod = platform.supportedAuthMethod;
        return switch (authMethod) {
          AuthMethod.none => 'None (Demo)',
          AuthMethod.oauth2 => 'OAuth 2.0',
          AuthMethod.appPassword => 'App Password',
          AuthMethod.basicAuth => 'Basic Auth',
          AuthMethod.apiKey => 'API Key',
        };
      }
    } catch (e) {
      _logger.w('Could not determine auth method for $platformId: $e');
    }
    
    // Fallback based on platform type if registry lookup fails
    return switch (platformId.toLowerCase()) {
      'gmail' => 'OAuth 2.0',
      'gmail-imap' => 'App Password',
      'outlook' => 'OAuth 2.0',
      'aol' => 'App Password',
      'yahoo' => 'App Password',
      'icloud' => 'App Password',
      _ => 'IMAP',
    };
  }

  /// Select account and navigate to scan progress
  Future<void> _selectAccount(String accountId) async {
    final email = accountId; // accountId is the email
    String platformId = await _credStore.getPlatformId(accountId) ?? '';
    
    // If platformId is not found, try to infer from email domain
    if (platformId.isEmpty) {
      _logger.w('Platform ID not found for $accountId, attempting to infer from email');
      
      if (email.contains('@gmail.com')) {
        platformId = 'gmail';
      } else if (email.contains('@aol.com')) {
        platformId = 'aol';
      } else if (email.contains('@yahoo.com')) {
        platformId = 'yahoo';
      } else if (email.contains('@outlook.com') || email.contains('@hotmail.com')) {
        platformId = 'outlook';
      } else if (email.contains('@icloud.com')) {
        platformId = 'icloud';
      } else {
        platformId = 'unknown';
      }
      
      _logger.i('Inferred platform: $platformId from email: $email');
    }

    _logger.i('Selected account: $accountId (platform: $platformId)');

    if (!mounted) return;

    // Navigate to scan progress with existing account
    // Using push (not pushReplacement) so back button returns here
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanProgressScreen(
          platformId: platformId,
          platformDisplayName: _getPlatformName(platformId),
          accountId: accountId,
          accountEmail: email,
        ),
      ),
    ).then((_) => _loadSavedAccounts()); // Refresh accounts on return
  }

  /// Navigate to platform selection to add new account
  void _addNewAccount() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PlatformSelectionScreen(),
      ),
    ).then((added) {
      if (added == true) {
        _logger.i('Account added, reloading account list...');
        _loadSavedAccounts();
      }
    }).catchError((e) {
      _logger.e('Error during account addition: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding account: $e')),
        );
      }
    });
  }

  /// Navigate to settings screen
  /// [UPDATED] ISSUE #123: Settings requires accountId, show account selector dialog
  void _openSettings() async {
    if (_savedAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an email account first')),
      );
      return;
    }

    // Show account selection dialog
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _savedAccounts.map((accountId) {
            // Extract platform and email from accountId (format: "platform-email")
            final parts = accountId.split('-');
            final platformId = parts[0];
            final email = parts.sublist(1).join('-');
            
            return ListTile(
              leading: Icon(_getPlatformIcon(platformId)),
              title: Text(email),
              subtitle: Text(_getPlatformDisplayName(platformId)),
              onTap: () => Navigator.pop(ctx, accountId),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(accountId: selected),
        ),
      );
    }
  }

  /// Build settings icon button for AppBar
  Widget _buildSettingsButton() {
    return IconButton(
      icon: const Icon(Icons.settings),
      tooltip: 'Settings',
      onPressed: _openSettings,
    );
  }

  /// Delete account with confirmation dialog
  Future<void> _deleteAccount(String accountId) async {
    final email = accountId; // accountId is the email

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete this account?\n\n'
          '$email\n\n'
          'This will remove saved credentials. You can re-add the account later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _credStore.deleteCredentials(accountId);
        setState(() {
          _savedAccounts.remove(accountId);
          // Remove from cache
          _accountDataCache.remove(accountId);
        });
        _logger.i('Deleted account: $accountId');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted $email')),
          );
        }

        // No need to navigate anywhere - the build method will show
        // the "Add Account" UI when _savedAccounts.isEmpty (lines 505-547)
      } catch (e) {
        _logger.e('Failed to delete account: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Schedule a refresh of accounts every 2 seconds to pick up newly added accounts
    // This handles the case where user adds an account, navigates away, and comes back
    final now = DateTime.now();
    if (now.difference(_lastReloadTime).inSeconds >= 2 && !_isLoading && mounted) {
      _lastReloadTime = now;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadSavedAccounts();
        }
      });
    }

    // Loading state with skeleton loaders
    if (_isLoading) {
      return Scaffold(
        appBar: AppBarWithExit(
          title: const Text('Select Account'),
          actions: [_buildSettingsButton()],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: 3, // Show 3 skeleton cards
            itemBuilder: (context, index) => const AccountCardSkeleton(),
          ),
        ),
      );
    }

    // Error state with recovery action
    if (_error != null) {
      return Scaffold(
        appBar: AppBarWithExit(title: const Text('Error')),
        body: GenericErrorDisplay(
          errorMessage: _error!,
          onRetry: () {
            setState(() {
              _error = null;
              _isLoading = true;
            });
            _loadSavedAccounts();
          },
        ),
      );
    }

    // No saved accounts - show empty state
    if (_savedAccounts.isEmpty) {
      return Scaffold(
        appBar: AppBarWithExit(
          title: const Text('Select Account'),
          elevation: 2,
          actions: [_buildSettingsButton()],
        ),
        body: NoAccountsEmptyState(onAddAccount: _addNewAccount),
      );
    }

    // Show saved accounts
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Select Account'),
        elevation: 2,
        actions: [_buildSettingsButton()],
      ),
      body: Column(
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Accounts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select an account to scan for spam',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),

          // Saved accounts list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedAccounts.length,
              itemBuilder: (context, index) {
                final accountId = _savedAccounts[index];
                
                // Load credentials which includes the actual email address
                return FutureBuilder<AccountDisplayData?>(
                  future: _loadAccountDisplayData(accountId),
                  builder: (context, snapshot) {
                    // Handle errors
                    if (snapshot.hasError) {
                      _logger.e('Error loading account $accountId: ${snapshot.error}');
                    }

                    final displayData = snapshot.data;
                    if (displayData == null) {
                      // Fallback if data couldn't be loaded - show delete option
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        color: Colors.red[50],
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.withValues(alpha: 0.2),
                            child: const Icon(Icons.error_outline, color: Colors.red),
                          ),
                          title: Text(
                            accountId,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Error: Missing credentials\nTap delete to remove',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteAccount(accountId),
                            tooltip: 'Delete account',
                            color: Colors.red[700],
                          ),
                        ),
                      );
                    }

                    final platformName = _getPlatformName(displayData.platformId);
                    final platformIcon = _getPlatformIcon(displayData.platformId);
                    final platformColor = _getPlatformColor(displayData.platformId);
                    final authMethod = _getAuthMethodDisplay(displayData.platformId);

                    _logger.d(
                      'Account: $accountId, Email: ${displayData.email}, Platform: ${displayData.platformId}, Auth: $authMethod',
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: platformColor.withValues(alpha: 0.2),
                          child: Icon(platformIcon, color: platformColor),
                        ),
                        // Display: email - provider - auth method
                        title: Text(
                          '${displayData.email} - $platformName - $authMethod',
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            accountId,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow, color: Colors.green),
                              onPressed: () => _selectAccount(accountId),
                              tooltip: 'Start Scan',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteAccount(accountId),
                              tooltip: 'Delete account',
                              color: Colors.red[300],
                            ),
                          ],
                        ),
                        onTap: () => _selectAccount(accountId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewAccount,
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
        tooltip: 'Add New Account',
      ),
    );
  }
}
