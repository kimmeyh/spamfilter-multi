/// Result of a batch email operation
///
/// [ISSUE #144] Tracks success and failure for batch IMAP/API operations.
/// When processing emails in batches (e.g., 10 at a time), individual
/// emails may succeed or fail independently.
library;

import 'email_message.dart';

/// Result of a batch operation on multiple emails
class BatchActionResult {
  /// Messages that were processed successfully
  final List<String> succeededIds;

  /// Messages that failed, mapped to their error messages
  final Map<String, String> failedIds;

  const BatchActionResult({
    required this.succeededIds,
    required this.failedIds,
  });

  /// All messages succeeded
  bool get allSucceeded => failedIds.isEmpty;

  /// Number of messages that succeeded
  int get successCount => succeededIds.length;

  /// Number of messages that failed
  int get failureCount => failedIds.length;

  /// Total messages in this batch
  int get totalCount => succeededIds.length + failedIds.length;

  /// Factory for a fully successful batch
  factory BatchActionResult.allSuccess(List<String> ids) {
    return BatchActionResult(succeededIds: ids, failedIds: {});
  }

  /// Factory for a fully failed batch
  factory BatchActionResult.allFailed(List<String> ids, String error) {
    return BatchActionResult(
      succeededIds: [],
      failedIds: {for (final id in ids) id: error},
    );
  }

  @override
  String toString() =>
      'BatchActionResult(succeeded: $successCount, failed: $failureCount)';
}

/// A pending batch operation collected during scan evaluation
///
/// Groups an email with its evaluation result and intended action
/// so that the scanner can execute them in batches after evaluation.
class PendingAction {
  final EmailMessage message;
  final String matchedRule;
  final BatchActionType actionType;

  const PendingAction({
    required this.message,
    required this.matchedRule,
    required this.actionType,
  });
}

/// Types of batch actions that can be grouped together
enum BatchActionType {
  /// Delete (move to trash/configured folder)
  delete,

  /// Move to junk folder
  moveToJunk,

  /// Move safe sender to configured folder
  safeSenderMove,
}
