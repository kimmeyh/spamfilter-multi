import 'dart:async';
import 'dart:io' show Platform;
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../adapters/auth/google_auth_service.dart';
import '../../util/redact.dart';

import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import 'spam_filter_platform.dart';
import 'email_provider.dart';

/// Gmail adapter using OAuth 2.0 and Gmail REST API
/// Provides better performance than IMAP for Gmail accounts
/// Phase 2 Sprint 4 Implementation
/// 
/// Uses [GoogleAuthService] for unified authentication across platforms.
class GmailApiAdapter implements SpamFilterPlatform {
  final GoogleAuthService _authService = GoogleAuthService();

  late final Logger _logger;
  gmail.GmailApi? _gmailApi;
  String? _userEmail;
  bool _isConnected = false;

  GmailApiAdapter() {
    _logger = Logger();
  }

  @override
  String get platformId => 'gmail';

  @override
  String get displayName => 'Gmail';

  @override
  AuthMethod get supportedAuthMethod => AuthMethod.oauth2;

  // Connection state used internally
  bool get isConnected => _isConnected;

  /// Initialize Gmail OAuth flow
  /// Returns true if authentication successful
  /// 
  /// Uses [GoogleAuthService] for unified authentication across all platforms.
  Future<bool> signIn() async {
    try {
      Redact.logSafe('========================================');
      Redact.logSafe('GMAIL SIGN-IN: Starting OAuth 2.0 flow via GoogleAuthService');
      Redact.logSafe('Platform: ${Platform.operatingSystem}');
      Redact.logSafe('========================================');

      // Use GoogleAuthService for unified auth
      final result = await _authService.signIn();

      if (!result.success || result.email == null || result.accessToken == null) {
        Redact.logSafe('========================================');
        Redact.logSafe('GMAIL SIGN-IN FAILED: Authentication incomplete');
        Redact.logSafe('  → Success: ${result.success}');
        Redact.logSafe('  → Email: ${result.email != null ? Redact.email(result.email!) : "null"}');
        Redact.logSafe('  → Has token: ${result.accessToken != null}');
        Redact.logSafe('  → Error: ${result.errorMessage ?? "none"}');
        Redact.logSafe('========================================');
        return false;
      }

      _userEmail = result.email;
      final headers = {'Authorization': 'Bearer ${result.accessToken}'};
      _gmailApi = gmail.GmailApi(_GoogleAuthClient(headers));
      _isConnected = true;

      Redact.logSafe('========================================');
      Redact.logSafe('GMAIL SIGN-IN SUCCESS!');
      Redact.logSafe('  → Email: ${Redact.email(_userEmail!)}');
      Redact.logSafe('  → API client created');
      Redact.logSafe('  → Connected: $_isConnected');
      Redact.logSafe('========================================');
      return true;
    } catch (e, stackTrace) {
      Redact.logError('GMAIL SIGN-IN EXCEPTION: Unexpected error', e);
      _logger.e('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Sign out and clear credentials
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _gmailApi = null;
      _userEmail = null;
      _isConnected = false;
      Redact.logSafe('Signed out from Gmail');
    } catch (e) {
      Redact.logError('Error signing out from Gmail', e);
    }
  }

  @override
  Future<void> loadCredentials(Credentials credentials) async {
    // Windows desktop path: reuse stored access token from prior browser OAuth
    if (Platform.isWindows && (credentials.accessToken?.isNotEmpty ?? false)) {
      Redact.logSafe('Using stored access token for Windows Gmail session');
      final headers = {
        'Authorization': 'Bearer ${credentials.accessToken}',
      };
      _gmailApi = gmail.GmailApi(_GoogleAuthClient(headers));
      _userEmail = credentials.email;
      _isConnected = true;

      // Validate token; if invalid/expired, attempt refresh via GoogleAuthService
      try {
        await _gmailApi!.users.getProfile('me');
      } catch (e) {
        Redact.logSafe('Stored access token appears invalid; attempting refresh via GoogleAuthService...');
        
        // Try to get a valid token from GoogleAuthService
        final newAccessToken = await _authService.getValidAccessToken();
        
        if (newAccessToken == null || newAccessToken.isEmpty) {
          Redact.logSafe('Token refresh failed; attempting interactive re-authentication...');
          
          // Refresh failed - prompt user to re-authenticate via browser
          final result = await _authService.signIn();
          
          if (!result.success || result.accessToken == null) {
            throw AuthenticationException(
              'Gmail OAuth session expired. Please re-authenticate.',
            );
          }

          // Use new access token from re-auth
          final reAuthHeaders = {
            'Authorization': 'Bearer ${result.accessToken}',
          };
          _gmailApi = gmail.GmailApi(_GoogleAuthClient(reAuthHeaders));
          _userEmail = result.email;
          Redact.logSafe('Re-authentication successful: ${Redact.email(_userEmail ?? "")}');
          return;
        }

        // Rebuild API client with refreshed access token
        final refreshedHeaders = {
          'Authorization': 'Bearer $newAccessToken',
        };
        _gmailApi = gmail.GmailApi(_GoogleAuthClient(refreshedHeaders));
        Redact.logSafe('Access token refreshed successfully via GoogleAuthService');
      }
      return;
    }

    // Gmail uses OAuth via GoogleAuthService; we validate that the current session
    // is active and the email matches the loaded credentials.
    if (_gmailApi == null || !_isConnected) {
      // Attempt to initialize and restore session via GoogleAuthService
      // Pass the specific account email to initialize (not just first account)
      try {
        final result = await _authService.initialize(accountId: credentials.email);

        if (!result.success || result.accessToken == null) {
          throw AuthenticationException('Not authenticated with Google');
        }

        final headers = {'Authorization': 'Bearer ${result.accessToken}'};
        _gmailApi = gmail.GmailApi(_GoogleAuthClient(headers));
        _userEmail = result.email;
        _isConnected = true;
      } catch (e) {
        throw AuthenticationException('Gmail OAuth not established', e);
      }
    }

    if (credentials.email.isNotEmpty && _userEmail != null) {
      if (credentials.email.toLowerCase() != _userEmail!.toLowerCase()) {
        Redact.logSafe('Loaded credentials email does not match signed-in user');
      }
    }
  }

  @override
  Future<void> disconnect() async {
    // IMPORTANT: disconnect() should ONLY close the connection, NOT delete credentials
    // Credentials should only be deleted when user explicitly logs out
    // This allows scan operations to close connections without losing saved accounts
    _gmailApi = null;
    _userEmail = null;
    _isConnected = false;
    Redact.logSafe('Gmail connection closed (credentials preserved)');
  }

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    if (_gmailApi == null) {
      throw StateError('Not connected. Call signIn() first.');
    }

    try {
      Redact.logSafe('Fetching Gmail messages from: $folderNames');
      
      List<EmailMessage> emails = [];

      for (String folder in folderNames) {
        // Build Gmail query
        String query = _buildGmailQuery(folder: folder, daysBack: daysBack);
        Redact.logSafe('Gmail query for $folder: $query');
        gmail.ListMessagesResponse messagesResponse;
        Future<gmail.ListMessagesResponse> listMessages() {
          return _gmailApi!.users.messages.list(
            'me',
            q: query,
            maxResults: 100, // Fetch in batches of 100
          );
        }

        try {
          // List messages with query
          messagesResponse = await listMessages();
        } on gmail.DetailedApiRequestError catch (apiErr) {
          final msg = apiErr.message ?? '';
          final insufficientScopes = apiErr.status == 403 && msg.toLowerCase().contains('insufficient authentication scopes');
          if (Platform.isWindows && insufficientScopes) {
            Redact.logSafe('Insufficient Gmail scopes detected. Attempting re-auth via GoogleAuthService...');
            // Attempt to upgrade scopes via GoogleAuthService and retry once
            try {
              final result = await _authService.signIn();
              if (!result.success || result.accessToken == null) {
                throw AuthenticationException('User cancelled Gmail OAuth re-authentication');
              }

              final newAccess = result.accessToken!;

              // Rebuild API client with new access token and retry
              final refreshedHeaders = {
                'Authorization': 'Bearer $newAccess',
              };
              _gmailApi = gmail.GmailApi(_GoogleAuthClient(refreshedHeaders));
              Redact.logSafe('Re-authentication successful; retrying message list...');
              messagesResponse = await listMessages();
            } catch (reauthErr) {
              Redact.logError('Re-authentication to fix scopes failed', reauthErr);
              rethrow;
            }
          } else {
            rethrow;
          }
        }

        if (messagesResponse.messages == null || messagesResponse.messages!.isEmpty) {
          Redact.logSafe('No messages found in $folder');
          continue;
        }

        Redact.logSafe('Found ${messagesResponse.messages!.length} messages in $folder');

        // Fetch full message details in batch
        for (var message in messagesResponse.messages!) {
          try {
            final fullMessage = await _gmailApi!.users.messages.get(
              'me',
              message.id!,
              format: 'full',
            );

            final emailMessage = _convertGmailMessage(fullMessage, folder);
            if (emailMessage != null) {
              emails.add(emailMessage);
            }
          } catch (e) {
            Redact.logError('Error fetching Gmail message ${message.id}', e);
          }
        }
      }

      Redact.logSafe('Successfully fetched ${emails.length} Gmail messages');
      return emails;
    } catch (e) {
      Redact.logError('Error fetching Gmail messages', e);
      rethrow;
    }
  }

