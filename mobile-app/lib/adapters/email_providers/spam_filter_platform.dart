/// Core abstraction layer for all email platforms
/// 
/// This interface defines the unified API that all email provider adapters
/// must implement, allowing the spam filter to work seamlessly across
/// Gmail, Outlook, IMAP servers, and any future email platforms.
library;

import '../../core/models/batch_action_result.dart';
import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import 'email_provider.dart';

/// Unified abstraction for email platform operations
abstract class SpamFilterPlatform {
  /// Platform identifier (e.g., 'gmail', 'outlook', 'aol', 'imap')
  String get platformId;

  /// Human-readable platform name for UI display
  String get displayName;

  /// Authentication method supported by this platform
  AuthMethod get supportedAuthMethod;

  /// Load and validate credentials for this platform
  /// 
  /// Throws [AuthenticationException] if credentials are invalid
  /// Throws [ConnectionException] if unable to connect to server
  Future<void> loadCredentials(Credentials credentials);

  /// Fetch messages with platform-specific optimization
  /// 
  /// Parameters:
  /// - [daysBack]: Number of days to search backward from today
  /// - [folderNames]: List of folder/mailbox names to search in
  /// 
  /// Returns list of [EmailMessage] objects with standardized format
  /// 
  /// Throws [FetchException] if unable to retrieve messages
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  });

  /// Apply compiled rules with platform-native filtering when available
  /// 
  /// Some platforms (Gmail, Outlook) support server-side filtering which
  /// can be more efficient than client-side regex matching.
  /// 
  /// Parameters:
  /// - [messages]: List of messages to evaluate
  /// - [compiledRegex]: Map of rule names to compiled regex patterns
  /// 
  /// Returns list of [EvaluationResult] indicating matched rules per message
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  });

  /// Execute action (delete, move, mark) with platform-specific API
  /// 
  /// Parameters:
  /// - [message]: The email message to act upon
  /// - [action]: The action to perform
  /// 
  /// Throws [ActionException] if action fails
  /// Configure the folder to use for deleted rule emails
  /// 
  /// Parameters:
  /// - [folderName]: Name of the folder to move deleted emails to (null = use provider default)
  /// 
  /// Each platform has its own default:
  /// - IMAP: 'Trash'
  /// - Gmail: 'TRASH' (trash label)
  void setDeletedRuleFolder(String? folderName);

  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  });

  /// Move message to a specific folder/label
  ///
  /// Parameters:
  /// - [message]: The email message to move
  /// - [targetFolder]: The folder/label to move to (platform-specific naming)
  ///
  /// Throws [ActionException] if move fails
  Future<void> moveToFolder({
    required EmailMessage message,
    required String targetFolder,
  });

  /// Mark message as read
  ///
  /// Parameters:
  /// - [message]: The email message to mark as read
  ///
  /// Throws [ActionException] if operation fails
  ///
  /// [ISSUE #138] Added for enhanced deleted email processing
  Future<void> markAsRead({
    required EmailMessage message,
  });

  /// Apply flag/label/category to message with rule name
  ///
  /// Parameters:
  /// - [message]: The email message to flag
  /// - [flagName]: The flag/label/category name (typically rule name)
  ///
  /// Provider-specific behavior:
  /// - Gmail: Creates label "SpamFilter/{flagName}" and applies it
  /// - IMAP: Adds keyword "$SpamFilter-{flagName}" if server supports custom keywords
  /// - AOL: Same as IMAP (uses IMAP keywords)
  ///
  /// Throws [ActionException] if operation fails
  /// Returns silently if provider does not support flagging (e.g., IMAP server without PERMANENTFLAGS \*)
  ///
  /// [ISSUE #138] Added for enhanced deleted email processing
  Future<void> applyFlag({
    required EmailMessage message,
    required String flagName,
  });

  /// List available folders with platform-specific names
  /// 
  /// Returns list of [FolderInfo] with canonical folder types
  Future<List<FolderInfo>> listFolders();

  /// Test connection and authentication without fetching data
  /// 
  /// Useful for validating credentials during account setup
  Future<ConnectionStatus> testConnection();

  /// Disconnect and cleanup resources
  ///
  /// Should be called when done with this platform instance
  Future<void> disconnect();

  // --- Batch Operations (Issue #144) ---
  // Batch methods for processing multiple emails in one operation.
  // Adapters should override for native batch support (IMAP sequence sets, Gmail batch API).
  // Default implementations are provided by BatchOperationsMixin.

  /// Mark multiple messages as read in a single batch operation.
  Future<BatchActionResult> markAsReadBatch(List<EmailMessage> messages);

  /// Apply flag/keyword to multiple messages in a single batch operation.
  Future<BatchActionResult> applyFlagBatch(List<EmailMessage> messages, String flagName);

  /// Move multiple messages to a target folder in a single batch operation.
  Future<BatchActionResult> moveToFolderBatch(List<EmailMessage> messages, String targetFolder);

  /// Execute an action on multiple messages in a single batch operation.
  Future<BatchActionResult> takeActionBatch(List<EmailMessage> messages, FilterAction action);
}

