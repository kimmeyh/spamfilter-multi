/// Store for managing unmatched emails from scan results
///
/// This store handles:
/// - Storing emails that did not match any rules during scans
/// - Tracking email availability (still exists, deleted, moved)
/// - Marking emails as processed by user
library;

/// - Provider-specific email identifiers (Gmail message ID, IMAP UID)

import 'package:logger/logger.dart';

import '../models/evaluation_result.dart';
import '../services/diagnostic_logger.dart';
import 'database_helper.dart';

/// The detail the diagnostic log gets when a current rule or safe sender
/// covers a No Rule row (Sprint 77 final review).
///
/// The rule's TYPE, never its NAME: an exact-sender rule is named
/// `Block_<address>` and a subject rule `Block_Subject_<subject text>`
/// (RuleQuickActionService), and [DiagnosticLogger.scrub] redacts addresses
/// but not subject text.
String coveredByRuleDetail(EvaluationResult eval) => eval.isSafeSender
    ? 'safe sender'
    : 'rule type ${eval.matchedPatternType ?? 'unknown'}';

/// Maximum length stored in the `body_preview` column.
///
/// SEC-14 (Sprint 33): Email bodies can contain secrets, PII, or tracking
/// beacons. Capping at 100 chars keeps enough context for triage without
/// persisting full message content to disk.
const int kBodyPreviewMaxLength = 100;

/// Truncate a body preview to at most [kBodyPreviewMaxLength] characters.
///
/// Returns null if input is null, the original string if it is shorter
/// than the cap, or a substring otherwise. Does not append an ellipsis;
/// the UI layer decides how to present truncation if needed.
String? truncateBodyPreview(String? preview) {
  if (preview == null) return null;
  if (preview.length <= kBodyPreviewMaxLength) return preview;
  return preview.substring(0, kBodyPreviewMaxLength);
}

/// Model class for unmatched emails
class UnmatchedEmail {
  final int? id;
  final int scanResultId;
  final String providerIdentifierType;
  final String providerIdentifierValue;
  final String fromEmail;
  final String? fromName;
  final String? subject;
  final String? bodyPreview;
  final String folderName;
  final DateTime? emailDate;
  final String availabilityStatus; // 'available', 'deleted', 'moved', 'unknown'
  final DateTime? availabilityCheckedAt;
  final bool processed;
  /// First time a scan saw this email (F245: never changes after insert).
  final DateTime createdAt;

  /// F245 (Sprint 77): the last time a scan saw this email. Refreshed by the
  /// upsert; the 90-day retention cuts on this, so an email a scan still
  /// sees never ages out. Null on a model built for insert means "now"
  /// ([createdAt]); rows migrated from v11 start equal to created_at.
  final DateTime? lastSeenAt;

  /// F96 (Sprint 43): the SPF/DKIM/DMARC classification name
  /// (`green`/`yellow`/`red`/`grey`) captured at scan time, so the
  /// email-detail quick-add path can re-hydrate it and fire the RED
  /// anti-phishing warning instead of always classifying GREY off-scan.
  /// Null for rows written before v8.
  final String? authClassification;

  UnmatchedEmail({
    this.id,
    required this.scanResultId,
    required this.providerIdentifierType,
    required this.providerIdentifierValue,
    required this.fromEmail,
    this.fromName,
    this.subject,
    this.bodyPreview,
    required this.folderName,
    this.emailDate,
    this.availabilityStatus = 'unknown',
    this.availabilityCheckedAt,
    this.processed = false,
    required this.createdAt,
    this.lastSeenAt,
    this.authClassification,
  });

