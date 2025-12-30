import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

/// Handles Gmail OAuth for Windows platform using browser-based flow
///
/// Uses OAuth 2.0 Authorization Code with PKCE and a loopback
/// redirect (http://localhost:8080/oauth/callback). No client secret.
class GmailWindowsOAuthHandler {
  static final Logger _logger = Logger();
  static final FlutterAppAuth _appAuth = FlutterAppAuth();

  // OAuth 2.0 Configuration - injected at build time via --dart-define
  // Read from compile-time environment (works on Android where Platform.environment is empty)
  static const String _clientId = String.fromEnvironment(
    'WINDOWS_GMAIL_DESKTOP_CLIENT_ID',
    defaultValue: String.fromEnvironment('GMAIL_DESKTOP_CLIENT_ID', defaultValue: 'YOUR_CLIENT_ID.apps.googleusercontent.com'),
  );
  static const String _clientSecret = String.fromEnvironment(
    'WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET',
    defaultValue: '',
  );
  static const String _redirectUri = String.fromEnvironment(
    'GMAIL_REDIRECT_URI',
    defaultValue: 'http://localhost:8080/oauth/callback',
  );
  
  // Android OAuth client ID (for flutter_appauth with custom scheme)
  static const String _androidClientId = '577022808534-0ejdbmoouklgtucjo3tooovn2pr01ga2.apps.googleusercontent.com';
  
  // Mobile redirect URI uses custom scheme based on reversed Android client ID
  static String get _mobileRedirectUri {
    // Format: com.googleusercontent.apps.<client_id_prefix>:/oauthredirect
    // For Android client ID: 577022808534-0ejdbmoouklgtucjo3tooovn2pr01ga2
    return 'com.googleusercontent.apps.577022808534-0ejdbmoouklgtucjo3tooovn2pr01ga2:/oauthredirect';
  }
  
  static const String _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/gmail.modify',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  // PKCE verifier for the current auth flow
  static String? _codeVerifier;

  // Log configuration on first use
  static bool _configLogged = false;
  static void _logConfig() {
    if (!_configLogged) {
      _configLogged = true;
      // Use warning level to ensure visibility in release builds
      _logger.w('OAuth Configuration:');
      _logger.w('  Client ID: ${_clientId}');
      _logger.w('  Client Secret: ${_clientSecret.isEmpty ? "(not set)" : "(set, ${_clientSecret.length} chars)"}');
      _logger.w('  Redirect URI: $_redirectUri');
      // Explicitly log which client ID is being used and why
      if (Platform.isWindows) {
        if (_clientId == '' || _clientId.startsWith('YOUR_CLIENT_ID')) {
          _logger.e('  ERROR: WINDOWS_GMAIL_DESKTOP_CLIENT_ID is missing or placeholder! Gmail OAuth will fail.');
        } else {
          _logger.i('  Using WINDOWS_GMAIL_DESKTOP_CLIENT_ID for Windows Gmail OAuth.');
        }
      }
      if (_clientId == '' || _clientId.startsWith('YOUR_CLIENT_ID')) {
        _logger.w('  WARNING: Using placeholder client ID! Build with --dart-define or --dart-define-from-file to inject real credentials.');
      }
    }
  }

  /// Start browser-based OAuth flow (loopback + PKCE)
  /// On desktop, uses localhost redirect with local HTTP server.
  /// On mobile, uses custom scheme redirect with app_links.
  static Future<Map<String, String>?> authenticateWithBrowser() async {
    // Check if we're on mobile (Android/iOS)
    final isMobile = Platform.isAndroid || Platform.isIOS;
    
    if (isMobile) {
      return await _authenticateWithBrowserMobile();
    } else {
      return await _authenticateWithBrowserDesktop();
    }
  }
  
