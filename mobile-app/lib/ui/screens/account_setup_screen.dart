import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../../adapters/email_providers/email_provider.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/storage/settings_store.dart';
import 'scan_progress_screen.dart';
import 'gmail_oauth_screen.dart';

/// Account setup screen for MVP
class AccountSetupScreen extends StatefulWidget {
  /// Email platform ID (e.g., 'aol', 'gmail', 'outlook')
  final String platformId;
  
  /// Human-readable platform name for display
  final String platformDisplayName;

  const AccountSetupScreen({
    super.key,
    required this.platformId,
    required this.platformDisplayName,
  });

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _logger = Logger();
  bool _isLoading = false;
  bool _isTesting = false;
  String? _connectionStatus;
  final SecureCredentialsStore _credStore = SecureCredentialsStore();
  late final bool _isGmail;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isGmail = widget.platformId.toLowerCase() == 'gmail';
    if (_isGmail) {
      // Pre-fill the email field if the user is signed in later; keep blank for now.
      _connectionStatus = 'Tap a button below to sign in with Google OAuth 2.0';
    }
  }

  /// Test IMAP connection with provided credentials
  Future<void> _testConnection() async {
    if (_isGmail) {
      await _startGmailOAuth();
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and app password are required.')),
        );
      }
      return;
    }

    setState(() {
      _isTesting = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      // Get platform adapter
      final platform = PlatformRegistry.getPlatform(widget.platformId);
      if (platform == null) {
        throw Exception('Platform ${widget.platformId} not supported');
      }

      // Load credentials
      final credentials = Credentials(email: email, password: password);
      await platform.loadCredentials(credentials);

      // Test connection
      final status = await platform.testConnection();
      
      setState(() {
        _isTesting = false;
        _connectionStatus = status.isConnected
            ? '[OK] Connection successful!'
            : '[FAIL] Connection failed: ${status.errorMessage ?? 'Unknown error'}';
      });

      if (status.isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('[OK] Connection test successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Disconnect after test
      await platform.disconnect();
    } catch (e) {
      setState(() {
        _isTesting = false;
        _connectionStatus = '[FAIL] Connection failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection test failed: $e')),
        );
      }
    }
  }

  /// Save credentials and proceed to scan screen
  /// 
  /// Multi-account support: Creates unique accountId combining platformId + email
  /// Example: "aol-a@aol.com" allows multiple AOL accounts like "aol-b@aol.com"
  /// 
  /// [NEW] PHASE 2 SPRINT 4: Gmail OAuth handled separately via GmailOAuthScreen
  Future<void> _handleConnect() async {
    setState(() => _isLoading = true);
    
    // [NEW] Gmail uses OAuth flow - redirect to Gmail OAuth screen
    if (_isGmail) {
      setState(() => _isLoading = false);
      await _startGmailOAuth();
      return;
    }

    // Standard IMAP credentials flow for AOL, Yahoo, iCloud, etc.
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and app password are required.')),
        );
      }
      return;
    }

    // [NEW] MULTI-ACCOUNT SUPPORT: Use email as primary key
    // Store platformId separately to keep fields independent
    // Email is unique identifier, platformId is stored as metadata
    final accountId = email; // Use email as the account identifier

    // Save credentials securely with email as accountId and platformId as separate field
    try {
      await _credStore.saveCredentials(
        accountId,
        Credentials(email: email, password: password),
        platformId: widget.platformId,
      );
      
      _logger.i('[OK] Saved credentials for account: $accountId');
    } catch (e) {
      setState(() => _isLoading = false);
      _logger.e('Failed to save credentials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save credentials: $e')),
        );
      }
      return;
    }
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('[OK] Account $email saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // [NEW] PHASE 3.1: Navigate directly to ScanProgressScreen
      // [UPDATED] ISSUE #123: Scan mode from Settings (single source of truth)
      final scanProvider = context.read<EmailScanProvider>();
      final settingsStore = SettingsStore();
      final manualScanMode = await settingsStore.getManualScanMode();
      scanProvider.initializeScanMode(mode: manualScanMode);
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ScanProgressScreen(
            platformId: widget.platformId,
            platformDisplayName: widget.platformDisplayName,
            accountId: accountId,
            accountEmail: email,
          ),
        ),
      ).then((_) {
        // After scan screen is popped, pop account setup to return to account selection
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    }
  }

  Future<void> _startGmailOAuth() async {
    if (!mounted) return;

    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => GmailOAuthScreen(
          platformId: widget.platformId,
        ),
      ),
    );

    if (added == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Show scan mode selection dialog
  /// Allows user to choose between:
  /// - readonly (default): Safe testing, no email modifications
  /// - testLimit: Limit modifications to N emails for safe testing
  /// - testAll: Full scan with revert capability
  void _showScanModeSelector(
    BuildContext context,
    String accountId,
    String email,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ScanModeSelector(
        parentContext: context,
        platformId: widget.platformId,
        platformDisplayName: widget.platformDisplayName,
        accountId: accountId,
        accountEmail: email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.platformDisplayName} - Account Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.platformDisplayName} Email Setup',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            if (!_isGmail)
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'App Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_open, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gmail uses Google Sign-In. No app password needed. Tap below to sign in.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            
            // Test connection button
            OutlinedButton.icon(
              onPressed: _isTesting || _isLoading ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isGmail ? Icons.login : Icons.wifi_tethering),
              label: Text(
                _isTesting
                    ? 'Testing...'
                    : _isGmail
                        ? 'Google Sign-In (OAuth 2.0)'
                        : 'Test Connection',
              ),
            ),
            
            // Connection status message
            if (_connectionStatus != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _connectionStatus!.startsWith('[OK]')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _connectionStatus!.startsWith('[OK]')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Text(
                  _connectionStatus!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _connectionStatus!.startsWith('[OK]')
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Save and proceed button
            ElevatedButton(
              onPressed: _isLoading || _isTesting ? null : _handleConnect,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(_isGmail ? 'Sign in with Google (OAuth 2.0)' : 'Save Credentials & Continue'),
            ),
            
            const SizedBox(height: 16),
            Text(
              'Platform: ${widget.platformDisplayName} (${widget.platformId})',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Scan mode selector widget
/// 
/// Allows user to choose how to handle email modifications:
/// - readonly (default): Safe for testing, no modifications made
/// - testLimit: Test on limited number of emails (user-specified)
/// - testAll: Full scan with revert capability after
/// 
/// [NEW] PHASE 2 SPRINT 3: Read-only mode by default, safe testing
class _ScanModeSelector extends StatefulWidget {
  final BuildContext parentContext;
  final String platformId;
  final String platformDisplayName;
  final String accountId;
  final String accountEmail;

  const _ScanModeSelector({
    required this.parentContext,
    required this.platformId,
    required this.platformDisplayName,
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
    // readonly is default (safe)
    _selectedMode = ScanMode.readonly;
  }

  @override
  void dispose() {
    _testLimitController.dispose();
    super.dispose();
  }

  /// Proceed with selected scan mode
  Future<void> _proceedWithScanMode() async {
    // [NEW] PHASE 3.1: Show warning dialog for Full Scan mode
    if (_selectedMode == ScanMode.fullScan) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Warning: Full Scan Mode'),
            ],
          ),
          content: const Text(
            'Full Scan mode will PERMANENTLY delete or move emails based on your rules.\n\n'
            'This action CANNOT be undone.\n\n'
            'Are you sure you want to enable Full Scan mode?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Enable Full Scan'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return; // User cancelled
      }
    }

    final scanProvider = widget.parentContext.read<EmailScanProvider>();

    // Initialize scan mode before proceeding
    int? testLimit;
    if (_selectedMode == ScanMode.testLimit) {
      testLimit = _testLimit;
    }

    scanProvider.initializeScanMode(
      mode: _selectedMode,
      testLimit: testLimit,
    );

    _logger.i(
      '[INVESTIGATION] Initialized scan mode: $_selectedMode'
      '${testLimit != null ? ' (limit: $testLimit emails)' : ''}',
    );

    // Close the dialog first
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Navigate to ScanProgressScreen, replacing Account Setup Screen
    // This keeps the navigation stack clean: Account Selection → Platform Selection → Scan Progress
    if (!mounted) return;

    // Capture context before async gap
    final parentContext = widget.parentContext;
    await Navigator.of(parentContext).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScanProgressScreen(
          platformId: widget.platformId,
          platformDisplayName: widget.platformDisplayName,
          accountId: widget.accountId,
          accountEmail: widget.accountEmail,
        ),
      ),
    );

    // After scan completes and returns, pop Platform Selection to return to Account Selection
    // The scan is done, account was added, notify Account Selection to reload
    // Check both State.mounted and that the parentContext is still valid
    if (!mounted || !parentContext.mounted) return;
    Navigator.of(parentContext).pop(true);
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
              'How would you like to scan emails?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Read-only mode (default)
            GestureDetector(
              onTap: () {
                setState(() => _selectedMode = ScanMode.readonly);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedMode == ScanMode.readonly
                        ? Colors.blue
                        : Colors.grey.shade300,
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
                          value: ScanMode.readonly,
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() => _selectedMode = ScanMode.readonly);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Read-Only Mode (Recommended)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '[CHECKLIST] Safe testing - no emails modified',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Test limit mode
            GestureDetector(
              onTap: () {
                setState(() => _selectedMode = ScanMode.testLimit);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedMode == ScanMode.testLimit
                        ? Colors.blue
                        : Colors.grey.shade300,
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
                          value: ScanMode.testLimit,
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() => _selectedMode = ScanMode.testLimit);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Test Limited Emails',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '[NOTES] Apply changes to first N emails only',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_selectedMode == ScanMode.testLimit) ...[
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
                                setState(() {
                                  _testLimit = int.tryParse(value) ?? 50;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Full test mode
            GestureDetector(
              onTap: () {
                setState(() => _selectedMode = ScanMode.testAll);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedMode == ScanMode.testAll
                        ? Colors.blue
                        : Colors.grey.shade300,
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
                          value: ScanMode.testAll,
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() => _selectedMode = ScanMode.testAll);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Full Scan with Revert',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '⚡ Apply all changes (can be reverted)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // [NEW] PHASE 3.1: Full Scan mode (permanent)
            GestureDetector(
              onTap: () {
                setState(() => _selectedMode = ScanMode.fullScan);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedMode == ScanMode.fullScan
                        ? Colors.blue
                        : Colors.grey.shade300,
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
                          value: ScanMode.fullScan,
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() => _selectedMode = ScanMode.fullScan);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Full Scan',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '🔥 PERMANENT delete/move (cannot revert)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                          ? 'No emails will be modified. Safe for testing.'
                          : _selectedMode == ScanMode.testLimit
                              ? 'Only first $_testLimit emails will be modified.'
                              : _selectedMode == ScanMode.testAll
                                  ? 'All actions can be reverted using "Revert Last Run" option.'
                                  : '[WARNING] PERMANENT changes - emails will be DELETED or MOVED. This action CANNOT be undone!',
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
          onPressed: _proceedWithScanMode,
          child: const Text('Continue with Scan'),
        ),
      ],
    );
  }
}