  /// Convert model to database map
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'scan_result_id': scanResultId,
        'provider_identifier_type': providerIdentifierType,
        'provider_identifier_value': providerIdentifierValue,
        'from_email': fromEmail.toLowerCase(),
        'from_name': fromName,
        'subject': subject,
        // SEC-14 (Sprint 33): enforce body preview cap at insert boundary so
        // any caller that bypassed constructor-level truncation is still safe.
        'body_preview': truncateBodyPreview(bodyPreview),
        'folder_name': folderName,
        'email_date': emailDate?.millisecondsSinceEpoch,
        'availability_status': availabilityStatus,
        'availability_checked_at': availabilityCheckedAt?.millisecondsSinceEpoch,
        'processed': processed ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'last_seen_at': (lastSeenAt ?? createdAt).millisecondsSinceEpoch,
        'auth_classification': authClassification,
      };

  /// Create model from database map
  static UnmatchedEmail fromMap(Map<String, dynamic> map) => UnmatchedEmail(
        id: map['id'] as int?,
        scanResultId: map['scan_result_id'] as int,
        providerIdentifierType: map['provider_identifier_type'] as String,
        providerIdentifierValue: map['provider_identifier_value'] as String,
        fromEmail: map['from_email'] as String,
        fromName: map['from_name'] as String?,
        subject: map['subject'] as String?,
        bodyPreview: map['body_preview'] as String?,
        folderName: map['folder_name'] as String,
        emailDate: map['email_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['email_date'] as int)
            : null,
        availabilityStatus: map['availability_status'] as String? ?? 'unknown',
        availabilityCheckedAt: map['availability_checked_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                map['availability_checked_at'] as int)
            : null,
        processed: (map['processed'] as int?) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['created_at'] as int? ?? 0),
        lastSeenAt: map['last_seen_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_seen_at'] as int)
            : null,
        authClassification: map['auth_classification'] as String?,
      );

  /// Create copy with optional field updates
  UnmatchedEmail copyWith({
    int? id,
    int? scanResultId,
    String? providerIdentifierType,
    String? providerIdentifierValue,
    String? fromEmail,
    String? fromName,
    String? subject,
    String? bodyPreview,
    String? folderName,
    DateTime? emailDate,
    String? availabilityStatus,
    DateTime? availabilityCheckedAt,
    bool? processed,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    String? authClassification,
  }) =>
      UnmatchedEmail(
        id: id ?? this.id,
        scanResultId: scanResultId ?? this.scanResultId,
        providerIdentifierType:
            providerIdentifierType ?? this.providerIdentifierType,
        providerIdentifierValue:
            providerIdentifierValue ?? this.providerIdentifierValue,
        fromEmail: fromEmail ?? this.fromEmail,
        fromName: fromName ?? this.fromName,
        subject: subject ?? this.subject,
        bodyPreview: bodyPreview ?? this.bodyPreview,
        folderName: folderName ?? this.folderName,
        emailDate: emailDate ?? this.emailDate,
        availabilityStatus: availabilityStatus ?? this.availabilityStatus,
        availabilityCheckedAt:
            availabilityCheckedAt ?? this.availabilityCheckedAt,
        processed: processed ?? this.processed,
        createdAt: createdAt ?? this.createdAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        authClassification: authClassification ?? this.authClassification,
      );

  @override
  String toString() =>
      'UnmatchedEmail(id: $id, from: $fromEmail, subject: $subject, status: $availabilityStatus)';
}

/// Why a No Rule row was marked addressed (or back to unaddressed).
///
/// Sprint 77 MV step 5 (Harold): a row left the list and nothing recorded
/// why, so the cause could only be guessed from screenshots. Every caller of
/// [UnmatchedEmailStore.markAsProcessed] must now name one of these, and the
/// store writes it to the diagnostic log -- a new caller cannot skip it.
enum NoRuleMarkReason {
  /// A bulk action on selected rows (safe sender, block rule) succeeded.
  bulkAction,

  /// "Remove Current Rule": dismissed without creating a rule.
  dismissed,

  /// The email detail view's mark button.
  detailView,

  /// The list's load-time cleanup: a current rule or safe sender covers it.
  coveredByRule,

  /// F283 (Sprint 78): a quick action (safe sender or block rule) chosen in
  /// the shared email detail pop-up on Review No Rule Items succeeded.
  popupAction,
}

/// What [UnmatchedEmailStore.upsertUnmatchedEmails] did with one email.
enum UnmatchedUpsertOutcome {
  /// First sighting: a new row.
  inserted,