  /// Desktop browser OAuth with localhost redirect
  static Future<Map<String, String>?> _authenticateWithBrowserDesktop() async {
    try {
      final authUrl = buildAuthorizationUrl(useMobileRedirect: false);
      _logger.d('Authorization URL: $authUrl');

      final uri = Uri.parse(authUrl);
      if (!await canLaunchUrl(uri)) {
        throw Exception('Could not launch browser for OAuth');
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // Start local server to capture OAuth callback
      final authCode = await _captureAuthorizationCode();
      if (authCode == null) {
        _logger.w('OAuth flow cancelled by user');
        return null;
      }

      final tokens = await exchangeCodeForTokens(authCode, useMobileRedirect: false);
      _logger.i('OAuth flow completed successfully');
      return tokens;
    } catch (e, stackTrace) {
      _logger.e('Browser OAuth failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Mobile browser OAuth with flutter_appauth
  static Future<Map<String, String>?> _authenticateWithBrowserMobile() async {
    try {
      _logger.i('[MobileOAuth] Starting browser-based OAuth for mobile with flutter_appauth...');
      _logger.i('[MobileOAuth] Android Client ID: $_androidClientId');
      _logger.i('[MobileOAuth] Redirect URI: $_mobileRedirectUri');
      
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _androidClientId,  // Use Android client ID for mobile
          _mobileRedirectUri,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: _authEndpoint,
            tokenEndpoint: _tokenEndpoint,
          ),
          scopes: _scopes,
          promptValues: ['consent'],
          additionalParameters: {
            'access_type': 'offline',
          },
        ),
      );
      
      if (result == null) {
        _logger.w('[MobileOAuth] OAuth flow cancelled by user');
        return null;
      }
      
      _logger.i('[MobileOAuth] OAuth flow completed successfully');
      return {
        'access_token': result.accessToken ?? '',
        'refresh_token': result.refreshToken ?? '',
        'token_type': result.tokenType ?? 'Bearer',
        'expires_in': result.accessTokenExpirationDateTime != null 
            ? result.accessTokenExpirationDateTime!.difference(DateTime.now()).inSeconds.toString()
            : '3600',
      };
    } catch (e, stackTrace) {
      _logger.e('[MobileOAuth] Browser OAuth failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Build OAuth authorization URL with PKCE (S256)
  static String buildAuthorizationUrl({bool useMobileRedirect = false}) {
    _logConfig();
    
    // Generate PKCE values for this flow
    _codeVerifier = _generateCodeVerifier();
    final codeChallenge = _codeChallengeS256(_codeVerifier!);
    
    final redirectUri = useMobileRedirect ? _mobileRedirectUri : _redirectUri;

    final params = <String, String>{
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scopes.join(' '),
      'access_type': 'offline', // Request refresh token
      'prompt': 'consent', // Force consent screen for refresh token
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final authUrl = '$_authEndpoint?$queryString';
    _logger.w('Authorization URL built: $authUrl');
    return authUrl;
  }

  /// Capture authorization code from OAuth callback
  static Future<String?> _captureAuthorizationCode() async {
    final completer = Completer<String?>();
    HttpServer? server;
    try {
      server = await HttpServer.bind('localhost', 8080);
      _logger.d('Local OAuth callback server started on port 8080');

      // Set timeout for user interaction (5 minutes)
      Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) {
          server?.close();
          completer.complete(null);
          _logger.w('OAuth callback timeout - no response after 5 minutes');
        }
      });

      server.listen((HttpRequest request) async {
        final uri = request.uri;
        if (uri.path == '/oauth/callback') {
          final code = uri.queryParameters['code'];
          final error = uri.queryParameters['error'];

          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(code != null
                ? '<html><head><title>Success</title></head><body style="font-family: Arial; text-align: center; padding: 50px;"><h1 style="color: #4CAF50;">✅ Authentication Successful!</h1><p>You can close this window and return to the app.</p></body></html>'
                : '<html><head><title>Error</title></head><body style="font-family: Arial; text-align: center; padding: 50px;"><h1 style="color: #f44336;">❌ Authentication Failed</h1><p>Error: ${error ?? "Unknown error"}</p><p>Please try again.</p></body></html>');
          await request.response.close();

          if (!completer.isCompleted) {
            server?.close();
            completer.complete(code);
          }
        }
      });
    } catch (e) {
      _logger.e('Failed to start OAuth callback server', error: e);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  /// Exchange authorization code for access and refresh tokens (PKCE)
  static Future<Map<String, String>> exchangeCodeForTokens(String authCode, {bool useMobileRedirect = false}) async {
    try {
      if (_codeVerifier == null) {
        throw Exception('PKCE code_verifier not initialized. Call buildAuthorizationUrl() first.');
      }

      _logger.d('Exchanging authorization code for tokens');

      _logConfig();
      
      final redirectUri = useMobileRedirect ? _mobileRedirectUri : _redirectUri;
      
      final requestBody = {
        'client_id': _clientId,
        'code': authCode,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': _codeVerifier!,
      };
      
      // Add client_secret if available (may be required by some OAuth configurations)
      if (_clientSecret.isNotEmpty) {
        requestBody['client_secret'] = _clientSecret;
        _logger.i('Including client_secret in token exchange');
      }
      
      _logger.i('Token exchange request body:');
      requestBody.forEach((key, value) {
        if (key == 'code_verifier' || key == 'client_secret') {
          _logger.i('  $key: ${value.substring(0, 20)}... (truncated)');
        } else {
          _logger.i('  $key: $value');
        }
      });

      // Manually construct and log the form body for debugging
      final formBody = requestBody.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      _logger.d('Form-encoded body (first 100 chars): ${formBody.substring(0, 100)}');

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: requestBody,
      );

      if (response.statusCode != 200) {
        _logger.e('Token exchange failed: ${response.statusCode} - ${response.body}');
        throw Exception('Token exchange failed: ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'access_token': (data['access_token'] ?? '') as String,
        'refresh_token': (data['refresh_token'] ?? '') as String,
        'token_type': (data['token_type'] ?? '') as String,
        'expires_in': (data['expires_in'] ?? '').toString(),
      };
    } catch (e) {
      _logger.e('Token exchange failed', error: e);
      rethrow;
    }
  }

  /// Refresh access token using refresh token (no client secret with PKCE)
  static Future<String> refreshAccessToken(String refreshToken) async {
    try {
      _logger.d('Refreshing access token');

      _logConfig();
      
      final body = <String, String>{
        'client_id': _clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      };

      // Include client_secret if present (some OAuth configurations require it)
      if (_clientSecret.isNotEmpty) {
        body['client_secret'] = _clientSecret;
        _logger.i('Including client_secret in token refresh');
      }

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode != 200) {
        _logger.e('Token refresh failed: ${response.statusCode} - ${response.body}');
        throw Exception('Token refresh failed: ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['access_token'] ?? '') as String;
    } catch (e) {
      _logger.e('Token refresh failed', error: e);
      rethrow;
    }
  }

  /// Validate access token and get user email
  static Future<String> getUserEmail(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v1/userinfo?alt=json'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (data['email'] ?? '') as String;
      } else {
        throw Exception('Failed to fetch user email: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to get user email', error: e);
      rethrow;
    }
  }

  // --- PKCE helpers ---
  static String _generateCodeVerifier({int length = 64}) {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  static String _codeChallengeS256(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    // Base64 URL-safe without padding
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
