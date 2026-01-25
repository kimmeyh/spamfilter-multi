/// Store for managing scan result metadata
///
/// This store handles:
/// - Creating scan result records for manual and background scans
/// - Tracking scan metadata (type, mode, counts, status)
/// - Updating counts as scan progresses
/// - Retrieving scan results by account or date
/// - Deleting scan results (with cascade to unmatched emails)

import 'package:logger/logger.dart';

import 'database_helper.dart';

/// Model class for scan results
class ScanResult {
  final int? id;
  final String accountId;
  final String scanType; // 'manual' or 'background'
  final String scanMode; // 'readonly', 'safe_senders', 'full'
  final int startedAt; // milliseconds since epoch
  final int? completedAt; // nullable until scan finishes
  final int totalEmails;
  final int processedCount; // emails processed/actioned
  final int deletedCount; // proposed or executed deletes
  final int movedCount; // proposed or executed moves
  final int safeSenderCount; // safe sender matches
  final int noRuleCount; // emails with no rule match
  final int errorCount; // scan errors
  final String status; // 'in_progress', 'completed', 'error'
  final String? errorMessage; // error details if status='error'
  final List<String> foldersScanned; // folders that were scanned

  ScanResult({
    this.id,
    required this.accountId,
    required this.scanType,
    required this.scanMode,
    required this.startedAt,
    this.completedAt,
    required this.totalEmails,
    this.processedCount = 0,
    this.deletedCount = 0,
    this.movedCount = 0,
    this.safeSenderCount = 0,
    this.noRuleCount = 0,
    this.errorCount = 0,
    this.status = 'in_progress',
    this.errorMessage,
    this.foldersScanned = const [],
  });

  /// Convert model to database map
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'account_id': accountId,
        'scan_type': scanType,
        'scan_mode': scanMode,
        'started_at': startedAt,
        'completed_at': completedAt,
        'total_emails': totalEmails,
        'processed_count': processedCount,
        'deleted_count': deletedCount,
        'moved_count': movedCount,
        'safe_sender_count': safeSenderCount,
        'no_rule_count': noRuleCount,
        'error_count': errorCount,
        'status': status,
        'error_message': errorMessage,
        'folders_scanned': foldersScanned.isEmpty ? '[]' : '[${foldersScanned.map((f) => '"$f"').join(',')}]',
      };

  /// Create model from database map
  static ScanResult fromMap(Map<String, dynamic> map) {
    final foldersJson = map['folders_scanned'] as String? ?? '[]';
    List<String> folders = [];
    try {
      if (foldersJson.isNotEmpty && foldersJson != '[]') {
        // Simple JSON parsing for folder names
        // Only parse if it looks like a JSON array (starts with [ and ends with ])
        if (foldersJson.startsWith('[') && foldersJson.endsWith(']')) {
          final cleaned = foldersJson.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
          if (cleaned.isNotEmpty) {
            folders = cleaned.split(',').map((f) => f.trim()).toList();
          }
        }
      }
    } catch (e) {
      // If parsing fails, continue with empty list
    }

    return ScanResult(
      id: map['id'] as int?,
      accountId: map['account_id'] as String,
      scanType: map['scan_type'] as String,
      scanMode: map['scan_mode'] as String,
      startedAt: map['started_at'] as int,
      completedAt: map['completed_at'] as int?,
      totalEmails: map['total_emails'] as int? ?? 0,
      processedCount: map['processed_count'] as int? ?? 0,
      deletedCount: map['deleted_count'] as int? ?? 0,
      movedCount: map['moved_count'] as int? ?? 0,
      safeSenderCount: map['safe_sender_count'] as int? ?? 0,
      noRuleCount: map['no_rule_count'] as int? ?? 0,
      errorCount: map['error_count'] as int? ?? 0,
      status: map['status'] as String? ?? 'in_progress',
      errorMessage: map['error_message'] as String?,
      foldersScanned: folders,
    );
  }

  /// Create copy with optional field updates
  ScanResult copyWith({
    int? id,
    String? accountId,
    String? scanType,
    String? scanMode,
    int? startedAt,
    int? completedAt,
    int? totalEmails,
    int? processedCount,
    int? deletedCount,
    int? movedCount,
    int? safeSenderCount,
    int? noRuleCount,
    int? errorCount,
    String? status,
    String? errorMessage,
    List<String>? foldersScanned,
  }) =>
      ScanResult(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        scanType: scanType ?? this.scanType,
        scanMode: scanMode ?? this.scanMode,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        totalEmails: totalEmails ?? this.totalEmails,
        processedCount: processedCount ?? this.processedCount,
        deletedCount: deletedCount ?? this.deletedCount,
        movedCount: movedCount ?? this.movedCount,
        safeSenderCount: safeSenderCount ?? this.safeSenderCount,
        noRuleCount: noRuleCount ?? this.noRuleCount,
        errorCount: errorCount ?? this.errorCount,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        foldersScanned: foldersScanned ?? this.foldersScanned,
      );

  @override
  String toString() =>
      'ScanResult(id: $id, type: $scanType, account: $accountId, status: $status, processed: $processedCount, noRule: $noRuleCount)';
}

