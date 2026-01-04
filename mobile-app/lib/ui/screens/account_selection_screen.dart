import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../main.dart' show routeObserver;
import 'account_setup_screen.dart';
import 'platform_selection_screen.dart';
import 'scan_progress_screen.dart';

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
/// ⚠️ IMPORTANT: Credentials are platform-specific!
/// - Windows: Stored in Windows Credential Manager
/// - Android: Stored in Android Keystore  
/// - iOS: Stored in iOS Keychain
/// - Accounts must be set up separately on each device/platform
/// 
/// ✨ PHASE 2 SPRINT 3: Account persistence between app runs
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
    _logger.i('🔄 Navigated back to Account Selection - refreshing account list');
    _loadSavedAccounts();
  }

  /// Reload accounts when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logger.i('🔄 App resumed - refreshing account list');
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
      _logger.i('✅ Loaded ${accounts.length} saved accounts');
    } catch (e) {
      _logger.e('❌ Failed to load accounts: $e');
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
      // Try to retrieve full credentials (platform-aware: handles both IMAP and OAuth)
      final creds = await _credStore.getCredentialsForPlatform(accountId);

      if (creds == null) {
        _logger.w('⚠️ No credentials found for account: $accountId');
        return null;
      }

      // Email is the most reliable source of truth
      String email = creds.email;

      // If email is empty or just the platformId (old format), try to infer from storage
      if (email.isEmpty || !email.contains('@')) {
        // This is likely an old account where accountId was just the platformId
        // Try to infer email from accountId or use a placeholder
        email = accountId.contains('@') ? accountId : 'Account (email not set)';
        _logger.w('⚠️ Email not properly stored for account: $accountId, using fallback: $email');
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

      _logger.d('✅ Loaded account data: email=$email, platformId=$platformId for accountId=$accountId');

      return AccountDisplayData(
        email: email,
        platformId: platformId,
      );
    } catch (e) {
      _logger.e('❌ Error loading account display data for $accountId: $e');
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

  /// Get color for platform
  Color _getPlatformColor(String platformId) {
    switch (platformId.toLowerCase()) {
      case 'aol':
        return Colors.blue;
      case 'gmail':
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

    // Show scan mode selector dialog (same as new account setup)
    // This ensures users can choose readonly/testLimit/testAll for every scan
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ScanModeSelector(
        parentContext: context,
        platformId: platformId,
        accountId: accountId,
        accountEmail: email,
      ),
    );

    // Refresh accounts after scan completes
    _loadSavedAccounts();
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

    // Loading state
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading accounts...'),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _loadSavedAccounts();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // No saved accounts - show "Add Account" UI instead of navigating away
    // (Navigation away via pushReplacement would break the back button behavior)
    if (_savedAccounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Account'),
          elevation: 2,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mail_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Email Accounts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Add your first email account to get started.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Email Account'),
                onPressed: _addNewAccount,
              ),
            ],
          ),
        ),
      );
    }

    // Show saved accounts
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Account'),
        elevation: 2,
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

          // Add new account button (fixed at bottom)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addNewAccount,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Account'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scan mode selector dialog for quick scans from account list
/// Allows users to choose readonly/testLimit/testAll mode before scanning
class _ScanModeSelector extends StatefulWidget {
  final BuildContext parentContext;
  final String platformId;
  final String accountId;
  final String accountEmail;

  const _ScanModeSelector({
    required this.parentContext,
    required this.platformId,
    required this.accountId,
    required this.accountEmail,
  });

  @override
  State<_ScanModeSelector> createState() => _ScanModeSelectorState();
}

class _ScanModeSelectorState extends State<_ScanModeSelector> {
  late ScanMode _selectedMode;
  int _testLimit = 50;
  final _testLimitController = TextEditingController(text: '50');
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _selectedMode = ScanMode.readonly; // Safe default
  }

  @override
  void dispose() {
    _testLimitController.dispose();
    super.dispose();
  }

  Future<void> _proceedWithScan() async {
    final scanProvider = widget.parentContext.read<EmailScanProvider>();

    // Initialize scan mode
    int? testLimit;
    if (_selectedMode == ScanMode.testLimit) {
      testLimit = _testLimit;
    }

    scanProvider.initializeScanMode(
      mode: _selectedMode,
      testLimit: testLimit,
    );

    _logger.i(
      '🔍 Quick scan mode: $_selectedMode'
      '${testLimit != null ? ' (limit: $testLimit)' : ''}',
    );

    // Close dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Navigate to scan progress
    if (!mounted) return;
    final parentContext = widget.parentContext;
    
    await Navigator.of(parentContext).push(
      MaterialPageRoute(
        builder: (_) => ScanProgressScreen(
          platformId: widget.platformId,
          platformDisplayName: _getPlatformName(widget.platformId),
          accountId: widget.accountId,
          accountEmail: widget.accountEmail,
        ),
      ),
    );
  }

  String _getPlatformName(String platformId) {
    final info = PlatformRegistry.getPlatformInfo(platformId);
    return info?.displayName ?? platformId.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scan Mode'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose scan mode:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Read-only mode
            _buildModeOption(
              mode: ScanMode.readonly,
              title: 'Read-Only (Recommended)',
              description: '📋 Safe - no emails modified',
              color: Colors.green,
            ),
            const SizedBox(height: 12),

            // Test limit mode
            _buildModeOption(
              mode: ScanMode.testLimit,
              title: 'Test Limited Emails',
              description: '📝 Modify first N emails only',
              color: Colors.orange,
              showLimit: true,
            ),
            const SizedBox(height: 12),

            // Test all mode
            _buildModeOption(
              mode: ScanMode.testAll,
              title: 'Full Scan with Revert',
              description: '⚡ All changes (can revert)',
              color: Colors.red,
            ),
            const SizedBox(height: 16),

            // Help text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedMode == ScanMode.readonly
                          ? 'No emails will be modified.'
                          : _selectedMode == ScanMode.testLimit
                              ? 'Only $_testLimit emails modified.'
                              : 'Can revert using "Revert Last Run".',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _proceedWithScan,
          child: const Text('Start Scan'),
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required ScanMode mode,
    required String title,
    required String description,
    required Color color,
    bool showLimit = false,
  }) {
    final isSelected = _selectedMode == mode;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<ScanMode>(
                  value: mode,
                  groupValue: _selectedMode,
                  onChanged: (value) => setState(() => _selectedMode = mode),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showLimit && isSelected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: TextField(
                      controller: _testLimitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of emails',
                        border: OutlineInputBorder(),
                        hintText: '50',
                      ),
                      onChanged: (value) {
                        setState(() => _testLimit = int.tryParse(value) ?? 50);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
