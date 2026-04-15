import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../adapters/email_providers/email_provider.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/security/auth_rate_limiter.dart';
import '../../core/storage/settings_store.dart';
import '../../util/redact.dart';
import 'help_screen.dart';
import 'scan_progress_screen.dart';
import 'gmail_oauth_screen.dart';

/// Gmail authentication method choices
///
/// [ISSUE #178] Sprint 19: Allows Gmail users to choose between
/// OAuth 2.0 (Google Sign-In) or IMAP with App Password.
enum GmailAuthMethod {
  /// Google Sign-In via OAuth 2.0 (recommended)
  oauth,

  /// IMAP with App Password
  appPassword,
}

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

  /// [ISSUE #178] Gmail auth method selection (null = not yet chosen for Gmail,
  /// or not applicable for non-Gmail platforms)
  GmailAuthMethod? _gmailAuthMethod;

  /// Whether user is in App Password mode for Gmail
  bool get _isGmailAppPassword =>
      _isGmail && _gmailAuthMethod == GmailAuthMethod.appPassword;

  /// Whether user is in OAuth mode for Gmail (or has not yet chosen)
  bool get _isGmailOAuth =>
      _isGmail && _gmailAuthMethod == GmailAuthMethod.oauth;

  /// The effective platform ID for credential storage and adapter lookup.
  /// Gmail App Password uses 'gmail-imap', everything else uses the original ID.
  String get _effectivePlatformId =>
      _isGmailAppPassword ? 'gmail-imap' : widget.platformId;

  /// The effective display name for the platform.
  String get _effectiveDisplayName =>
      _isGmailAppPassword ? 'Gmail (IMAP)' : widget.platformDisplayName;

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
    // For non-Gmail platforms, no auth method choice needed
    if (!_isGmail) {
      _gmailAuthMethod = null;
    }
  }

  /// [ISSUE #178] Handle Gmail auth method selection
  void _selectGmailAuthMethod(GmailAuthMethod method) {
    setState(() {
      _gmailAuthMethod = method;
      _connectionStatus = null;
    });
    if (method == GmailAuthMethod.oauth) {
      // Immediately start OAuth flow
      _startGmailOAuth();
    }
  }

  /// Basic email format validation (SEC-20)
  /// Returns null if valid, or an error message if invalid.
  String? _validateEmailFormat(String email) {
    if (email.isEmpty) return 'Email is required.';
    // Must contain exactly one @
    final atCount = '@'.allMatches(email).length;
    if (atCount != 1) return 'Email must contain exactly one @ symbol.';
    final parts = email.split('@');
    if (parts[0].isEmpty) return 'Email must have a username before @.';
    if (parts[1].isEmpty) return 'Email must have a domain after @.';
    if (!parts[1].contains('.')) return 'Email domain must contain at least one dot.';
    if (parts[1].startsWith('.') || parts[1].endsWith('.')) {
      return 'Email domain cannot start or end with a dot.';
    }
    return null;
  }

  /// Password length warning (SEC-21)
  /// Returns a warning message for short passwords, or null if OK.
  String? _passwordLengthWarning(String password) {
    if (password.isNotEmpty && password.length < 8) {
      return 'App passwords are typically 16 characters. '
          'Short passwords may indicate an incorrect entry.';
    }
    return null;
  }

  /// Validate email and password inputs before connection attempt.
  /// Returns true if validation passes, false if blocked.
  bool _validateInputs(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and app password are required.')),
        );
      }
      return false;
    }

    final emailError = _validateEmailFormat(email);
    if (emailError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(emailError)),
        );
      }
      return false;
    }

    // SEC-21 / H2 fix: Password length warning is now surfaced in the UI
    // (SnackBar, 5s duration) instead of log-only. Length is intentionally
    // NOT logged to avoid creating a password-search-space oracle.
    final passwordWarning = _passwordLengthWarning(password);
    if (passwordWarning != null) {
      _logger.w('[Account Setup] Short password entered (warning shown to user)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(passwordWarning),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    return true;
  }

  /// Test IMAP connection with provided credentials
  Future<void> _testConnection() async {
    if (_isGmailOAuth) {
      await _startGmailOAuth();
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_validateInputs(email, password)) return;

    setState(() {
      _isTesting = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      // Get platform adapter using effective platform ID
      final platform = PlatformRegistry.getPlatform(_effectivePlatformId);
      if (platform == null) {
        throw Exception('Platform $_effectivePlatformId not supported');
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
      // SEC-22 (Sprint 33): surface rate-limit blocks with a clear unlock
      // time instead of a raw toString() that exposes the redacted account
      // and exception name.
      String userMessage;
      if (e is AuthRateLimitedException) {
        final unlock = e.blockedUntil.toLocal();
        final hh = unlock.hour.toString().padLeft(2, '0');
        final mm = unlock.minute.toString().padLeft(2, '0');
        userMessage =
            'Too many failed sign-in attempts. Try again at $hh:$mm.';
      } else {
        userMessage = 'Connection failed: $e';
      }

      setState(() {
        _isTesting = false;
        _connectionStatus = '[FAIL] $userMessage';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage)),
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
  /// [UPDATED] ISSUE #178: Gmail IMAP App Password handled via standard IMAP flow
  Future<void> _handleConnect() async {
    setState(() => _isLoading = true);

    // Gmail OAuth flow - redirect to Gmail OAuth screen
    if (_isGmailOAuth) {
      setState(() => _isLoading = false);
      await _startGmailOAuth();
      return;
    }

    // Standard IMAP credentials flow for AOL, Yahoo, iCloud, Gmail IMAP, etc.
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_validateInputs(email, password)) {
      setState(() => _isLoading = false);
      return;
    }

    // [NEW] MULTI-ACCOUNT SUPPORT: Use email as primary key
    // Store platformId separately to keep fields independent
    // Email is unique identifier, platformId is stored as metadata
    final accountId = email; // Use email as the account identifier

    // Save credentials securely with email as accountId and platformId as separate field
    // [ISSUE #178] Gmail IMAP uses 'gmail-imap' as platformId for adapter routing
    try {
      await _credStore.saveCredentials(
        accountId,
        Credentials(email: email, password: password),
        platformId: _effectivePlatformId,
      );

      _logger.i('[OK] Saved credentials for account: ${Redact.accountId(accountId)} (platform: $_effectivePlatformId)');
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
            platformId: _effectivePlatformId,
            platformDisplayName: _effectiveDisplayName,
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

  @override
  Widget build(BuildContext context) {
    // [ISSUE #178] Gmail: Show auth method selector if not yet chosen
    if (_isGmail && _gmailAuthMethod == null) {
      return _buildGmailAuthMethodSelector(context);
    }

    // Standard account setup (IMAP password flow or Gmail OAuth)
    return _buildStandardSetup(context);
  }

  /// [ISSUE #178] Build the Gmail auth method choice screen
  Widget _buildGmailAuthMethodSelector(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gmail - Sign In Method'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => openHelp(context, HelpSection.accountSetup),
          ),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How would you like to sign in to Gmail?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred authentication method',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Option 1: App Password (IMAP) - Recommended
            _buildAuthMethodCard(
              icon: Icons.key,
              iconColor: Colors.orange.shade700,
              title: 'App Password (IMAP) (Recommended)',
              subtitle: 'Connect via IMAP using a Google App Password',
              benefits: const [
                'Reliable, persistent connection',
                'Standard IMAP protocol',
                'Requires 2-Step Verification enabled',
              ],
              borderColor: Colors.orange,
              onTap: () => _selectGmailAuthMethod(GmailAuthMethod.appPassword),
            ),

            const SizedBox(height: 16),

            // Option 2: Google Sign-In (OAuth)
            _buildAuthMethodCard(
              icon: Icons.login,
              iconColor: Colors.blue.shade700,
              title: 'Google Sign-In',
              subtitle: 'Sign in with your Google account using OAuth 2.0',
              benefits: const [
                'No app password needed',
                'Secure OAuth 2.0 authentication',
                'Note: May require more frequent re-authentication',
              ],
              borderColor: Colors.blue,
              onTap: () => _selectGmailAuthMethod(GmailAuthMethod.oauth),
            ),

            const SizedBox(height: 24),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Both methods are secure. App Password is recommended '
                      'for most users. Google Sign-In is an alternative but '
                      'may require more frequent re-authentication. This may '
                      'be resolved in a future update.',
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build an auth method choice card
  Widget _buildAuthMethodCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<String> benefits,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 12),
              ...benefits.map((benefit) => Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                      color: Colors.green.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        benefit,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the standard account setup form
  Widget _buildStandardSetup(BuildContext context) {
    // Determine if this is IMAP password flow (non-Gmail, or Gmail App Password)
    final showPasswordField = !_isGmail || _isGmailAppPassword;
    final showOAuthInfo = _isGmailOAuth;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_effectiveDisplayName} - Account Setup'),
        leading: _isGmail
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Go back to auth method selector
                  setState(() {
                    _gmailAuthMethod = null;
                    _connectionStatus = null;
                  });
                },
              )
            : null,
        actions: [
          // F54 (Sprint 33): Help icon -> Account Setup section.
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => openHelp(context, HelpSection.accountSetup),
          ),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_effectiveDisplayName} Email Setup',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            // [ISSUE #178] Show auth method indicator for Gmail
            if (_isGmail) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isGmailAppPassword
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isGmailAppPassword ? Icons.key : Icons.login,
                      size: 16,
                      color: _isGmailAppPassword
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isGmailAppPassword
                          ? 'App Password (IMAP)'
                          : 'Google Sign-In (OAuth 2.0)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isGmailAppPassword
                            ? Colors.orange.shade900
                            : Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],

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

            if (showPasswordField) ...[
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'App Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              // [ISSUE #178] Show App Password setup instructions for Gmail IMAP
              if (_isGmailAppPassword) ...[
                const SizedBox(height: 12),
                _buildAppPasswordInstructions(),
              ],
            ] else if (showOAuthInfo)
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
                  : Icon(showOAuthInfo ? Icons.login : Icons.wifi_tethering),
              label: Text(
                _isTesting
                    ? 'Testing...'
                    : showOAuthInfo
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
                  : Text(showOAuthInfo
                      ? 'Sign in with Google (OAuth 2.0)'
                      : 'Save Credentials & Continue'),
            ),

            const SizedBox(height: 16),
            Text(
              'Platform: $_effectiveDisplayName ($_effectivePlatformId)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            ],
          ),
        ),
      ),
    );
  }

  /// [ISSUE #178] Build Gmail App Password setup instructions
  ///
  /// Step-by-step instructions for creating a Google App Password.
  /// These steps are current as of February 2026.
  Widget _buildAppPasswordInstructions() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      leading: Icon(Icons.help_outline, color: Colors.orange.shade700, size: 20),
      title: const Text(
        'How to create a Gmail App Password',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prerequisites',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                _buildInstructionItem(
                  '2-Step Verification must be enabled on your Google Account.',
                ),
                _buildInstructionItem(
                  'App Passwords do not work with accounts that use '
                  'Advanced Protection.',
                ),
                const Divider(height: 24),
                Text(
                  'Steps to create an App Password',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                _buildNumberedStepWithLink(
                  1,
                  'Go to your Google Account at ',
                  'myaccount.google.com',
                  'https://myaccount.google.com',
                ),
                _buildNumberedStep(2,
                  'Select "Security & Sign-in" from the left navigation panel',
                ),
                _buildNumberedStep(3,
                  'Under "How you sign in to Google", verify that '
                  '"2-Step Verification" is ON',
                ),
                _buildNumberedStepWithLink(
                  4,
                  'Go to ',
                  'myaccount.google.com/apppasswords',
                  'https://myaccount.google.com/apppasswords',
                  suffix: ' (or search "App passwords" in the Security page)',
                ),
                _buildNumberedStep(5,
                  'In the "App name" field, type a name '
                  '(e.g., "MyEmailSpamFilter")',
                ),
                _buildNumberedStep(6,
                  'Click "Create"',
                ),
                _buildNumberedStep(7,
                  'Google will display a 16-character app password. '
                  'Copy this password.',
                ),
                _buildNumberedStep(8,
                  'Paste the 16-character password into the '
                  '"App Password" field above. Spaces are optional.',
                ),
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber,
                        color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Important: The app password is shown only once. '
                          'If you lose it, you must revoke and create a new one.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build a numbered step with a tappable link embedded in the text
  Widget _buildNumberedStepWithLink(
    int number,
    String prefix,
    String linkText,
    String url, {
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12),
                  children: [
                    TextSpan(text: prefix),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => launchUrl(Uri.parse(url)),
                        child: Text(
                          linkText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    if (suffix.isNotEmpty) TextSpan(text: suffix),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('  \u2022 ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
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
    _selectedMode = ScanMode.readOnly;
  }

  @override
  void dispose() {
    _testLimitController.dispose();
    super.dispose();
  }

  /// Proceed with selected scan mode
  Future<void> _proceedWithScanMode() async {
    // [NEW] PHASE 3.1: Show warning dialog for Full Scan mode
    if (_selectedMode == ScanMode.safeSendersAndRules) {
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
          content: SelectionArea(
            child: const Text(
              'Full Scan mode will PERMANENTLY delete or move emails based on your rules.\n\n'
              'This action CANNOT be undone.\n\n'
              'Are you sure you want to enable Full Scan mode?',
              style: TextStyle(fontSize: 14),
            ),
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
    if (_selectedMode == ScanMode.rulesOnly) {
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
      content: SelectionArea(
        child: SingleChildScrollView(
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
                setState(() => _selectedMode = ScanMode.readOnly);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedMode == ScanMode.readOnly
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
                          value: ScanMode.readOnly,
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() => _selectedMode = ScanMode.readOnly);
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
                setState(() => _selectedMode = ScanMode.rulesOnly);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedMode == ScanMode.rulesOnly
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
                          value: ScanMode.rulesOnly,
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() => _selectedMode = ScanMode.rulesOnly);
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
                    if (_selectedMode == ScanMode.rulesOnly) ...[
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
                setState(() => _selectedMode = ScanMode.safeSendersOnly);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedMode == ScanMode.safeSendersOnly
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
                          value: ScanMode.safeSendersOnly,
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() => _selectedMode = ScanMode.safeSendersOnly);
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
                setState(() => _selectedMode = ScanMode.safeSendersAndRules);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedMode == ScanMode.safeSendersAndRules
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
                          value: ScanMode.safeSendersAndRules,
                          groupValue: _selectedMode,
                          onChanged: (value) {
                            setState(() => _selectedMode = ScanMode.safeSendersAndRules);
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
                      _selectedMode == ScanMode.readOnly
                          ? 'No emails will be modified. Safe for testing.'
                          : _selectedMode == ScanMode.rulesOnly
                              ? 'Only first $_testLimit emails will be modified.'
                              : _selectedMode == ScanMode.safeSendersOnly
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