/// Database store for managing scan results
class ScanResultStore {
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();

  ScanResultStore(this._databaseHelper);

  /// Create a new scan result record
  ///
  /// Returns the ID of the inserted row, or throws exception on error
  Future<int> addScanResult(ScanResult scanResult) async {
    try {
      final db = await _databaseHelper.database;
      final id = await db.insert('scan_results', scanResult.toMap());
      _logger.d(
          'Added scan result: type=${scanResult.scanType}, account=${scanResult.accountId}, id=$id');
      return id;
    } catch (e) {
      _logger.e('Failed to add scan result: $e');
      rethrow;
    }
  }

  /// Get all scan results for a specific account
  ///
  /// Returns empty list if no scans found, throws exception on error
  Future<List<ScanResult>> getScanResultsByAccount(String accountId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'scan_results',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'started_at DESC',
      );

      final results = maps.map(ScanResult.fromMap).toList();
      _logger.d('Retrieved ${results.length} scan results for account $accountId');
      return results;
    } catch (e) {
      _logger.e('Failed to get scan results for account $accountId: $e');
      rethrow;
    }
  }

  /// Get scan results filtered by account and type
  ///
  /// Filter options:
  /// - scanType: 'manual' or 'background' (or null for all types)
  /// - statusOnly: if provided, only return scans with this status
  /// - completedOnly: if true, only return completed scans
  Future<List<ScanResult>> getScanResultsByAccountFiltered(
    String accountId, {
    String? scanType,
    String? statusOnly,
    bool? completedOnly,
  }) async {
    try {
      final db = await _databaseHelper.database;
      String where = 'account_id = ?';
      final whereArgs = <dynamic>[accountId];

      if (scanType != null) {
        where += ' AND scan_type = ?';
        whereArgs.add(scanType);
      }

      if (statusOnly != null) {
        where += ' AND status = ?';
        whereArgs.add(statusOnly);
      }

      if (completedOnly == true) {
        where += ' AND completed_at IS NOT NULL';
      }

      final maps = await db.query(
        'scan_results',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'started_at DESC',
      );

      return maps.map(ScanResult.fromMap).toList();
    } catch (e) {
      _logger.e('Failed to get filtered scan results: $e');
      rethrow;
    }
  }

  /// Get scan result by ID
  ///
  /// Returns scan result if found, null if not found, throws exception on error
  Future<ScanResult?> getScanResultById(int scanResultId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'scan_results',
        where: 'id = ?',
        whereArgs: [scanResultId],
      );

      if (maps.isEmpty) {
        _logger.d('Scan result not found: $scanResultId');
        return null;
      }

      return ScanResult.fromMap(maps.first);
    } catch (e) {
      _logger.e('Failed to get scan result $scanResultId: $e');
      rethrow;
    }
  }

  /// Get the most recent scan for a specific account and type
  ///
  /// Returns scan if found, null if no scans exist
  Future<ScanResult?> getLatestScanByType(String accountId, String scanType) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'scan_results',
        where: 'account_id = ? AND scan_type = ?',
        whereArgs: [accountId, scanType],
        orderBy: 'started_at DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        _logger.d('No scans found for account $accountId, type $scanType');
        return null;
      }

      return ScanResult.fromMap(maps.first);
    } catch (e) {
      _logger.e('Failed to get latest scan: $e');
      rethrow;
    }
  }

  /// Update scan result record
  ///
  /// Returns true on success, false if scan not found, throws exception on error
  Future<bool> updateScanResult(int scanResultId, ScanResult updates) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.update(
        'scan_results',
        updates.toMap(),
        where: 'id = ?',
        whereArgs: [scanResultId],
      );

      final success = result > 0;
      if (success) {
        _logger.d('Updated scan result $scanResultId');
      } else {
        _logger.w('Scan result not found for update: $scanResultId');
      }
      return success;
    } catch (e) {
      _logger.e('Failed to update scan result $scanResultId: $e');
      rethrow;
    }
  }

  /// Update specific fields in a scan result
  ///
  /// Allows partial updates without replacing entire record
  /// Returns true on success, false if scan not found
  Future<bool> updateScanResultFields(
    int scanResultId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.update(
        'scan_results',
        updates,
        where: 'id = ?',
        whereArgs: [scanResultId],
      );

      final success = result > 0;
      if (success) {
        _logger.d('Updated scan result fields: $scanResultId, fields: ${updates.keys.join(', ')}');
      }
      return success;
    } catch (e) {
      _logger.e('Failed to update scan result fields $scanResultId: $e');
      rethrow;
    }
  }

  /// Mark scan as completed
  ///
  /// Sets completed_at timestamp and status
  /// Returns true on success, false if scan not found
  Future<bool> markScanCompleted(int scanResultId) async {
    try {
      final db = await _databaseHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = await db.update(
        'scan_results',
        {
          'completed_at': now,
          'status': 'completed',
        },
        where: 'id = ?',
        whereArgs: [scanResultId],
      );

      final success = result > 0;
      if (success) {
        _logger.d('Marked scan $scanResultId as completed');
      }
      return success;
    } catch (e) {
      _logger.e('Failed to mark scan as completed: $e');
      rethrow;
    }
  }

  /// Mark scan as error
  ///
  /// Sets status to error and stores error message
  /// Returns true on success, false if scan not found
  Future<bool> markScanError(int scanResultId, String errorMessage) async {
    try {
      final db = await _databaseHelper.database;

      final result = await db.update(
        'scan_results',
        {
          'status': 'error',
          'error_message': errorMessage,
        },
        where: 'id = ?',
        whereArgs: [scanResultId],
      );

      final success = result > 0;
      if (success) {
        _logger.d('Marked scan $scanResultId as error: $errorMessage');
      }
      return success;
    } catch (e) {
      _logger.e('Failed to mark scan as error: $e');
      rethrow;
    }
  }

  /// Delete a scan result and all associated unmatched emails (CASCADE)
  ///
  /// Returns true on success, false if scan not found, throws exception on error
  Future<bool> deleteScanResult(int scanResultId) async {
    try {
      final db = await _databaseHelper.database;

      // Database will cascade delete unmatched_emails due to foreign key
      final result = await db.delete(
        'scan_results',
        where: 'id = ?',
        whereArgs: [scanResultId],
      );

      final success = result > 0;
      if (success) {
        _logger.d('Deleted scan result $scanResultId (cascade delete unmatched emails)');
      } else {
        _logger.w('Scan result not found for deletion: $scanResultId');
      }
      return success;
    } catch (e) {
      _logger.e('Failed to delete scan result $scanResultId: $e');
      rethrow;
    }
  }

  /// Delete all scans for a specific account (CASCADE)
  ///
  /// Returns number of scans deleted, throws exception on error
  Future<int> deleteScanResultsByAccount(String accountId) async {
    try {
      final db = await _databaseHelper.database;
      final count = await db.delete(
        'scan_results',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );

      _logger.d('Deleted $count scan results for account $accountId');
      return count;
    } catch (e) {
      _logger.e('Failed to delete scans for account $accountId: $e');
      rethrow;
    }
  }

  /// Get count of scans for an account
  Future<int> getScanCountByAccount(String accountId) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scan_results WHERE account_id = ?',
        [accountId],
      );

      final count = (result.first['count'] as int?) ?? 0;
      return count;
    } catch (e) {
      _logger.e('Failed to get scan count: $e');
      rethrow;
    }
  }

  /// Get count of incomplete scans
  Future<int> getIncompleteScansCount() async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM scan_results WHERE status = 'in_progress'",
      );

      final count = (result.first['count'] as int?) ?? 0;
      return count;
    } catch (e) {
      _logger.e('Failed to get incomplete scans count: $e');
      rethrow;
    }
  }
}
