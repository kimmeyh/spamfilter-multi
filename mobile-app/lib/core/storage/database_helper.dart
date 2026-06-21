import 'dart:convert';
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
/// v1: Initial schema (Sprint 12)
/// v2: Add pattern classification columns to rules table (Sprint 20)
/// v3: Add auth_rate_limit table for failed-auth throttling (SEC-22, Sprint 33)
/// v4: Add last_history_id column to accounts table (Sprint 37 F6c Phase 2,
///     Gmail OAuth incremental scans via historyId)
/// v5: Add account_folder_cursors table (Sprint 38 F6c Phase 2 IMAP extension,
///     per-(account, folder) cursor for UID-based incremental scans)
/// v6: Add columns to email_actions table (Sprint 39). This single version
///     intentionally carries MORE THAN ONE additive column so sibling tasks
///     can land in the same migration:
///       - F91: rfc5322_message_id (nullable TEXT) -- RFC 5322 Message-ID
///         captured at scan time for AOL copy-not-move source-folder dedup.
///       - F89: created_with_auth_state (nullable TEXT) on BOTH the rules and
///         safe_senders tables -- the GREEN/YELLOW/RED/GREY SPF/DKIM/DMARC
///         snapshot captured when a rule or safe sender was created via a
///         quick-add prompt.
const int databaseVersion = 7;

/// SQLite database helper - singleton pattern
class DatabaseHelper implements RuleDatabaseProvider {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static AppPaths? _appPaths;
  static final Logger _logger = Logger();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// Set AppPaths instance (must call before first database access)
  void setAppPaths(AppPaths appPaths) {
    _appPaths = appPaths;
  }

