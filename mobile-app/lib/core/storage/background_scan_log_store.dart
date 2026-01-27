import 'package:logger/logger.dart';
import 'database_helper.dart';

/// Data class for background scan log entry
class BackgroundScanLogEntry {
  final int? id;
  final String accountId;
  final int scheduledTime;
  final int? actualStartTime;
  final int? actualEndTime;
  final String status; // 'success', 'failed', 'retry'
  final String? errorMessage;
  final int emailsProcessed;
  final int unmatchedCount;

  BackgroundScanLogEntry({
    this.id,
    required this.accountId,
    required this.scheduledTime,
    this.actualStartTime,
    this.actualEndTime,
    required this.status,
    this.errorMessage,
    this.emailsProcessed = 0,
    this.unmatchedCount = 0,
  });

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'account_id': accountId,
      'scheduled_time': scheduledTime,
      'actual_start_time': actualStartTime,
      'actual_end_time': actualEndTime,
      'status': status,
      'error_message': errorMessage,
      'emails_processed': emailsProcessed,
      'unmatched_count': unmatchedCount,
    };
  }

  /// Convert from database map
  factory BackgroundScanLogEntry.fromMap(Map<String, dynamic> map) {
    return BackgroundScanLogEntry(
      id: map['id'] as int?,
      accountId: map['account_id'] as String,
      scheduledTime: map['scheduled_time'] as int,
      actualStartTime: map['actual_start_time'] as int?,
      actualEndTime: map['actual_end_time'] as int?,
      status: map['status'] as String,
      errorMessage: map['error_message'] as String?,
      emailsProcessed: (map['emails_processed'] as int?) ?? 0,
      unmatchedCount: (map['unmatched_count'] as int?) ?? 0,
    );
  }
}

/// Store for background scan log operations
class BackgroundScanLogStore {
  final DatabaseHelper _dbHelper;
  final Logger _logger = Logger();

  BackgroundScanLogStore(this._dbHelper);

  /// Insert a new background scan log entry
  Future<int> insertLog(BackgroundScanLogEntry entry) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert(
        'background_scan_log',
        entry.toMap(),
      );
      _logger.d('Inserted background scan log entry: $id for account ${entry.accountId}');
      return id;
    } catch (e) {
      _logger.e('Failed to insert background scan log entry', error: e);
      rethrow;
    }
  }

  /// Update a background scan log entry
  Future<int> updateLog(BackgroundScanLogEntry entry) async {
    try {
      if (entry.id == null) {
        throw Exception('Cannot update log entry without ID');
      }
      final db = await _dbHelper.database;
      final count = await db.update(
        'background_scan_log',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      _logger.d('Updated background scan log entry: ${entry.id}');
      return count;
    } catch (e) {
      _logger.e('Failed to update background scan log entry', error: e);
      rethrow;
    }
  }

  /// Get the most recent log entry for an account
  Future<BackgroundScanLogEntry?> getLatestLog(String accountId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'background_scan_log',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'scheduled_time DESC',
        limit: 1,
      );

      if (result.isEmpty) {
        return null;
      }

      return BackgroundScanLogEntry.fromMap(result.first);
    } catch (e) {
      _logger.e('Failed to get latest background scan log', error: e);
      rethrow;
    }
  }

  /// Get all log entries for an account
  Future<List<BackgroundScanLogEntry>> getLogsForAccount(String accountId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'background_scan_log',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'scheduled_time DESC',
      );

      return result.map((map) => BackgroundScanLogEntry.fromMap(map)).toList();
    } catch (e) {
      _logger.e('Failed to get background scan logs for account', error: e);
      rethrow;
    }
  }

  /// Get log entries with given status
  Future<List<BackgroundScanLogEntry>> getLogsByStatus(String status) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'background_scan_log',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'scheduled_time DESC',
      );

      return result.map((map) => BackgroundScanLogEntry.fromMap(map)).toList();
    } catch (e) {
      _logger.e('Failed to get background scan logs by status', error: e);
      rethrow;
    }
  }

  /// Delete old log entries (keep last N entries per account)
  Future<void> cleanupOldLogs({int keepPerAccount = 30}) async {
    try {
      final db = await _dbHelper.database;

      // Get all unique account IDs
      final accountResults = await db.rawQuery('''
        SELECT DISTINCT account_id FROM background_scan_log
      ''');

      for (final row in accountResults) {
        final accountId = row['account_id'] as String;

        // Get IDs of old entries to delete
        final idsToDelete = await db.rawQuery('''
          SELECT id FROM background_scan_log
          WHERE account_id = ?
          ORDER BY scheduled_time DESC
          LIMIT -1 OFFSET ?
        ''', [accountId, keepPerAccount]);

        // Delete old entries
        for (final row in idsToDelete) {
          await db.delete(
            'background_scan_log',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }

      _logger.d('Cleaned up old background scan logs (keeping $keepPerAccount per account)');
    } catch (e) {
      _logger.e('Failed to cleanup old background scan logs', error: e);
      rethrow;
    }
  }
}