  /// Already listed, but a descriptive field (the subject) differs.
  changed,

  /// Already listed and DISMISSED (processed = 1); this scan re-found it with
  /// no rule, so it was reset to unprocessed (Q20, "deferred until the next
  /// scan").
  reappeared,

  /// Already listed, unprocessed and identical: nothing for the user to see.
  unchanged,
}

/// One result of an upsert: the row id and what happened.
class UnmatchedUpsertResult {
  final int id;
  final UnmatchedUpsertOutcome outcome;
  const UnmatchedUpsertResult(this.id, this.outcome);

  /// True when the background export should list the email (Q19): everything
  /// except an unchanged, still-unaddressed row.
  bool get listInBackgroundExport => outcome != UnmatchedUpsertOutcome.unchanged;
}

/// Database store for managing unmatched emails
class UnmatchedEmailStore {
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();

  UnmatchedEmailStore(this._databaseHelper);

  /// Add a single unmatched email (F245: through [upsertUnmatchedEmails]).
  ///
  /// Returns the ID of the row now holding the email (inserted or refreshed).
  Future<int> addUnmatchedEmail(UnmatchedEmail email) async {
    final results = await upsertUnmatchedEmails([email]);
    _logger.d('Upserted unmatched email: ${email.fromEmail} '
        '(id: ${results.single.id}, ${results.single.outcome.name}, '
        'scan: ${email.scanResultId})');
    return results.single.id;
  }

  /// Add multiple unmatched emails in one transaction (F245: through
  /// [upsertUnmatchedEmails]). Returns the row ids in input order.
  Future<List<int>> addUnmatchedEmailBatch(List<UnmatchedEmail> emails) async {
    final results = await upsertUnmatchedEmails(emails);
    return [for (final r in results) r.id];
  }