  /// Delete a Gmail message by moving it to trash.
  Future<void> deleteMessage(EmailMessage message) async {
    if (_gmailApi == null) {
      throw StateError('Not connected. Call signIn() first.');
    }

    try {
      await _gmailApi!.users.messages.trash('me', message.id);
      Redact.logSafe('Gmail message ${message.id} moved to trash');
    } catch (e) {
      Redact.logError('Error deleting Gmail message', e);
      rethrow;
    }
  }

  /// Move a Gmail message to a target folder/label.
  Future<void> moveMessage(EmailMessage message, String targetFolder) async {
    if (_gmailApi == null) {
      throw StateError('Not connected. Call signIn() first.');
    }

    try {
      // Map folder name to Gmail label
      String labelId = _folderToLabelId(targetFolder);

      // Modify message labels
      await _gmailApi!.users.messages.modify(
        gmail.ModifyMessageRequest(
          removeLabelIds: ['INBOX'],
          addLabelIds: [labelId],
        ),
        'me',
        message.id,
      );

      Redact.logSafe('Gmail message ${message.id} moved to $targetFolder (label: $labelId)');
    } catch (e) {
      Redact.logError('Error moving Gmail message', e);
      rethrow;
    }
  }

  @override
  Future<List<FolderInfo>> listFolders() async {
    if (_gmailApi == null) {
      throw StateError('Not connected. Call signIn() first.');
    }

    try {
      final labelsResponse = await _gmailApi!.users.labels.list('me');
      
      List<FolderInfo> folders = [];
      if (labelsResponse.labels != null) {
        for (var label in labelsResponse.labels!) {
          final name = label.name ?? 'Unknown';
          // Map common Gmail labels to canonical names
          CanonicalFolder canonical;
          switch (name.toUpperCase()) {
            case 'INBOX':
              canonical = CanonicalFolder.inbox;
              break;
            case 'SPAM':
            case 'JUNK':
              canonical = CanonicalFolder.junk;
              break;
            case 'TRASH':
              canonical = CanonicalFolder.trash;
              break;
            case 'SENT':
              canonical = CanonicalFolder.sent;
              break;
            case 'DRAFTS':
            case 'DRAFT':
              canonical = CanonicalFolder.drafts;
              break;
            case 'ARCHIVE':
            case 'ALL MAIL':
              canonical = CanonicalFolder.archive;
              break;
            default:
              canonical = CanonicalFolder.custom;
          }

          folders.add(FolderInfo(
            id: label.id ?? name,
            displayName: name,
            canonicalName: canonical,
            messageCount: label.messagesTotal,
            isWritable: true,
          ));
        }
      }

      Redact.logSafe('Listed ${folders.length} Gmail labels');
      return folders;
    } catch (e) {
      Redact.logError('Error listing Gmail labels', e);
      rethrow;
    }
  }

