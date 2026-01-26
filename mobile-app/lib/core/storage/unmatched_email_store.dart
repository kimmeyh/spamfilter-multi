/// Store for managing unmatched emails from scan results
///
/// This store handles:
/// - Storing emails that did not match any rules during scans
/// - Tracking email availability (still exists, deleted, moved)
/// - Marking emails as processed by user
/// - Provider-specific email identifiers (Gmail message ID, IMAP UID)

import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import '../models/provider_email_identifier.dart';
import 'database_helper.dart';

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
  final DateTime createdAt;

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
        'body_preview': bodyPreview,
        'folder_name': folderName,
        'email_date': emailDate?.millisecondsSinceEpoch,
        'availability_status': availabilityStatus,
        'availability_checked_at': availabilityCheckedAt?.millisecondsSinceEpoch,
        'processed': processed ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
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
      );

  @override
  String toString() =>
      'UnmatchedEmail(id: $id, from: $fromEmail, subject: $subject, status: $availabilityStatus)';
}

/// Database store for managing unmatched emails
class UnmatchedEmailStore {
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();

  UnmatchedEmailStore(this._databaseHelper);

  /// Add a single unmatched email to database
  ///
  /// Returns the ID of the inserted row, or throws exception on error
  Future<int> addUnmatchedEmail(UnmatchedEmail email) async {
    try {
      final db = await _databaseHelper.database;
      final id = await db.insert('unmatched_emails', email.toMap());
      _logger.d(
          'Added unmatched email: ${email.fromEmail} (id: $id, scan: ${email.scanResultId})');
      return id;
    } catch (e) {
      _logger.e('Failed to add unmatched email: $e');
      rethrow;
    }
  }

  /// Add multiple unmatched emails in a single transaction (PERFORMANCE CRITICAL)
  ///
  /// Using transaction ensures all-or-nothing semantics and better performance
  /// Returns list of inserted IDs in order, or throws exception on error
  Future<List<int>> addUnmatchedEmailBatch(List<UnmatchedEmail> emails) async {
    if (emails.isEmpty) return [];

    try {
      final db = await _databaseHelper.database;
      final ids = <int>[];

      await db.transaction((txn) async {
        for (final email in emails) {
          final id = await txn.insert('unmatched_emails', email.toMap());
          ids.add(id);
        }
      });

      _logger.d('Batch inserted ${emails.length} unmatched emails');
      return ids;
    } catch (e) {
      _logger.e('Failed to batch insert unmatched emails: $e');
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
  Future<bool> markAsProcessed(int emailId, bool processed) async {
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