  /// F245 (Sprint 77, ADR-0045): THE ONLY WRITER of `unmatched_emails`.
  ///
  /// One No Rule row per email. Identity is
  /// (account, provider_identifier_type, provider_identifier_value,
  /// folder_name), where the account comes from
  /// `unmatched_emails.scan_result_id -> scan_results.account_id`; there is no
  /// account column (Harold, Q18). The match is ALWAYS inside the row's own
  /// account: two IMAP accounts can hold the same UID in a same-named folder,
  /// and those are two different emails.
  ///
  /// A matching row is REFRESHED in place (its id is kept, because the No Rule
  /// Review multi-select is keyed on it): `scan_result_id` moves to the current
  /// scan, `last_seen_at` and the descriptive fields are updated, and
  /// `created_at` (first seen) is kept. `processed` is RESET to 0 (Harold, Q20):
  /// a dismissed email is "deferred until the next scan" -- when a later scan
  /// still finds it with no rule, it comes back for a decision.
  ///
  /// PLATFORM PRIMITIVE (ADR-0042, Sprint 76 retro IMP-3): this is
  /// SELECT-then-UPDATE-or-INSERT inside one transaction, NOT
  /// `INSERT ... ON CONFLICT DO UPDATE`. UPSERT syntax needs SQLite 3.24+.
  /// Windows runs `sqflite_common_ffi` (a bundled, recent SQLite), but Android
  /// runs `sqflite` on the DEVICE's own SQLite and `minSdk` is 24, which is
  /// not guaranteed to ship 3.24 (unverified: the platform SQLite version per
  /// API level was not confirmed from developer.android.com). The portable
  /// form behaves the same on both. Serialization: `Database.transaction`
  /// issues `BEGIN IMMEDIATE` (sqflite_common `txnBeginTransaction`, shared by
  /// the ffi and Android implementations), which takes the write lock before
  /// the SELECT, so the UI isolate and a background worker (another isolate on
  /// Android, another process on Windows) cannot both miss the SELECT and
  /// insert; the second waits on `busy_timeout`. There is deliberately no
  /// cross-account UNIQUE index (it cannot express the account match without
  /// a new column), so this transaction is the only guard.
  ///
  /// Returns one [UnmatchedUpsertResult] per input, in order. The outcome says
  /// whether the email was new, changed, came back after being dismissed, or
  /// was already listed and unchanged (the background export omits those).
  Future<List<UnmatchedUpsertResult>> upsertUnmatchedEmails(
      List<UnmatchedEmail> emails) async {
    if (emails.isEmpty) return [];

    try {
      final db = await _databaseHelper.database;
      final results = <UnmatchedUpsertResult>[];
      final accountByScan = <int, String?>{};

      await db.transaction((txn) async {
        for (final email in emails) {
          if (!accountByScan.containsKey(email.scanResultId)) {
            final scanRows = await txn.query('scan_results',
                columns: ['account_id'],
                where: 'id = ?',
                whereArgs: [email.scanResultId],
                limit: 1);
            accountByScan[email.scanResultId] =
                scanRows.isEmpty ? null : scanRows.first['account_id'] as String?;
          }
          final accountId = accountByScan[email.scanResultId];

          final existing = accountId == null
              ? const <Map<String, Object?>>[]
              : await txn.rawQuery(
                  'SELECT u.id AS id, u.subject AS subject, u.processed AS processed '
                  'FROM unmatched_emails u '
                  'JOIN scan_results s ON s.id = u.scan_result_id '
                  'WHERE s.account_id = ? '
                  'AND u.provider_identifier_type = ? '
                  'AND u.provider_identifier_value = ? '
                  'AND u.folder_name = ? '
                  'ORDER BY u.id DESC LIMIT 1',
                  [
                    accountId,
                    email.providerIdentifierType,
                    email.providerIdentifierValue,
                    email.folderName,
                  ],
                );

          final values = email.toMap();
          if (existing.isEmpty) {
            final id = await txn.insert('unmatched_emails', values);
            results.add(UnmatchedUpsertResult(id, UnmatchedUpsertOutcome.inserted));
            continue;
          }

          final row = existing.first;
          final id = row['id'] as int;
          final wasProcessed = (row['processed'] as int?) == 1;
          final subjectChanged = (row['subject'] as String?) != email.subject;
          // Keep first-seen and the row id; everything else describes this sighting.
          values
            ..remove('id')
            ..remove('created_at')
            ..['processed'] = 0;
          await txn.update('unmatched_emails', values,
              where: 'id = ?', whereArgs: [id]);
          results.add(UnmatchedUpsertResult(
              id,
              wasProcessed
                  ? UnmatchedUpsertOutcome.reappeared
                  : subjectChanged
                      ? UnmatchedUpsertOutcome.changed
                      : UnmatchedUpsertOutcome.unchanged));
        }
      });

      // MV step 5: a dismissed row that a scan found again is logged, so
      // "it came back" is provable from the log, not only from the screen.
      for (final r in results) {
        if (r.outcome == UnmatchedUpsertOutcome.reappeared) {
          await DiagnosticLogger.log(
            kind: DiagnosticLogger.kindInfo,
            context: 'F245/no-rule',
            detail: 'row ${r.id} reappeared: dismissed earlier, found again '
                'with no rule',
          );
        }
      }

      final inserted = results
          .where((r) => r.outcome == UnmatchedUpsertOutcome.inserted)
          .length;
      _logger.d('Upserted ${emails.length} unmatched emails '
          '($inserted new, ${emails.length - inserted} refreshed)');
      return results;
    } catch (e) {
      _logger.e('Failed to upsert unmatched emails: $e');
      rethrow;
    }
  }

