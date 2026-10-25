import 'dart:async';

import 'diagnostic_logger.dart';

/// F302 (Sprint 81): the ONE value an IMAP message id holds when the server
/// answered a UID command without a UID.
///
/// Before this, `GenericIMAPAdapter._convertMimeMessage` stored the message
/// SEQUENCE number in the id field in that case. Every UID consumer then read
/// it as a UID, and a sequence number names a different message after any
/// delete, so a move, delete or presence check could act on the WRONG message.
///
/// The value is deliberately not an integer, so `int.tryParse` on it is null
/// even for a consumer that does not use the helpers below, and it is never
/// the empty string (an empty id reads as "no id at all" elsewhere). The
/// message's sequence number lives in its own field,
/// `EmailMessage.imapSequenceNumber`.
const String kNoValidImapUid = 'no-valid-uid';

/// True when [id] is the "no valid UID" constant. A pure check with no log.
bool isNoValidImapUid(String id) => id == kNoValidImapUid;

/// F302 R-3: the single gate every IMAP UID consumer goes through.
///
/// Returns false, and writes a diagnostic line naming [folderName] and the
/// calling [context], when [id] is [kNoValidImapUid]. Returns true for every
/// other id, including a non-numeric one (a Gmail id is opaque and valid for
/// Gmail; the numeric check is [parseImapUid]'s job).
///
/// Use this directly for a consumer that treats the id as an opaque identity
/// (the No Rule store). A consumer that needs the integer UID uses
/// [parseImapUid].
///
/// Enforced by `test/policy/f302_imap_uid_helper_test.dart`: an
/// `int.tryParse` / `int.parse` of a message id anywhere else in `lib/` fails
/// the build.
///
/// 7.7.1 L-3: the line is written at most once per [context] and folder per
/// [kNoValidImapUidLogWindow]. One message passes several gates in a scan
/// (convert, persist, cursor, each batch), so a server that sends no UIDs for
/// a large folder would otherwise write thousands of lines and rotate real
/// events out of the log. The next line after a window names how many were
/// skipped without a line.
bool hasValidImapUid(
  String id, {
  required String folderName,
  required String context,
}) {
  if (!isNoValidImapUid(id)) return true;
  final key = '$context\u0000$folderName';
  final now = DateTime.now();
  final last = _lastLogAt[key];
  if (last != null && now.difference(last) < kNoValidImapUidLogWindow) {
    _suppressed[key] = (_suppressed[key] ?? 0) + 1;
    return false;
  }
  final suppressed = _suppressed.remove(key) ?? 0;
  _lastLogAt[key] = now;
  unawaited(DiagnosticLogger.log(
    kind: DiagnosticLogger.kindSkipped,
    context: context,
    detail: 'message has no valid IMAP UID (the server sent none); skipped '
        'so no other message is touched. folder "$folderName"'
        '${suppressed > 0 ? '; $suppressed more skipped here since the '
            'last line' : ''}',
  ));
  return false;
}

/// How long [hasValidImapUid] waits before it writes another line for the
/// same context and folder.
const Duration kNoValidImapUidLogWindow = Duration(minutes: 10);

final Map<String, DateTime> _lastLogAt = {};
final Map<String, int> _suppressed = {};

/// Test seam: forget the log windows so each test starts fresh.
void debugResetNoValidImapUidLog() {
  _lastLogAt.clear();
  _suppressed.clear();
}

/// The integer UID in [id], or null when there is none to use: the
/// [kNoValidImapUid] constant (logged by [hasValidImapUid], naming the
/// folder), or an id that is not an integer. A null result is the caller's
/// existing "no UID" path (throw, skip or leave out).
int? parseImapUid(
  String id, {
  required String folderName,
  required String context,
}) {
  if (!hasValidImapUid(id, folderName: folderName, context: context)) {
    return null;
  }
  return int.tryParse(id);
}
