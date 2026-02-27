/// Generic IMAP email provider adapter
///
/// This adapter provides IMAP support for multiple email providers:
/// - AOL Mail (MVP Phase 1)
/// - Yahoo Mail
/// - iCloud Mail
/// - Any custom IMAP server
///
/// Uses the `enough_mail` package for IMAP protocol implementation.
///
/// [ISSUE #145] Uses IMAP UIDs (not sequence IDs) for all message operations.
/// UIDs are persistent and do not change when messages are moved or deleted,
/// preventing the "100-delete limit" bug where sequence IDs would shift
/// after each delete, causing operations on wrong messages.
library;

import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:logger/logger.dart';

import '../../core/models/batch_action_result.dart';
import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import 'spam_filter_platform.dart';
import 'email_provider.dart';

/// Generic IMAP implementation for multiple email providers
class GenericIMAPAdapter with BatchOperationsMixin implements SpamFilterPlatform {
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

  // [ISSUE #145] Track IMAP operations to detect and recover from connection drops
  int _operationCount = 0;
  static const int _reconnectThreshold = 50; // Reconnect every 50 operations to prevent server disconnects

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

  /// Factory constructor for Gmail via IMAP (App Password auth)
  ///
  /// [ISSUE #178] Gmail Dual-Auth: Allows Gmail access via IMAP with
  /// an app password instead of OAuth 2.0. Useful when Google Sign-In
  /// is unavailable or the user prefers app password authentication.
  factory GenericIMAPAdapter.gmail() {
    return GenericIMAPAdapter(
      imapHost: 'imap.gmail.com',
      imapPort: 993,
      isSecure: true,
      displayName: 'Gmail (IMAP)',
      platformId: 'gmail-imap',
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
      _operationCount = 0;
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

      // Log server capabilities for diagnostics (custom keyword support, etc.)
      final capabilities = _imapClient?.serverInfo.capabilities ?? [];
      _logger.i('[IMAP] Server capabilities: ${capabilities.map((c) => c.name).toList()}');
    } catch (e) {
      _logger.e('[IMAP] Failed to load credentials: $e');
      if (e is AuthenticationException) {
        // Propagate explicit authentication failures
        rethrow;
      }

      // Map handshake and network errors to connection failures so the UI
      // reports the real root cause instead of "Authentication failed".
      if (e is HandshakeException) {
        throw ConnectionException('TLS certificate validation failed: ${e.toString()}', e);
      }
      if (e is SocketException || e is TimeoutException) {
        throw ConnectionException('Network connection failed: ${e.toString()}', e);
      }

      // Fallback: treat other errors as connection failures
      // [UPDATED] Include underlying error details in message for better debugging
      throw ConnectionException('IMAP connection failed: ${e.toString()}', e);
    }
  }

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    if (_imapClient == null) {
      _logger.e('[IMAP] fetchMessages called but _imapClient is NULL');
      throw ConnectionException('Not connected - call loadCredentials first');
    }

    final messages = <EmailMessage>[];
    final sinceDate = daysBack > 0
        ? DateTime.now().subtract(Duration(days: daysBack))
        : null;

    _logger.i('[IMAP] fetchMessages: daysBack=$daysBack, sinceDate=$sinceDate, folders=$folderNames');
    _logger.i('[IMAP] fetchMessages: _imapClient connected=${_imapClient != null}, currentMailbox=$_currentMailbox');

    for (final folderName in folderNames) {
      try {
        _logger.i('[IMAP] fetchMessages: Selecting mailbox "$folderName"...');
        await _selectMailbox(folderName);
        _logger.i('[IMAP] fetchMessages: Mailbox "$folderName" selected, currentMailbox=$_currentMailbox');

        // [ISSUE #145] Use UID SEARCH for stable message identifiers
        final searchCriteria = sinceDate != null
            ? 'SINCE ${_formatImapDate(sinceDate)}'
            : 'ALL';
        _logger.i('[IMAP] fetchMessages: UID SEARCH criteria="$searchCriteria" in "$folderName"');

        final searchResult = await _imapClient!.uidSearchMessages(
          searchCriteria: searchCriteria,
        );

        _logger.i('[IMAP] fetchMessages: Search result: matchingSequence=${searchResult.matchingSequence}, isEmpty=${searchResult.matchingSequence?.isEmpty}');

        if (searchResult.matchingSequence == null ||
            searchResult.matchingSequence!.isEmpty) {
          _logger.i('[IMAP] fetchMessages: No messages found in "$folderName" (matchingSequence null or empty)');
          continue;
        }

        _logger.i('[IMAP] fetchMessages: Found ${searchResult.matchingSequence!.length} UIDs in "$folderName"');

        // [ISSUE #145] Fetch message details using UID FETCH
        final fetchedMessages = await _fetchMessageDetails(
          searchResult.matchingSequence!,
          folderName,
        );

        _logger.i('[IMAP] fetchMessages: Fetched ${fetchedMessages.length} message details from "$folderName"');
        messages.addAll(fetchedMessages);
      } catch (e, st) {
        _logger.e('[IMAP] fetchMessages: ERROR fetching from "$folderName": $e\n$st');
        // Continue with other folders even if one fails
      }
    }

