/// Generic IMAP email provider adapter
/// 
/// This adapter provides IMAP support for multiple email providers:
/// - AOL Mail (MVP Phase 1)
/// - Yahoo Mail
/// - iCloud Mail
/// - Any custom IMAP server
/// 
/// Uses the `enough_mail` package for IMAP protocol implementation.
library;

import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:logger/logger.dart';

import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import 'spam_filter_platform.dart';
import 'email_provider.dart';

/// Generic IMAP implementation for multiple email providers
class GenericIMAPAdapter implements SpamFilterPlatform {
  final String _imapHost;
  final int _imapPort;
  final bool _isSecure;
  final Logger _logger = Logger();

  @override
  final String platformId;

  @override
  final String displayName;

  @override
  AuthMethod get supportedAuthMethod => AuthMethod.appPassword;

  ImapClient? _imapClient;
  String? _currentMailbox;
  Credentials? _credentials;
  String? _deletedRuleFolder; // Folder to move deleted emails to (null = use default 'Trash')

  /// Create a generic IMAP adapter with custom settings
  GenericIMAPAdapter({
    required String imapHost,
    int imapPort = 993,
    bool isSecure = true,
    String? displayName,
    String? platformId,
  })  : _imapHost = imapHost,
        _imapPort = imapPort,
        _isSecure = isSecure,
        displayName = displayName ?? 'IMAP Server',
        platformId = platformId ?? 'imap';

  /// Factory constructor for AOL Mail (Phase 1 MVP)
  factory GenericIMAPAdapter.aol() {
    return GenericIMAPAdapter(
      imapHost: 'imap.aol.com',
      imapPort: 993,
      isSecure: true,
      displayName: 'AOL Mail',
      platformId: 'aol',
    );
  }

  /// Factory constructor for Yahoo Mail
  factory GenericIMAPAdapter.yahoo() {
    return GenericIMAPAdapter(
      imapHost: 'imap.mail.yahoo.com',
      imapPort: 993,
      isSecure: true,
      displayName: 'Yahoo Mail',
      platformId: 'yahoo',
    );
  }

  /// Factory constructor for iCloud Mail
  factory GenericIMAPAdapter.icloud() {
    return GenericIMAPAdapter(
      imapHost: 'imap.mail.me.com',
      imapPort: 993,
      isSecure: true,
      displayName: 'iCloud Mail',
      platformId: 'icloud',
    );
  }

  /// Factory constructor for custom IMAP server
  factory GenericIMAPAdapter.custom({
    String imapHost = '',
    int imapPort = 993,
    bool isSecure = true,
  }) {
    return GenericIMAPAdapter(
      imapHost: imapHost,
      imapPort: imapPort,
      isSecure: isSecure,
      displayName: 'Custom IMAP',
      platformId: 'imap',
    );
  }

  @override
  void setDeletedRuleFolder(String? folderName) {
    _deletedRuleFolder = folderName;
    _logger.d('Set deleted rule folder to: ${folderName ?? "Trash (default)"}');
  }

  @override
  Future<void> loadCredentials(Credentials credentials) async {
    try {
      _credentials = credentials;
      _imapClient = ImapClient(isLogEnabled: false);

      _logger.i('[IMAP] Connecting to $_imapHost:$_imapPort (secure: $_isSecure)');

      // NOTE: enough_mail ImapClient.connectToServer() does not support securityContext parameter.
      // Use default SSL/TLS certificate validation provided by Dart's dart:io.
      // For standard email providers (AOL, Gmail, Yahoo, Outlook), this is secure and reliable.
      // 
      // If custom certificate pinning is needed in future, can be implemented via:
      // 1. Post-connection socket inspection
      // 2. Custom IMAP wrapper with certificate validation
      // 3. Upgrade to dedicated secure IMAP library (Phase 3+)
      //
      // REMOVED: SecurityContext creation and custom certificate handling (not supported by enough_mail)
      // REMOVED: Custom certificate file loading from assets
      // REMOVED: Bad certificate override handler (dangerous for production)

      await _imapClient!.connectToServer(
        _imapHost,
        _imapPort,
        isSecure: _isSecure,
      );

      // Debug: Log email and masked password before login
        final maskedPassword = credentials.password != null
          ? credentials.password!.replaceAll(RegExp('.'), '*').substring(0, credentials.password!.length > 4 ? 4 : credentials.password!.length) + '...'
          : '(none)';
      _logger.i('[IMAP] IMAP login attempt: email="${credentials.email}", password="$maskedPassword"');

      await _imapClient!.login(
        credentials.email,
        credentials.password ?? '',
      );

      _logger.i('[IMAP] Successfully authenticated to $displayName');
    } catch (e) {
      _logger.e('[IMAP] Failed to load credentials: $e');
      if (e is AuthenticationException) {
        // Propagate explicit authentication failures
        rethrow;
      }

      // Map handshake and network errors to connection failures so the UI
      // reports the real root cause instead of "Authentication failed".
      if (e is HandshakeException) {
        throw ConnectionException('TLS certificate validation failed', e);
      }
      if (e is SocketException || e is TimeoutException) {
        throw ConnectionException('Network connection failed', e);
      }

      // Fallback: treat other errors as connection failures
      throw ConnectionException('IMAP connection failed', e);
    }
  }

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    if (_imapClient == null) {
      throw ConnectionException('Not connected - call loadCredentials first');
    }

