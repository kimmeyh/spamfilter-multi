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
import '../../core/security/auth_rate_limiter.dart';
import '../../core/storage/database_helper.dart';
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

  // [BUG-S40-1] Bulk UID MOVE tuning for AOL/Yahoo servers.
  //
  // AOL/Yahoo implement the IMAP MESSAGELIMIT extension (RFC 9738): a UID MOVE
  // that exceeds the server's per-command message limit moves only a SUBSET,
  // returns a tagged OK (not NO), and reports the unprocessed remainder via a
  // [MESSAGELIMIT n lowestUid] response code. enough_mail 2.1.7 does not parse
  // that response code, so a single large UID MOVE silently leaves the tail
  // behind. The fix is to send small chunks, verify each chunk actually left
  // the source folder, and loop the folder until no targeted UIDs remain.
  //
  // Chunk size is held well below AOL's advertised MESSAGELIMIT (1000) because
  // field reports show the EFFECTIVE per-command cap on the spam/Bulk folder is
  // far lower and variable (~19-211 observed). 50 balances throughput against
  // that cap; smaller is safer but slower.
  static const int _moveChunkSize = 50;
  // Delay between UID MOVE chunks on the same connection to stay under
  // command-frequency rate limits (Yahoo/AOL throttle rapid commands).
  static const Duration _moveChunkDelay = Duration(milliseconds: 250);
  // Max full passes over a source folder. Each pass re-moves any survivors.
  // Guards against an infinite loop if the server refuses a message outright.
  static const int _moveMaxPasses = 6;

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
    // SEC-22 (Sprint 33): check rate limiter before attempting sign-in so a
    // blocked account never touches the network.
    final rateLimiter = AuthRateLimiter(DatabaseHelper());
    final rateLimitAccountId = '$platformId-${credentials.email}';
    await rateLimiter.assertNotBlocked(rateLimitAccountId);

    try {
      _credentials = credentials;
      _operationCount = 0;
      _imapClient = ImapClient(isLogEnabled: false);

      _logger.i('[IMAP] Connecting to $_imapHost:$_imapPort (secure: $_isSecure)');

      // NOTE: enough_mail ImapClient.connectToServer() does not support securityContext parameter.
      // Use default SSL/TLS certificate validation provided by Dart's dart:io.
      // For standard email providers (AOL, Gmail, Yahoo, Outlook), this is secure and reliable.
      //
      // SEC-8 (Sprint 33): Certificate pinning is NOT applied to IMAP because
      // enough_mail's ImapClient does not expose a SecurityContext or
      // bad-certificate callback. Pinning HTTPS OAuth endpoints is handled by
      // PinnedHttpClient (see lib/core/security/certificate_pinner.dart).
      // IMAP pinning is tracked as a future enhancement; options:
      // 1. Post-connection socket inspection (not exposed by enough_mail API)
      // 2. Fork enough_mail to accept a SecurityContext parameter
      // 3. Replace enough_mail with a secure IMAP library that supports pinning
      //
      // REMOVED: SecurityContext creation and custom certificate handling (not supported by enough_mail)
      // REMOVED: Custom certificate file loading from assets
      // REMOVED: Bad certificate override handler (dangerous for production)

      await _imapClient!.connectToServer(
        _imapHost,
        _imapPort,
        isSecure: _isSecure,
      );

      _logger.i('[IMAP] IMAP login attempt for $displayName');

      await _imapClient!.login(
        credentials.email,
        credentials.password ?? '',
      );

      _logger.i('[IMAP] Successfully authenticated to $displayName');

      // SEC-22: successful auth clears any accrued failure count.
      await rateLimiter.recordSuccess(rateLimitAccountId);

      // Log server capabilities for diagnostics (custom keyword support, etc.)
      final capabilities = _imapClient?.serverInfo.capabilities ?? [];
      _logger.i('[IMAP] Server capabilities: ${capabilities.map((c) => c.name).toList()}');
    } catch (e) {
      _logger.e('[IMAP] Failed to load credentials: $e');
      if (e is AuthenticationException) {
        // SEC-22: server rejected credentials -> count as a failed attempt.
        // Swallow any DB error inside the limiter so it never hides the
        // original auth failure from the caller.
        try {
          await rateLimiter.recordFailure(rateLimitAccountId);
        } catch (limiterError) {
          _logger.w('Auth rate limiter write failed: $limiterError');
        }
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

  /// Sprint 38 Round 1 (extending F6c Phase 2 to IMAP): fetch only messages
  /// with a UID strictly greater than [startUid] in [folderName]. Returns
  /// the list of new emails plus the new highest-UID-seen for the caller
  /// to persist as the next scan's cursor.
  ///
  /// Used by EmailScanner._fetchFolderMessages for the per-folder
  /// incremental scan path. Unlike Gmail's history.list (which is
  /// account-wide and has a ~7-day expiry window), IMAP UID cursors are
  /// per-mailbox and never "expire" -- UIDs are monotonically increasing
  /// per RFC 3501 (subject to UIDVALIDITY changes; not handled in V1
  /// because UIDVALIDITY changes are rare for established mailboxes).
  ///
  /// Returns ImapIncrementalFetchResult.empty() when no new UIDs exist
  /// (caller still persists the cursor, which advances on every server
  /// state change). Throws on connection errors.
  Future<ImapIncrementalFetchResult> fetchMessagesIncremental({
    required int startUid,
    required String folderName,
  }) async {
    if (_imapClient == null) {
      _logger.e('[IMAP] fetchMessagesIncremental called but _imapClient is NULL');
      throw ConnectionException('Not connected - call loadCredentials first');
    }

    _logger.i('[IMAP] fetchMessagesIncremental: startUid=$startUid, folder=$folderName');

    try {
      await _selectMailbox(folderName);

      // UID lastUid+1:* = "every UID strictly greater than lastUid up
      // through the end of the mailbox". Standard RFC 3501 syntax.
      final lowerBound = startUid + 1;
      final searchCriteria = 'UID $lowerBound:*';
      _logger.i('[IMAP] fetchMessagesIncremental: UID SEARCH criteria="$searchCriteria"');

      final searchResult = await _imapClient!.uidSearchMessages(
        searchCriteria: searchCriteria,
      );

      final sequence = searchResult.matchingSequence;
      if (sequence == null || sequence.isEmpty) {
        _logger.i('[IMAP] fetchMessagesIncremental: no new UIDs since $startUid');
        return ImapIncrementalFetchResult.empty(newCursor: startUid);
      }

      // Compute the new cursor BEFORE the per-message fetch in case any
      // individual message fetch fails -- we still want to advance the
      // cursor past the IDs we successfully discovered, since rerunning
      // the search next time would just discover them again.
      var maxUid = startUid;
      for (final id in sequence.toList()) {
        if (id > maxUid) maxUid = id;
      }

      _logger.i('[IMAP] fetchMessagesIncremental: found ${sequence.length} new UIDs in $folderName (new cursor=$maxUid)');

      final fetched = await _fetchMessageDetails(sequence, folderName);
      _logger.i('[IMAP] fetchMessagesIncremental: fetched ${fetched.length} message details');

      return ImapIncrementalFetchResult(
        emails: fetched,
        newCursor: maxUid,
      );
    } catch (e, st) {
      _logger.e('[IMAP] fetchMessagesIncremental ERROR for $folderName: $e\n$st');
      rethrow;
    }
  }

  /// Sprint 38 Round 1: returns the current highest UID in [folderName],
  /// or null if the folder is empty / not selectable. Used by
  /// EmailScanner._fetchFolderMessages to capture an initial cursor
  /// AFTER a full first-scan so subsequent scans can run incrementally.
  Future<int?> getCurrentMaxUid(String folderName) async {
    if (_imapClient == null) {
      _logger.e('[IMAP] getCurrentMaxUid called but _imapClient is NULL');
      throw ConnectionException('Not connected - call loadCredentials first');
    }
    try {
      await _selectMailbox(folderName);
      // UID 1:* matches every existing UID; we then take the max.
      final searchResult = await _imapClient!.uidSearchMessages(
        searchCriteria: 'UID 1:*',
      );
      final seq = searchResult.matchingSequence;
      if (seq == null || seq.isEmpty) {
        _logger.i('[IMAP] getCurrentMaxUid: $folderName is empty');
        return 0; // cursor of 0 means "next scan picks up everything from UID 1"
      }
      var maxUid = 0;
      for (final id in seq.toList()) {
        if (id > maxUid) maxUid = id;
      }
      _logger.i('[IMAP] getCurrentMaxUid: $folderName -> $maxUid');
      return maxUid;
    } catch (e) {
      _logger.e('[IMAP] getCurrentMaxUid ERROR for $folderName: $e');
      return null;
    }
  }

  /// S38-CI-4 (Sprint 39): return the SMALLEST UID in [folderName] whose
  /// message arrived on or after [since] -- the "UID floor" for the
  /// configured `daysBack` retention window.
  ///
  /// EmailScanner uses this floor to CAP the oldest-no-rule cursor so a
  /// no-rule UID older than `now - daysBack` is not persisted as the
  /// cursor and therefore ages out of the backlog (see
  /// EmailScanner._updateOldestNoRuleCursors). One lookup per folder per
  /// scan: the result is cached by the caller for the scan duration.
  ///
  /// Mirrors [getCurrentMaxUid] but searches `UID SEARCH SINCE <date>`
  /// (RFC 3501 section 6.4.4) and takes the minimum matching UID instead
  /// of the maximum. The IMAP `SINCE` key matches the message internal
  /// date (server receipt date) with date granularity, consistent with
  /// how [fetchMessages] applies the same `daysBack` window.
  ///
  /// Returns null when no message matches (the window is empty) or on any
  /// error, so the caller degrades gracefully and skips the cap rather
  /// than clamping against a bogus floor.
  Future<int?> firstUidSince(String folderName, DateTime since) async {
    if (_imapClient == null) {
      _logger.e('[IMAP] firstUidSince called but _imapClient is NULL');
      return null;
    }
    try {
      await _selectMailbox(folderName);
      final searchCriteria = 'SINCE ${_formatImapDate(since)}';
      _logger.i('[IMAP] firstUidSince: UID SEARCH criteria="$searchCriteria" in "$folderName"');
      final searchResult = await _imapClient!.uidSearchMessages(
        searchCriteria: searchCriteria,
      );
      final seq = searchResult.matchingSequence;
      if (seq == null || seq.isEmpty) {
        _logger.i('[IMAP] firstUidSince: no messages since $since in $folderName');
        return null;
      }
      int? minUid;
      for (final id in seq.toList()) {
        if (minUid == null || id < minUid) minUid = id;
      }
      _logger.i('[IMAP] firstUidSince: $folderName floor UID=$minUid (since=$since)');
      return minUid;
    } catch (e) {
      _logger.e('[IMAP] firstUidSince ERROR for $folderName: $e');
      return null;
    }
  }

  /// F91 (Sprint 39): find messages in [folderName] whose RFC 5322
  /// `Message-ID` header equals [messageId].
  ///
  /// Implements post-safe-sender-move source-folder dedup for AOL's
  /// copy-not-move behavior (see SpamFilterPlatform.searchByMessageId).
  ///
  /// IMAP `SEARCH HEADER` quoting (RFC 3501 section 6.4.4): the header field
  /// name and the substring are both IMAP strings. We quote both as IMAP
  /// quoted-strings. The value [messageId] is expected to include the angle
  /// brackets (for example `<abc@host>`). Any embedded double quotes or
  /// backslashes are escaped per RFC 3501 quoted-string rules so a malformed
  /// Message-ID cannot break out of the quoted string. Matching is
  /// case-insensitive per RFC 3501 (`SEARCH HEADER` does a case-insensitive
  /// substring match on the header value).
  ///
  /// Returns the matching messages (empty when none). Returns empty on any
  /// search error rather than throwing, so the caller's dedup step degrades
  /// to a no-op instead of failing the scan.
  @override
  Future<List<EmailMessage>> searchByMessageId(
    String folderName,
    String messageId,
  ) async {
    if (_imapClient == null) {
      _logger.e('[IMAP] searchByMessageId called but _imapClient is NULL');
      throw ConnectionException('Not connected - call loadCredentials first');
    }

    final trimmed = messageId.trim();
    if (trimmed.isEmpty) {
      _logger.w('[IMAP] searchByMessageId: empty messageId, skipping');
      return const [];
    }

    try {
      await _checkAndReconnect();
      await _selectMailbox(folderName);

      // Escape per RFC 3501 quoted-string: backslash and double quote.
      final escaped = trimmed.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      final searchCriteria = 'HEADER "Message-ID" "$escaped"';
      _logger.i('[IMAP] searchByMessageId: UID SEARCH $searchCriteria in "$folderName"');

      final searchResult = await _imapClient!.uidSearchMessages(
        searchCriteria: searchCriteria,
      );
      _operationCount++;

      final sequence = searchResult.matchingSequence;
      if (sequence == null || sequence.isEmpty) {
        _logger.i('[IMAP] searchByMessageId: no match in "$folderName"');
        return const [];
      }

      _logger.i('[IMAP] searchByMessageId: ${sequence.length} match(es) in "$folderName"');
      return _fetchMessageDetails(sequence, folderName);
    } catch (e, st) {
      _logger.e('[IMAP] searchByMessageId ERROR in "$folderName": $e\n$st');
      // Degrade to no-op: dedup must never break the scan.
      return const [];
    }
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
      final uids = _parseUids(entry.value);
      if (uids.isEmpty) {
        _logger.w('[IMAP] moveToFolderBatch: no valid UIDs parsed for "${entry.key}", skipping');
        continue;
      }

      // [BUG-S40-1] Chunk + verify + loop-until-empty. A single large UID MOVE
      // against AOL/Yahoo silently moves only a subset (RFC 9738 MESSAGELIMIT),
      // so we move in small chunks, verify each chunk left the source folder,
      // and repeat over any survivors for up to _moveMaxPasses passes.
      final survivingUids = await _moveFolderChunkedWithRetry(
        sourceFolder: entry.key,
        uids: uids,
        targetFolder: targetFolder,
      );

      partitionByMoveSurvival(
        messages: entry.value,
        survivingUids: survivingUids,
        sourceFolder: entry.key,
        targetFolder: targetFolder,
        onSucceeded: succeeded.add,
        onFailed: (id, reason) => failed[id] = reason,
      );
    }

    _logger.i('[IMAP] moveToFolderBatch result: ${succeeded.length} succeeded, ${failed.length} failed');
    return BatchActionResult(succeededIds: succeeded, failedIds: failed);
  }

  /// [BUG-S40-1] Move [uids] out of [sourceFolder] into [targetFolder]
  /// reliably against servers that perform partial UID MOVE (AOL/Yahoo).
  ///
  /// Strategy: split the UID set into [_moveChunkSize] chunks; for each chunk
  /// issue a UID MOVE, pause [_moveChunkDelay], then verify which of that
  /// chunk's UIDs actually left the source folder. UIDs that remain are carried
  /// into the next pass. The folder is swept up to [_moveMaxPasses] times until
  /// no targeted UIDs remain. Returns the UIDs that STILL remain after all
  /// passes (genuine failures). On a per-chunk MOVE exception the chunk falls
  /// back to single-message moves before verification, so one bad message does
  /// not poison a whole chunk.
  ///
  /// This is bounded and deterministic: each pass either reduces the survivor
  /// set or the loop exits, so the historical "reappears on every scan" delete
  /// loop is resolved within a single scan instead of across many.
  Future<List<int>> _moveFolderChunkedWithRetry({
    required String sourceFolder,
    required List<int> uids,
    required String targetFolder,
  }) async {
    var remaining = List<int>.from(uids);

    for (var pass = 1; pass <= _moveMaxPasses && remaining.isNotEmpty; pass++) {
      _logger.i(
        '[IMAP] move pass $pass/$_moveMaxPasses: ${remaining.length} UIDs from '
        '"$sourceFolder" -> "$targetFolder" (chunk=$_moveChunkSize)',
      );
      final stillRemaining = <int>[];

      for (final chunk in chunkUids(remaining, _moveChunkSize)) {
        try {
          await _checkAndReconnect();
          await _selectMailbox(sourceFolder);
          _logger.i(
            '[IMAP] UID MOVE chunk ${chunk.length} UIDs from "$sourceFolder" '
            '-> "$targetFolder" (pass $pass, op #$_operationCount)',
          );
          await _imapClient!.uidMove(
            MessageSequence.fromIds(chunk, isUid: true),
            targetMailboxPath: targetFolder,
          );
          _operationCount++;
        } catch (e) {
          // A chunk-level MOVE failure must not abort the whole batch.
          // Verification below re-checks the chunk regardless, so a transient
          // failure here simply leaves the chunk's UIDs in the survivor set to
          // be retried on the next pass.
          _logger.w(
            '[IMAP] UID MOVE chunk failed (pass $pass) for "$sourceFolder": $e; '
            'chunk will be re-verified and retried',
          );
        }

        // Pace requests to stay under AOL/Yahoo command-rate limits.
        await Future<void>.delayed(_moveChunkDelay);

        // Verify which of this chunk's UIDs actually left the source folder.
        final survivors = await _uidsStillPresent(sourceFolder, chunk);
        if (survivors.isNotEmpty) {
          _logger.w(
            '[IMAP] move pass $pass: ${survivors.length}/${chunk.length} UIDs '
            'still in "$sourceFolder" after chunk MOVE',
          );
          stillRemaining.addAll(survivors);
        }
      }

      if (stillRemaining.length == remaining.length) {
        // No forward progress this pass: the server is refusing these UIDs.
        // Stop early rather than spin through the remaining passes.
        _logger.e(
          '[IMAP] move pass $pass made no progress (${stillRemaining.length} '
          'UIDs unmovable from "$sourceFolder"); aborting further passes',
        );
        return stillRemaining;
      }
      remaining = stillRemaining;
    }

    if (remaining.isEmpty) {
      _logger.i('[IMAP] all UIDs successfully moved out of "$sourceFolder"');
    } else {
      _logger.e(
        '[IMAP] ${remaining.length} UIDs still in "$sourceFolder" after '
        '$_moveMaxPasses passes (recorded as failures)',
      );
    }
    return remaining;
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

  /// [BUG-S40-1] Split [uids] into consecutive chunks of at most [chunkSize].
  ///
  /// Pure helper extracted so the chunk boundaries (the off-by-one-prone part
  /// of the bulk-move loop) can be unit tested. Order is preserved and no UID
  /// is dropped or duplicated. A non-positive [chunkSize] yields a single chunk
  /// containing all UIDs (defensive; callers always pass a positive constant).
  static List<List<int>> chunkUids(List<int> uids, int chunkSize) {
    if (uids.isEmpty) return const [];
    if (chunkSize <= 0) return [List<int>.from(uids)];
    final chunks = <List<int>>[];
    for (var i = 0; i < uids.length; i += chunkSize) {
      final end = (i + chunkSize < uids.length) ? i + chunkSize : uids.length;
      chunks.add(uids.sublist(i, end));
    }
    return chunks;
  }

  /// [BUG-S40-1] Partition a moved batch into succeeded / failed based on which
  /// UIDs actually left the source folder.
  ///
  /// A message is a SUCCESS only if its UID is NOT in [survivingUids] (the set
  /// the server still reports in [sourceFolder] after the move + retry). A
  /// message whose UID survived is a real FAILURE -- the server acknowledged
  /// the move but did not perform it (the AOL copy-not-move pathology). A
  /// message with an unparseable UID is treated as a success (it could not have
  /// been part of the UID-keyed survivor set, and the legacy behavior counted
  /// it as moved).
  ///
  /// Pure and side-effect-free apart from the two callbacks, so it can be unit
  /// tested without an IMAP client.
  static void partitionByMoveSurvival({
    required List<EmailMessage> messages,
    required List<int> survivingUids,
    required String sourceFolder,
    required String targetFolder,
    required void Function(String id) onSucceeded,
    required void Function(String id, String reason) onFailed,
  }) {
    final survivorSet = survivingUids.toSet();
    for (final message in messages) {
      final uid = int.tryParse(message.id);
      if (uid != null && survivorSet.contains(uid)) {
        onFailed(
          message.id,
          'Server acknowledged move to "$targetFolder" but message remained '
          'in "$sourceFolder" after retry (AOL copy-not-move)',
        );
      } else {
        onSucceeded(message.id);
      }
    }
  }

  /// [BUG-S40-1] Return the subset of [candidateUids] that are STILL present in
  /// [folderName], used to verify a UID MOVE actually removed messages from the
  /// source folder (AOL acknowledges moves it does not perform).
  ///
  /// Selects [folderName] and issues a single `UID SEARCH UID <set>`. The
  /// intersection of the requested UIDs and the server's match set is what
  /// remains. On any error the candidates are treated as "still present" (the
  /// conservative choice: a failed verification must not be reported as a
  /// successful move).
  Future<List<int>> _uidsStillPresent(
    String folderName,
    List<int> candidateUids,
  ) async {
    if (candidateUids.isEmpty || _imapClient == null) {
      return const [];
    }
    try {
      await _selectMailbox(folderName);
      // Build an explicit UID set (e.g. "143312,143313,143315") rather than
      // relying on MessageSequence.toString() formatting inside the criterion.
      final uidSet = candidateUids.join(',');
      final searchResult = await _imapClient!.uidSearchMessages(
        searchCriteria: 'UID $uidSet',
      );
      _operationCount++;
      final matched = searchResult.matchingSequence;
      if (matched == null || matched.isEmpty) {
        return const [];
      }
      final present = matched.toList().toSet();
      return candidateUids.where(present.contains).toList();
    } catch (e) {
      _logger.w(
        '[IMAP] _uidsStillPresent: verification search failed in '
        '"$folderName": $e; treating ${candidateUids.length} UIDs as unverified '
        '(still present)',
      );
      return List<int>.from(candidateUids);
    }
  }

  @override
  Future<List<FolderInfo>> listFolders() async {
    if (_imapClient == null) {
      throw ConnectionException('Not connected');
    }

    try {
      _logger.i('Listing mailboxes');
      // Use recursive: true to include child mailboxes like [Gmail]/Trash
      final allMailboxes = await _imapClient!.listMailboxes(recursive: true);

      // Filter out non-selectable parent folders (e.g., [Gmail] virtual container)
      final mailboxes = allMailboxes.where((m) => !m.isNotSelectable).toList();

      return mailboxes.map((mailbox) {
        // Use path as display name for clarity (e.g., [Gmail]/Trash instead of Trash)
        // but use leaf name for canonical folder detection
        final displayName = mailbox.path.isNotEmpty ? mailbox.path : mailbox.name;
        // enough_mail populates pathSeparator from the IMAP LIST response delimiter
        // field (second token after "LIST (flags)"), e.g. '/' or '.' or ':'.
        // This is the live server value, not a hardcoded default.
        final delimiter = mailbox.pathSeparator;
        return FolderInfo(
          id: mailbox.path,
          displayName: displayName,
          canonicalName: _getCanonicalFolder(mailbox.name),
          messageCount: mailbox.messagesExists,
          isWritable: true,
          hierarchyDelimiter: delimiter,
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

    // F91 (Sprint 39): capture the RFC 5322 Message-ID header for
    // post-safe-sender-move source-folder dedup. headersMap keys are the
    // raw header names; look up case-insensitively because servers vary
    // ("Message-ID", "Message-Id", "message-id").
    String? messageIdHeader;
    for (final entry in headersMap.entries) {
      if (entry.key.toLowerCase() == 'message-id') {
        messageIdHeader = EmailMessage.parseMessageId(entry.value);
        break;
      }
    }

    return EmailMessage(
      id: messageId,
      from: mimeMessage.from?.first.email ?? '',
      subject: mimeMessage.decodeSubject() ?? '',
      body: mimeMessage.decodeTextPlainPart() ?? '',
      headers: headersMap,
      receivedDate: mimeMessage.decodeDate() ?? DateTime.now(),
      folderName: folderName,
      messageIdHeader: messageIdHeader,
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

/// Sprint 38 Round 1 (extending F6c Phase 2 to IMAP): result of an
/// incremental IMAP UID-since fetch.
///
/// `emails` is the list of messages with UID > startUid (empty if no new
/// messages exist). `newCursor` is the highest UID seen during this scan
/// -- caller persists it as `account_folder_cursors.cursor_value` so the
/// next scan resumes from `newCursor + 1`.
///
/// Unlike Gmail's IncrementalFetchResult there is no `expired` state for
/// IMAP. UIDs are monotonically increasing per RFC 3501 (subject to
/// UIDVALIDITY changes; if UIDVALIDITY changes mid-mailbox, the
/// `UID startUid+1:*` search returns zero results and the scan
/// silently picks up from the new UIDVALIDITY -- a rare edge case
/// acceptable for V1).
class ImapIncrementalFetchResult {
  final List<EmailMessage> emails;
  final int newCursor;

  const ImapIncrementalFetchResult({
    required this.emails,
    required this.newCursor,
  });

  factory ImapIncrementalFetchResult.empty({required int newCursor}) =>
      ImapIncrementalFetchResult(emails: const [], newCursor: newCursor);
}