  @override
  Future<ConnectionStatus> testConnection() async {
    try {
      Redact.logSafe('Testing Gmail OAuth connection...');
      
      if (!_isConnected || _gmailApi == null) {
        return ConnectionStatus.failure('Not signed in. Call signIn() first.');
      }

      // Try to fetch user profile (minimal operation)
      final profile = await _gmailApi!.users.getProfile('me');
      return ConnectionStatus.success(serverInfo: {
        'email': profile.emailAddress,
        'messagesTotal': profile.messagesTotal,
        'threadsTotal': profile.threadsTotal,
      });
    } catch (e) {
      Redact.logError('Gmail connection test failed', e);
      return ConnectionStatus.failure('Connection test failed: $e');
    }
  }

  /// Build Gmail API query string
  String _buildGmailQuery({
    required String folder,
    int daysBack = 365,
  }) {
    List<String> queryParts = [];

    // Map folder to Gmail label query
    if (folder.toUpperCase() == 'INBOX') {
      queryParts.add('in:inbox');
    } else if (folder.toLowerCase() == 'spam' || folder.toLowerCase() == 'junk') {
      queryParts.add('in:spam');
    } else if (folder.toLowerCase() == 'trash') {
      queryParts.add('in:trash');
    } else if (folder.toLowerCase() == 'sent') {
      queryParts.add('in:sent');
    } else if (folder.toLowerCase() == 'drafts') {
      queryParts.add('in:draft');
    } else {
      // Custom label - include in search
      queryParts.add('label:$folder');
    }

    // Add date filter (days back)
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
    final dateStr = '${cutoffDate.year}/${cutoffDate.month.toString().padLeft(2, '0')}/${cutoffDate.day.toString().padLeft(2, '0')}';
    queryParts.add('after:$dateStr');

    return queryParts.join(' ');
  }

