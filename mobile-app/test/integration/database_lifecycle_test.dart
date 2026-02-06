import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/rule_database_store.dart';
import 'package:spam_filter_mobile/core/storage/safe_sender_database_store.dart';
import '../helpers/database_test_helper.dart';

/// Integration tests for database lifecycle operations
///
/// Tests the complete lifecycle:
/// 1. Create database
/// 2. Verify database exists
/// 3. Add rules to database
/// 4. Load rules from database
/// 5. Clear rules from database
/// 6. Verify rules are cleared
void main() {
  // Initialize Flutter binding and FFI for desktop testing
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('Database Lifecycle Integration Tests', () {
    late DatabaseTestHelper testHelper;
    late DatabaseHelper dbHelper;
    late RuleDatabaseStore ruleStore;
    late SafeSenderDatabaseStore safeSenderStore;
    late String testDbPath;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      dbHelper = testHelper.dbHelper;
      testDbPath = testHelper.testDbPath;

      ruleStore = RuleDatabaseStore(dbHelper);
      safeSenderStore = SafeSenderDatabaseStore(dbHelper);
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    test('1. Database is created successfully', () async {
      // Act: Access database (triggers creation)
      final db = await dbHelper.database;

      // Assert: Database is not null and open
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('2. Database file exists on disk after creation', () async {
      // Arrange: Get database path
      final db = await dbHelper.database;
      final dbPath = db.path;

      // Act: Check if file exists
      final dbFile = File(dbPath);
      final exists = await dbFile.exists();

      // Assert: Database file exists
      expect(exists, isTrue);
      expect(dbFile.lengthSync(), greaterThan(0));
    });

    test('3. Database has correct schema (all required tables)', () async {
      // Arrange
      final db = await dbHelper.database;

      // Act: Query for tables
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
      );

      final tableNames = tables.map((t) => t['name'] as String).toList();

      // Assert: All required tables exist
      expect(tableNames, contains('rules'));
      expect(tableNames, contains('safe_senders'));
      expect(tableNames, contains('accounts'));
      expect(tableNames, contains('scan_results'));
      expect(tableNames, contains('email_actions'));
    });

    test('4. Add rules to database and verify count', () async {
      // Arrange: Create test rules
      final testRules = [
        {
          'name': 'TestRule1',
          'enabled': 1,
          'is_local': 0,
          'execution_order': 10,
          'condition_type': 'OR',
          'condition_from': '["spammer@example.com"]',
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
        },
        {
          'name': 'TestRule2',
          'enabled': 1,
          'is_local': 0,
          'execution_order': 20,
          'condition_type': 'AND',
          'condition_subject': '["urgent"]',
          'action_move_to_folder': 'Spam',
          'date_added': DateTime.now().millisecondsSinceEpoch,
        },
      ];

      // Act: Insert rules
      for (final rule in testRules) {
        await dbHelper.insertRule(rule);
      }

      // Assert: Query rule count
      final rules = await dbHelper.queryRules();
      expect(rules.length, equals(2));
      expect(rules[0]['name'], equals('TestRule1'));
      expect(rules[1]['name'], equals('TestRule2'));
    });

    test('5. Load rules from database using RuleDatabaseStore', () async {
      // Arrange: Insert test rule
      await dbHelper.insertRule({
        'name': 'LoadTest',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["test@example.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      // Act: Load rules using store
      final ruleSet = await ruleStore.loadRules();

      // Assert: Rule loaded correctly
      expect(ruleSet.rules.length, equals(1));
      expect(ruleSet.rules[0].name, equals('LoadTest'));
      expect(ruleSet.rules[0].enabled, isTrue);
      expect(ruleSet.rules[0].conditions.type, equals('OR'));
    });

    test('6. Clear all rules from database', () async {
      // Arrange: Insert multiple rules
      for (int i = 0; i < 5; i++) {
        await dbHelper.insertRule({
          'name': 'ClearTest$i',
          'enabled': 1,
          'is_local': 0,
          'execution_order': i * 10,
          'condition_type': 'OR',
          'condition_from': '["test$i@example.com"]',
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Verify rules exist
      final beforeClear = await dbHelper.queryRules();
      expect(beforeClear.length, equals(5));

      // Act: Clear all rules
      await dbHelper.deleteAllRules();

      // Assert: No rules remain
      final afterClear = await dbHelper.queryRules();
      expect(afterClear.length, equals(0));
    });

    test('7. Verify rules are cleared (database is empty)', () async {
      // Arrange: Insert and clear
      await dbHelper.insertRule({
        'name': 'VerifyTest',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["test@example.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });
      await dbHelper.deleteAllRules();

      // Act: Load rules
      final ruleSet = await ruleStore.loadRules();

      // Assert: Empty rule set
      expect(ruleSet.rules, isEmpty);
    });

    test('8. Add safe senders to database', () async {
      // Arrange: Create test safe senders
      final testSafeSenders = [
        {
          'pattern': '^trusted@company\\.com\$',
          'pattern_type': 'email',
          'date_added': DateTime.now().millisecondsSinceEpoch,
        },
        {
          'pattern': '^[^@\\s]+@(?:[a-z0-9-]+\\.)*trusted\\.com\$',
          'pattern_type': 'domain',
          'date_added': DateTime.now().millisecondsSinceEpoch,
        },
      ];

      // Act: Insert safe senders
      for (final sender in testSafeSenders) {
        await dbHelper.insertSafeSender(sender);
      }

      // Assert: Query count
      final safeSenders = await dbHelper.querySafeSenders();
      expect(safeSenders.length, equals(2));
    });

    test('9. Clear safe senders from database', () async {
      // Arrange: Insert safe senders
      await dbHelper.insertSafeSender({
        'pattern': '^test@example\\.com\$',
        'pattern_type': 'email',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      // Verify exists
      final beforeClear = await dbHelper.querySafeSenders();
      expect(beforeClear.length, equals(1));

      // Act: Clear all
      await dbHelper.deleteAllSafeSenders();

      // Assert: Empty
      final afterClear = await dbHelper.querySafeSenders();
      expect(afterClear.length, equals(0));
    });

    test('10. Database survives close and reopen', () async {
      // Arrange: Insert rule
      await dbHelper.insertRule({
        'name': 'PersistenceTest',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["persist@example.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      // Act: Close database properly via helper (so _database is reset)
      await dbHelper.close();

      // Reopen (create new helper with same path)
      final newHelper = DatabaseHelper();
      newHelper.setAppPaths(testHelper.appPaths);

      // Assert: Rule still exists after reopen
      final rules = await newHelper.queryRules();
      expect(rules.length, equals(1));
      expect(rules[0]['name'], equals('PersistenceTest'));

      await newHelper.close();
    });
  });

  group('Database Schema Validation Tests', () {
    late DatabaseTestHelper testHelper;
    late DatabaseHelper dbHelper;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      dbHelper = testHelper.dbHelper;
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    test('Rules table has UNIQUE constraint on name', () async {
      // Arrange
      final testRule = {
        'name': 'UniqueTest',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["test@example.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      };

      // Act: Insert same rule twice
      await dbHelper.insertRule(testRule);

      // Assert: Second insert should fail
      expect(
        () => dbHelper.insertRule(testRule),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Safe senders table has UNIQUE constraint on pattern', () async {
      // Arrange
      final testSender = {
        'pattern': '^unique@example\\.com\$',
        'pattern_type': 'email',
        'date_added': DateTime.now().millisecondsSinceEpoch,
      };

      // Act: Insert same pattern twice
      await dbHelper.insertSafeSender(testSender);

      // Assert: Second insert should fail
      expect(
        () => dbHelper.insertSafeSender(testSender),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Foreign key constraints are enforced', () async {
      // Arrange: Get database
      final db = await dbHelper.database;

      // Act: Try to insert email_action without parent scan_result
      final invalidAction = {
        'scan_result_id': 99999, // Non-existent
        'email_id': 'test',
        'email_from': 'test@example.com',
        'email_subject': 'Test',
        'email_received_date': DateTime.now().millisecondsSinceEpoch,
        'email_folder': 'INBOX',
        'action_type': 'none',
        'success': 1,
      };

      // Assert: Should fail due to foreign key constraint
      expect(
        () => db.insert('email_actions', invalidAction),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