  /// F245 (Sprint 77, Harold Q21): every UNPROCESSED No Rule row for one
  /// account, across scans. With one row per email there are no duplicates.
  /// The account comes from `scan_results.account_id` (no account column).
  Future<List<UnmatchedEmail>> getUnprocessedForAccount(String accountId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.rawQuery(
        'SELECT u.* FROM unmatched_emails u '
        'JOIN scan_results s ON s.id = u.scan_result_id '
        'WHERE s.account_id = ? AND u.processed = 0 '
        'ORDER BY u.created_at DESC, u.id ASC',
        [accountId],
      );
      return maps.map(UnmatchedEmail.fromMap).toList();
    } catch (e) {
      _logger.e('Failed to get unprocessed unmatched emails for account: $e');
      rethrow;
    }
  }

  /// Get all unmatched emails for a specific scan result
  ///
  /// Returns empty list if no emails found, throws exception on error
  Future<List<UnmatchedEmail>> getUnmatchedEmailsByScan(int scanResultId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'unmatched_emails',
        where: 'scan_result_id = ?',
        whereArgs: [scanResultId],
        orderBy: 'created_at DESC',
      );

      final emails = maps.map(UnmatchedEmail.fromMap).toList();
      _logger.d('Retrieved ${emails.length} unmatched emails for scan $scanResultId');
      return emails;
    } catch (e) {
      _logger.e('Failed to get unmatched emails for scan $scanResultId: $e');
      rethrow;
    }
  }

  /// Get unmatched emails with optional filtering
  ///
  /// Filter options:
  /// - availabilityOnly: if true, only return 'available' emails
  /// - processedOnly: if true, only return processed emails
  /// - unprocessedOnly: if true, only return unprocessed emails
  Future<List<UnmatchedEmail>> getUnmatchedEmailsByScanFiltered(
    int scanResultId, {
    bool? availabilityOnly,
    bool? processedOnly,
    bool? unprocessedOnly,
  }) async {
    try {
      final db = await _databaseHelper.database;
      String where = 'scan_result_id = ?';
      final whereArgs = <dynamic>[scanResultId];

      if (availabilityOnly == true) {
        where += ' AND availability_status = ?';
        whereArgs.add('available');
      }

      if (processedOnly == true) {
        where += ' AND processed = 1';
      } else if (unprocessedOnly == true) {
        where += ' AND processed = 0';
      }

      final maps = await db.query(
        'unmatched_emails',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      return maps.map(UnmatchedEmail.fromMap).toList();
    } catch (e) {
      _logger.e('Failed to get filtered unmatched emails: $e');
      rethrow;
    }
  }

  /// Update availability status for an unmatched email
  ///
  /// Status should be one of: 'available', 'deleted', 'moved', 'unknown'
  /// Returns true on success, false if email not found, throws exception on error
  Future<bool> updateAvailabilityStatus(
    int emailId,
    String status,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = await db.update(
        'unmatched_emails',
        {
          'availability_status': status,
          'availability_checked_at': now,
        },
        where: 'id = ?',
        whereArgs: [emailId],
      );

      final success = result > 0;
      if (success) {
        _logger.d('Updated availability status for email $emailId to $status');
      } else {
        _logger.w('Email not found for availability update: $emailId');
      }
      return success;
    } catch (e) {
      _logger.e('Failed to update availability status for email $emailId: $e');
      rethrow;
    }
  }

  /// Mark unmatched email as processed/unprocessed by user
  ///
  /// Returns true on success, false if email not found, throws exception on error
  ///
  /// [reason] says why, and is written to the diagnostic log with [detail]
  /// (a short fixed label such as an action name or a rule type). [detail] is
  /// passed through [DiagnosticLogger.scrub] here, the one sink, so an address
  /// that reaches it is redacted. The scrub does NOT cover subject text, so a
  /// caller must never pass a rule name (a subject rule is named from the
  /// subject).
  Future<bool> markAsProcessed(
    int emailId,
    bool processed, {
    required NoRuleMarkReason reason,
    String? detail,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.update(
        'unmatched_emails',
        {'processed': processed ? 1 : 0},
        where: 'id = ?',
        whereArgs: [emailId],
      );

      final success = result > 0;
      if (success) {
        _logger.d('Marked email $emailId as ${processed ? 'processed' : 'unprocessed'}');
        await DiagnosticLogger.log(
          kind: DiagnosticLogger.kindInfo,
          context: 'F245/no-rule',
          detail: 'row $emailId marked '
              '${processed ? 'addressed' : 'unaddressed'}: ${reason.name}'
              '${detail == null || detail.isEmpty ? '' : ' (${DiagnosticLogger.scrub(detail)})'}',
        );
      }
      return success;
    } catch (e) {
      _logger.e('Failed to mark email $emailId as processed: $e');
      rethrow;
    }
  }

  /// Delete a single unmatched email
  ///
  /// Returns true on success, false if email not found, throws exception on error
  Future<bool> deleteUnmatchedEmail(int emailId) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.delete(
        'unmatched_emails',
        where: 'id = ?',
        whereArgs: [emailId],
      );

      final success = result > 0;
      if (success) {
        _logger.d('Deleted unmatched email $emailId');
      }
      return success;
    } catch (e) {
      _logger.e('Failed to delete unmatched email $emailId: $e');
      rethrow;
    }
  }

  /// Delete all unmatched emails for a specific scan (CASCADE)
  ///
  /// Note: This is typically triggered automatically when scan_result is deleted
  /// Returns number of emails deleted, throws exception on error
  Future<int> deleteUnmatchedEmailsByScan(int scanResultId) async {
    try {
      final db = await _databaseHelper.database;
      final count = await db.delete(
        'unmatched_emails',
        where: 'scan_result_id = ?',
        whereArgs: [scanResultId],
      );

      _logger.d('Deleted $count unmatched emails for scan $scanResultId');
      return count;
    } catch (e) {
      _logger.e('Failed to delete unmatched emails for scan $scanResultId: $e');
      rethrow;
    }
  }

  /// Get unmatched email by ID
  ///
  /// Returns email if found, null if not found, throws exception on error
  Future<UnmatchedEmail?> getUnmatchedEmailById(int emailId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'unmatched_emails',
        where: 'id = ?',
        whereArgs: [emailId],
      );

      if (maps.isEmpty) {
        _logger.d('Unmatched email not found: $emailId');
        return null;
      }

      return UnmatchedEmail.fromMap(maps.first);
    } catch (e) {
      _logger.e('Failed to get unmatched email $emailId: $e');
      rethrow;
    }
  }

  /// Delete unmatched emails older than [retentionDays] days (SEC-14, Sprint 33).
  ///
  /// Removes rows whose LAST-SEEN time (F245, Harold Q22; `created_at` for a
  /// row that has none) is older than `now - retentionDays * 1d`, so an email
  /// a scan still finds is never cut at 90 days.
  /// Returns the number of rows deleted. Intended to be called on app startup
  /// and after each scan completes so retention enforcement is continuous and
  /// independent of UI navigation.
  ///
  /// Passing a non-positive [retentionDays] is treated as "retain forever"
  /// (no-op) to make it easy to expose a user-facing "keep all" option.
  Future<int> deleteOlderThan(int retentionDays) async {
    if (retentionDays <= 0) {
      _logger.d('Retention cleanup skipped: retentionDays=$retentionDays '
          '(retain forever)');
      return 0;
    }

    try {
      final cutoff = DateTime.now()
          .subtract(Duration(days: retentionDays))
          .millisecondsSinceEpoch;

      final db = await _databaseHelper.database;
      final count = await db.delete(
        'unmatched_emails',
        where: 'COALESCE(last_seen_at, created_at) < ?',
        whereArgs: [cutoff],
      );

      if (count > 0) {
        _logger.i('Deleted $count unmatched emails older than '
            '$retentionDays days (retention cleanup)');
      } else {
        _logger.d('No unmatched emails older than $retentionDays days to '
            'delete');
      }
      return count;
    } catch (e) {
      _logger.e('Failed to delete unmatched emails older than '
          '$retentionDays days: $e');
      rethrow;
    }
  }

  /// Get count of unmatched emails for a scan
  Future<int> getUnmatchedEmailCountByScan(int scanResultId) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM unmatched_emails WHERE scan_result_id = ?',
        [scanResultId],
      );

      final count = (result.first['count'] as int?) ?? 0;
      return count;
    } catch (e) {
      _logger.e('Failed to get unmatched email count: $e');
      rethrow;
    }
  }
}