    final messages = <EmailMessage>[];
    final sinceDate = daysBack > 0
        ? DateTime.now().subtract(Duration(days: daysBack))
        : null;

    _logger.i('Fetching messages from ${daysBack > 0 ? "$daysBack days back" : "all time"} in folders: $folderNames');

    for (final folderName in folderNames) {
      try {
        await _selectMailbox(folderName);

        // Use IMAP SEARCH command with date filter or ALL
        final searchCriteria = sinceDate != null
            ? 'SINCE ${_formatImapDate(sinceDate)}'
            : 'ALL';
        _logger.d('Searching with criteria: $searchCriteria');

        final searchResult = await _imapClient!.searchMessages(
          searchCriteria: searchCriteria,
        );

        if (searchResult.matchingSequence == null ||
            searchResult.matchingSequence!.isEmpty) {
          _logger.i('No messages found in $folderName');
          continue;
        }

        _logger.i('Found ${searchResult.matchingSequence!.length} messages in $folderName');

        // Fetch message details in batches
        final fetchedMessages = await _fetchMessageDetails(
          searchResult.matchingSequence!,
          folderName,
        );

        messages.addAll(fetchedMessages);
      } catch (e) {
        _logger.e('Error fetching from $folderName: $e');
        // Continue with other folders even if one fails
      }
    }

