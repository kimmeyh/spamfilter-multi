import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;

import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/migration_manager.dart';
import 'package:spam_filter_mobile/adapters/storage/app_paths.dart';

/// Integration tests for YAML to database migration
///
/// Tests:
/// 1. Migrate rules from YAML files
/// 2. Verify rules have been loaded from YAML file
/// 3. Verify safe senders migrated correctly
/// 4. Verify migration is idempotent (no duplicates)
/// 5. Verify backup creation
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('YAML Migration Integration Tests', () {
    late DatabaseHelper dbHelper;
    late MigrationManager migrationManager;
    late AppPaths appPaths;
    late Directory testDir;

    setUp(() async {
      // Create temporary test directory
      testDir = Directory.systemTemp.createTempSync('yaml_migration_test_');

      // Initialize AppPaths with test directory
      appPaths = AppPaths();
      await appPaths.initialize();

      // Initialize database helper
      dbHelper = DatabaseHelper();
      dbHelper.setAppPaths(appPaths);

      // Initialize migration manager
      migrationManager = MigrationManager(
        databaseHelper: dbHelper,
        appPaths: appPaths,
      );
    });

    tearDown(() async {
      // Cleanup
      try {
        final db = await dbHelper.database;
        await db.close();
        if (await testDir.exists()) {
          await testDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('1. Migration detects no YAML files and creates empty database', () async {
      // Arrange: Ensure no YAML files exist
      final rulesPath = appPaths.rulesFilePath;
      final safeSendersPath = appPaths.safeSendersFilePath;

      final rulesFile = File(rulesPath);
      final safeSendersFile = File(safeSendersPath);

      if (await rulesFile.exists()) await rulesFile.delete();
      if (await safeSendersFile.exists()) await safeSendersFile.delete();

      // Act: Run migration
      final results = await migrationManager.migrate();

      // Assert: Migration completes with zero imports
      expect(results.isComplete, isTrue);
      expect(results.rulesImported, equals(0));
      expect(results.safeSendersImported, equals(0));
    });

    test('2. Migrate rules from YAML file', () async {
      // Arrange: Create test YAML file with rules
      final rulesYaml = '''
version: "1.0"
settings:
  default_execution_order_increment: 10
rules:
  - name: "TestSpamRule"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^spammer@example\\.com\$"]
      subject: ["^urgent.*\$"]
    actions:
      delete: true
    exceptions:
      from: ["^trusted@example\\.com\$"]

  - name: "TestMoveRule"
    enabled: "True"
    conditions:
      type: "AND"
      subject: ["^newsletter.*\$"]
    actions:
      moveToFolder: "Marketing"
''';

      final rulesFile = File(appPaths.rulesFilePath);
      await rulesFile.parent.create(recursive: true);
      await rulesFile.writeAsString(rulesYaml);

      // Act: Run migration
      final results = await migrationManager.migrate();

      // Assert: Rules imported successfully
      expect(results.isSuccess, isTrue);
      expect(results.rulesImported, equals(2));
      expect(results.rulesFailed, equals(0));
    });

    test('3. Verify rules loaded from YAML have correct data', () async {
      // Arrange: Create YAML with specific rule
      final rulesYaml = '''
version: "1.0"
settings:
  default_execution_order_increment: 10
rules:
  - name: "VerifyDataRule"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^test@verify\\.com\$"]
      header: ["^X-Spam-Flag: YES\$"]
    actions:
      delete: true
      assignToCategory: "Spam"
    exceptions:
      subject: ["^important.*\$"]
''';

      final rulesFile = File(appPaths.rulesFilePath);
      await rulesFile.parent.create(recursive: true);
      await rulesFile.writeAsString(rulesYaml);

      // Act: Migrate and query
      await migrationManager.migrate();
      final rules = await dbHelper.queryRules();

      // Assert: Rule data matches YAML
      expect(rules.length, equals(1));
      final rule = rules[0];

      expect(rule['name'], equals('VerifyDataRule'));
      expect(rule['enabled'], equals(1));
      expect(rule['condition_type'], equals('OR'));
      expect(rule['condition_from'], contains('test@verify\\.com'));
      expect(rule['condition_header'], contains('X-Spam-Flag: YES'));
      expect(rule['action_delete'], equals(1));
      expect(rule['action_assign_category'], equals('Spam'));
      expect(rule['exception_subject'], contains('important'));
    });

    test('4. Migrate safe senders from YAML file', () async {
      // Arrange: Create test safe senders YAML
      final safeSendersYaml = '''
safe_senders:
  - "^john\\.doe@company\\.com\$"
  - "^[^@\\s]+@(?:[a-z0-9-]+\\.)*trusted\\.com\$"
  - "^newsletter@example\\.com\$"
''';

      final safeSendersFile = File(appPaths.safeSendersFilePath);
      await safeSendersFile.parent.create(recursive: true);
      await safeSendersFile.writeAsString(safeSendersYaml);

      // Act: Run migration
      final results = await migrationManager.migrate();

      // Assert: Safe senders imported
      expect(results.safeSendersImported, equals(3));
      expect(results.safeSendersFailed, equals(0));
    });

    test('5. Verify safe senders loaded correctly', () async {
      // Arrange: Create YAML
      final safeSendersYaml = '''
safe_senders:
  - "^verified@safe\\.com\$"
  - "^[^@\\s]+@(?:[a-z0-9-]+\\.)*whitelist\\.com\$"
''';

      final safeSendersFile = File(appPaths.safeSendersFilePath);
      await safeSendersFile.parent.create(recursive: true);
      await safeSendersFile.writeAsString(safeSendersYaml);

      // Act: Migrate and query
      await migrationManager.migrate();
      final safeSenders = await dbHelper.querySafeSenders();

      // Assert: Patterns match
      expect(safeSenders.length, equals(2));
      expect(
        safeSenders.any((s) => s['pattern'].toString().contains('verified@safe')),
        isTrue,
      );
      expect(
        safeSenders.any((s) => s['pattern'].toString().contains('whitelist\\.com')),
        isTrue,
      );
    });

    test('6. Migration is idempotent (no duplicates on second run)', () async {
      // Arrange: Create YAML with rules
      final rulesYaml = '''
version: "1.0"
settings:
  default_execution_order_increment: 10
rules:
  - name: "IdempotentRule"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^test@example\\.com\$"]
    actions:
      delete: true
''';

      final rulesFile = File(appPaths.rulesFilePath);
      await rulesFile.parent.create(recursive: true);
      await rulesFile.writeAsString(rulesYaml);

      // Act: Run migration twice
      final firstRun = await migrationManager.migrate();
      final secondRun = await migrationManager.migrate();

      // Query database
      final rules = await dbHelper.queryRules();

      // Assert: Only one rule (no duplicates)
      expect(firstRun.rulesImported, equals(1));
      expect(secondRun.rulesImported, equals(0)); // Already migrated
      expect(rules.length, equals(1));
    });

    test('7. Migration detects if already completed', () async {
      // Arrange: Insert rule directly (simulate previous migration)
      await dbHelper.insertRule({
        'name': 'ExistingRule',
        'enabled': 1,
        'is_local': 0,
        'execution_order': 10,
        'condition_type': 'OR',
        'condition_from': '["existing@example.com"]',
        'action_delete': 1,
        'date_added': DateTime.now().millisecondsSinceEpoch,
      });

      // Act: Check migration status
      final isComplete = await migrationManager.isMigrationComplete();

      // Assert: Migration detected as complete
      expect(isComplete, isTrue);
    });

    test('8. Migration handles malformed YAML gracefully', () async {
      // Arrange: Create invalid YAML
      final rulesYaml = '''
version: "1.0"
settings:
  default_execution_order_increment: 10
rules:
  - name: "ValidRule"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^valid@example\\.com\$"]
    actions:
      delete: true

  - name: "InvalidRule"
    enabled: "True"
    conditions:
      # Missing type field
      from: ["^invalid@example\\.com\$"]
    actions:
      # Missing action
''';

      final rulesFile = File(appPaths.rulesFilePath);
      await rulesFile.parent.create(recursive: true);
      await rulesFile.writeAsString(rulesYaml);

      // Act: Run migration (should not crash)
      final results = await migrationManager.migrate();

      // Assert: Valid rule imported, invalid skipped
      expect(results.rulesImported, greaterThanOrEqualTo(1));
      expect(results.errors, isNotEmpty); // Invalid rule logged as error
    });

    test('9. Migration tracks statistics correctly', () async {
      // Arrange: Create YAML with multiple rules and safe senders
      final rulesYaml = '''
version: "1.0"
settings:
  default_execution_order_increment: 10
rules:
  - name: "Rule1"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^test1@example\\.com\$"]
    actions:
      delete: true

  - name: "Rule2"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^test2@example\\.com\$"]
    actions:
      moveToFolder: "Spam"

  - name: "Rule3"
    enabled: "False"
    conditions:
      type: "AND"
      subject: ["^test.*\$"]
    actions:
      delete: true
''';

      final safeSendersYaml = '''
safe_senders:
  - "^safe1@example\\.com\$"
  - "^safe2@example\\.com\$"
''';

      final rulesFile = File(appPaths.rulesFilePath);
      final safeSendersFile = File(appPaths.safeSendersFilePath);

      await rulesFile.parent.create(recursive: true);
      await rulesFile.writeAsString(rulesYaml);
      await safeSendersFile.writeAsString(safeSendersYaml);

      // Act: Run migration
      final results = await migrationManager.migrate();

      // Assert: Counts match
      expect(results.rulesImported, equals(3));
      expect(results.safeSendersImported, equals(2));
      expect(results.isSuccess, isTrue);
      expect(results.isComplete, isTrue);
    });

    test('10. Migration creates backups of YAML files', () async {
      // Arrange: Create YAML files
      final rulesYaml = '''
version: "1.0"
settings:
  default_execution_order_increment: 10
rules:
  - name: "BackupTestRule"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^backup@example\\.com\$"]
    actions:
      delete: true
''';

      final rulesFile = File(appPaths.rulesFilePath);
      await rulesFile.parent.create(recursive: true);
      await rulesFile.writeAsString(rulesYaml);

      // Act: Run migration
      await migrationManager.migrate();

      // Assert: Backup directory created
      final backupDir = Directory(path.join(appPaths.backupDirectory.path));
      expect(await backupDir.exists(), isTrue);

      // Check for backup files (timestamped)
      final backupFiles = await backupDir.list().toList();
      expect(backupFiles.length, greaterThan(0));
    });
  });

  group('Migration Error Handling Tests', () {
    late DatabaseHelper dbHelper;
    late MigrationManager migrationManager;
    late AppPaths appPaths;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      appPaths = AppPaths();
      await appPaths.initialize();

      dbHelper = DatabaseHelper();
      dbHelper.setAppPaths(appPaths);

      migrationManager = MigrationManager(
        databaseHelper: dbHelper,
        appPaths: appPaths,
      );
    });

    test('Migration handles missing condition type gracefully', () async {
      // Arrange: Rule without condition type
      final rulesYaml = '''
version: "1.0"
rules:
  - name: "MissingTypeRule"
    enabled: "True"
    conditions:
      from: ["^test@example\\.com\$"]
    actions:
      delete: true
''';

      final rulesFile = File(appPaths.rulesFilePath);
      await rulesFile.parent.create(recursive: true);
      await rulesFile.writeAsString(rulesYaml);

      // Act: Run migration (should not crash)
      final results = await migrationManager.migrate();

      // Assert: Error reported but migration completes
      expect(results.isComplete, isTrue);
      expect(results.errors, isNotEmpty);
    });

    test('Migration handles duplicate rule names', () async {
      // Arrange: YAML with duplicate rule names
      final rulesYaml = '''
version: "1.0"
rules:
  - name: "DuplicateRule"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^first@example\\.com\$"]
    actions:
      delete: true

  - name: "DuplicateRule"
    enabled: "True"
    conditions:
      type: "OR"
      from: ["^second@example\\.com\$"]
    actions:
      moveToFolder: "Spam"
''';

      final rulesFile = File(appPaths.rulesFilePath);
      await rulesFile.parent.create(recursive: true);
      await rulesFile.writeAsString(rulesYaml);

      // Act: Run migration
      final results = await migrationManager.migrate();

      // Assert: Only first rule imported, second skipped
      expect(results.rulesImported, equals(1));
      expect(results.rulesFailed, equals(1));
      expect(results.skippedRules, contains('DuplicateRule'));
    });
  });
}
