import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:logger/logger.dart';
import 'package:spam_filter_mobile/adapters/auth/google_auth_service.dart';
import 'package:spam_filter_mobile/adapters/auth/token_store.dart';
import 'package:spam_filter_mobile/adapters/auth/secure_token_store.dart';
import 'package:spam_filter_mobile/adapters/email_providers/gmail_windows_oauth_handler.dart';
import 'package:spam_filter_mobile/adapters/storage/secure_credentials_store.dart';
import 'package:spam_filter_mobile/adapters/email_providers/email_provider.dart';
import 'package:spam_filter_mobile/ui/screens/folder_selection_screen.dart';
import 'package:spam_filter_mobile/util/redact.dart';

/// WebView-based Gmail OAuth for Windows (backup approach)
/// 
/// This screen provides an embedded WebView OAuth flow as a backup option
/// when the browser-based approach is not preferred or doesn't work.
/// 
/// The WebView intercepts the OAuth callback URL and extracts the
/// authorization code to complete the authentication flow.
class GmailWebViewOAuthScreen extends StatefulWidget {
  final String platformId;

  const GmailWebViewOAuthScreen({
    super.key,
    required this.platformId,
  });

  @override
  State<GmailWebViewOAuthScreen> createState() => _GmailWebViewOAuthScreenState();
}

class _GmailWebViewOAuthScreenState extends State<GmailWebViewOAuthScreen> {
  final Logger _logger = Logger();
  final SecureTokenStore _tokenStore = SecureTokenStore();
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _logger.d('WebView loading: $url');
            setState(() => _isLoading = true);
            _checkForOAuthCallback(url);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            _logger.e('WebView error: ${error.description}');
            setState(() {
              _errorMessage = 'Failed to load authentication page: ${error.description}';
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(GmailWindowsOAuthHandler.buildAuthorizationUrl()));
  }


  void _checkForOAuthCallback(String url) {
    final uri = Uri.parse(url);
    
    // Check if this is the OAuth callback
    if (uri.scheme == 'http' && uri.host == 'localhost' && uri.path == '/oauth/callback') {
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (code != null) {
        _handleAuthorizationCode(code);
      } else if (error != null) {
        Redact.logSafe('OAuth error: $error');
        setState(() {
          _errorMessage = 'Authentication failed: $error';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAuthorizationCode(String code) async {
    setState(() => _isLoading = true);

    try {
      Redact.logSafe('Exchanging authorization code from WebView');

      // Exchange code for tokens
      final tokenResult = await GmailWindowsOAuthHandler.exchangeCodeForTokens(code);
      
      // Get user email from profile
      final accessToken = tokenResult['access_token']!;
      final refreshToken = tokenResult['refresh_token'];
      final expiresInStr = tokenResult['expires_in'];
      final email = await GmailWindowsOAuthHandler.getUserEmail(accessToken);

      // Calculate expiry
      final expiresIn = int.tryParse(expiresInStr ?? '3600') ?? 3600;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      // Save tokens using SecureTokenStore (new OAuth architecture)
      final accountId = 'gmail-$email';
      final tokens = GmailTokens(
        accessToken: accessToken,
        refreshToken: refreshToken?.isNotEmpty == true ? refreshToken : null,
        expiresAt: expiresAt,
        grantedScopes: GmailScopes.defaultScopes,
        email: email,
      );
      await _tokenStore.saveTokens(accountId, tokens);

      // Also save to legacy SecureCredentialsStore for compatibility
      final credentialsStore = SecureCredentialsStore();
      final credentials = Credentials(email: email, password: '', accessToken: accessToken);
      await credentialsStore.saveCredentials(email, credentials, platformId: widget.platformId);

      Redact.logSafe('Gmail WebView OAuth successful for ${Redact.email(email)}');

      // Navigate to folder selection
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FolderSelectionScreen(
              platformId: widget.platformId,
              accountId: email,
              accountEmail: email,
              onFoldersSelected: (folders) {
                _logger.i('Folders selected after WebView OAuth: $folders');
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      Redact.logError('WebView OAuth failed', e);
      _logger.e('Stack trace', stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Authentication failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Google'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_errorMessage == null)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Try reloading
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _initializeWebView();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading authentication...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
