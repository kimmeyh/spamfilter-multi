import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/adapters/storage/app_paths.dart';

/// Test implementation of AppPaths for database and migration testing.
/// Provides isolated paths for each test run using a temp directory.
///
/// This class provides ALL AppPaths properties from a temp directory,
/// allowing tests to run without the path_provider plugin.
///
/// Usage for database-only tests:
/// ```dart
/// final appPaths = TestAppPaths.databaseOnly('/tmp/test.db');
/// ```
///
/// Usage for full file system tests (migrations, YAML files):
/// ```dart
/// final appPaths = await TestAppPaths.withFullPaths();
/// // Clean up when done:
/// await appPaths.cleanup();
/// ```
class TestAppPaths extends AppPaths {
  final Directory _testAppSupportDir;
  final Directory _testRulesDir;
  final Directory _testCredentialsDir;
  final Directory _testBackupDir;
  final Directory _testLogsDir;

  /// Create TestAppPaths with a full temp directory structure.
  /// Use [withFullPaths] factory for convenience.
  TestAppPaths._internal(this._testAppSupportDir)
      : _testRulesDir = Directory(path.join(_testAppSupportDir.path, 'rules')),
        _testCredentialsDir = Directory(path.join(_testAppSupportDir.path, 'credentials')),
        _testBackupDir = Directory(path.join(_testAppSupportDir.path, 'backups')),
        _testLogsDir = Directory(path.join(_testAppSupportDir.path, 'logs'));

  /// Create TestAppPaths with only a database path override.
  /// For tests that only need database access, not file system paths.
  factory TestAppPaths.databaseOnly(String testDbPath) {
    final dir = Directory(path.dirname(testDbPath));
    return _DatabaseOnlyTestAppPaths(dir, testDbPath);
  }

  /// Create TestAppPaths with full temp directory structure.
  /// Creates all subdirectories (rules, credentials, backups, logs).
  static Future<TestAppPaths> withFullPaths() async {
    final tempDir = await Directory.systemTemp.createTemp('spam_filter_test_');
    final appPaths = TestAppPaths._internal(tempDir);
    await appPaths._createDirectories();
    return appPaths;
  }

  /// Create all subdirectories
  Future<void> _createDirectories() async {
    await _testRulesDir.create(recursive: true);
    await _testCredentialsDir.create(recursive: true);
    await _testBackupDir.create(recursive: true);
    await _testLogsDir.create(recursive: true);
  }

  /// Clean up temp directory when done
  Future<void> cleanup() async {
    try {
      if (await _testAppSupportDir.exists()) {
        await _testAppSupportDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  @override
  Directory get appSupportDirectory => _testAppSupportDir;

  @override
  Directory get rulesDirectory => _testRulesDir;

  @override
  String get rulesFilePath => path.join(_testRulesDir.path, 'rules.yaml');

  @override
  String get safeSendersFilePath => path.join(_testRulesDir.path, 'rules_safe_senders.yaml');

  @override
  String get databaseFilePath => path.join(_testAppSupportDir.path, 'spam_filter.db');

  @override
  Directory get credentialsDirectory => _testCredentialsDir;

  @override
  String get credentialsMetadataPath => path.join(_testCredentialsDir.path, 'credentials.json');

  @override
  Directory get backupDirectory => _testBackupDir;

  @override
  Directory get logsDirectory => _testLogsDir;

  @override
  String get debugLogPath => path.join(_testLogsDir.path, 'debug.log');

  @override
  Future<bool> rulesFileExists() async {
    return File(rulesFilePath).exists();
  }

  @override
  Future<bool> safeSendersFileExists() async {
    return File(safeSendersFilePath).exists();
  }

  /// Get the temp directory path for debugging
  String get tempDirPath => _testAppSupportDir.path;
}

/// Internal class for database-only test paths.
/// Only overrides databaseFilePath, throws on other properties.
class _DatabaseOnlyTestAppPaths extends TestAppPaths {
  final String _dbPath;

  _DatabaseOnlyTestAppPaths(Directory dir, this._dbPath) : super._internal(dir);

  @override
  String get databaseFilePath => _dbPath;
}

/// Helper class for database test setup and teardown.
///
/// Usage:
/// ```dart
/// late DatabaseTestHelper testHelper;
///
/// setUpAll(() {
///   DatabaseTestHelper.initializeFfi();
/// });
///
/// setUp(() async {
///   testHelper = DatabaseTestHelper();
///   await testHelper.setUp();
/// });
///
/// tearDown(() async {
///   await testHelper.tearDown();
/// });
/// ```
class DatabaseTestHelper {
  late DatabaseHelper dbHelper;
  late String testDbPath;
  late TestAppPaths appPaths;
  Directory? _tempDir;

  /// Initialize FFI for SQLite - call once in setUpAll
  static void initializeFfi() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  /// Set up the test database with isolated path.
  /// By default creates database-only paths. Use [withFullPaths: true]
  /// for tests that need full file system paths (migrations, YAML files).
  Future<void> setUp({bool withFullPaths = false}) async {
    if (withFullPaths) {
      // Create full temp directory structure for migration tests
      appPaths = await TestAppPaths.withFullPaths();
      testDbPath = appPaths.databaseFilePath;
      _tempDir = appPaths.appSupportDirectory;
    } else {
      // Create temp database path for testing (database-only)
      _tempDir = await Directory.systemTemp.createTemp('spam_filter_test_');
      testDbPath = '${_tempDir!.path}/test.db';
      appPaths = TestAppPaths.databaseOnly(testDbPath);
    }

    // Initialize DatabaseHelper with test path
    dbHelper = DatabaseHelper();
    dbHelper.setAppPaths(appPaths);

    // Clear any existing data
    try {
      await dbHelper.deleteAllData();
    } catch (e) {
      // Ignore if database does not exist yet
    }
  }

  /// Tear down the test database and clean up files
  Future<void> tearDown() async {
    // Close database and clean up
    await dbHelper.close();
    try {
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
      if (_tempDir != null && await _tempDir!.exists()) {
        await _tempDir!.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Create a test account - required before inserting scan_results due to FK constraint
  Future<void> createTestAccount(String accountId, {String? email, String? platformId}) async {
    await dbHelper.insertAccount({
      'account_id': accountId,
      'platform_id': platformId ?? 'test-platform',
      'email': email ?? '$accountId@test.com',
      'display_name': 'Test User',
      'date_added': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Create a test scan result - requires account to exist first
  Future<int> createTestScanResult(String accountId, {
    String scanType = 'manual',
    String scanMode = 'readonly',
    int totalEmails = 100,
    String status = 'completed',
  }) async {
    return await dbHelper.insertScanResult({
      'account_id': accountId,
      'scan_type': scanType,
      'scan_mode': scanMode,
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'total_emails': totalEmails,
      'processed_count': totalEmails,
      'deleted_count': 0,
      'moved_count': 0,
      'safe_sender_count': 0,
      'no_rule_count': 0,
      'error_count': 0,
      'status': status,
      'folders_scanned': '["INBOX"]',
    });
  }
}