  /// Get or initialize the database
  @override
  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  /// Initialize database and create tables
  Future<Database> _initializeDatabase() async {
    if (_appPaths == null) {
      throw StateError('AppPaths not set. Call setAppPaths() before accessing database.');
    }

    final dbPath = _appPaths!.databaseFilePath;

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
    // last_history_id is Gmail-only (Sprint 37 F6c). Used as the
    // startHistoryId for users.history.list incremental delta scans;
    // null means "no successful scan yet, do a full scan and then
    // persist the resulting historyId".
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        account_id TEXT PRIMARY KEY,
        platform_id TEXT NOT NULL,
        email TEXT NOT NULL,
        display_name TEXT,
        date_added INTEGER NOT NULL,
        last_scanned INTEGER,
        last_history_id TEXT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_platform ON accounts(platform_id);');

    // Sprint 38 Round 1: per-(account, folder) cursor table for IMAP
    // incremental scans (extending F6c Phase 2 to IMAP). See v5 migration
    // block for the rationale + cursor strategy.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_folder_cursors (
        account_id TEXT NOT NULL,
        folder_name TEXT NOT NULL,
        cursor_type TEXT NOT NULL,
        cursor_value TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (account_id, folder_name, cursor_type)
      );
    ''');

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
        rfc5322_message_id TEXT,
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
        created_by TEXT DEFAULT 'manual',
        pattern_category TEXT,
        pattern_sub_type TEXT,
        source_domain TEXT,
        created_with_auth_state TEXT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rules_enabled ON rules(enabled, execution_order);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rules_name ON rules(name);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rules_category ON rules(pattern_category, pattern_sub_type);');

    // Safe senders table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS safe_senders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pattern TEXT NOT NULL UNIQUE,
        pattern_type TEXT NOT NULL,
        exception_patterns TEXT,
        date_added INTEGER NOT NULL,
        date_modified INTEGER,
        created_by TEXT DEFAULT 'manual',
        created_with_auth_state TEXT
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

    // Background scan log table (tracks background scan execution history)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS background_scan_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT NOT NULL,
        scheduled_time INTEGER NOT NULL,
        actual_start_time INTEGER,
        actual_end_time INTEGER,
        status TEXT NOT NULL,
        error_message TEXT,
        emails_processed INTEGER DEFAULT 0,
        unmatched_count INTEGER DEFAULT 0,
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_background_scan_log_account ON background_scan_log(account_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_background_scan_log_scheduled ON background_scan_log(scheduled_time DESC);');

    // Auth rate limit table (SEC-22, Sprint 33): track failed auth attempts
    // per account so we can throttle sign-in after too many failures.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_rate_limit (
        account_id TEXT PRIMARY KEY,
        window_start INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        block_until INTEGER
      );
    ''');

    _logger.i('Database tables created successfully');
  }

  /// Handle database schema upgrades
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    _logger.i('Database upgrade: $oldVersion -> $newVersion');

    if (oldVersion < 2) {
      // v2: Add pattern classification columns to rules table (Sprint 20)
      // Check if columns already exist (split script may have added them)
      _logger.i('Applying v2 migration: adding pattern classification columns');
      final tableInfo = await db.rawQuery('PRAGMA table_info(rules)');
      final existingColumns = tableInfo.map((r) => r['name'] as String).toSet();

      if (!existingColumns.contains('pattern_category')) {
        await db.execute('ALTER TABLE rules ADD COLUMN pattern_category TEXT;');
      }
      if (!existingColumns.contains('pattern_sub_type')) {
        await db.execute('ALTER TABLE rules ADD COLUMN pattern_sub_type TEXT;');
      }
      if (!existingColumns.contains('source_domain')) {
        await db.execute('ALTER TABLE rules ADD COLUMN source_domain TEXT;');
      }
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rules_category ON rules(pattern_category, pattern_sub_type);');
      _logger.i('v2 migration complete');
    }

    if (oldVersion < 3) {
      // v3: Auth rate limit table for failed-auth throttling (SEC-22, Sprint 33)
      _logger.i('Applying v3 migration: creating auth_rate_limit table');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS auth_rate_limit (
          account_id TEXT PRIMARY KEY,
          window_start INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          block_until INTEGER
        );
      ''');
      _logger.i('v3 migration complete');
    }

    if (oldVersion < 4) {
      // v4: Gmail historyId column on accounts table (Sprint 37 F6c)
      // Null-default additive column; safe migration.
      _logger.i('Applying v4 migration: adding last_history_id to accounts');
      final tableInfo = await db.rawQuery('PRAGMA table_info(accounts)');
      final existingColumns = tableInfo.map((r) => r['name'] as String).toSet();
      if (!existingColumns.contains('last_history_id')) {
        await db.execute('ALTER TABLE accounts ADD COLUMN last_history_id TEXT;');
      }
      _logger.i('v4 migration complete');
    }

    if (oldVersion < 5) {
      // v5: per-(account, folder) cursor table for IMAP incremental scans
      // (Sprint 38 Round 1 -- extending F6c Phase 2 from Gmail-OAuth-only
      // to also cover IMAP-backed accounts: gmail-imap, aol, yahoo, etc.)
      //
      // IMAP cursor strategy: persist the highest UID seen per (account,
      // folder) after each successful scan. Next scan does
      // `UID SEARCH UID lastUid+1:*` to fetch only new messages.
      //
      // Why a separate table instead of more columns on accounts:
      //   - Gmail historyId is per-account (one cursor per account)
      //   - IMAP UID cursors are per-folder (separate cursors per folder)
      //   - Forward-compatible with future per-folder cursors for any
      //     provider (e.g., MODSEQ for IMAP CONDSTORE)
      _logger.i('Applying v5 migration: creating account_folder_cursors');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_folder_cursors (
          account_id TEXT NOT NULL,
          folder_name TEXT NOT NULL,
          cursor_type TEXT NOT NULL,
          cursor_value TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (account_id, folder_name, cursor_type)
        );
      ''');
      _logger.i('v5 migration complete');
    }

    if (oldVersion < 6) {
      // v6: additive nullable columns on the email_actions table (Sprint 39).
      //
      // This block is intentionally written to carry MORE THAN ONE column so
      // sibling tasks share one schema version. To add a column, append
      // another guarded `if (!existingColumns.contains(...))` ALTER TABLE
      // below -- do NOT bump the version again for a same-sprint sibling.
      //
      // This v6 block carries THREE additive columns across two features plus a
      // one-time data cleanup; all land in the same schema version:
      //   - F91: email_actions.rfc5322_message_id (RFC 5322 Message-ID captured
      //     at scan time; existing rows null).
      //   - F89: rules.created_with_auth_state + safe_senders.created_with_auth_state
      //     (SPF/DKIM/DMARC snapshot at rule/safe-sender creation; existing rows null).
      //   - BUG-S37-2: removes six malformed bundled TLD rules (see below).
      // To add another column in a future same-sprint sibling, append a guarded
      // `if (!existingColumns.contains(...))` ALTER TABLE -- do NOT bump the
      // version again for a same-sprint sibling. All additions are nullable
      // additive columns -> safe migration.
      _logger.i('Applying v6 migration: adding columns to email_actions');
      final tableInfo = await db.rawQuery('PRAGMA table_info(email_actions)');
      final existingColumns = tableInfo.map((r) => r['name'] as String).toSet();
      if (!existingColumns.contains('rfc5322_message_id')) {
        await db.execute('ALTER TABLE email_actions ADD COLUMN rfc5322_message_id TEXT;');
      }

      // F89 (Sprint 39): persist the SPF/DKIM/DMARC authentication state at
      // the moment a rule or safe sender was created from a quick-add prompt.
      // GREEN/YELLOW/RED/GREY snapshot lets a later audit show "you
      // whitelisted this sender even though its mail had failed
      // authentication." Nullable additive columns -> safe migration.
      // Existing rows are null (created before this feature shipped).
      final rulesInfo = await db.rawQuery('PRAGMA table_info(rules)');
      final rulesColumns = rulesInfo.map((r) => r['name'] as String).toSet();
      if (!rulesColumns.contains('created_with_auth_state')) {
        await db.execute('ALTER TABLE rules ADD COLUMN created_with_auth_state TEXT;');
      }
      final safeSendersInfo = await db.rawQuery('PRAGMA table_info(safe_senders)');
      final safeSendersColumns =
          safeSendersInfo.map((r) => r['name'] as String).toSet();
      if (!safeSendersColumns.contains('created_with_auth_state')) {
        await db.execute('ALTER TABLE safe_senders ADD COLUMN created_with_auth_state TEXT;');
      }

      // BUG-S37-2 (Sprint 39): remove six malformed bundled TLD block rules
      // that were typos or miscategorized second-level domains. They were
      // removed from the bundled rules.yaml for fresh installs; this cleanup
      // removes them from existing installs that already seeded them.
      // .c (single char), .giw, .nwm, .xd (junk), .sweepss (typo of .sweeps,
      // which is retained), .qzz.io (second-level domain, not a TLD).
      //
      // condition_header is a JSON-encoded array (e.g. ["@.*\\.c$"]), so a raw
      // SQL LIKE is fragile across JSON/SQLite escaping. Instead, read the
      // top_level_domain rules, JSON-decode each header, and delete by exact
      // pattern match in Dart. Idempotent: re-running deletes nothing once gone.
      const badTldPatterns = <String>{
        r'@.*\.c$',
        r'@.*\.giw$',
        r'@.*\.nwm$',
        r'@.*\.xd$',
        r'@.*\.sweepss$',
        r'@.*\.qzz.io$',
      };
      final tldRules = await db.query(
        'rules',
        columns: ['id', 'condition_header'],
        where: "pattern_sub_type = 'top_level_domain'",
      );
      final idsToDelete = <Object>[];
      for (final row in tldRules) {
        final raw = row['condition_header'];
        if (raw is! String) continue;
        try {
          final headers = (jsonDecode(raw) as List).cast<String>();
          if (headers.any(badTldPatterns.contains)) {
            idsToDelete.add(row['id'] as Object);
          }
        } catch (_) {
          // Malformed JSON in an existing row: skip rather than fail migration.
        }
      }
      if (idsToDelete.isNotEmpty) {
        final placeholders = List.filled(idsToDelete.length, '?').join(',');
        final deleted = await db.delete(
          'rules',
          where: 'id IN ($placeholders)',
          whereArgs: idsToDelete,
        );
        _logger.i('v6 migration: removed $deleted malformed TLD rule(s) (BUG-S37-2)');
      }

      _logger.i('v6 migration complete');
    }

    if (oldVersion < 7) {
      _logger.i('Running v7 migration');

      // BUG-S37-2 (Sprint 42): remove two more malformed bundled TLD block
      // rules that are typos, not real TLDs: .sho and .sweeps. Removed from the
      // bundled rules.yaml for fresh installs; this cleanup removes them from
      // existing installs. Same JSON-decode-then-delete approach as v6.
      const badTldPatternsV7 = <String>{
        r'@.*\.sho$',
        r'@.*\.sweeps$',
      };
      final tldRulesV7 = await db.query(
        'rules',
        columns: ['id', 'condition_header'],
        where: "pattern_sub_type = 'top_level_domain'",
      );
      final idsToDeleteV7 = <Object>[];
      for (final row in tldRulesV7) {
        final raw = row['condition_header'];
        if (raw is! String) continue;
        try {
          final headers = (jsonDecode(raw) as List).cast<String>();
          if (headers.any(badTldPatternsV7.contains)) {
            idsToDeleteV7.add(row['id'] as Object);
          }
        } catch (_) {
          // Malformed JSON: skip rather than fail migration.
        }
      }
      if (idsToDeleteV7.isNotEmpty) {
        final placeholders = List.filled(idsToDeleteV7.length, '?').join(',');
        final deleted = await db.delete(
          'rules',
          where: 'id IN ($placeholders)',
          whereArgs: idsToDeleteV7,
        );
        _logger.i('v7 migration: removed $deleted malformed TLD rule(s) (BUG-S37-2: .sho, .sweeps)');
      }

      _logger.i('v7 migration complete');
    }
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
  // Gmail Incremental Scan (Sprint 37 F6c + Sprint 38 F6c Phase 2)
  // ============================================================================

  /// Returns the persisted Gmail historyId for [accountId], or null if no
  /// previous scan has persisted one yet. Used by EmailScanner to decide
  /// between a full scan (null) and an incremental scan (non-null) via
  /// GmailApiAdapter.fetchMessagesIncremental.
  Future<String?> getLastHistoryId(String accountId) async {
    final account = await getAccount(accountId);
    if (account == null) return null;
    final value = account['last_history_id'];
    return value is String ? value : null;
  }

  /// Persists the Gmail historyId returned by GmailApiAdapter.getCurrentHistoryId
  /// or .fetchMessagesIncremental for [accountId]. Pass null to clear (used
  /// when an incremental scan returns IncrementalFetchResult.expired and the
  /// caller has to fall back to a full scan and re-capture the historyId).
  Future<void> setLastHistoryId(String accountId, String? historyId) async {
    await updateAccount(accountId, {'last_history_id': historyId});
  }

  // ============================================================================
  // IMAP Per-Folder Cursors (Sprint 38 Round 1, extending F6c Phase 2 to IMAP)
  // ============================================================================

  /// Sprint 38 Round 4 (post-Round-3 redesign 2026-05-17): cursor type for
  /// the **oldest unaddressed no-rule** IMAP UID per (account, folder).
  ///
  /// The Round 1 design used a "highest UID seen" cursor, which caused
  /// subsequent scans to skip previously-no-rule emails -- the wrong
  /// behavior for the manual-scan re-evaluation workflow. Round 4 inverts
  /// the semantics: the cursor points at the OLDEST UID still tagged as
  /// no-rule, so each scan re-fetches that backlog from cursor forward
  /// (via `UID SEARCH UID cursor:*`). The cursor advances as the user
  /// adds rules / safe senders that match the oldest no-rule emails.
  /// When all no-rules are addressed, the cursor is cleared and the
  /// next scan falls back to the configured `daysBack` window.
  ///
  /// One row per (account_id, folder_name) since IMAP UIDs are
  /// mailbox-scoped per RFC 3501.
  static const String cursorTypeOldestNoRuleUid = 'oldest_no_rule_uid';

  /// Round 1 cursor type (next-after-max-UID). Retained as a constant so the
  /// v5 migration's table schema continues to accept legacy rows that may
  /// have been written by Sprint 38 dev builds prior to the Round 4 redesign.
  /// New code uses [cursorTypeOldestNoRuleUid] exclusively; legacy
  /// `imap_uid` rows are inert (never read, never written) and have no
  /// automated cleanup -- they will linger in the table on affected dev
  /// installs until manually removed. Production builds never wrote Round 1
  /// rows because the v5 migration shipped with the Round 4 semantics.
  @Deprecated('Round 1 design replaced by cursorTypeOldestNoRuleUid in Round 4')
  static const String cursorTypeImapUid = 'imap_uid';

  /// Returns the persisted cursor value for [accountId] / [folderName] /
  /// [cursorType], or null if no previous scan has persisted one yet.
  ///
  /// Round 4 default cursor type is [cursorTypeOldestNoRuleUid] -- the
  /// oldest UID still tagged as no-rule. EmailScanner uses it to start
  /// the next scan at `UID SEARCH UID cursor:*`, re-fetching the
  /// still-unaddressed backlog. When null, scan falls back to the
  /// configured `daysBack` window.
  Future<String?> getFolderCursor(
    String accountId,
    String folderName, {
    String cursorType = cursorTypeOldestNoRuleUid,
  }) async {
    final db = await database;
    final rows = await db.query(
      'account_folder_cursors',
      columns: ['cursor_value'],
      where: 'account_id = ? AND folder_name = ? AND cursor_type = ?',
      whereArgs: [accountId, folderName, cursorType],
    );
    if (rows.isEmpty) return null;
    final v = rows.first['cursor_value'];
    return v is String ? v : null;
  }

  /// Persists [cursorValue] for [accountId] / [folderName] / [cursorType].
  /// Inserts or replaces on conflict. Pass null to clear (sets the next
  /// scan back to full-fetch by `daysBack`).
  Future<void> setFolderCursor(
    String accountId,
    String folderName,
    String? cursorValue, {
    String cursorType = cursorTypeOldestNoRuleUid,
  }) async {
    final db = await database;
    if (cursorValue == null) {
      await db.delete(
        'account_folder_cursors',
        where: 'account_id = ? AND folder_name = ? AND cursor_type = ?',
        whereArgs: [accountId, folderName, cursorType],
      );
      return;
    }
    await db.insert(
      'account_folder_cursors',
      {
        'account_id': accountId,
        'folder_name': folderName,
        'cursor_type': cursorType,
        'cursor_value': cursorValue,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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
