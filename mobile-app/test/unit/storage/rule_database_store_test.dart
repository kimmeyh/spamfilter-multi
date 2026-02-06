import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/storage/rule_database_store.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';

void main() {
  // Initialize FFI for testing
  sqfliteFfiInit();

  /// Create in-memory test database with tables
  Future<Database> createTestDatabase() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    // Create rules table
    await db.execute('''
      CREATE TABLE rules (
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
      )
    ''');

    // Create safe_senders table
    await db.execute('''
      CREATE TABLE safe_senders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pattern TEXT NOT NULL UNIQUE,
        pattern_type TEXT NOT NULL,
        exception_patterns TEXT,
        date_added INTEGER NOT NULL,
        created_by TEXT DEFAULT 'manual'
      )
    ''');

    return db;
  }

  /// Create mock RuleDatabaseProvider that uses test database
  MockRuleDatabaseProvider createMockHelper(Database db) {
    return MockRuleDatabaseProvider(db);
  }

  group('RuleDatabaseStore - Basic Operations', () {
    late Database testDb;
    late RuleDatabaseStore store;
    late MockRuleDatabaseProvider mockHelper;

    setUp(() async {
      testDb = await createTestDatabase();
      mockHelper = createMockHelper(testDb);
      store = RuleDatabaseStore(mockHelper);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('loadRules returns empty RuleSet when database is empty', () async {
      final ruleSet = await store.loadRules();
      expect(ruleSet.rules, isEmpty);
      expect(ruleSet.version, '1.0');
    });

    test('loadSafeSenders returns empty list when database is empty', () async {
      final safeSenders = await store.loadSafeSenders();
      expect(safeSenders.safeSenders, isEmpty);
    });

    test('addRule inserts rule to database', () async {
      final rule = _createTestRule('TestRule', 10);
      await store.addRule(rule);

      final result = await testDb.query('rules', where: 'name = ?', whereArgs: ['TestRule']);
      expect(result.length, 1);
      expect(result.first['enabled'], 1);
      expect(result.first['execution_order'], 10);
    });

    test('getRule returns rule by name', () async {
      final rule = _createTestRule('GetTestRule', 20);
      await store.addRule(rule);

      final retrieved = await store.getRule('GetTestRule');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'GetTestRule');
      expect(retrieved.executionOrder, 20);
    });

    test('getRule returns null when rule not found', () async {
      final result = await store.getRule('NonExistentRule');
      expect(result, isNull);
    });

    test('deleteRule removes rule from database', () async {
      final rule = _createTestRule('DeleteTestRule', 30);
      await store.addRule(rule);
      await store.deleteRule('DeleteTestRule');

      final result = await testDb.query('rules', where: 'name = ?', whereArgs: ['DeleteTestRule']);
      expect(result, isEmpty);
    });

    test('addSafeSender inserts pattern to database', () async {
      // Use a proper regex pattern to test 'email' pattern type detection
      // Pattern starting with ^ and containing @ is classified as 'email' type
      await store.addSafeSender(r'^trusted@example\.com$');

      final result = await testDb.query('safe_senders', where: 'pattern = ?', whereArgs: [r'^trusted@example\.com$']);
      expect(result.length, 1);
      expect(result.first['pattern_type'], 'email');
    });

    test('removeSafeSender deletes pattern from database', () async {
      await store.addSafeSender('removeme@example.com');
      await store.removeSafeSender('removeme@example.com');

      final result = await testDb.query('safe_senders', where: 'pattern = ?', whereArgs: ['removeme@example.com']);
      expect(result, isEmpty);
    });
  });

  group('RuleDatabaseStore - Serialization', () {
    late Database testDb;
    late RuleDatabaseStore store;
    late MockRuleDatabaseProvider mockHelper;

    setUp(() async {
      testDb = await createTestDatabase();
      mockHelper = createMockHelper(testDb);
      store = RuleDatabaseStore(mockHelper);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Rule with array conditions serializes correctly', () async {
      final rule = Rule(
        name: 'JsonTestRule',
        enabled: true,
        isLocal: false,
        executionOrder: 10,
        conditions: RuleConditions(
          type: 'OR',
          from: ['spam@example.com', 'junk@example.com'],
          header: ['X-Spam: Yes'],
          subject: ['viagra', 'cialis'],
          body: [],
        ),
        actions: RuleActions(delete: true, moveToFolder: null, assignToCategory: null),
      );

      await store.addRule(rule);
      final retrieved = await store.getRule('JsonTestRule');

      expect(retrieved, isNotNull);
      expect(retrieved!.conditions.from, ['spam@example.com', 'junk@example.com']);
      expect(retrieved.conditions.header, ['X-Spam: Yes']);
      expect(retrieved.conditions.subject, ['viagra', 'cialis']);
      expect(retrieved.conditions.body, isEmpty);
    });

    test('Rule with metadata preserves data', () async {
      final rule = Rule(
        name: 'MetadataTestRule',
        enabled: true,
        isLocal: false,
        executionOrder: 10,
        conditions: RuleConditions(type: 'AND', from: [], header: [], subject: [], body: []),
        actions: RuleActions(delete: true, moveToFolder: null, assignToCategory: null),
        metadata: {'source': 'manual', 'version': 1},
      );

      await store.addRule(rule);
      final retrieved = await store.getRule('MetadataTestRule');

      expect(retrieved!.metadata, {'source': 'manual', 'version': 1});
    });

    test('Rule with exceptions serializes correctly', () async {
      final rule = Rule(
        name: 'ExceptionTestRule',
        enabled: true,
        isLocal: false,
        executionOrder: 10,
        conditions: RuleConditions(type: 'AND', from: ['spam@example.com'], header: [], subject: [], body: []),
        actions: RuleActions(delete: true, moveToFolder: null, assignToCategory: null),
        exceptions: RuleExceptions(
          from: ['trusted@example.com'],
          header: [],
          subject: [],
          body: [],
        ),
      );

      await store.addRule(rule);
      final retrieved = await store.getRule('ExceptionTestRule');

      expect(retrieved!.exceptions, isNotNull);
      expect(retrieved.exceptions!.from, ['trusted@example.com']);
    });
  });

  group('RuleDatabaseStore - Multiple Operations', () {
    late Database testDb;
    late RuleDatabaseStore store;
    late MockRuleDatabaseProvider mockHelper;

    setUp(() async {
      testDb = await createTestDatabase();
      mockHelper = createMockHelper(testDb);
      store = RuleDatabaseStore(mockHelper);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('loadRules returns all rules sorted by execution order', () async {
      await store.addRule(_createTestRule('Rule3', 30));
      await store.addRule(_createTestRule('Rule1', 10));
      await store.addRule(_createTestRule('Rule2', 20));

      final ruleSet = await store.loadRules();
      expect(ruleSet.rules.length, 3);
      expect(ruleSet.rules[0].name, 'Rule1');
      expect(ruleSet.rules[1].name, 'Rule2');
      expect(ruleSet.rules[2].name, 'Rule3');
    });

    test('loadSafeSenders returns all patterns', () async {
      await store.addSafeSender('pattern1@example.com');
      await store.addSafeSender('pattern2@example.com');
      await store.addSafeSender('pattern3@example.com');

      final safeSenders = await store.loadSafeSenders();
      expect(safeSenders.safeSenders.length, 3);
      expect(safeSenders.safeSenders, containsAll(['pattern1@example.com', 'pattern2@example.com', 'pattern3@example.com']));
    });

    test('updateRule modifies existing rule', () async {
      final rule = _createTestRule('UpdateTest', 10);
      await store.addRule(rule);

      final updated = Rule(
        name: 'UpdateTest',
        enabled: false,
        isLocal: false,
        executionOrder: 20,
        conditions: RuleConditions(type: 'OR', from: [], header: [], subject: [], body: []),
        actions: RuleActions(delete: false, moveToFolder: 'Archive', assignToCategory: null),
      );

      await store.updateRule(updated);
      final retrieved = await store.getRule('UpdateTest');

      expect(retrieved!.enabled, false);
      expect(retrieved.executionOrder, 20);
      expect(retrieved.actions.moveToFolder, 'Archive');
    });

    test('saveRules replaces all rules', () async {
      await store.addRule(_createTestRule('OldRule', 10));

      final newRuleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          _createTestRule('NewRule1', 10),
          _createTestRule('NewRule2', 20),
        ],
      );

      await store.saveRules(newRuleSet);

      final result = await testDb.query('rules');
      expect(result.length, 2);
      expect(result.map((r) => r['name']), containsAll(['NewRule1', 'NewRule2']));
      expect(result.map((r) => r['name']), isNot(contains('OldRule')));
    });

    test('saveSafeSenders replaces all patterns', () async {
      await store.addSafeSender('old@example.com');

      final newSafeSenders = SafeSenderList(safeSenders: ['new1@example.com', 'new2@example.com']);
      await store.saveSafeSenders(newSafeSenders);

      final result = await testDb.query('safe_senders');
      expect(result.length, 2);
      expect(result.map((r) => r['pattern']), containsAll(['new1@example.com', 'new2@example.com']));
    });
  });

  group('RuleDatabaseStore - Error Cases', () {
    late Database testDb;
    late RuleDatabaseStore store;
    late MockRuleDatabaseProvider mockHelper;

    setUp(() async {
      testDb = await createTestDatabase();
      mockHelper = createMockHelper(testDb);
      store = RuleDatabaseStore(mockHelper);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('addRule throws exception for duplicate rule name', () async {
      final rule = _createTestRule('DuplicateRule', 10);
      await store.addRule(rule);

      expect(
        () => store.addRule(rule),
        throwsA(isA<RuleDatabaseStorageException>()),
      );
    });

    test('updateRule throws exception when rule does not exist', () async {
      final rule = _createTestRule('NonExistentRule', 10);

      expect(
        () => store.updateRule(rule),
        throwsA(isA<RuleDatabaseStorageException>()),
      );
    });

    test('deleteRule throws exception when rule does not exist', () async {
      expect(
        () => store.deleteRule('NonExistentRule'),
        throwsA(isA<RuleDatabaseStorageException>()),
      );
    });

    test('addSafeSender throws exception for duplicate pattern', () async {
      const pattern = 'duplicate@example.com';
      await store.addSafeSender(pattern);

      expect(
        () => store.addSafeSender(pattern),
        throwsA(isA<RuleDatabaseStorageException>()),
      );
    });

    test('removeSafeSender throws exception when pattern does not exist', () async {
      expect(
        () => store.removeSafeSender('nonexistent@example.com'),
        throwsA(isA<RuleDatabaseStorageException>()),
      );
    });
  });
}

/// Test helper: Create a simple test rule
Rule _createTestRule(String name, int executionOrder) {
  return Rule(
    name: name,
    enabled: true,
    isLocal: false,
    executionOrder: executionOrder,
    conditions: RuleConditions(
      type: 'AND',
      from: [],
      header: [],
      subject: [],
      body: [],
    ),
    actions: RuleActions(delete: true, moveToFolder: null, assignToCategory: null),
  );
}

/// Mock RuleDatabaseProvider that uses test database for testing
class MockRuleDatabaseProvider implements RuleDatabaseProvider {
  final Database _database;

  MockRuleDatabaseProvider(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<List<Map<String, dynamic>>> queryRules({bool? enabledOnly}) async {
    if (enabledOnly == true) {
      return await _database.query('rules', where: 'enabled = 1');
    }
    return await _database.query('rules');
  }

  @override
  Future<List<Map<String, dynamic>>> querySafeSenders() async {
    return await _database.query('safe_senders');
  }

  @override
  Future<int> insertRule(Map<String, dynamic> rule) async {
    return await _database.insert('rules', rule);
  }

  @override
  Future<int> insertSafeSender(Map<String, dynamic> safeSender) async {
    return await _database.insert('safe_senders', safeSender);
  }

  @override
  Future<Map<String, dynamic>?> getRule(String ruleName) async {
    final results = await _database.query(
      'rules',
      where: 'name = ?',
      whereArgs: [ruleName],
    );
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<Map<String, dynamic>?> getSafeSender(String pattern) async {
    final results = await _database.query(
      'safe_senders',
      where: 'pattern = ?',
      whereArgs: [pattern],
    );
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<int> updateRule(String ruleName, Map<String, dynamic> values) async {
    return await _database.update(
      'rules',
      values,
      where: 'name = ?',
      whereArgs: [ruleName],
    );
  }

  @override
  Future<int> deleteRule(String ruleName) async {
    return await _database.delete(
      'rules',
      where: 'name = ?',
      whereArgs: [ruleName],
    );
  }

  @override
  Future<int> updateSafeSender(String pattern, Map<String, dynamic> values) async {
    return await _database.update(
      'safe_senders',
      values,
      where: 'pattern = ?',
      whereArgs: [pattern],
    );
  }

  @override
  Future<int> deleteSafeSender(String pattern) async {
    return await _database.delete(
      'safe_senders',
      where: 'pattern = ?',
      whereArgs: [pattern],
    );
  }

  @override
  Future<void> deleteAllRules() async {
    await _database.delete('rules');
  }

  @override
  Future<void> deleteAllSafeSenders() async {
    await _database.delete('safe_senders');
  }
}
