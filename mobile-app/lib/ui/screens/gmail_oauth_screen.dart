import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../../adapters/auth/google_auth_service.dart';
import '../../adapters/email_providers/email_provider.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../screens/gmail_webview_oauth_screen.dart';
import '../../screens/gmail_manual_token_screen.dart';
import '../../util/redact.dart';
import 'folder_selection_screen.dart';
import 'scan_progress_screen.dart';

/// Gmail OAuth authentication screen
/// Handles Google Sign-In flow and credential storage
/// Phase 2 Sprint 4 Implementation
class GmailOAuthScreen extends StatefulWidget {
  final String platformId;

  const GmailOAuthScreen({
    Key? key,
    required this.platformId,
  }) : super(key: key);

  @override
  State<GmailOAuthScreen> createState() => _GmailOAuthScreenState();
}

class _GmailOAuthScreenState extends State<GmailOAuthScreen> {
  final GoogleAuthService _authService = GoogleAuthService();
  final Logger _logger = Logger();
  bool _isSigningIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Check if running on Windows - show OAuth options dialog
    // On Android, let user choose from buttons (no auto-launch)
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWindowsOAuthOptions();
      });
    }
  }

  /// Show Windows-specific OAuth method selection dialog
  void _showWindowsOAuthOptions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Choose Authentication Method'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gmail OAuth on Windows requires one of these methods:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildOAuthOption(
                icon: Icons.web,
                title: 'Browser OAuth (Recommended)',
                description: 'Sign in using your system browser',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _handleBrowserOAuth();
                },
              ),
              const SizedBox(height: 8),
              _buildOAuthOption(
                icon: Icons.phone_android,
                title: 'WebView OAuth',
                description: 'Sign in within the app',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _handleWebViewOAuth();
                },
              ),
              const SizedBox(height: 8),
              _buildOAuthOption(
                icon: Icons.vpn_key,
                title: 'Manual Token Entry',
                description: 'Paste OAuth tokens manually',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _handleManualTokenEntry();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Show alternate OAuth methods on non-Windows platforms
  void _showAlternateOAuthOptions() {
    // On Windows, reuse the existing three-option dialog
    if (Platform.isWindows) {
      _showWindowsOAuthOptions();
      return;
    }

    // For Android/iOS, provide WebView and Manual Token fallbacks
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Alternate Sign-In Methods'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'If Google Sign-In is unresponsive in this emulator, try one of these:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildOAuthOption(
                icon: Icons.phone_android,
                title: 'WebView OAuth',
                description: 'Authenticate within the app using WebView',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _handleWebViewOAuth();
                },
              ),
              const SizedBox(height: 8),
              _buildOAuthOption(
                icon: Icons.vpn_key,
                title: 'Manual Token Entry',
                description: 'Paste OAuth tokens generated in Google OAuth Playground',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _handleManualTokenEntry();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build an OAuth method option button
  Widget _buildOAuthOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  /// Handle browser-based OAuth (primary method for Windows)
  Future<void> _handleBrowserOAuth() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      Redact.logSafe('Starting browser-based OAuth via GoogleAuthService');
      
      // Use GoogleAuthService for unified auth flow
      final result = await _authService.signIn();

      if (!mounted) return;

      if (!result.success || result.email == null || result.accessToken == null) {
        Redact.logSafe('Browser OAuth cancelled or failed');
        setState(() {
          _errorMessage = result.errorMessage ?? 'Authentication cancelled';
          _isSigningIn = false;
        });
        return;
      }

      final email = result.email!;

      // UNIFIED STORAGE FIX: GoogleAuthService already saved Gmail tokens - just save platformId
      final accountId = email;
      final credStore = SecureCredentialsStore();

      // Save platformId only (GoogleAuthService already saved tokens and added to account list)
      // This avoids the race condition where duplicate storage calls could cause account loss
      await credStore.savePlatformId(accountId, widget.platformId);

      Redact.logSafe('Gmail OAuth successful for ${Redact.email(email)}');

      // Initialize scan provider and navigate to folder selection
      final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
      scanProvider.reset();

      if (!mounted) return;

      final selectedFolders = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (context) => FolderSelectionScreen(
            platformId: widget.platformId,
            accountId: accountId,
            accountEmail: email,
            onFoldersSelected: (folders) {
              _logger.i('Folders selected after browser OAuth: $folders');
            },
          ),
        ),
      );

      if (selectedFolders != null && selectedFolders.isNotEmpty && mounted) {
        // Navigate to scan progress screen instead of just popping back
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ScanProgressScreen(
              platformId: widget.platformId,
              platformDisplayName: 'Gmail',
              accountId: accountId,
              accountEmail: email,
            ),
          ),
        );
      } else if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    } catch (e, stackTrace) {
      Redact.logError('Browser OAuth failed', e);
      _logger.e('Browser OAuth failed', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = 'Browser authentication failed: ${e.toString()}';
          _isSigningIn = false;
        });
      }
    }
  }

  /// Handle WebView OAuth (backup method for Windows)
  void _handleWebViewOAuth() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GmailWebViewOAuthScreen(
          platformId: widget.platformId,
        ),
      ),
    );
  }

  /// Handle manual token entry (fallback method for Windows)
  void _handleManualTokenEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GmailManualTokenScreen(
          platformId: widget.platformId,
        ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      Redact.logSafe('Starting Gmail OAuth sign-in via GoogleAuthService...');
      
      // Use GoogleAuthService for unified native sign-in
      final result = await _authService.signIn();

      if (!mounted) return;

      if (result.success && result.email != null) {
        Redact.logSafe('Gmail OAuth successful for ${Redact.email(result.email!)}');
        
        // Save OAuth credentials for legacy compatibility
        final credStore = SecureCredentialsStore();
        final accountId = result.email!;

        try {
          // GoogleAuthService already saved Gmail tokens - just save platformId
          await credStore.savePlatformId(accountId, widget.platformId);
          Redact.logSafe('Saved platformId for ${Redact.accountId(accountId)}');
        } catch (e) {
          Redact.logError('Error saving platformId', e);
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to save credentials: $e';
              _isSigningIn = false;
            });
          }
          return;
        }

        // Initialize scan provider
        final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
        scanProvider.reset();

        // Navigate to folder selection and bubble success upward
        if (mounted) {
          final selectedFolders = await Navigator.push<List<String>>(
            context,
            MaterialPageRoute(
              builder: (context) => FolderSelectionScreen(
                platformId: widget.platformId,
                accountId: accountId,
                accountEmail: result.email!,
                onFoldersSelected: (folders) {
                  _logger.i('Folders selected after OAuth: $folders');
                },
              ),
            ),
          );

          if (selectedFolders != null && selectedFolders.isNotEmpty && mounted) {
            // Navigate to scan progress screen instead of just popping back
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ScanProgressScreen(
                  platformId: widget.platformId,
                  platformDisplayName: 'Gmail',
                  accountId: accountId,
                  accountEmail: result.email!,
                ),
              ),
            );
          } else if (mounted) {
            setState(() {
              _isSigningIn = false;
            });
          }
        }
      } else {
        Redact.logSafe('Gmail sign-in failed or was cancelled');
        setState(() {
          _errorMessage = result.errorMessage ?? 'Sign-in was cancelled or failed';
          _isSigningIn = false;
        });
      }
    } catch (e) {
      Redact.logError('Gmail sign-in exception', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isSigningIn = false;
        });
        // Offer alternate methods when native Google Sign-In fails
        _showAlternateOAuthOptions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gmail Sign-In'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Gmail Logo
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red[50],
                ),
                child: Icon(
                  Icons.email,
                  size: 80,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Sign in with Gmail',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'You\'ll be redirected to Google sign-in to authorize access to your Gmail account securely.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Sign-in button or loading indicator
              if (_isSigningIn)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Redirecting to authentication...'),
                    ],
                  ),
                )
              else if (Platform.isAndroid)
                // On Android, show OAuth methods - native with appauth fallback is primary
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _handleSignIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Google Sign-In (OAuth 2.0)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _handleManualTokenEntry,
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Manual Token Entry'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: _handleSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),

              // Alternate methods helper (Windows/other platforms)
              if (!Platform.isAndroid) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _showAlternateOAuthOptions,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Trouble signing in? Try WebView or manual tokens'),
                ),
              ],

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sign-In Error',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Privacy notice
              _buildPrivacyNotice(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Privacy & Security',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Your Gmail credentials are never stored on this device\n'
            '• OAuth tokens are managed securely by Google\n'
            '• Only email reading and modification permissions are requested\n'
            '• You can revoke access anytime in your Google Account settings\n'
            '• This app processes emails locally, never syncs to external servers\n'
            '• All rule evaluation happens on your device',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[900],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Note: Gmail adapter is passed to EmailScanProvider via FolderSelectionScreen
    // Don't disconnect here - it will be managed by scan flow
    super.dispose();
  }
}
