import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/adapters/storage/app_paths.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

/// Comprehensive DatabaseHelper test suite
///
/// Tests all CRUD operations for database tables:
/// - scan_results
/// - email_actions
/// - rules
/// - safe_senders
/// - app_settings
/// - account_settings
/// - background_scan_schedule
/// - accounts
///
/// Note: Foreign key constraints are enforced, so tests must create
/// parent records (accounts) before inserting child records (scan_results).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late String testDbPath;

  /// Helper function to create a test account
  /// Required before inserting scan_results due to FK constraint
  Future<void> createTestAccount(String accountId, {String? email}) async {
    await dbHelper.insertAccount({
      'account_id': accountId,
      'platform_id': 'test-platform',
      'email': email ?? '$accountId@test.com',
      'display_name': 'Test User',
      'date_added': DateTime.now().millisecondsSinceEpoch,
    });
  }

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create temp database path for testing
    final tempDir = await Directory.systemTemp.createTemp('spam_filter_test_');
    testDbPath = '${tempDir.path}/test.db';

    // Override database path for testing
    final testAppPaths = TestAppPaths(testDbPath);

    // Initialize DatabaseHelper with test path
    dbHelper = DatabaseHelper();
    dbHelper.setAppPaths(testAppPaths);

    // Clear any existing data
    try {
      await dbHelper.deleteAllData();
    } catch (e) {
      // Ignore if database does not exist yet
    }
  });

  tearDown(() async {
    // Close database and clean up
    await dbHelper.close();
    try {
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  group('Database Initialization', () {
    test('should initialize database with all tables', () async {
      final db = await dbHelper.database;
      expect(db.isOpen, isTrue);

      // Verify all tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains('accounts'));
      expect(tableNames, contains('scan_results'));
      expect(tableNames, contains('email_actions'));
      expect(tableNames, contains('rules'));
      expect(tableNames, contains('safe_senders'));
      expect(tableNames, contains('app_settings'));
      expect(tableNames, contains('account_settings'));
      expect(tableNames, contains('background_scan_schedule'));
      expect(tableNames, contains('unmatched_emails'));
      expect(tableNames, contains('background_scan_log'));
    });

    test('should enforce foreign key constraints', () async {
      final db = await dbHelper.database;
      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect(result.first['foreign_keys'], equals(1));
    });
  });

  group('Scan Results CRUD', () {
    test('should insert scan result', () async {
      // Create account first (FK constraint)
      await createTestAccount('test-account');

      final scanId = await dbHelper.insertScanResult({
        'account_id': 'test-account',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 100,
        'processed_count': 0,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'scanning',
        'folders_scanned': '["INBOX"]',
      });

      expect(scanId, greaterThan(0));
    });

    test('should query scan results by account', () async {
      // Create accounts first (FK constraint)
      await createTestAccount('account-1');
      await createTestAccount('account-2');

      // Insert test data
      await dbHelper.insertScanResult({
        'account_id': 'account-1',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 50,
        'processed_count': 50,
        'deleted_count': 10,
        'moved_count': 5,
        'safe_sender_count': 35,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'completed',
        'folders_scanned': '["INBOX"]',
      });

      await dbHelper.insertScanResult({
        'account_id': 'account-2',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 25,
        'processed_count': 25,
        'deleted_count': 5,
        'moved_count': 2,
        'safe_sender_count': 18,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'completed',
        'folders_scanned': '["INBOX"]',
      });

      final results = await dbHelper.queryScanResults(accountId: 'account-1');
      expect(results.length, equals(1));
      expect(results.first['account_id'], equals('account-1'));
      expect(results.first['total_emails'], equals(50));
    });

    test('should get specific scan result', () async {
      // Create account first (FK constraint)
      await createTestAccount('test-account');

      final scanId = await dbHelper.insertScanResult({
        'account_id': 'test-account',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 100,
        'processed_count': 100,
        'deleted_count': 20,
        'moved_count': 10,
        'safe_sender_count': 70,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'completed',
        'folders_scanned': '["INBOX", "Spam"]',
      });

      final result = await dbHelper.getScanResult(scanId);
      expect(result, isNotNull);
      expect(result!['id'], equals(scanId));
      expect(result['deleted_count'], equals(20));
    });

    test('should update scan result', () async {
      // Create account first (FK constraint)
      await createTestAccount('test-account');

      final scanId = await dbHelper.insertScanResult({
        'account_id': 'test-account',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 100,
        'processed_count': 0,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'scanning',
        'folders_scanned': '["INBOX"]',
      });

      await dbHelper.updateScanResult(scanId, {
        'processed_count': 100,
        'deleted_count': 15,
        'status': 'completed',
        'completed_at': DateTime.now().millisecondsSinceEpoch,
      });

      final updated = await dbHelper.getScanResult(scanId);
      expect(updated!['processed_count'], equals(100));
      expect(updated['status'], equals('completed'));
      expect(updated['completed_at'], isNotNull);
    });
  });

  group('Email Actions CRUD', () {
    late int scanId;

    setUp(() async {
      // Create account first (FK constraint)
      await createTestAccount('test-account');

      // Create a scan result for email actions
      scanId = await dbHelper.insertScanResult({
        'account_id': 'test-account',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 10,
        'processed_count': 0,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'scanning',
        'folders_scanned': '["INBOX"]',
      });
    });

    test('should insert email action', () async {
      final actionId = await dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': 'msg-123',
        'email_from': 'test@example.com',
        'email_subject': 'Test Email',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'delete',
        'matched_rule_name': 'SpamRule',
        'matched_pattern': '@example\\.com',
        'is_safe_sender': 0,
        'success': 1,
      });

      expect(actionId, greaterThan(0));
    });

    test('should query email actions by scan result', () async {
      // Insert test actions
      await dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': 'msg-1',
        'email_from': 'spam@example.com',
        'email_subject': 'Spam Email',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'delete',
        'matched_rule_name': 'SpamRule',
        'matched_pattern': '@example\\.com',
        'is_safe_sender': 0,
        'success': 1,
      });

      await dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': 'msg-2',
        'email_from': 'safe@trusted.com',
        'email_subject': 'Important Email',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'none',
        'is_safe_sender': 1,
        'success': 1,
      });

      final actions = await dbHelper.queryEmailActions(scanResultId: scanId);
      expect(actions.length, equals(2));
    });

    test('should count unmatched emails', () async {
      // Insert emails with and without matched rules
      await dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': 'msg-1',
        'email_from': 'unknown@test.com',
        'email_subject': 'Unknown Email',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'none',
        'is_safe_sender': 0,
        'success': 1,
      });

      await dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': 'msg-2',
        'email_from': 'spam@example.com',
        'email_subject': 'Spam Email',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'delete',
        'matched_rule_name': 'SpamRule',
        'matched_pattern': '@example\\.com',
        'is_safe_sender': 0,
        'success': 1,
      });

      final count = await dbHelper.getUnmatchedEmailCount(scanId);
      expect(count, equals(1)); // Only msg-1 has no matched_rule_name
    });
  });

  group('Rules CRUD', () {
    test('should insert rule', () async {
      final ruleId = await dbHelper.insertRule({
        'name': 'TestRule',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["@spam\\\\.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      expect(ruleId, greaterThan(0));
    });

    test('should query rules with enabled filter', () async {
      // Insert enabled and disabled rules
      await dbHelper.insertRule({
        'name': 'EnabledRule',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["@enabled\\\\.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.insertRule({
        'name': 'DisabledRule',
        'enabled': 0,
        'is_local': 0,
        'execution_order': 20,
        'condition_type': 'OR',
        'condition_from': '["@disabled\\\\.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      final enabledOnly = await dbHelper.queryRules(enabledOnly: true);
      expect(enabledOnly.length, equals(1));
      expect(enabledOnly.first['name'], equals('EnabledRule'));

      final allRules = await dbHelper.queryRules();
      expect(allRules.length, equals(2));
    });

    test('should get specific rule', () async {
      await dbHelper.insertRule({
        'name': 'TestRule',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'AND',
        'condition_from': '["@test\\\\.com"]',
        'condition_subject': '["spam"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      final rule = await dbHelper.getRule('TestRule');
      expect(rule, isNotNull);
      expect(rule!['name'], equals('TestRule'));
      expect(rule['condition_type'], equals('AND'));
    });

    test('should update rule', () async {
      await dbHelper.insertRule({
        'name': 'TestRule',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["@test\\\\.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.updateRule('TestRule', {
        'enabled': 0,
        'execution_order': 20,
        'date_modified': DateTime.now().millisecondsSinceEpoch,
      });

      final updated = await dbHelper.getRule('TestRule');
      expect(updated!['enabled'], equals(0));
      expect(updated['execution_order'], equals(20));
    });

    test('should delete rule', () async {
      await dbHelper.insertRule({
        'name': 'TestRule',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["@test\\\\.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.deleteRule('TestRule');

      final deleted = await dbHelper.getRule('TestRule');
      expect(deleted, isNull);
    });

    test('should delete all rules', () async {
      await dbHelper.insertRule({
        'name': 'Rule1',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["@test\\\\.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.insertRule({
        'name': 'Rule2',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 20,
        'condition_type': 'OR',
        'condition_from': '["@spam\\\\.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.deleteAllRules();

      final rules = await dbHelper.queryRules();
      expect(rules.isEmpty, isTrue);
    });
  });

  group('Safe Senders CRUD', () {
    test('should insert safe sender', () async {
      final id = await dbHelper.insertSafeSender({
        'pattern': '^user@example\\\\.com\$',
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      expect(id, greaterThan(0));
    });

    test('should query all safe senders', () async {
      await dbHelper.insertSafeSender({
        'pattern': '^user1@example\\\\.com\$',
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.insertSafeSender({
        'pattern': '^user2@example\\\\.com\$',
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      final safeSenders = await dbHelper.querySafeSenders();
      expect(safeSenders.length, equals(2));
    });

    test('should get specific safe sender', () async {
      const pattern = '^user@example\\\\.com\$';
      await dbHelper.insertSafeSender({
        'pattern': pattern,
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      final safeSender = await dbHelper.getSafeSender(pattern);
      expect(safeSender, isNotNull);
      expect(safeSender!['pattern'], equals(pattern));
    });

    test('should update safe sender', () async {
      const pattern = '^user@example\\\\.com\$';
      await dbHelper.insertSafeSender({
        'pattern': pattern,
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.updateSafeSender(pattern, {
        'pattern_type': 'wildcard',
        'date_modified': DateTime.now().millisecondsSinceEpoch,
      });

      final updated = await dbHelper.getSafeSender(pattern);
      expect(updated!['pattern_type'], equals('wildcard'));
    });

    test('should delete safe sender', () async {
      const pattern = '^user@example\\\\.com\$';
      await dbHelper.insertSafeSender({
        'pattern': pattern,
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.deleteSafeSender(pattern);

      final deleted = await dbHelper.getSafeSender(pattern);
      expect(deleted, isNull);
    });

    test('should delete all safe senders', () async {
      await dbHelper.insertSafeSender({
        'pattern': '^user1@example\\\\.com\$',
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.insertSafeSender({
        'pattern': '^user2@example\\\\.com\$',
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.deleteAllSafeSenders();

      final safeSenders = await dbHelper.querySafeSenders();
      expect(safeSenders.isEmpty, isTrue);
    });
  });

  group('App Settings CRUD', () {
    test('should set and get app setting', () async {
      await dbHelper.setAppSetting('theme', 'dark', 'string');

      final value = await dbHelper.getAppSetting('theme');
      expect(value, equals('dark'));
    });

    test('should get all app settings', () async {
      await dbHelper.setAppSetting('theme', 'dark', 'string');
      await dbHelper.setAppSetting('language', 'en', 'string');
      await dbHelper.setAppSetting('notifications', 'true', 'boolean');

      final settings = await dbHelper.getAllAppSettings();
      expect(settings.length, equals(3));
      expect(settings['theme'], equals('dark'));
      expect(settings['language'], equals('en'));
      expect(settings['notifications'], equals('true'));
    });

    test('should replace existing setting', () async {
      await dbHelper.setAppSetting('theme', 'light', 'string');
      await dbHelper.setAppSetting('theme', 'dark', 'string');

      final value = await dbHelper.getAppSetting('theme');
      expect(value, equals('dark'));
    });
  });

  group('Database Statistics', () {
    test('should return statistics for all tables', () async {
      // Insert test data
      await dbHelper.insertRule({
        'name': 'TestRule',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["@test\\\\.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.insertSafeSender({
        'pattern': '^user@example\\\\.com\$',
        'pattern_type': 'regex',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      final stats = await dbHelper.getStatistics();
      expect(stats['rules'], equals(1));
      expect(stats['safe_senders'], equals(1));
      expect(stats['scan_results'], equals(0));
      expect(stats['email_actions'], equals(0));
    });
  });

  // Issue #58: Foreign Key Constraint Testing
  group('Foreign Key Constraints', () {
    test('should reject scan_result with non-existent account_id', () async {
      // Attempt to insert scan_result without creating account first
      // This should fail due to FK constraint
      expect(
        () async => await dbHelper.insertScanResult({
          'account_id': 'nonexistent-account',
          'scan_type': 'manual',
          'scan_mode': 'readonly',
          'started_at': DateTime.now().millisecondsSinceEpoch,
          'total_emails': 100,
          'processed_count': 0,
          'deleted_count': 0,
          'moved_count': 0,
          'safe_sender_count': 0,
          'no_rule_count': 0,
          'error_count': 0,
          'status': 'scanning',
          'folders_scanned': '["INBOX"]',
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('should reject email_action with non-existent scan_result_id', () async {
      // Create account and scan_result first
      await createTestAccount('test-account');
      await dbHelper.insertScanResult({
        'account_id': 'test-account',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 10,
        'processed_count': 0,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'scanning',
        'folders_scanned': '["INBOX"]',
      });

      // Attempt to insert email_action with invalid scan_result_id
      expect(
        () async => await dbHelper.insertEmailAction({
          'scan_result_id': 99999, // Non-existent ID
          'email_id': 'msg-123',
          'email_from': 'test@example.com',
          'email_subject': 'Test Email',
          'email_received_date': DateTime.now().millisecondsSinceEpoch,
          'email_folder': 'INBOX',
          'action_type': 'delete',
          'is_safe_sender': 0,
          'success': 1,
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('should cascade delete email_actions when scan_result is deleted', () async {
      // Create account, scan_result, and email_action
      await createTestAccount('test-account');
      final scanId = await dbHelper.insertScanResult({
        'account_id': 'test-account',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 10,
        'processed_count': 1,
        'deleted_count': 1,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'completed',
        'folders_scanned': '["INBOX"]',
      });

      await dbHelper.insertEmailAction({
        'scan_result_id': scanId,
        'email_id': 'msg-123',
        'email_from': 'test@example.com',
        'email_subject': 'Test Email',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'delete',
        'is_safe_sender': 0,
        'success': 1,
      });

      // Verify email_action exists
      var actions = await dbHelper.queryEmailActions(scanResultId: scanId);
      expect(actions.length, equals(1));

      // Delete scan_result directly via database (CASCADE should delete email_actions)
      final db = await dbHelper.database;
      await db.delete('scan_results', where: 'id = ?', whereArgs: [scanId]);

      // Verify email_actions are also deleted (CASCADE)
      actions = await dbHelper.queryEmailActions(scanResultId: scanId);
      expect(actions.length, equals(0));
    });

    test('should accept scan_result with valid account_id', () async {
      // Create account first
      await createTestAccount('valid-account');

      // Insert scan_result with valid account_id
      final scanId = await dbHelper.insertScanResult({
        'account_id': 'valid-account',
        'scan_type': 'manual',
        'scan_mode': 'readonly',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'total_emails': 100,
        'processed_count': 0,
        'deleted_count': 0,
        'moved_count': 0,
        'safe_sender_count': 0,
        'no_rule_count': 0,
        'error_count': 0,
        'status': 'scanning',
        'folders_scanned': '["INBOX"]',
      });

      expect(scanId, greaterThan(0));
    });

    test('foreign keys pragma should be enabled', () async {
      final db = await dbHelper.database;
      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect(result.first['foreign_keys'], equals(1));
    });
  });

  group('Accounts CRUD', () {
    test('should insert account', () async {
      final accountId = await dbHelper.insertAccount({
        'account_id': 'test-account-id',
        'platform_id': 'gmail',
        'email': 'test@gmail.com',
        'display_name': 'Test User',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      expect(accountId, greaterThan(0));
    });

    test('should query accounts', () async {
      await dbHelper.insertAccount({
        'account_id': 'account-1',
        'platform_id': 'gmail',
        'email': 'user1@gmail.com',
        'display_name': 'User 1',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.insertAccount({
        'account_id': 'account-2',
        'platform_id': 'aol',
        'email': 'user2@aol.com',
        'display_name': 'User 2',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      final accounts = await dbHelper.getAllAccounts();
      expect(accounts.length, equals(2));
    });

    test('should get specific account', () async {
      await dbHelper.insertAccount({
        'account_id': 'specific-account',
        'platform_id': 'gmail',
        'email': 'specific@gmail.com',
        'display_name': 'Specific User',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      final account = await dbHelper.getAccount('specific-account');
      expect(account, isNotNull);
      expect(account!['email'], equals('specific@gmail.com'));
    });

    test('should update account', () async {
      await dbHelper.insertAccount({
        'account_id': 'update-account',
        'platform_id': 'gmail',
        'email': 'update@gmail.com',
        'display_name': 'Original Name',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.updateAccount('update-account', {
        'display_name': 'Updated Name',
        'last_scanned': DateTime.now().millisecondsSinceEpoch,
      });

      final updated = await dbHelper.getAccount('update-account');
      expect(updated!['display_name'], equals('Updated Name'));
      expect(updated['last_scanned'], isNotNull);
    });

    test('should delete account', () async {
      await dbHelper.insertAccount({
        'account_id': 'delete-account',
        'platform_id': 'gmail',
        'email': 'delete@gmail.com',
        'display_name': 'Delete User',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      await dbHelper.deleteAccount('delete-account');

      final deleted = await dbHelper.getAccount('delete-account');
      expect(deleted, isNull);
    });
  });
}

/// Test implementation of AppPaths for database testing
class TestAppPaths extends AppPaths {
  final String testDbPath;

  TestAppPaths(this.testDbPath);

  @override
  String get databaseFilePath => testDbPath;
}