    _logger.i('[IMAP] fetchMessages: COMPLETE - Total messages fetched across all folders: ${messages.length}');
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
      // [ISSUE #145] Proactive reconnect before operation if threshold reached
      await _checkAndReconnect();

      // Ensure we are in the correct mailbox
      if (_currentMailbox != message.folderName) {
        await _selectMailbox(message.folderName);
      }

      final messageUid = int.tryParse(message.id);
      if (messageUid == null) {
        throw ActionException(
          'Invalid message UID: ${message.id}',
          FilterAction.moveToFolder,
        );
      }

      // [ISSUE #145] Use UID-based sequence and UID MOVE command
      final sequence = MessageSequence.fromId(messageUid, isUid: true);

      _logger.i('[IMAP] UID MOVE message ${message.id} to $targetFolder (op #$_operationCount)');
      await _imapClient!.uidMove(
        sequence,
        targetMailboxPath: targetFolder,
      );
      _operationCount++;
    } catch (e) {
      _logger.e('[IMAP] Failed to move message ${message.id} to $targetFolder: $e');
      throw ActionException('Move to folder failed', FilterAction.moveToFolder, e);
    }
  }

  /// [ISSUE #138] Mark message as read using IMAP UID STORE command
  @override
  Future<void> markAsRead({
    required EmailMessage message,
  }) async {
    if (_imapClient == null) {
      throw ConnectionException('Not connected');
    }

    try {
      // [ISSUE #145] Proactive reconnect before operation if threshold reached
      await _checkAndReconnect();

      // Ensure we are in the correct mailbox
      if (_currentMailbox != message.folderName) {
        await _selectMailbox(message.folderName);
      }

      final messageUid = int.tryParse(message.id);
      if (messageUid == null) {
        throw ActionException(
          'Invalid message UID: ${message.id}',
          FilterAction.markAsRead,
        );
      }

      // [ISSUE #145] Use UID-based sequence and UID STORE command
      final sequence = MessageSequence.fromId(messageUid, isUid: true);

      _logger.i('[IMAP] UID STORE +Seen on message ${message.id} (op #$_operationCount)');
      await _imapClient!.uidStore(
        sequence,
        [MessageFlags.seen],
        action: StoreAction.add,
      );
      _operationCount++;
    } catch (e) {
      _logger.e('[IMAP] Failed to mark message ${message.id} as read: $e');
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
      // Ensure we are in the correct mailbox
      if (_currentMailbox != message.folderName) {
        await _selectMailbox(message.folderName);
      }

      final messageUid = int.tryParse(message.id);
      if (messageUid == null) {
        throw ActionException(
          'Invalid message UID: ${message.id}',
          FilterAction.markAsRead, // Reuse markAsRead for now
        );
      }

      // [ISSUE #145] Use UID-based sequence and UID STORE command
      final sequence = MessageSequence.fromId(messageUid, isUid: true);

      // Sanitize flag name for IMAP keyword (no spaces, max 30 chars)
      final sanitized = _sanitizeFlagName(flagName);
      final keyword = 'SpamFilter-$sanitized';

      _logger.i('[IMAP] UID STORE +keyword "$keyword" on message ${message.id} (op #$_operationCount)');
      try {
        await _imapClient!.uidStore(
          sequence,
          [keyword],
          action: StoreAction.add,
          silent: false,
        );
        _operationCount++;
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
      // [ISSUE #145] Proactive reconnect before operation if threshold reached
      await _checkAndReconnect();

      // Ensure we are in the correct mailbox
      if (_currentMailbox != message.folderName) {
        await _selectMailbox(message.folderName);
      }

      final messageUid = int.tryParse(message.id);
      if (messageUid == null) {
        throw ActionException(
          'Invalid message UID: ${message.id}',
          action,
        );
      }

      // [ISSUE #145] Use UID-based sequence for all operations
      final sequence = MessageSequence.fromId(messageUid, isUid: true);

      switch (action) {
        case FilterAction.delete:
          // Move to configured folder instead of permanent delete
          // This allows recovery if spam filter makes a mistake
          final targetFolder = _deletedRuleFolder ?? 'Trash';
          _logger.i('[IMAP] UID MOVE message ${message.id} to $targetFolder (op #$_operationCount)');
          await _imapClient!.uidMove(
            sequence,
            targetMailboxPath: targetFolder,
          );
          _operationCount++;
          break;

        case FilterAction.moveToJunk:
          _logger.i('[IMAP] UID MOVE message ${message.id} to Junk (op #$_operationCount)');
          await _imapClient!.uidMove(
            sequence,
            targetMailboxPath: 'Junk',
          );
          _operationCount++;
          break;

        case FilterAction.moveToFolder:
          // Requires additional parameter for target folder
          // For now, default to Junk
          _logger.i('[IMAP] UID MOVE message ${message.id} to Junk (default) (op #$_operationCount)');
          await _imapClient!.uidMove(
            sequence,
            targetMailboxPath: 'Junk',
          );
          _operationCount++;
          break;

        case FilterAction.markAsRead:
          _logger.i('[IMAP] UID STORE +Seen on message ${message.id} (op #$_operationCount)');
          await _imapClient!.uidStore(
            sequence,
            [MessageFlags.seen],
            action: StoreAction.add,
          );
          _operationCount++;
          break;

        case FilterAction.markAsSpam:
          // Some servers support custom flags
          _logger.i('[IMAP] UID STORE +Junk on message ${message.id} (op #$_operationCount)');
          await _imapClient!.uidStore(
            sequence,
            [r'$Junk'],
            action: StoreAction.add,
          );
          _operationCount++;
          break;
      }
    } catch (e) {
      _logger.e('[IMAP] Failed to perform action $action on message ${message.id}: $e');
      throw ActionException('Action failed', action, e);
    }
  }

  // --- Batch Operation Overrides (Issue #144) ---
  // Use IMAP UID sequence sets for batch operations.
  // A single UID STORE/MOVE command with multiple UIDs is far more efficient
  // than individual commands per message.

  @override
  Future<BatchActionResult> markAsReadBatch(List<EmailMessage> messages) async {
    if (_imapClient == null || messages.isEmpty) {
      return BatchActionResult.allSuccess(messages.map((m) => m.id).toList());
    }

    await _checkAndReconnect();

    // Group messages by folder (IMAP requires selecting mailbox first)
    final byFolder = _groupByFolder(messages);
    final succeeded = <String>[];
    final failed = <String, String>{};

    for (final entry in byFolder.entries) {
      try {
        await _selectMailbox(entry.key);
        final uids = _parseUids(entry.value);
        if (uids.isEmpty) continue;

        final sequence = MessageSequence.fromIds(uids, isUid: true);
        _logger.i('[IMAP] BATCH UID STORE +Seen on ${uids.length} messages (op #$_operationCount)');
        await _imapClient!.uidStore(
          sequence,
          [MessageFlags.seen],
          action: StoreAction.add,
        );
        _operationCount++;
        succeeded.addAll(entry.value.map((m) => m.id));
      } catch (e) {
        _logger.e('[IMAP] Batch markAsRead failed for folder ${entry.key}: $e');
        // Fall back to single-message processing for this folder
        for (final message in entry.value) {
          try {
            await markAsRead(message: message);
            succeeded.add(message.id);
          } catch (e2) {
            failed[message.id] = e2.toString();
          }
        }
      }
    }

    return BatchActionResult(succeededIds: succeeded, failedIds: failed);
  }

  @override
  Future<BatchActionResult> applyFlagBatch(
    List<EmailMessage> messages,
    String flagName,
  ) async {
    if (_imapClient == null || messages.isEmpty) {
      return BatchActionResult.allSuccess(messages.map((m) => m.id).toList());
    }

    final sanitized = _sanitizeFlagName(flagName);
    final keyword = 'SpamFilter-$sanitized';
    final byFolder = _groupByFolder(messages);
    final succeeded = <String>[];
    final failed = <String, String>{};

    for (final entry in byFolder.entries) {
      try {
        await _selectMailbox(entry.key);
        final uids = _parseUids(entry.value);
        if (uids.isEmpty) continue;

        final sequence = MessageSequence.fromIds(uids, isUid: true);
        _logger.i('[IMAP] BATCH UID STORE +keyword "$keyword" on ${uids.length} messages (op #$_operationCount)');
        await _imapClient!.uidStore(
          sequence,
          [keyword],
          action: StoreAction.add,
          silent: false,
        );
        _operationCount++;
        succeeded.addAll(entry.value.map((m) => m.id));
      } catch (e) {
        // Server may not support custom keywords — log warning but do not fail the batch
        // AOL and some other IMAP servers do not support custom keywords (no \* in PERMANENTFLAGS)
        _logger.w('[IMAP] Batch applyFlag failed for folder ${entry.key} (server may not support custom keywords): $e');
        succeeded.addAll(entry.value.map((m) => m.id));
      }
    }

    return BatchActionResult(succeededIds: succeeded, failedIds: failed);
  }

  @override
  Future<BatchActionResult> moveToFolderBatch(
    List<EmailMessage> messages,
    String targetFolder,
  ) async {
    _logger.i('[IMAP] moveToFolderBatch called: ${messages.length} messages to "$targetFolder"');
    if (_imapClient == null || messages.isEmpty) {
      _logger.i('[IMAP] moveToFolderBatch skipped: client=${_imapClient != null}, messages=${messages.length}');
      return BatchActionResult.allSuccess(messages.map((m) => m.id).toList());
    }

    await _checkAndReconnect();

    final byFolder = _groupByFolder(messages);
    final succeeded = <String>[];
    final failed = <String, String>{};

    for (final entry in byFolder.entries) {
      try {
        _logger.i('[IMAP] moveToFolderBatch: selecting source folder "${entry.key}" for ${entry.value.length} messages');
        await _selectMailbox(entry.key);
        final uids = _parseUids(entry.value);
        if (uids.isEmpty) {
          _logger.w('[IMAP] moveToFolderBatch: no valid UIDs parsed, skipping');
          continue;
        }

        final sequence = MessageSequence.fromIds(uids, isUid: true);
        _logger.i('[IMAP] BATCH UID MOVE ${uids.length} messages (UIDs: $uids) from "${entry.key}" to "$targetFolder" (op #$_operationCount)');
        await _imapClient!.uidMove(
          sequence,
          targetMailboxPath: targetFolder,
        );
        _operationCount++;
        _logger.i('[IMAP] BATCH UID MOVE completed successfully');
        succeeded.addAll(entry.value.map((m) => m.id));
      } catch (e) {
        _logger.e('[IMAP] Batch move failed for folder ${entry.key}: $e');
        // Fall back to single-message processing for this folder
        for (final message in entry.value) {
          try {
            await moveToFolder(message: message, targetFolder: targetFolder);
            succeeded.add(message.id);
          } catch (e2) {
            failed[message.id] = e2.toString();
          }
        }
      }
    }

    _logger.i('[IMAP] moveToFolderBatch result: ${succeeded.length} succeeded, ${failed.length} failed');
    return BatchActionResult(succeededIds: succeeded, failedIds: failed);
  }

  @override
  Future<BatchActionResult> takeActionBatch(
    List<EmailMessage> messages,
    FilterAction action,
  ) async {
    if (_imapClient == null || messages.isEmpty) {
      return BatchActionResult.allSuccess(messages.map((m) => m.id).toList());
    }

    // Route to specific batch method based on action type
    switch (action) {
      case FilterAction.delete:
        final targetFolder = _deletedRuleFolder ?? 'Trash';
        return moveToFolderBatch(messages, targetFolder);
      case FilterAction.moveToJunk:
      case FilterAction.moveToFolder:
        return moveToFolderBatch(messages, 'Junk');
      case FilterAction.markAsRead:
        return markAsReadBatch(messages);
      case FilterAction.markAsSpam:
        // Batch store $Junk flag
        await _checkAndReconnect();
        final byFolder = _groupByFolder(messages);
        final succeeded = <String>[];
        final failed = <String, String>{};
        for (final entry in byFolder.entries) {
          try {
            await _selectMailbox(entry.key);
            final uids = _parseUids(entry.value);
            if (uids.isEmpty) continue;
            final sequence = MessageSequence.fromIds(uids, isUid: true);
            await _imapClient!.uidStore(
              sequence,
              [r'$Junk'],
              action: StoreAction.add,
            );
            _operationCount++;
            succeeded.addAll(entry.value.map((m) => m.id));
          } catch (e) {
            for (final message in entry.value) {
              failed[message.id] = e.toString();
            }
          }
        }
        return BatchActionResult(succeededIds: succeeded, failedIds: failed);
    }
  }

  /// Group messages by folder name for batch operations
  Map<String, List<EmailMessage>> _groupByFolder(List<EmailMessage> messages) {
    final grouped = <String, List<EmailMessage>>{};
    for (final message in messages) {
      grouped.putIfAbsent(message.folderName, () => []).add(message);
    }
    return grouped;
  }

  /// Parse UIDs from message IDs, skipping invalid ones
  List<int> _parseUids(List<EmailMessage> messages) {
    final uids = <int>[];
    for (final message in messages) {
      final uid = int.tryParse(message.id);
      if (uid != null) {
        uids.add(uid);
      } else {
        _logger.w('[IMAP] Invalid message UID: ${message.id}');
      }
    }
    return uids;
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
        _logger.i('[IMAP] Disconnecting from $displayName (total ops: $_operationCount)');
        await _imapClient!.logout();
        _imapClient = null;
        _currentMailbox = null;
        _operationCount = 0;
      }
    } catch (e) {
      _logger.w('Error during disconnect: $e');
    }
  }

  // Private helper methods

  /// [ISSUE #145] Check operation count and proactively reconnect if threshold reached.
  /// This prevents IMAP server disconnects during long scan sessions (e.g., AOL
  /// disconnects after ~100 sequential operations). Reconnects transparently
  /// without losing the scan state since UIDs are persistent.
  Future<void> _checkAndReconnect() async {
    if (_operationCount < _reconnectThreshold) {
      return;
    }

    if (_credentials == null || _imapClient == null) {
      return;
    }

    _logger.i('[IMAP] Reconnect threshold reached ($_operationCount ops). Reconnecting...');

    final savedMailbox = _currentMailbox;

    try {
      // Graceful disconnect
      try {
        await _imapClient!.logout();
      } catch (e) {
        _logger.w('[IMAP] Error during reconnect logout: $e');
      }

      // Fresh connection
      _imapClient = ImapClient(isLogEnabled: false);
      await _imapClient!.connectToServer(
        _imapHost,
        _imapPort,
        isSecure: _isSecure,
      );
      await _imapClient!.login(
        _credentials!.email,
        _credentials!.password ?? '',
      );

      _operationCount = 0;
      _currentMailbox = null;

      // Re-select the mailbox we were working in
      if (savedMailbox != null) {
        await _selectMailbox(savedMailbox);
      }

      _logger.i('[IMAP] Reconnected successfully. Resuming operations.');
    } catch (e) {
      _logger.e('[IMAP] Reconnect failed: $e');
      throw ConnectionException('IMAP reconnect failed: ${e.toString()}', e);
    }
  }

  Future<void> _selectMailbox(String mailboxName) async {
    if (_currentMailbox == mailboxName) {
      _logger.d('[IMAP] _selectMailbox: Already in "$mailboxName", skipping');
      return; // Already selected
    }

    try {
      _logger.i('[IMAP] _selectMailbox: Selecting "$mailboxName" (was: "$_currentMailbox")');
      final mailbox = await _imapClient!.selectMailboxByPath(mailboxName);
      _currentMailbox = mailboxName;
      _logger.i('[IMAP] _selectMailbox: Selected "$mailboxName" - messagesExists=${mailbox.messagesExists}, messagesRecent=${mailbox.messagesRecent}, uidValidity=${mailbox.uidValidity}');
    } catch (e) {
      _logger.e('[IMAP] _selectMailbox: FAILED to select "$mailboxName": $e');
      throw FetchException('Failed to select mailbox: $mailboxName', e);
    }
  }

  /// [ISSUE #145] Fetch message details using UID FETCH for stable identifiers
  Future<List<EmailMessage>> _fetchMessageDetails(
    MessageSequence sequence,
    String folderName,
  ) async {
    final messages = <EmailMessage>[];

    try {
      // [ISSUE #145] Use UID FETCH to get message UIDs alongside content
      final fetchResult = await _imapClient!.uidFetchMessages(
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

    // [ISSUE #145] Use UID instead of sequence ID for stable message identification.
    // UIDs persist across mailbox operations (move, delete) while sequence IDs shift.
    // Fall back to sequence ID only if UID is unavailable (should not happen with UID FETCH).
    final messageId = mimeMessage.uid?.toString()
        ?? mimeMessage.sequenceId?.toString()
        ?? '';
    if (mimeMessage.uid == null) {
      _logger.w('[IMAP] Message has no UID, falling back to sequenceId: ${mimeMessage.sequenceId}');
    }

    return EmailMessage(
      id: messageId,
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