/// Mixin providing default single-message fallback implementations for batch operations.
///
/// [ISSUE #144] Adapters that do not have native batch support can mix this in
/// to get working batch methods that process messages one at a time.
/// Adapters with native batch support (IMAP, Gmail) should override these methods.
mixin BatchOperationsMixin implements SpamFilterPlatform {
  @override
  Future<BatchActionResult> markAsReadBatch(List<EmailMessage> messages) async {
    final succeeded = <String>[];
    final failed = <String, String>{};
    for (final message in messages) {
      try {
        await markAsRead(message: message);
        succeeded.add(message.id);
      } catch (e) {
        failed[message.id] = e.toString();
      }
    }
    return BatchActionResult(succeededIds: succeeded, failedIds: failed);
  }

  @override
  Future<BatchActionResult> applyFlagBatch(
    List<EmailMessage> messages,
    String flagName,
  ) async {
    final succeeded = <String>[];
    final failed = <String, String>{};
    for (final message in messages) {
      try {
        await applyFlag(message: message, flagName: flagName);
        succeeded.add(message.id);
      } catch (e) {
        failed[message.id] = e.toString();
      }
    }
    return BatchActionResult(succeededIds: succeeded, failedIds: failed);
  }

  @override
  Future<BatchActionResult> moveToFolderBatch(
    List<EmailMessage> messages,
    String targetFolder,
  ) async {
    final succeeded = <String>[];
    final failed = <String, String>{};
    for (final message in messages) {
      try {
        await moveToFolder(message: message, targetFolder: targetFolder);
        succeeded.add(message.id);
      } catch (e) {
        failed[message.id] = e.toString();
      }
    }
    return BatchActionResult(succeededIds: succeeded, failedIds: failed);
  }

  @override
  Future<BatchActionResult> takeActionBatch(
    List<EmailMessage> messages,
    FilterAction action,
  ) async {
    final succeeded = <String>[];
    final failed = <String, String>{};
    for (final message in messages) {
      try {
        await takeAction(message: message, action: action);
        succeeded.add(message.id);
      } catch (e) {
        failed[message.id] = e.toString();
      }
    }
    return BatchActionResult(succeededIds: succeeded, failedIds: failed);
  }
}

/// Authentication methods supported by various platforms
enum AuthMethod {
  /// No authentication required (Demo mode)
  none,

  /// OAuth 2.0 (Google, Microsoft, Yahoo)
  oauth2,

  /// App-specific password (AOL, iCloud, Yahoo)
  appPassword,

  /// Basic username/password authentication (Generic IMAP)
  basicAuth,

  /// API key (ProtonMail Bridge)
  apiKey,
}

/// Actions that can be performed on email messages
enum FilterAction {
  /// Permanently delete the message
  delete,

  /// Move to junk/spam folder
  moveToJunk,

  /// Move to a specific folder
  moveToFolder,

  /// Mark as read without moving
  markAsRead,

  /// Mark as spam/junk
  markAsSpam,
}

/// Information about an email folder/mailbox
class FolderInfo {
  /// Platform-specific folder identifier
  final String id;

  /// Display name in platform's native format
  final String displayName;

  /// Standardized folder type (INBOX, JUNK, TRASH, SENT, etc.)
  final CanonicalFolder canonicalName;

  /// Number of messages in folder (if available)
  final int? messageCount;

  /// Whether this folder can be written to
  final bool isWritable;

  const FolderInfo({
    required this.id,
    required this.displayName,
    required this.canonicalName,
    this.messageCount,
    this.isWritable = true,
  });

  @override
  String toString() => '$displayName (${canonicalName.name})';
}

/// Standardized folder types across all platforms
enum CanonicalFolder {
  inbox,
  junk,
  trash,
  sent,
  drafts,
  archive,
  custom,
}

/// Result of connection test
class ConnectionStatus {
  /// Whether connection was successful
  final bool isConnected;

  /// Error message if connection failed
  final String? errorMessage;

  /// Additional server information (version, capabilities, etc.)
  final Map<String, dynamic>? serverInfo;

  const ConnectionStatus({
    required this.isConnected,
    this.errorMessage,
    this.serverInfo,
  });

  /// Factory for successful connection
  factory ConnectionStatus.success({Map<String, dynamic>? serverInfo}) {
    return ConnectionStatus(
      isConnected: true,
      serverInfo: serverInfo,
    );
  }

  /// Factory for failed connection
  factory ConnectionStatus.failure(String errorMessage) {
    return ConnectionStatus(
      isConnected: false,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    if (isConnected) {
      return 'Connected${serverInfo != null ? ' - $serverInfo' : ''}';
    }
    return 'Failed: $errorMessage';
  }
}

/// Exception thrown during authentication
class AuthenticationException implements Exception {
  final String message;
  final dynamic originalError;

  AuthenticationException(this.message, [this.originalError]);

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Exception thrown during connection
class ConnectionException implements Exception {
  final String message;
  final dynamic originalError;

  ConnectionException(this.message, [this.originalError]);

  @override
  String toString() => 'ConnectionException: $message';
}

/// Exception thrown during message fetching
class FetchException implements Exception {
  final String message;
  final dynamic originalError;

  FetchException(this.message, [this.originalError]);

  @override
  String toString() => 'FetchException: $message';
}

/// Exception thrown during action execution
class ActionException implements Exception {
  final String message;
  final FilterAction action;
  final dynamic originalError;

  ActionException(this.message, this.action, [this.originalError]);

  @override
  String toString() => 'ActionException (${action.name}): $message';
}
