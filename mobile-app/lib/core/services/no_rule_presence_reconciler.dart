/// F276 (Sprint 80): No Rule Review must not list mail that is gone.
///
/// Since Sprint 77 (F245, ADR-0045) No Rule Review lists every unprocessed row
/// across scans, so an email the user deleted or moved in their mail app stayed
/// listed for up to 90 days, and a Gmail message moved from Spam to Inbox was
/// listed twice. Review's own actions only create rules and never touch the
/// message, so they cannot discover that it is gone.
///
/// The fix runs where a session to the folder already exists: after a scan has
/// fetched a folder, it asks the adapter which listed rows of that folder still
/// exist ([MessagePresenceChecker]) and records the answer. Review hides rows
/// marked gone ([UnmatchedEmailStore.getUnprocessedForAccount]); a later
/// sighting records `available` with the sighting time
/// ([UnmatchedEmailStore.upsertUnmatchedEmails]), so a message that comes back
/// is listed again and is not re-checked within [kNoRulePresenceRecheck].
/// The check only reads the mailbox, so it runs in every scan mode, read-only
/// included, on Windows and Android alike (ADR-0042 parity: shared Dart, both
/// adapters).
library;

import '../../adapters/email_providers/spam_filter_platform.dart';
import '../storage/unmatched_email_store.dart';

/// A row is checked again at most this often.
const Duration kNoRulePresenceRecheck = Duration(hours: 1);

/// Result of one folder's presence check.
class NoRulePresenceOutcome {
  const NoRulePresenceOutcome({
    required this.checked,
    required this.deleted,
    required this.moved,
  });

  /// Rows the adapter answered for.
  final int checked;

  /// Rows marked deleted (not found in the folder).
  final int deleted;

  /// Rows marked moved (Gmail: the message lost the folder's label).
  final int moved;
}

/// Checks the unprocessed No Rule rows of [accountId] in [folderName] that are
/// due ([kNoRulePresenceRecheck]) and records each answer. At most [limit] rows
/// per call: an IMAP chunked UID SEARCH is cheap, a Gmail check is one request
/// per message, so the caller passes a smaller limit for Gmail.
///
/// Errors from [checker] propagate (the caller rethrows session-fatal ones and
/// logs the rest); rows are then left unchanged.
Future<NoRulePresenceOutcome> reconcileNoRulePresence({
  required MessagePresenceChecker checker,
  required UnmatchedEmailStore store,
  required String accountId,
  required String folderName,
  required int limit,
  DateTime? now,
}) async {
  final checkedBefore =
      (now ?? DateTime.now()).subtract(kNoRulePresenceRecheck);
  final rows = await store.getRowsToVerify(accountId, folderName,
      checkedBefore: checkedBefore, limit: limit);
  if (rows.isEmpty) {
    return const NoRulePresenceOutcome(checked: 0, deleted: 0, moved: 0);
  }

  final rowIdsByProviderId = <String, List<int>>{};
  for (final row in rows) {
    final id = row.id;
    if (id == null) continue;
    rowIdsByProviderId
        .putIfAbsent(row.providerIdentifierValue, () => <int>[])
        .add(id);
  }

  final presence = await checker.checkMessagesPresent(
    folderName: folderName,
    ids: rowIdsByProviderId.keys.toList(),
  );

  final statusByRowId = <int, String>{};
  var deleted = 0;
  var moved = 0;
  presence.forEach((providerId, value) {
    final rowIds = rowIdsByProviderId[providerId];
    if (rowIds == null) return;
    final status = switch (value) {
      MessagePresence.present => UnmatchedEmailStore.availabilityAvailable,
      MessagePresence.absent => UnmatchedEmailStore.availabilityDeleted,
      MessagePresence.moved => UnmatchedEmailStore.availabilityMoved,
    };
    for (final rowId in rowIds) {
      statusByRowId[rowId] = status;
      if (value == MessagePresence.absent) deleted++;
      if (value == MessagePresence.moved) moved++;
    }
  });
  await store.applyPresence(statusByRowId);
  return NoRulePresenceOutcome(
      checked: statusByRowId.length, deleted: deleted, moved: moved);
}
