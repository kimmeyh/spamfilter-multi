import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../adapters/email_providers/custom_imap_settings.dart';
import '../../adapters/email_providers/email_provider.dart';
import '../../adapters/email_providers/generic_imap_adapter.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/security/imap_certificate_trust.dart';
import '../../core/security/imap_host_policy.dart';
import '../../core/storage/settings_store.dart';
import '../../util/error_messages.dart';
import '../../util/redact.dart';
import '../utils/credential_labels.dart';
import 'help_screen.dart';
import 'scan_progress_screen.dart';
import 'gmail_oauth_screen.dart';
import '../widgets/standard_app_bar_actions.dart';
import '../widgets/screen_version_line.dart'; // F229 (Sprint 73)
import '../widgets/system_inset_wrapper.dart'; // F209 (Sprint 69)

/// Sprint 77 MV-Q4: the text of the "Account already added" question.
/// [providerName] null = the saved account's provider is unknown.
@visibleForTesting
String replaceAccountMessage(String? providerName) {
  final which = providerName == null ? '' : ' ($providerName)';
  return 'This email address is already added$which. Replace its saved '
      'sign-in details with the ones you entered? Its scan history, rules '
      'and settings are kept.';
}

/// MV-Q4: the provider's display name for a stored platform id, or null.
@visibleForTesting
String? providerNameFor(String? platformId) {
  if (platformId == null) return null;
  if (platformId == 'gmail-imap') return 'Gmail, App Password';
  for (final info in PlatformRegistry.getSupportedPlatforms()) {
    if (info.id == platformId) return info.displayName;
  }
  return null;
}

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

  /// SEC-8b: shown when Save goes ahead because the server could not be
  /// reached to check its certificate (the only failure that may save).
  @visibleForTesting
  static const String savedUncheckedMessage =
      'The server could not be reached, so its certificate was not checked. '
      'It is checked the first time the app connects.';

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // F192 (Sprint 77): Custom IMAP server fields. Used only when
  // `widget.platformId == 'imap'`; every other provider ignores them.
  final _hostController = TextEditingController();
  final _portController =
      TextEditingController(text: ImapEncryption.sslTls.defaultPort.toString());
  final _usernameController = TextEditingController();
  ImapEncryption _encryption = ImapEncryption.sslTls;
  String? _hostError;
  String? _portError;

  /// True once the user typed in the Username field. Until then the field
  /// follows the email address, because most IMAP logins are the address.
  bool _usernameEdited = false;

  /// The host the user already accepted the one-time local-network warning
  /// for (lower-cased). The warning shows ONCE: Test Connection and Save share
  /// this, so accepting it on the first never asks again for the same host.
  String? _localHostAcknowledged;

  /// SEC-8b (ADR-0046): fingerprint of the server certificate trusted in THIS
  /// form (the user said Yes in "Trust this server?", or the device trusted
  /// it during Save). Bound to [_trustedCertTarget] so trust given to one
  /// server is never carried to a different host, port or encryption.
  String? _trustedCertSha256;
  String? _trustedCertTarget;

  static String _certTarget(CustomImapSettings s) =>
      '${s.host.toLowerCase()}:${s.port}:${s.encryption.wireValue}';

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
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  /// True for the Custom IMAP provider (F192): the form shows the server
  /// section and Test Connection / Save carry the server settings.
  bool get _isCustomImap => widget.platformId == 'imap';

  /// MV-Q5: "App Password" or "Password", for the provider actually chosen
  /// (Gmail App Password resolves through 'gmail-imap').
  /// MV-Q8: a Custom IMAP server known to take an app password (Yahoo, AOL,
  /// Gmail, iCloud) reads "App Password", from the server name as typed.
  String get _credentialLabel => credentialLabelFor(_effectivePlatformId,
      imapHost: _isCustomImap ? _hostController.text : null);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      // Username follows the email address until the user edits it.
      if (_isCustomImap && !_usernameEdited) {
        _usernameController.text = _emailController.text.trim();
      }
    });
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
  /// Returns null if valid, or a generic error message if invalid.
  /// Messages are intentionally generic to avoid leaking validation details.
  String? _validateEmailFormat(String email) {
    if (email.isEmpty) return 'Email is required.';
    // All format checks return the same generic message (SEC-20)
    final atCount = '@'.allMatches(email).length;
    if (atCount != 1) return 'Please enter a valid email address.';
    final parts = email.split('@');
    if (parts[0].isEmpty) return 'Please enter a valid email address.';
    if (parts[1].isEmpty) return 'Please enter a valid email address.';
    if (!parts[1].contains('.')) return 'Please enter a valid email address.';
    if (parts[1].startsWith('.') || parts[1].endsWith('.')) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Password length warning (SEC-21)
  /// Returns a warning message for short passwords, or null if OK.
  ///
  /// MV-Q5: only for an app password, whose length the provider fixes. A
  /// normal password's length is the user's own choice, so a short one is
  /// not a sign of a wrong entry.
  String? _passwordLengthWarning(String password) {
    if (_credentialLabel != 'App Password') return null;
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
          SnackBar(
              content: Text(
                  'Email and ${_credentialLabel.toLowerCase()} are required.')),
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

  /// F192 / SEC-15 (Sprint 77): validate the Custom IMAP server fields and, for
  /// a local or private address, show the one-time warning.
  ///
  /// Called from BOTH [_testConnection] and [_handleConnect]. The policy
  /// itself lives in ONE pure function, `ImapHostPolicy.classify`; this method
  /// only turns its answer into field messages and a dialog.
  ///
  /// Returns the settings to use, or null when the form must stop (a field
  /// message is shown, or the user declined the warning).
  Future<CustomImapSettings?> _prepareCustomServer() async {
    final host = _hostController.text.trim();
    final hostClass = ImapHostPolicy.classify(host);
    final port = int.tryParse(_portController.text.trim());

    String? hostError;
    switch (hostClass) {
      case ImapHostClass.empty:
        hostError = ImapHostPolicy.emptyMessage;
      case ImapHostClass.malformed:
        hostError = ImapHostPolicy.malformedMessage;
      case ImapHostClass.publicHost:
      case ImapHostClass.localOrPrivate:
        hostError = null;
    }
    final portError = (port == null || port < 1 || port > 65535)
        ? 'Enter a port number from 1 to 65535.'
        : null;

    setState(() {
      _hostError = hostError;
      _portError = portError;
    });
    if (hostError != null || portError != null) return null;

    if (hostClass == ImapHostClass.localOrPrivate &&
        _localHostAcknowledged != host.toLowerCase()) {
      final proceed = await _confirmLocalHost();
      if (!proceed || !mounted) return null;
      _localHostAcknowledged = host.toLowerCase();
    }

    final settings = CustomImapSettings(
      host: host,
      port: port!,
      encryption: _encryption,
      username: _usernameController.text.trim(),
    );
    // SEC-8b: carry the trusted fingerprint only to the SAME server.
    return _trustedCertTarget == _certTarget(settings)
        ? settings.withTrustedCertificate(_trustedCertSha256)
        : settings;
  }

  /// SEC-8b (Sprint 77 Q4, ADR-0046): the one-time "Trust this server?"
  /// question for a certificate the device does not trust. Shows the
  /// certificate's SHA-256 fingerprint, subject, issuer and validity. On Yes,
  /// the fingerprint is remembered for THIS server in the form (and stored
  /// with the account on Save). Returns true when the user trusts it.
  Future<bool> _confirmServerCertificate(
      ServerCertificateNotTrustedException e, CustomImapSettings settings) async {
    final cert = e.certificate;
    final changed = e.problem == CertificateTrustProblem.changed;
    String day(DateTime d) => d.toLocal().toString().split(' ').first;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trust this server?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(changed
                  ? 'The certificate of ${e.host} is different from the one '
                      'you trusted before. Your device does not trust the new '
                      'one, so the app has not sent your password.'
                  : 'Your device does not trust the certificate of ${e.host} '
                      '(for example, it is self-signed), so the app has not '
                      'sent your password.'),
              const SizedBox(height: 8),
              const Text('Trust it only if you run this server yourself, or '
                  'the fingerprint below matches the one your server shows.'),
              const SizedBox(height: 12),
              const Text('Fingerprint (SHA-256)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SelectableText(cert.displayFingerprint,
                  key: const Key('cert_fingerprint'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 8),
              Text('Issued to: ${cert.subject}'),
              Text('Issued by: ${cert.issuer}'
                  '${cert.isSelfSigned ? ' (self-signed)' : ''}'),
              Text('Valid: ${day(cert.validFrom)} to ${day(cert.validTo)}'),
              Text('Server: ${e.host}:${e.port}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Do Not Trust'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Trust'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return false;
    setState(() {
      _trustedCertSha256 = cert.sha256Hex;
      _trustedCertTarget = _certTarget(settings);
    });
    return true;
  }

  /// SEC-8b: Save checks the server certificate BEFORE storing the account,
  /// so the trust question is asked while the user is here (a background
  /// scan can never ask). No password is sent by this check.
  ///
  /// Returns the settings to store (with the fingerprint of a certificate
  /// the device trusts or the user accepted), or null when Save must stop.
  ///
  /// Only a server that could not be REACHED (`SocketException`,
  /// `TimeoutException` -- no network, wrong address, port closed) lets Save
  /// continue, because Save never required a connection; the user is told
  /// the certificate was not checked, and it is checked on the first
  /// connection, where an untrusted one stops with a message that says how
  /// to confirm it. Every other failure means the server WAS reached and the
  /// secure connection failed (STARTTLS refused, TLS handshake failure, a
  /// broken exchange): saving would store an account whose every scan fails,
  /// so Save stops with the named reason (Sprint 77 Phase 5.1.2 F-PRECHECK;
  /// before, a catch-all saved it anyway and reported "Account saved").
  Future<CustomImapSettings?> _checkCertificateBeforeSave(
      String email, String password, CustomImapSettings settings) async {
    final platform = PlatformRegistry.getPlatform(_effectivePlatformId);
    if (platform is! GenericIMAPAdapter) return settings;
    final credentials = Credentials(
      email: email,
      password: password,
      additionalParams: settings.toParams(),
    );
    try {
      final info = await platform.probeServerCertificate(credentials);
      return settings.withTrustedCertificate(info.sha256Hex);
    } on ServerCertificateNotTrustedException catch (e) {
      if (!mounted) return null;
      final trusted = await _confirmServerCertificate(e, settings);
      if (!trusted) {
        if (mounted) {
          setState(() => _connectionStatus =
              '[FAIL] Not saved: the server certificate was not trusted.');
        }
        return null;
      }
      return settings.withTrustedCertificate(e.certificate.sha256Hex);
    } on SocketException catch (e) {
      return _saveUnchecked(settings, e);
    } on TimeoutException catch (e) {
      return _saveUnchecked(settings, e);
    } catch (e) {
      // UserFacingConnectionException (STARTTLS refused), HandshakeException
      // and anything else: the server answered and the secure connection
      // failed. Never saved.
      _logger.w('Certificate check before Save failed; not saved: $e');
      if (mounted) {
        setState(() => _connectionStatus =
            '[FAIL] Not saved: ${ErrorMessages.humanize(e)}');
      }
      return null;
    }
  }

  /// A network failure only (see [_checkCertificateBeforeSave]): save, and
  /// say the certificate was not checked.
  CustomImapSettings _saveUnchecked(CustomImapSettings settings, Object e) {
    _logger.w('Server not reachable during the certificate check; saving '
        'without a recorded certificate: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AccountSetupScreen.savedUncheckedMessage)),
      );
    }
    return settings;
  }

  /// The one-time local-network warning (Sprint 77 Q2). Text is fixed by
  /// Harold and lives in [ImapHostPolicy.localNetworkWarning].
  Future<bool> _confirmLocalHost() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Local server'),
        content: const Text(ImapHostPolicy.localNetworkWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result == true;
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

    CustomImapSettings? customServer;
    if (_isCustomImap) {
      customServer = await _prepareCustomServer();
      if (customServer == null || !mounted) return;
    }

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
      final credentials = Credentials(
        email: email,
        password: password,
        additionalParams: customServer?.toParams(),
      );
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
    } on ServerCertificateNotTrustedException catch (e) {
      // SEC-8b: ask "Trust this server?"; on Yes, test again with the
      // fingerprint (the second attempt connects only to that certificate).
      setState(() {
        _isTesting = false;
        _connectionStatus = '[FAIL] ${e.userMessage}';
      });
      if (customServer == null || !mounted) return;
      final trusted = await _confirmServerCertificate(e, customServer);
      if (trusted && mounted) await _testConnection();
    } catch (e) {
      // SEC-22 (Sprint 33): surface rate-limit blocks with a clear unlock
      // time instead of a raw toString() that exposes the redacted account
      // and exception name. F151f (Sprint 58): the fallback for every other
      // exception type now goes through ErrorMessages.humanize() instead of
      // raw '$e' interpolation, which previously leaked internal exception
      // class names (e.g. "ConnectionException: ...") to the user.
      final userMessage = ErrorMessages.humanize(e);

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

  /// Sprint 77 MV-Q4 (Harold, Q4 = 1): ask before an add replaces a saved
  /// account. Accounts are keyed by email address alone, so adding an address
  /// that is already saved (the same address on a second server, or one
  /// already added as AOL) used to overwrite that account's sign-in with no
  /// warning. Re-adding is also how a user enters a new app password, so the
  /// add is confirmed, not blocked. True = go ahead.
  Future<bool> _confirmReplaceExisting(String accountId) async {
    if (!await _credStore.credentialsExist(accountId)) return true;
    final existing = await _credStore.getPlatformId(accountId);
    if (!mounted) return false;
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account already added'),
        content: Text(replaceAccountMessage(providerNameFor(existing))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return replace == true;
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

    // MV-Q4 (Sprint 77): the account id is the email address, so saving an
    // address that is already saved REPLACES that account's sign-in. Ask
    // first, before any server or certificate question.
    if (!await _confirmReplaceExisting(email)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // F192 / SEC-15: validate the server fields (and show the one-time
    // local-network warning) before anything is saved.
    CustomImapSettings? customServer;
    if (_isCustomImap) {
      customServer = await _prepareCustomServer();
      if (customServer == null || !mounted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      // SEC-8b: certificate check (and the trust question) before saving.
      customServer =
          await _checkCertificateBeforeSave(email, password, customServer);
      if (customServer == null || !mounted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
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
        Credentials(
          email: email,
          password: password,
          additionalParams: customServer?.toParams(),
        ),
        platformId: _effectivePlatformId,
      );

      _logger.i('[OK] Saved credentials for account: ${Redact.accountId(accountId)} (platform: $_effectivePlatformId)');
    } catch (e) {
      setState(() => _isLoading = false);
      // F151f (Sprint 58): the log line keeps the raw exception for
      // diagnostics; only the user-facing SnackBar text is humanized.
      _logger.e('Failed to save credentials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.humanize(e))),
        );
      }
      return;
    }

    setState(() => _isLoading = false);

    await _finishAccountAdded(
      accountId: accountId,
      email: email,
      platformId: _effectivePlatformId,
      displayName: _effectiveDisplayName,
    );
  }

  /// What happens once a new account is saved -- ONE path for every provider
  /// (Harold, Sprint 75 Manual Validation: a Gmail account must finish "the
  /// same that is done after adding AOL and Yahoo accounts"): the saved
  /// message, then the Manual Scan screen for that account, which REPLACES
  /// this screen. Its back arrow is a plain pop to the route below; the
  /// account list refreshes when it is shown again (`didPopNext`).
  Future<void> _finishAccountAdded({
    required String accountId,
    required String email,
    required String platformId,
    required String displayName,
  }) async {
    if (!mounted) return;
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
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScanProgressScreen(
          platformId: platformId,
          platformDisplayName: displayName,
          accountId: accountId,
          accountEmail: email,
        ),
      ),
    );
    // PR #448 review: no `.then` here. `pushReplacement` disposes this
    // State, so a callback guarded by `mounted` could never run (it was
    // dead code that read as "pop back to the account list").
  }

  Future<void> _startGmailOAuth() async {
    if (!mounted) return;

    // The sign-in screen returns the signed-in address once the account is
    // saved (null if the user backed out), and the account then finishes
    // exactly like an AOL or Yahoo account.
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => GmailOAuthScreen(
          platformId: widget.platformId,
        ),
      ),
    );

    if (email != null && mounted) {
      await _finishAccountAdded(
        accountId: email,
        email: email,
        platformId: widget.platformId,
        displayName: 'Gmail',
      );
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
    return SystemInsetWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gmail - Sign In Method'),
          // F134 (Sprint 52): declared via the ONE shared builder (was already
          // Accounts then Help; the builder makes that structural).
          actions: StandardAppBarActions.build(
            context: context,
            helpSection: HelpSection.accountSetup,
            includeNoRuleReview: false,
            includeScanHistory: false,
            includeSettings: false,
          ),
        ),
        body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          const ScreenVersionLine(),
          Expanded(child: SelectionArea(
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
        )),
        ],
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
    // F133-S52 R-2 (Sprint 52): this shared card helper was a bare InkWell --
    // tappable but unnamed. It renders the sign-in-method choices on
    // account_setup, which is the FIRST screen a brand-new Store user meets,
    // so an unannounced choice here is the highest-impact instance of the gap.
    // Wrapping the HELPER covers every call site at once.
    //
    // `excludeSemantics: true` is correct here: the card body is text and
    // decoration with no interactive children, so merging it into one node is
    // what a screen reader should hear. The subtitle becomes the hint rather
    // than being concatenated into the label, so the announcement leads with
    // WHAT the choice is.
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Semantics(
        container: true,
        button: true,
        excludeSemantics: true,
        label: title,
        hint: subtitle,
        onTap: onTap,
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
      ),
    );
  }

  /// Build the standard account setup form
  Widget _buildStandardSetup(BuildContext context) {
    // Determine if this is IMAP password flow (non-Gmail, or Gmail App Password)
    final showPasswordField = !_isGmail || _isGmailAppPassword;
    final showOAuthInfo = _isGmailOAuth;

    return SystemInsetWrapper(
      child: Scaffold(
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
          // F134 (Sprint 52): declared via the ONE shared builder.
          actions: StandardAppBarActions.build(
            context: context,
            helpSection: HelpSection.accountSetup,
            includeNoRuleReview: false,
            includeScanHistory: false,
            includeSettings: false,
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            const ScreenVersionLine(),
            Expanded(child: SelectionArea(
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
              if (_isCustomImap) ...[
                _buildCustomServerSection(),
                const SizedBox(height: 16),
              ],
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
                  decoration: InputDecoration(
                    // MV-Q5: "App Password" only where the provider takes
                    // one; a Custom IMAP server takes the normal password.
                    labelText: _credentialLabel,
                    // MV-Q8: an unknown custom server may still take an app
                    // password; the app cannot know, so it says so.
                    helperText: _isCustomImap && _credentialLabel == 'Password'
                        ? kCustomImapPasswordHint
                        : null,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
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
                        : kSaveAccountButtonLabel),
              ),

              const SizedBox(height: 16),
              Text(
                'Platform: $_effectiveDisplayName ($_effectivePlatformId)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              ],
            ),
          ),
        )),
          ],
        ),
      ),
    );
  }

  /// F192 (Sprint 77): the server section of the Custom IMAP form: host, port,
  /// encryption and username. Shown above the email and password fields.
  Widget _buildCustomServerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('custom_imap_host'),
          controller: _hostController,
          decoration: InputDecoration(
            labelText: 'Server name',
            hintText: 'imap.example.com',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.dns),
            errorText: _hostError,
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          // Always rebuild: the password label follows the server name (MV-Q8).
          onChanged: (_) => setState(() => _hostError = null),
        ),
        const SizedBox(height: 16),
        Text('Encryption', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SegmentedButton<ImapEncryption>(
          key: const Key('custom_imap_encryption'),
          segments: [
            for (final mode in ImapEncryption.values)
              ButtonSegment<ImapEncryption>(
                value: mode,
                label: Text(mode.label),
              ),
          ],
          selected: {_encryption},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            final next = selection.first;
            setState(() {
              // Move the port to the new mode's usual value only when the
              // user has not typed a different one.
              final current = int.tryParse(_portController.text.trim());
              if (current == null || current == _encryption.defaultPort) {
                _portController.text = next.defaultPort.toString();
              }
              _encryption = next;
              _portError = null;
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('custom_imap_port'),
          controller: _portController,
          decoration: InputDecoration(
            labelText: 'Port',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.numbers),
            errorText: _portError,
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) {
            if (_portError != null) setState(() => _portError = null);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('custom_imap_username'),
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            helperText: 'Usually your email address. Change it only if your '
                'server uses a different login name.',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => _usernameEdited = true,
        ),
        const SizedBox(height: 8),
        Text(
          'To change these server settings later, delete the account on the Accounts screen and add it again.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
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
/// - readOnly (default): Safe for testing, no modifications made
/// - rulesOnly / safeSendersOnly: execute one action family, revertable
/// - safeSendersAndRules: full scan, permanent
///
/// F181 (Sprint 63): the 50-email test-limit option was removed (unenforced
/// promise -- see the F181 card).
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
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    // readonly is default (safe)
    _selectedMode = ScanMode.readOnly;
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

    // Initialize scan mode before proceeding (F181: no test limit).
    scanProvider.initializeScanMode(mode: _selectedMode);

    _logger.i('[INVESTIGATION] Initialized scan mode: $_selectedMode');

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

            // F133-S52 R-2 (Sprint 52): the scan-mode selectors are
            // radio-GROUP options whose whole card is tappable via a bare
            // GestureDetector. The inner Radio already carries correct radio
            // semantics, but it is announced WITHOUT the option name -- the
            // title text sits in a sibling Text, so a screen reader hears
            // "radio button, selected" with no indication of WHICH mode.
            //
            // `inMutuallyExclusiveGroup` + `checked` + a label is the standard
            // radio-group pattern: it names the option AND reports its selected
            // state. Deliberately NOT `excludeSemantics` -- that would destroy
            // the inner Radio's own working semantics, which is the opposite of
            // the goal.
            Semantics(
              container: true,
              inMutuallyExclusiveGroup: true,
              checked: _selectedMode == ScanMode.readOnly,
              label: 'Read-Only Mode (Recommended). '
                  'Safe testing - no emails modified',
              onTap: () {
                setState(() => _selectedMode = ScanMode.readOnly);
              },
              child: GestureDetector(
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
            ),
            const SizedBox(height: 12),

            // Rules-only mode -- see the Read-Only selector above for why this
            // uses inMutuallyExclusiveGroup + checked rather than
            // excludeSemantics (F133-S52 R-2). F181 (Sprint 63): renamed from
            // the removed "Test Limited Emails" framing -- the 50-email cap
            // was never enforced and is gone.
            Semantics(
              container: true,
              inMutuallyExclusiveGroup: true,
              checked: _selectedMode == ScanMode.rulesOnly,
              label: 'Process Rules Only. '
                  'Apply spam rule actions only (can be reverted)',
              onTap: () {
                setState(() => _selectedMode = ScanMode.rulesOnly);
              },
              child: GestureDetector(
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
                                'Process Rules Only',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '[NOTES] Apply spam rule actions only (can be reverted)',
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
                  ],
                ),
              ),
            ),
            ),
            const SizedBox(height: 12),

            // Full test mode -- see the Read-Only selector for the pattern
            // rationale (F133-S52 R-2).
            Semantics(
              container: true,
              inMutuallyExclusiveGroup: true,
              checked: _selectedMode == ScanMode.safeSendersOnly,
              label: 'Full Scan with Revert. '
                  'Apply all changes (can be reverted)',
              onTap: () {
                setState(() => _selectedMode = ScanMode.safeSendersOnly);
              },
              child: GestureDetector(
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
                                'Apply all changes (can be reverted)',
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
            ),
            const SizedBox(height: 12),

            // [NEW] PHASE 3.1: Full Scan mode (permanent)
            // The label states PERMANENT explicitly -- a screen-reader user
            // must hear the irreversibility before selecting, not after
            // (F133-S52 R-2).
            Semantics(
              container: true,
              inMutuallyExclusiveGroup: true,
              checked: _selectedMode == ScanMode.safeSendersAndRules,
              label: 'Full Scan. '
                  'PERMANENT delete or move, cannot revert',
              onTap: () {
                setState(() => _selectedMode = ScanMode.safeSendersAndRules);
              },
              child: GestureDetector(
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
                                'PERMANENT delete/move (cannot revert)',
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
                              ? 'Spam rule actions will be applied to every matching email. Can be reverted using "Revert Last Run".'
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
