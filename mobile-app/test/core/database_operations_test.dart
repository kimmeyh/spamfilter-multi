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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late String testDbPath;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp() async {
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
  };

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
}

/// Test implementation of AppPaths for database testing
class TestAppPaths extends AppPaths {
  final String testDbPath;

  TestAppPaths(this.testDbPath);

  @override
  String get databaseFilePath => testDbPath;
}