  /// Extract email address from "Name <email@domain.com>" format
  /// Returns just the email address for consistency with IMAP behavior
  String _extractEmail(String fromHeader) {
    if (fromHeader.isEmpty) return '';
    
    // Match email in angle brackets: "Name <email@domain.com>"
    final angleMatch = RegExp(r'<([^>]+)>').firstMatch(fromHeader);
    if (angleMatch != null) {
      return angleMatch.group(1) ?? '';
    }
    
    // If no angle brackets, assume it's already just an email
    return fromHeader;
  }

  /// Convert Gmail message to EmailMessage
  EmailMessage? _convertGmailMessage(
    gmail.Message gmailMessage,
    String folderName,
  ) {
    try {
      final headers = gmailMessage.payload?.headers ?? [];
      
      String getHeader(String name) {
        return headers
            .firstWhere(
              (h) => h.name?.toLowerCase() == name.toLowerCase(),
              orElse: () => gmail.MessagePartHeader(name: name, value: ''),
            )
            .value ??
            '';
      }

      // Extract body (prefer text/plain)
      String body = '';
      if (gmailMessage.payload?.body?.data != null) {
        body = gmailMessage.payload!.body!.data!;
      } else if (gmailMessage.payload?.parts != null) {
        for (var part in gmailMessage.payload!.parts!) {
          if (part.mimeType == 'text/plain' && part.body?.data != null) {
            body = part.body!.data!;
            break;
          }
        }
      }

      // Parse date more robustly
      DateTime parsedDate;
      try {
        parsedDate = DateTime.tryParse(getHeader('Date')) ?? DateTime.now();
      } catch (e) {
        parsedDate = DateTime.now();
      }

      return EmailMessage(
        id: gmailMessage.id ?? '',
        from: _extractEmail(getHeader('From')),
        subject: getHeader('Subject'),
        body: body,
        headers: {
          for (var header in headers) header.name ?? '': header.value ?? '',
        },
        receivedDate: parsedDate,
        folderName: folderName,
      );
    } catch (e) {
      Redact.logError('Error converting Gmail message', e);
      return null;
    }
  }

