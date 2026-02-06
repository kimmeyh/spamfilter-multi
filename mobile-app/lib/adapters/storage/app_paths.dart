/// Application path helper for platform-specific directory management
/// 
/// Provides consistent paths across Android, iOS, and web platforms
/// for storing rules, credentials, and temporary files.
library;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Centralized application paths manager
/// 
/// Handles all file system paths for the spam filter app:
/// - Rules and safe senders (YAML files)
/// - Credentials (encrypted JSON)
/// - Temporary files and backups
/// 
/// Example:
/// ```dart
/// final appPaths = AppPaths();
/// await appPaths.initialize();
/// 
/// // Get rules directory
/// final rulesDir = appPaths.rulesDirectory;
/// final rulesFile = appPaths.rulesFilePath;
/// 
/// // Get credentials directory
/// final credsDir = appPaths.credentialsDirectory;
/// ```
class AppPaths {
  late Directory _appSupportDir;
  late Directory _rulesDir;
  late Directory _credentialsDir;
  late Directory _backupDir;
  late Directory _logsDir;

  bool _initialized = false;

  /// Initialize application directories (must call before accessing paths)
  Future<void> initialize() async {
    if (_initialized) return;

    // Get app support directory (persistent, not cleared by app uninstall on most platforms)
    _appSupportDir = await getApplicationSupportDirectory();

    // Create subdirectories if they don't exist
    _rulesDir = Directory(path.join(_appSupportDir.path, 'rules'));
    _credentialsDir = Directory(path.join(_appSupportDir.path, 'credentials'));
    _backupDir = Directory(path.join(_appSupportDir.path, 'backups'));
    _logsDir = Directory(path.join(_appSupportDir.path, 'logs'));

    // Create directories
    await _rulesDir.create(recursive: true);
    await _credentialsDir.create(recursive: true);
    await _backupDir.create(recursive: true);
    await _logsDir.create(recursive: true);

    _initialized = true;
  }

  /// Verify that initialization was called
  void _checkInitialized() {
    if (!_initialized) {
      throw StateError('AppPaths not initialized. Call initialize() first.');
    }
  }

  /// Root app support directory
  ///
  /// Platform-specific paths:
  /// - Android: /data/user/0/com.example.spam_filter_mobile/files
  /// - iOS: /Library/Application Support/spam_filter_mobile
  /// - Windows: C:\Users\{username}\AppData\Roaming\com.example\spam_filter_mobile
  /// - Linux: ~/.local/share/spam_filter_mobile
  /// - macOS: ~/Library/Application Support/spam_filter_mobile
  Directory get appSupportDirectory {
    _checkInitialized();
    return _appSupportDir;
  }

  /// Rules and safe senders directory
  /// 
  /// Stores YAML files:
  /// - rules.yaml (main filter rules)
  /// - rules_safe_senders.yaml (whitelist patterns)
  Directory get rulesDirectory {
    _checkInitialized();
    return _rulesDir;
  }

  /// Full path to main rules file
  String get rulesFilePath {
    _checkInitialized();
    return path.join(_rulesDir.path, 'rules.yaml');
  }

  /// Full path to safe senders file
  String get safeSendersFilePath {
    _checkInitialized();
    return path.join(_rulesDir.path, 'rules_safe_senders.yaml');
  }

  /// Full path to SQLite database file (Phase 3.5+)
  ///
  /// Stores scan results, rules, settings, and scan history.
  ///
  /// Platform-specific paths:
  /// - Windows: C:\Users\{username}\AppData\Roaming\com.example\spam_filter_mobile\spam_filter.db
  /// - Android: /data/user/0/com.example.spam_filter_mobile/files/spam_filter.db
  /// - iOS: /Library/Application Support/spam_filter_mobile/spam_filter.db
  /// - Linux: ~/.local/share/spam_filter_mobile/spam_filter.db
  /// - macOS: ~/Library/Application Support/spam_filter_mobile/spam_filter.db
  String get databaseFilePath {
    _checkInitialized();
    return path.join(_appSupportDir.path, 'spam_filter.db');
  }

  /// Credentials and tokens directory (secure storage primary location)
  /// 
  /// Note: Actual credentials stored via flutter_secure_storage
  /// This directory may be used for OAuth token cache metadata
  Directory get credentialsDirectory {
    _checkInitialized();
    return _credentialsDir;
  }

  /// Full path to credentials metadata file (for OAuth tokens, etc.)
  String get credentialsMetadataPath {
    _checkInitialized();
    return path.join(_credentialsDir.path, 'credentials.json');
  }

  /// Backup directory for YAML files
  /// 
  /// Stores timestamped backups:
  /// - rules_backup_20251211_143050.yaml
  /// - rules_safe_senders_backup_20251211_143050.yaml
  Directory get backupDirectory {
    _checkInitialized();
    return _backupDir;
  }

  /// Generate timestamped backup filename
  /// 
  /// Example: rules_backup_20251211_143050.yaml
  String getBackupFilename(String baseFilename, DateTime timestamp) {
    final name = baseFilename.replaceFirst(RegExp(r'\.yaml$'), '');
    final ts = timestamp.toIso8601String().replaceAll(RegExp(r'[:-]'), '').split('.')[0];
    return '${name}_backup_$ts.yaml';
  }

  /// Logs directory for app debugging
  Directory get logsDirectory {
    _checkInitialized();
    return _logsDir;
  }

  /// Full path to debug log file
  String get debugLogPath {
    _checkInitialized();
    return path.join(_logsDir.path, 'debug.log');
  }

  /// Check if rules file exists
  Future<bool> rulesFileExists() async {
    _checkInitialized();
    final file = File(rulesFilePath);
    return file.exists();
  }

  /// Check if safe senders file exists
  Future<bool> safeSendersFileExists() async {
    _checkInitialized();
    final file = File(safeSendersFilePath);
    return file.exists();
  }

  /// Delete all app data (for testing or factory reset)
  Future<void> deleteAllData() async {
    _checkInitialized();
    await _appSupportDir.delete(recursive: true);
    _initialized = false;
  }

  /// Get total size of app data in bytes
  Future<int> getTotalDataSize() async {
    _checkInitialized();
    
    int totalSize = 0;
    for (final file in _appSupportDir.listSync(recursive: true)) {
      if (file is File) {
        totalSize += await file.length();
      }
    }
    return totalSize;
  }

  /// Pretty print app paths for debugging
  String debugInfo() {
    _checkInitialized();
    return '''
AppPaths Debug Info:
  Support: ${_appSupportDir.path}
  Rules: ${_rulesDir.path}
  Credentials: ${_credentialsDir.path}
  Backups: ${_backupDir.path}
  Logs: ${_logsDir.path}
''';
  }
}

/// Singleton instance of AppPaths (optional pattern)
AppPaths? _instance;

/// Get or create the AppPaths singleton
AppPaths getAppPaths() {
  _instance ??= AppPaths();
  return _instance!;
}
