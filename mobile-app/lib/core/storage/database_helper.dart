import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';

import '../../adapters/storage/app_paths.dart';

/// Minimal database interface for rule storage operations
abstract class RuleDatabaseProvider {
  Future<Database> get database;
  Future<List<Map<String, dynamic>>> queryRules({bool? enabledOnly});
  Future<List<Map<String, dynamic>>> querySafeSenders();
  Future<int> insertRule(Map<String, dynamic> rule);
  Future<int> insertSafeSender(Map<String, dynamic> safeSender);
  Future<Map<String, dynamic>?> getRule(String ruleName);
  Future<Map<String, dynamic>?> getSafeSender(String pattern);
  Future<int> updateRule(String ruleName, Map<String, dynamic> values);
  Future<int> updateSafeSender(String pattern, Map<String, dynamic> values);
  Future<int> deleteRule(String ruleName);
  Future<int> deleteSafeSender(String pattern);
  Future<void> deleteAllRules();
  Future<void> deleteAllSafeSenders();
}

/// Database schema version (increment on schema changes)
const int databaseVersion = 1;

/// SQLite database helper - singleton pattern
class DatabaseHelper implements RuleDatabaseProvider {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static final Logger _logger = Logger();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// Get or initialize the database
  @override
  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  /// Initialize database and create tables
  Future<Database> _initializeDatabase() async {
    // Use in-memory database for testing if databaseFactory is FFI (indicates test environment)
    final dbPath = databaseFactory.toString().contains('ffi')
        ? 'test_db.sqlite'
        : getAppPaths().databaseFilePath;

    _logger.i('Initializing database at: $dbPath');

    final db = await openDatabase(
      dbPath,
      version: databaseVersion,
      onConfigure: (db) async {
        // Ensure SQLite foreign key constraints are enforced
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );

    return db;
  }

  /// Create all tables on first launch
  Future<void> _createTables(Database db, int version) async {
    _logger.i('Creating database tables (version: $version)');

    // Accounts table (virtual, for tracking account metadata)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        account_id TEXT PRIMARY KEY,
        platform_id TEXT NOT NULL,
        email TEXT NOT NULL,
        display_name TEXT,
        date_added INTEGER NOT NULL,
        last_scanned INTEGER
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_platform ON accounts(platform_id);');

    // Scan results table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT NOT NULL,
        scan_type TEXT NOT NULL,
        scan_mode TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        total_emails INTEGER NOT NULL,
        processed_count INTEGER NOT NULL,
        deleted_count INTEGER NOT NULL,
        moved_count INTEGER NOT NULL,
        safe_sender_count INTEGER NOT NULL,
        no_rule_count INTEGER NOT NULL,
        error_count INTEGER NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        folders_scanned TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_scan_results_account ON scan_results(account_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_scan_results_completed ON scan_results(completed_at DESC);');

    // Email actions table (individual email results)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS email_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scan_result_id INTEGER NOT NULL,
        email_id TEXT NOT NULL,
        email_from TEXT NOT NULL,
        email_subject TEXT NOT NULL,
        email_received_date INTEGER NOT NULL,
        email_folder TEXT NOT NULL,
        action_type TEXT NOT NULL,
        matched_rule_name TEXT,
        matched_pattern TEXT,
        is_safe_sender INTEGER NOT NULL DEFAULT 0,
        success INTEGER NOT NULL,
        error_message TEXT,
        email_still_exists INTEGER DEFAULT 1,
        FOREIGN KEY (scan_result_id) REFERENCES scan_results(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_email_actions_scan ON email_actions(scan_result_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_email_actions_no_rule ON email_actions(matched_rule_name) WHERE matched_rule_name IS NULL;');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_email_actions_folder ON email_actions(email_folder);');

    // Rules table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        enabled INTEGER NOT NULL DEFAULT 1,
        is_local INTEGER NOT NULL DEFAULT 0,
        execution_order INTEGER NOT NULL,
        condition_type TEXT NOT NULL,
        condition_from TEXT,
        condition_header TEXT,
        condition_subject TEXT,
        condition_body TEXT,
        action_delete INTEGER NOT NULL DEFAULT 0,
        action_move_to_folder TEXT,
        action_assign_category TEXT,
        exception_from TEXT,
        exception_header TEXT,
        exception_subject TEXT,
        exception_body TEXT,
        metadata TEXT,
        date_added INTEGER NOT NULL,
        date_modified INTEGER,
        created_by TEXT DEFAULT 'manual'
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rules_enabled ON rules(enabled, execution_order);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rules_name ON rules(name);');

    // Safe senders table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS safe_senders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pattern TEXT NOT NULL UNIQUE,
        pattern_type TEXT NOT NULL,
        exception_patterns TEXT,
        date_added INTEGER NOT NULL,
        date_modified INTEGER,
        created_by TEXT DEFAULT 'manual'
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_safe_senders_pattern ON safe_senders(pattern);');

    // App settings table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        value_type TEXT NOT NULL,
        date_modified INTEGER NOT NULL
      );
    ''');

    // Account settings table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_settings (
        account_id TEXT NOT NULL,
        setting_key TEXT NOT NULL,
        setting_value TEXT NOT NULL,
        value_type TEXT NOT NULL,
        date_modified INTEGER NOT NULL,
        PRIMARY KEY (account_id, setting_key)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_account_settings_account ON account_settings(account_id);');

    // Background scan schedule table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS background_scan_schedule (
        account_id TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL DEFAULT 0,
        frequency_minutes INTEGER NOT NULL DEFAULT 15,
        last_run INTEGER,
        next_scheduled INTEGER,
        scan_mode TEXT NOT NULL DEFAULT 'readonly',
        folders TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
      );
    ''');

    // Unmatched emails table (emails that matched no rules during scan)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS unmatched_emails (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scan_result_id INTEGER NOT NULL,
        provider_identifier_type TEXT NOT NULL,
        provider_identifier_value TEXT NOT NULL,
        from_email TEXT NOT NULL,
        from_name TEXT,
        subject TEXT,
        body_preview TEXT,
        folder_name TEXT NOT NULL,
        email_date INTEGER,
        availability_status TEXT DEFAULT 'unknown',
        availability_checked_at INTEGER,
        processed INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (scan_result_id) REFERENCES scan_results(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_unmatched_scan ON unmatched_emails(scan_result_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_unmatched_processed ON unmatched_emails(processed);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_unmatched_availability ON unmatched_emails(availability_status);');

    _logger.i('Database tables created successfully');
  }

  /// Handle database schema upgrades
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    _logger.w('Database upgrade: $oldVersion → $newVersion (not implemented yet)');
    // Future migrations will be implemented here
  }

  // ============================================================================
  // CRUD Operations - scan_results
  // ============================================================================

  Future<int> insertScanResult(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('scan_results', values);
  }

  Future<List<Map<String, dynamic>>> queryScanResults({
    String? accountId,
    String? scanType,
    int? limit,
  }) async {
    final db = await database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (accountId != null) {
      whereClause += ' AND account_id = ?';
      whereArgs.add(accountId);
    }
    if (scanType != null) {
      whereClause += ' AND scan_type = ?';
      whereArgs.add(scanType);
    }

    return db.query(
      'scan_results',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'completed_at DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getScanResult(int scanResultId) async {
    final db = await database;
    final results = await db.query(
      'scan_results',
      where: 'id = ?',
      whereArgs: [scanResultId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateScanResult(int scanResultId, Map<String, dynamic> values) async {
    final db = await database;
    return db.update(
      'scan_results',
      values,
      where: 'id = ?',
      whereArgs: [scanResultId],
    );
  }

  // ============================================================================
  // CRUD Operations - email_actions
  // ============================================================================

  Future<int> insertEmailAction(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('email_actions', values);
  }

  Future<int> insertEmailActionBatch(List<Map<String, dynamic>> values) async {
    final db = await database;
    int count = 0;
    for (final value in values) {
      count += await db.insert('email_actions', value);
    }
    return count;
  }

  Future<List<Map<String, dynamic>>> queryEmailActions({
    int? scanResultId,
    String? folder,
    bool? unmatchedOnly,
    int? limit,
  }) async {
    final db = await database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (scanResultId != null) {
      whereClause += ' AND scan_result_id = ?';
      whereArgs.add(scanResultId);
    }
    if (folder != null) {
      whereClause += ' AND email_folder = ?';
      whereArgs.add(folder);
    }
    if (unmatchedOnly == true) {
      whereClause += ' AND matched_rule_name IS NULL';
    }

    return db.query(
      'email_actions',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'email_received_date DESC',
      limit: limit,
    );
  }

  Future<int> getUnmatchedEmailCount(int scanResultId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM email_actions WHERE scan_result_id = ? AND matched_rule_name IS NULL',
      [scanResultId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> updateEmailAction(int emailActionId, Map<String, dynamic> values) async {
    final db = await database;
    return db.update(
      'email_actions',
      values,
      where: 'id = ?',
      whereArgs: [emailActionId],
    );
  }

  // ============================================================================
  // CRUD Operations - rules
  // ============================================================================

  @override
  Future<int> insertRule(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('rules', values);
  }

  @override
  Future<List<Map<String, dynamic>>> queryRules({bool? enabledOnly}) async {
    final db = await database;
    String whereClause = '1=1';
    if (enabledOnly == true) {
      whereClause = 'enabled = 1';
    }
    return db.query(
      'rules',
      where: whereClause,
      orderBy: 'execution_order ASC',
    );
  }

  @override
  Future<Map<String, dynamic>?> getRule(String ruleName) async {
    final db = await database;
    final results = await db.query(
      'rules',
      where: 'name = ?',
      whereArgs: [ruleName],
    );
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<int> updateRule(String ruleName, Map<String, dynamic> values) async {
    final db = await database;
    return db.update(
      'rules',
      values,
      where: 'name = ?',
      whereArgs: [ruleName],
    );
  }

  @override
  Future<int> deleteRule(String ruleName) async {
    final db = await database;
    return db.delete(
      'rules',
      where: 'name = ?',
      whereArgs: [ruleName],
    );
  }

  @override
  Future<void> deleteAllRules() async {
    final db = await database;
    await db.delete('rules');
  }

  // ============================================================================
  // CRUD Operations - safe_senders
  // ============================================================================

  @override
  Future<int> insertSafeSender(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('safe_senders', values);
  }

  @override
  Future<List<Map<String, dynamic>>> querySafeSenders() async {
    final db = await database;
    return db.query('safe_senders', orderBy: 'pattern ASC');
  }

  @override
  Future<Map<String, dynamic>?> getSafeSender(String pattern) async {
    final db = await database;
    final results = await db.query(
      'safe_senders',
      where: 'pattern = ?',
      whereArgs: [pattern],
    );
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<int> updateSafeSender(String pattern, Map<String, dynamic> values) async {
    final db = await database;
    return db.update(
      'safe_senders',
      values,
      where: 'pattern = ?',
      whereArgs: [pattern],
    );
  }

  @override
  Future<int> deleteSafeSender(String pattern) async {
    final db = await database;
    return db.delete(
      'safe_senders',
      where: 'pattern = ?',
      whereArgs: [pattern],
    );
  }

  @override
  Future<void> deleteAllSafeSenders() async {
    final db = await database;
    await db.delete('safe_senders');
  }

  // ============================================================================
  // CRUD Operations - app_settings
  // ============================================================================

  Future<int> setAppSetting(String key, String value, String valueType) async {
    final db = await database;
    return db.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'value_type': valueType,
        'date_modified': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getAppSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<Map<String, dynamic>> getAllAppSettings() async {
    final db = await database;
    final results = await db.query('app_settings');
    final settings = <String, dynamic>{};
    for (final row in results) {
      settings[row['key'] as String] = row['value'];
    }
    return settings;
  }

  // ============================================================================
  // CRUD Operations - account_settings
  // ============================================================================

  Future<int> setAccountSetting(String accountId, String key, String value, String valueType) async {
    final db = await database;
    return db.insert(
      'account_settings',
      {
        'account_id': accountId,
        'setting_key': key,
        'setting_value': value,
        'value_type': valueType,
        'date_modified': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getAccountSetting(String accountId, String key) async {
    final db = await database;
    final results = await db.query(
      'account_settings',
      where: 'account_id = ? AND setting_key = ?',
      whereArgs: [accountId, key],
    );
    return results.isNotEmpty ? results.first['setting_value'] as String? : null;
  }

  Future<Map<String, dynamic>> getAccountSettings(String accountId) async {
    final db = await database;
    final results = await db.query(
      'account_settings',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    final settings = <String, dynamic>{};
    for (final row in results) {
      settings[row['setting_key'] as String] = row['setting_value'];
    }
    return settings;
  }

  // ============================================================================
  // CRUD Operations - background_scan_schedule
  // ============================================================================

  Future<int> insertBackgroundSchedule(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert(
      'background_scan_schedule',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getBackgroundSchedule(String accountId) async {
    final db = await database;
    final results = await db.query(
      'background_scan_schedule',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getEnabledBackgroundSchedules() async {
    final db = await database;
    return db.query(
      'background_scan_schedule',
      where: 'enabled = 1',
    );
  }

  Future<int> updateBackgroundSchedule(String accountId, Map<String, dynamic> values) async {
    final db = await database;
    return db.update(
      'background_scan_schedule',
      values,
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  // ============================================================================
  // CRUD Operations - accounts
  // ============================================================================

  Future<int> insertAccount(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert(
      'accounts',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAccount(String accountId) async {
    final db = await database;
    final results = await db.query(
      'accounts',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    final db = await database;
    return db.query('accounts', orderBy: 'date_added DESC');
  }

  Future<int> updateAccount(String accountId, Map<String, dynamic> values) async {
    final db = await database;
    return db.update(
      'accounts',
      values,
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  Future<int> deleteAccount(String accountId) async {
    final db = await database;
    return db.delete(
      'accounts',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Clear all data (for testing)
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('email_actions');
    await db.delete('scan_results');
    await db.delete('rules');
    await db.delete('safe_senders');
    await db.delete('app_settings');
    await db.delete('account_settings');
    await db.delete('background_scan_schedule');
    await db.delete('accounts');
    _logger.w('All database data deleted');
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    final stats = <String, dynamic>{};

    final scanCount = await db.rawQuery('SELECT COUNT(*) as count FROM scan_results');
    stats['scan_results'] = (scanCount.first['count'] as int?) ?? 0;

    final emailCount = await db.rawQuery('SELECT COUNT(*) as count FROM email_actions');
    stats['email_actions'] = (emailCount.first['count'] as int?) ?? 0;

    final rulesCount = await db.rawQuery('SELECT COUNT(*) as count FROM rules');
    stats['rules'] = (rulesCount.first['count'] as int?) ?? 0;

    final safeSendersCount = await db.rawQuery('SELECT COUNT(*) as count FROM safe_senders');
    stats['safe_senders'] = (safeSendersCount.first['count'] as int?) ?? 0;

    return stats;
  }
}
