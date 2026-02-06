import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:spam_filter_mobile/adapters/auth/google_auth_service.dart';
import 'package:spam_filter_mobile/adapters/auth/token_store.dart';
import 'package:spam_filter_mobile/adapters/auth/secure_token_store.dart';
import 'package:spam_filter_mobile/adapters/email_providers/gmail_windows_oauth_handler.dart';
import 'package:spam_filter_mobile/adapters/storage/secure_credentials_store.dart';
import 'package:spam_filter_mobile/adapters/email_providers/email_provider.dart';
import 'package:spam_filter_mobile/ui/screens/folder_selection_screen.dart';
import 'package:spam_filter_mobile/util/redact.dart';

/// Manual token entry for Gmail OAuth (fallback option)
/// 
/// This screen allows users to manually paste OAuth tokens obtained
/// from Google's OAuth 2.0 Playground or other sources.
/// 
/// This is the last resort option when:
/// - Browser-based OAuth doesn't work
/// - WebView OAuth doesn't work
/// - User prefers manual control
class GmailManualTokenScreen extends StatefulWidget {
  final String platformId;

  const GmailManualTokenScreen({
    super.key,
    required this.platformId,
  });

  @override
  State<GmailManualTokenScreen> createState() => _GmailManualTokenScreenState();
}

class _GmailManualTokenScreenState extends State<GmailManualTokenScreen> {
  final Logger _logger = Logger();
  final SecureTokenStore _tokenStore = SecureTokenStore();
  final _formKey = GlobalKey<FormState>();
  final _accessTokenController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;

  @override
  void dispose() {
    _accessTokenController.dispose();
    _refreshTokenController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accessToken = _accessTokenController.text.trim();
      final refreshToken = _refreshTokenController.text.trim();

      Redact.logSafe('Validating manually entered OAuth tokens');

      // Validate access token by fetching user email
      final email = await GmailWindowsOAuthHandler.getUserEmail(accessToken);

      // Save tokens using SecureTokenStore (new OAuth architecture)
      final accountId = 'gmail-$email';
      final tokens = GmailTokens(
        accessToken: accessToken,
        refreshToken: refreshToken.isNotEmpty ? refreshToken : null,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        grantedScopes: GmailScopes.defaultScopes,
        email: email,
      );
      await _tokenStore.saveTokens(accountId, tokens);

      // Also save to legacy SecureCredentialsStore for compatibility
      final credentialsStore = SecureCredentialsStore();
      final credentials = Credentials(email: email, password: '', accessToken: accessToken);
      await credentialsStore.saveCredentials(email, credentials, platformId: widget.platformId);

      Redact.logSafe('Gmail manual token entry successful for ${Redact.email(email)}');

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
                _logger.i('Folders selected after manual token entry: $folders');
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      Redact.logError('Manual token validation failed', e);
      _logger.e('Stack trace', stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Token validation failed. Please verify your tokens are correct and try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Token Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInstructions(),
              const SizedBox(height: 24),
              _buildAccessTokenField(),
              const SizedBox(height: 16),
              _buildRefreshTokenField(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorMessage(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'How to Get OAuth Tokens',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Follow these steps to obtain your Gmail OAuth tokens:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              '1',
              'Visit OAuth 2.0 Playground',
              'https://developers.google.com/oauthplayground/',
            ),
            _buildInstructionStep(
              '2',
              'In Step 1, select "Gmail API v1" and check:',
              'https://www.googleapis.com/auth/gmail.modify',
            ),
            _buildInstructionStep(
              '3',
              'Click "Authorize APIs" and sign in with your Gmail account',
            ),
            _buildInstructionStep(
              '4',
              'In Step 2, click "Exchange authorization code for tokens"',
            ),
            _buildInstructionStep(
              '5',
              'Copy the "Access token" and "Refresh token" values',
            ),
            _buildInstructionStep(
              '6',
              'Paste them into the fields below',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Security Warning: Keep your tokens secure and never share them with anyone!',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text, [String? detail]) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 14)),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: InkWell(
                      onTap: detail.startsWith('http') ? () {
                        Clipboard.setData(ClipboardData(text: detail));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } : null,
                      child: Text(
                        detail,
                        style: TextStyle(
                          color: detail.startsWith('http') ? Colors.blue : Colors.grey.shade700,
                          decoration: detail.startsWith('http') ? TextDecoration.underline : null,
                          fontSize: 12,
                          fontFamily: detail.startsWith('http') ? null : 'monospace',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessTokenField() {
    return TextFormField(
      controller: _accessTokenController,
      decoration: InputDecoration(
        labelText: 'Access Token *',
        hintText: 'Paste your access token here',
        border: const OutlineInputBorder(),
        helperText: 'Required - Expires after ~1 hour',
        prefixIcon: const Icon(Icons.key),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
              tooltip: _showPassword ? 'Hide token' : 'Show token',
            ),
            IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _accessTokenController.text = data!.text!;
                }
              },
              tooltip: 'Paste from clipboard',
            ),
          ],
        ),
      ),
      obscureText: !_showPassword,
      maxLines: _showPassword ? 3 : 1,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Access token is required';
        }
        if (value.trim().length < 20) {
          return 'Invalid access token format (too short)';
        }
        return null;
      },
    );
  }

  Widget _buildRefreshTokenField() {
    return TextFormField(
      controller: _refreshTokenController,
      decoration: InputDecoration(
        labelText: 'Refresh Token (Recommended)',
        hintText: 'Paste your refresh token here',
        border: const OutlineInputBorder(),
        helperText: 'Optional - Allows automatic token renewal',
        prefixIcon: const Icon(Icons.refresh),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
              tooltip: _showPassword ? 'Hide token' : 'Show token',
            ),
            IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _refreshTokenController.text = data!.text!;
                }
              },
              tooltip: 'Paste from clipboard',
            ),
          ],
        ),
      ),
      obscureText: !_showPassword,
      maxLines: _showPassword ? 2 : 1,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline),
                SizedBox(width: 8),
                Text('Validate & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