    _logger.i('Total messages fetched: ${messages.length}');
    return messages;
  }

  @override
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  }) async {
    // IMAP does not support server-side regex filtering,
    // so we use the client-side RuleEvaluator
    _logger.i('Applying rules to ${messages.length} messages (client-side)');

    final results = <EvaluationResult>[];

    for (final _ in messages) {
      // Note: This is a simplified version. In production, you would:
      // 1. Load the actual rule sets from YAML
      // 2. Use the PatternCompiler to create regex patterns
      // 3. Pass those to the RuleEvaluator
      // For now, this demonstrates the interface
      
      // Placeholder - actual implementation would use RuleEvaluator.evaluate()
      results.add(EvaluationResult.noMatch());
    }

    return results;
  }

  @override
  Future<void> moveToFolder({
    required EmailMessage message,
    required String targetFolder,
  }) async {
    if (_imapClient == null) {
      throw ConnectionException('Not connected');
    }

    try {
      // Ensure we're in the correct mailbox
      if (_currentMailbox != message.folderName) {
        await _selectMailbox(message.folderName);
      }

      final messageId = int.tryParse(message.id);
      if (messageId == null) {
        throw ActionException(
          'Invalid message ID: ${message.id}',
          FilterAction.moveToFolder,
        );
      }

      final sequence = MessageSequence.fromId(messageId);

      _logger.i('Moving message ${message.id} to $targetFolder');
      await _imapClient!.move(
        sequence,
        targetMailboxPath: targetFolder,
      );
    } catch (e) {
      _logger.e('Failed to move message ${message.id} to $targetFolder: $e');
      throw ActionException('Move to folder failed', FilterAction.moveToFolder, e);
    }
  }

  /// [ISSUE #138] Mark message as read using IMAP STORE command
  @override
  Future<void> markAsRead({
    required EmailMessage message,
  }) async {
    if (_imapClient == null) {
      throw ConnectionException('Not connected');
    }

    try {
      // Ensure we're in the correct mailbox
      if (_currentMailbox != message.folderName) {
        await _selectMailbox(message.folderName);
      }

      final messageId = int.tryParse(message.id);
      if (messageId == null) {
        throw ActionException(
          'Invalid message ID: ${message.id}',
          FilterAction.markAsRead,
        );
      }

      final sequence = MessageSequence.fromId(messageId);

      _logger.i('Marking message ${message.id} as read');
      await _imapClient!.store(
        sequence,
        [MessageFlags.seen],
        action: StoreAction.add,
      );
    } catch (e) {
      _logger.e('Failed to mark message ${message.id} as read: $e');
      throw ActionException('Mark as read failed', FilterAction.markAsRead, e);
    }
  }

  /// [ISSUE #138] Apply IMAP keyword flag with rule name (if server supports it)
  @override
  Future<void> applyFlag({
    required EmailMessage message,
    required String flagName,
  }) async {
    if (_imapClient == null) {
      throw ConnectionException('Not connected');
    }

    try {
      // Ensure we're in the correct mailbox
      if (_currentMailbox != message.folderName) {
        await _selectMailbox(message.folderName);
      }

      final messageId = int.tryParse(message.id);
      if (messageId == null) {
        throw ActionException(
          'Invalid message ID: ${message.id}',
          FilterAction.markAsRead, // Reuse markAsRead for now
        );
      }

      final sequence = MessageSequence.fromId(messageId);

      // Sanitize flag name for IMAP keyword (no spaces, max 30 chars)
      final sanitized = _sanitizeFlagName(flagName);
      final keyword = 'SpamFilter-$sanitized';

      _logger.i('Applying IMAP keyword "$keyword" to message ${message.id}');
      try {
        await _imapClient!.store(
          sequence,
          [keyword],
          action: StoreAction.add,
          silent: false,
        );
        _logger.i('Successfully applied keyword: $keyword');
      } catch (e) {
        // Server may not support custom keywords - log warning but continue
        _logger.w('Failed to apply keyword (server may not support custom keywords): $e');
        // Do not throw - flagging is enhancement, not critical
      }
    } catch (e) {
      _logger.e('Error applying IMAP keyword: $e');
      // Do not throw - flagging is enhancement, not critical
    }
  }

  /// Sanitize rule name for IMAP keyword (alphanumeric, hyphens, underscores only, max 30 chars)
  String _sanitizeFlagName(String name) {
    // Replace spaces and special chars with underscores
    String sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    // Truncate to 30 chars
    if (sanitized.length > 30) {
      sanitized = sanitized.substring(0, 30);
    }
    return sanitized;
  }

  @override
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  }) async {
    if (_imapClient == null) {
      throw ConnectionException('Not connected');
    }

    try {
      // Ensure we're in the correct mailbox
      if (_currentMailbox != message.folderName) {
        await _selectMailbox(message.folderName);
      }

      final messageId = int.tryParse(message.id);
      if (messageId == null) {
        throw ActionException(
          'Invalid message ID: ${message.id}',
          action,
        );
      }

      final sequence = MessageSequence.fromId(messageId);

      switch (action) {
        case FilterAction.delete:
          // Move to configured folder instead of permanent delete
          // This allows recovery if spam filter makes a mistake
          final targetFolder = _deletedRuleFolder ?? 'Trash';
          _logger.i('Moving message ${message.id} to $targetFolder');
          await _imapClient!.move(
            sequence,
            targetMailboxPath: targetFolder,
          );
          break;

        case FilterAction.moveToJunk:
          _logger.i('Moving message ${message.id} to Junk');
          await _imapClient!.move(
            sequence,
            targetMailboxPath: 'Junk',
          );
          break;

        case FilterAction.moveToFolder:
          // Requires additional parameter for target folder
          // For now, default to Junk
          _logger.i('Moving message ${message.id} to Junk (default)');
          await _imapClient!.move(
            sequence,
            targetMailboxPath: 'Junk',
          );
          break;

        case FilterAction.markAsRead:
          _logger.i('Marking message ${message.id} as read');
          await _imapClient!.store(
            sequence,
            [MessageFlags.seen],
            action: StoreAction.add,
          );
          break;

        case FilterAction.markAsSpam:
          // Some servers support custom flags
          _logger.i('Marking message ${message.id} as spam');
          await _imapClient!.store(
            sequence,
            [r'$Junk'],
            action: StoreAction.add,
          );
          break;
      }
    } catch (e) {
      _logger.e('Failed to perform action $action on message ${message.id}: $e');
      throw ActionException('Action failed', action, e);
    }
  }

  @override
  Future<List<FolderInfo>> listFolders() async {
    if (_imapClient == null) {
      throw ConnectionException('Not connected');
    }

    try {
      _logger.i('Listing mailboxes');
      final mailboxes = await _imapClient!.listMailboxes();

      return mailboxes.map((mailbox) {
        return FolderInfo(
          id: mailbox.path,
          displayName: mailbox.name,
          canonicalName: _getCanonicalFolder(mailbox.name),
          messageCount: mailbox.messagesExists,
          isWritable: true,
        );
      }).toList();
    } catch (e) {
      _logger.e('Failed to list folders: $e');
      throw FetchException('Failed to list folders', e);
    }
  }

  @override
  Future<ConnectionStatus> testConnection() async {
    try {
      if (_credentials == null) {
        return ConnectionStatus.failure('No credentials provided');
      }

      await loadCredentials(_credentials!);

      // Get server capabilities
      final capabilities = _imapClient?.serverInfo.capabilities ?? [];

      return ConnectionStatus.success(
        serverInfo: {
          'host': _imapHost,
          'port': _imapPort,
          'secure': _isSecure,
          'capabilities': capabilities.map((c) => c.name).toList(),
        },
      );
    } catch (e) {
      _logger.e('Connection test failed: $e');
      return ConnectionStatus.failure(e.toString());
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_imapClient != null) {
        _logger.i('Disconnecting from $displayName');
        await _imapClient!.logout();
        _imapClient = null;
        _currentMailbox = null;
      }
    } catch (e) {
      _logger.w('Error during disconnect: $e');
    }
  }

  // Private helper methods

  Future<void> _selectMailbox(String mailboxName) async {
    if (_currentMailbox == mailboxName) {
      return; // Already selected
    }

    try {
      await _imapClient!.selectMailboxByPath(mailboxName);
      _currentMailbox = mailboxName;
      _logger.d('Selected mailbox: $mailboxName');
    } catch (e) {
      throw FetchException('Failed to select mailbox: $mailboxName', e);
    }
  }

  Future<List<EmailMessage>> _fetchMessageDetails(
    MessageSequence sequence,
    String folderName,
  ) async {
    final messages = <EmailMessage>[];

    try {
      // Fetch headers and body preview using enough_mail's FetchContentDefinition
      final fetchResult = await _imapClient!.fetchMessages(
        sequence,
        'BODY.PEEK[]', // Fetch full message without marking as read
      );

      for (final mimeMessage in fetchResult.messages) {
        try {
          messages.add(_convertMimeMessage(mimeMessage, folderName));
        } catch (e) {
          _logger.w('Failed to parse message: $e');
          // Continue with other messages
        }
      }
    } catch (e) {
      throw FetchException('Failed to fetch message details', e);
    }

    return messages;
  }

  EmailMessage _convertMimeMessage(MimeMessage mimeMessage, String folderName) {
    final headersMap = <String, String>{};
    if (mimeMessage.headers != null) {
      for (final header in mimeMessage.headers!) {
        headersMap[header.name] = header.value ?? '';
      }
    }
    
    return EmailMessage(
      id: mimeMessage.sequenceId?.toString() ?? '',
      from: mimeMessage.from?.first.email ?? '',
      subject: mimeMessage.decodeSubject() ?? '',
      body: mimeMessage.decodeTextPlainPart() ?? '',
      headers: headersMap,
      receivedDate: mimeMessage.decodeDate() ?? DateTime.now(),
      folderName: folderName,
    );
  }

  String _formatImapDate(DateTime date) {
    // RFC 3501 date format: 1-Jan-2025
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day}-${months[date.month - 1]}-${date.year}';
  }

  CanonicalFolder _getCanonicalFolder(String folderName) {
    final lowerName = folderName.toLowerCase();
    if (lowerName == 'inbox') return CanonicalFolder.inbox;
    // Issue #48: AOL uses "Bulk Mail" and "Bulk Email" for spam folders
    if ((lowerName == 'junk') || (lowerName == 'spam') || (lowerName == 'bulk') || (lowerName == 'bulk mail') || (lowerName == 'bulk email')) {
      return CanonicalFolder.junk;
    }
    if (lowerName.contains('trash') || lowerName.contains('deleted')) {
      return CanonicalFolder.trash;
    }
    if (lowerName.contains('sent')) return CanonicalFolder.sent;
    if (lowerName.contains('draft')) return CanonicalFolder.drafts;
    if (lowerName.contains('archive')) return CanonicalFolder.archive;
    return CanonicalFolder.custom;
  }
}