  /// Map folder name to Gmail label ID
  String _folderToLabelId(String folder) {
    switch (folder.toUpperCase()) {
      case 'INBOX':
        return 'INBOX';
      case 'SPAM':
      case 'JUNK':
        return 'SPAM';
      case 'TRASH':
        return 'TRASH';
      case 'SENT':
        return 'SENT';
      case 'DRAFTS':
        return 'DRAFT';
      default:
        return folder; // Assume it's a custom label
    }
  }

  @override
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  }) async {
    // Default client-side regex evaluation; Gmail server-side filters are not used here.
    final results = <EvaluationResult>[];
    for (final msg in messages) {
      String? matchedRule;
      String? matchedPattern;
      for (final entry in compiledRegex.entries) {
        final ruleName = entry.key;
        final pattern = entry.value;
        final fromValue = msg.headers['From'] ?? msg.from;
        if (pattern.allMatches(msg.subject).isNotEmpty ||
            pattern.allMatches(msg.body).isNotEmpty ||
            (fromValue).contains(pattern.toString())) {
          matchedRule = ruleName;
          matchedPattern = pattern.toString();
          break;
        }
      }

      if (matchedRule == null || matchedRule.isEmpty) {
        results.add(EvaluationResult.noMatch());
      } else {
        // Simple policy: delete on match; adjust if project expects move
        results.add(EvaluationResult(
          shouldDelete: true,
          shouldMove: false,
          matchedRule: matchedRule,
          matchedPattern: matchedPattern ?? '',
        ));
      }
    }
    return results;
  }

  @override
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  }) async {
    switch (action) {
      case FilterAction.delete:
        await deleteMessage(message);
        return;
      case FilterAction.moveToJunk:
        await moveMessage(message, 'SPAM');
        return;
      case FilterAction.moveToFolder:
        // Requires target folder; handled by higher-level flow. No-op here.
        _logger.w('moveToFolder requires target folder; skipping');
        return;
      case FilterAction.markAsRead:
        // Mark read via modify
        if (_gmailApi == null) throw StateError('Not connected');
        await _gmailApi!.users.messages.modify(
          gmail.ModifyMessageRequest(removeLabelIds: ['UNREAD']),
          'me',
          message.id,
        );
        return;
      case FilterAction.markAsSpam:
        await moveMessage(message, 'SPAM');
        return;
    }
  }

  /// Get user's email address
  String? get userEmail => _userEmail;

  // Backwards compatibility: some tests expect `connect(credentials)`
  Future<void> connect(Credentials credentials) async {
    await loadCredentials(credentials);
  }

  /// Check if an email still exists (for availability tracking)
  ///
  /// Uses Gmail API messages.get with minimal fields to verify email exists
  /// Returns true if email found, false if deleted
  Future<bool> checkEmailExists(String messageId) async {
    try {
      if (_gmailApi == null) {
        _logger.w('Gmail API not initialized for availability check');
        return false;
      }

      // Try to get the message with minimal fields
      // This is fast and only checks existence
      await _gmailApi!.users.messages.get(
        'me',
        messageId,
        format: 'minimal',
      );

      // If we get here, the message exists
      _logger.d('Email $messageId still exists');
      return true;
    } catch (e) {
      // If we get 404 or similar, message is deleted
      if (e.toString().contains('404') || e.toString().contains('notFound')) {
        _logger.d('Email $messageId is deleted');
        return false;
      }

      // For other errors, log and assume deleted (safe approach)
      _logger.e('Error checking email existence: $e');
      return false;
    }
  }
}

/// HTTP client with Google auth headers
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

