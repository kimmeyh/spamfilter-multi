import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../providers/email_scan_provider.dart';

/// Settings storage for app-wide and per-account configuration
///
/// This store provides:
/// - App-wide settings (manual scan defaults, background scan defaults)
/// - Per-account setting overrides
/// - Type-safe getter/setter methods
/// - JSON serialization for complex values (lists, maps)
///
/// Database Tables:
/// - app_settings: Global app settings (key-value pairs)
/// - account_settings: Per-account overrides (account_id + key → value)
///
/// Example:
/// ```dart
/// final store = SettingsStore();
/// await store.initialize();
///
/// // Get/set app-wide settings
/// final scanMode = await store.getManualScanMode();
/// await store.setManualScanMode(ScanMode.readonly);
///
/// // Get/set per-account overrides
/// final accountFolders = await store.getAccountFolders('gmail-user@gmail.com');
/// await store.setAccountFolders('gmail-user@gmail.com', ['INBOX', 'Spam']);
/// ```
class SettingsStore {
  final DatabaseHelper _dbHelper;
  final Logger _logger = Logger();

  SettingsStore([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper();

  // ============================================================
  // App-Wide Settings Keys
  // ============================================================
  static const String keyManualScanMode = 'manual_scan_mode';
  static const String keyManualScanFolders = 'manual_scan_folders';
  static const String keyConfirmDialogsEnabled = 'confirm_dialogs_enabled';
  static const String keyBackgroundScanEnabled = 'background_scan_enabled';
  static const String keyBackgroundScanFrequency = 'background_scan_frequency';
  static const String keyBackgroundScanMode = 'background_scan_mode';
  static const String keyBackgroundScanFolders = 'background_scan_folders';
  static const String keyCsvExportDirectory = 'csv_export_directory';
  static const String keyBackgroundScanDebugCsv = 'background_scan_debug_csv';
  static const String keyManualScanDaysBack = 'manual_scan_days_back';
  static const String keyBackgroundScanDaysBack = 'background_scan_days_back';

  // ============================================================
  // Default Values
  // ============================================================
  static const ScanMode defaultManualScanMode = ScanMode.readonly;
  static const List<String> defaultManualScanFolders = ['INBOX'];
  static const bool defaultConfirmDialogsEnabled = true;
  static const bool defaultBackgroundScanEnabled = false;
  static const int defaultBackgroundScanFrequency = 15; // minutes
  static const ScanMode defaultBackgroundScanMode = ScanMode.readonly;
  static const List<String> defaultBackgroundScanFolders = ['INBOX'];
  static const String? defaultCsvExportDirectory = null; // null means use Downloads folder
  static const bool defaultBackgroundScanDebugCsv = false;
  static const int defaultManualScanDaysBack = 0; // 0 = all emails
  static const int defaultBackgroundScanDaysBack = 7; // 7 days for background

  // ============================================================
  // Manual Scan Settings
  // ============================================================

  /// Get the default scan mode for manual scans
  Future<ScanMode> getManualScanMode() async {
    final value = await _getAppSetting(keyManualScanMode);
    if (value == null) return defaultManualScanMode;
    return _parseScanMode(value);
  }

  /// Set the default scan mode for manual scans
  Future<void> setManualScanMode(ScanMode mode) async {
    await _setAppSetting(keyManualScanMode, mode.name, 'string');
  }

  /// Get the default folders to scan for manual scans
  Future<List<String>> getManualScanFolders() async {
    final value = await _getAppSetting(keyManualScanFolders);
    if (value == null) return List.from(defaultManualScanFolders);
    return _parseStringList(value);
  }

  /// Set the default folders to scan for manual scans
  Future<void> setManualScanFolders(List<String> folders) async {
    await _setAppSetting(keyManualScanFolders, jsonEncode(folders), 'json');
  }

  /// Get whether confirmation dialogs are enabled
  Future<bool> getConfirmDialogsEnabled() async {
    final value = await _getAppSetting(keyConfirmDialogsEnabled);
    if (value == null) return defaultConfirmDialogsEnabled;
    return value == 'true';
  }

  /// Set whether confirmation dialogs are enabled
  Future<void> setConfirmDialogsEnabled(bool enabled) async {
    await _setAppSetting(keyConfirmDialogsEnabled, enabled.toString(), 'bool');
  }

  // ============================================================
  // Background Scan Settings
  // ============================================================

  /// Get whether background scanning is enabled
  Future<bool> getBackgroundScanEnabled() async {
    final value = await _getAppSetting(keyBackgroundScanEnabled);
    if (value == null) return defaultBackgroundScanEnabled;
    return value == 'true';
  }

  /// Set whether background scanning is enabled
  Future<void> setBackgroundScanEnabled(bool enabled) async {
    await _setAppSetting(keyBackgroundScanEnabled, enabled.toString(), 'bool');
  }

  /// Get background scan frequency in minutes
  Future<int> getBackgroundScanFrequency() async {
    final value = await _getAppSetting(keyBackgroundScanFrequency);
    if (value == null) return defaultBackgroundScanFrequency;
    return int.tryParse(value) ?? defaultBackgroundScanFrequency;
  }

  /// Set background scan frequency in minutes
  Future<void> setBackgroundScanFrequency(int minutes) async {
    await _setAppSetting(keyBackgroundScanFrequency, minutes.toString(), 'int');
  }

  /// Get the scan mode for background scans
  Future<ScanMode> getBackgroundScanMode() async {
    final value = await _getAppSetting(keyBackgroundScanMode);
    if (value == null) return defaultBackgroundScanMode;
    return _parseScanMode(value);
  }

  /// Set the scan mode for background scans
  Future<void> setBackgroundScanMode(ScanMode mode) async {
    await _setAppSetting(keyBackgroundScanMode, mode.name, 'string');
  }

  /// Get the default folders to scan for background scans
  Future<List<String>> getBackgroundScanFolders() async {
    final value = await _getAppSetting(keyBackgroundScanFolders);
    if (value == null) return List.from(defaultBackgroundScanFolders);
    return _parseStringList(value);
  }

  /// Set the default folders to scan for background scans
  Future<void> setBackgroundScanFolders(List<String> folders) async {
    await _setAppSetting(keyBackgroundScanFolders, jsonEncode(folders), 'json');
  }

  /// Get whether debug CSV export is enabled for background scans
  Future<bool> getBackgroundScanDebugCsv() async {
    final value = await _getAppSetting(keyBackgroundScanDebugCsv);
    if (value == null) return defaultBackgroundScanDebugCsv;
    return value == 'true';
  }

  /// Set whether debug CSV export is enabled for background scans
  Future<void> setBackgroundScanDebugCsv(bool enabled) async {
    await _setAppSetting(keyBackgroundScanDebugCsv, enabled.toString(), 'bool');
  }

  // ============================================================
  // Days Back Settings
  // ============================================================

  /// Get the default days back for manual scans
  /// Returns 0 for "all emails" or 1-90 for days back
  Future<int> getManualScanDaysBack() async {
    final value = await _getAppSetting(keyManualScanDaysBack);
    if (value == null) return defaultManualScanDaysBack;
    return int.tryParse(value) ?? defaultManualScanDaysBack;
  }

  /// Set the default days back for manual scans
  /// Pass 0 for "all emails" or 1-90 for days back
  Future<void> setManualScanDaysBack(int daysBack) async {
    await _setAppSetting(keyManualScanDaysBack, daysBack.toString(), 'int');
  }

  /// Get the default days back for background scans
  /// Returns 0 for "all emails" or 1-90 for days back
  Future<int> getBackgroundScanDaysBack() async {
    final value = await _getAppSetting(keyBackgroundScanDaysBack);
    if (value == null) return defaultBackgroundScanDaysBack;
    return int.tryParse(value) ?? defaultBackgroundScanDaysBack;
  }

  /// Set the default days back for background scans
  /// Pass 0 for "all emails" or 1-90 for days back
  Future<void> setBackgroundScanDaysBack(int daysBack) async {
    await _setAppSetting(keyBackgroundScanDaysBack, daysBack.toString(), 'int');
  }

  // ============================================================
  // Export Settings
  // ============================================================

  /// Get the default directory for CSV exports
  /// Returns null if not set (use system Downloads folder)
  Future<String?> getCsvExportDirectory() async {
    return await _getAppSetting(keyCsvExportDirectory);
  }

  /// Set the default directory for CSV exports
  /// Pass null to clear (will use Downloads folder)
  Future<void> setCsvExportDirectory(String? directory) async {
    if (directory == null) {
      await _deleteAppSetting(keyCsvExportDirectory);
    } else {
      await _setAppSetting(keyCsvExportDirectory, directory, 'string');
    }
  }

  // ============================================================
  // Per-Account Settings
  // ============================================================

  /// Get account-specific folders override
  /// Returns null if no override set (use global default)
  Future<List<String>?> getAccountFolders(String accountId) async {
    final value = await _getAccountSetting(accountId, 'folders');
    if (value == null) return null;
    return _parseStringList(value);
  }

  /// Set account-specific folders override
  /// Pass null to clear the override
  Future<void> setAccountFolders(String accountId, List<String>? folders) async {
    if (folders == null) {
      await _deleteAccountSetting(accountId, 'folders');
    } else {
      await _setAccountSetting(accountId, 'folders', jsonEncode(folders), 'json');
    }
  }

  /// Get account-specific scan mode override
  /// Returns null if no override set (use global default)
  Future<ScanMode?> getAccountScanMode(String accountId) async {
    final value = await _getAccountSetting(accountId, 'scan_mode');
    if (value == null) return null;
    return _parseScanMode(value);
  }

  /// Set account-specific scan mode override
  /// Pass null to clear the override
  Future<void> setAccountScanMode(String accountId, ScanMode? mode) async {
    if (mode == null) {
      await _deleteAccountSetting(accountId, 'scan_mode');
    } else {
      await _setAccountSetting(accountId, 'scan_mode', mode.name, 'string');
    }
  }

  /// Get account-specific background scan enabled override
  /// Returns null if no override set (use global default)
  Future<bool?> getAccountBackgroundEnabled(String accountId) async {
    final value = await _getAccountSetting(accountId, 'background_enabled');
    if (value == null) return null;
    return value == 'true';
  }

  /// Set account-specific background scan enabled override
  /// Pass null to clear the override
  Future<void> setAccountBackgroundEnabled(String accountId, bool? enabled) async {
    if (enabled == null) {
      await _deleteAccountSetting(accountId, 'background_enabled');
    } else {
      await _setAccountSetting(accountId, 'background_enabled', enabled.toString(), 'bool');
    }
  }

  /// Get account-specific deleted rule folder
  /// Returns null if not set (will default to provider-specific Trash folder)
  Future<String?> getAccountDeletedRuleFolder(String accountId) async {
    final value = await _getAccountSetting(accountId, 'deleted_rule_folder');
    return value;
  }

  /// Set account-specific deleted rule folder
  /// Pass null to clear the setting (will use provider default)
  Future<void> setAccountDeletedRuleFolder(String accountId, String? folder) async {
    if (folder == null) {
      await _deleteAccountSetting(accountId, 'deleted_rule_folder');
    } else {
      await _setAccountSetting(accountId, 'deleted_rule_folder', folder, 'string');
    }
  }

  /// Get account-specific safe sender folder
  /// Returns null if not set (will default to INBOX)
  Future<String?> getAccountSafeSenderFolder(String accountId) async {
    final value = await _getAccountSetting(accountId, 'safe_sender_folder');
    return value;
  }

  /// Set account-specific safe sender folder
  /// Pass null to clear the setting (will use INBOX default)
  Future<void> setAccountSafeSenderFolder(String accountId, String? folder) async {
    if (folder == null) {
      await _deleteAccountSetting(accountId, 'safe_sender_folder');
    } else {
      await _setAccountSetting(accountId, 'safe_sender_folder', folder, 'string');
    }
  }

  // ============================================================
  // [NEW] ISSUE #123: Per-Account Manual Scan Settings
  // ============================================================

  /// Get account-specific manual scan mode
  /// Returns null if not set (will use app-wide default)
  Future<ScanMode?> getAccountManualScanMode(String accountId) async {
    final value = await _getAccountSetting(accountId, 'manual_scan_mode');
    if (value == null) return null;
    return ScanMode.values.firstWhere((e) => e.name == value);
  }

  /// Set account-specific manual scan mode
  /// Pass null to clear (will use app-wide default)
  Future<void> setAccountManualScanMode(String accountId, ScanMode? mode) async {
    if (mode == null) {
      await _deleteAccountSetting(accountId, 'manual_scan_mode');
    } else {
      await _setAccountSetting(accountId, 'manual_scan_mode', mode.name, 'string');
    }
  }

  /// Get account-specific manual scan folders
  /// Returns null if not set (will use app-wide default)
  Future<List<String>?> getAccountManualScanFolders(String accountId) async {
    final value = await _getAccountSetting(accountId, 'manual_scan_folders');
    if (value == null) return null;
    return _parseStringList(value);
  }

  /// Set account-specific manual scan folders
  /// Pass null to clear (will use app-wide default)
  Future<void> setAccountManualScanFolders(String accountId, List<String>? folders) async {
    if (folders == null) {
      await _deleteAccountSetting(accountId, 'manual_scan_folders');
    } else {
      await _setAccountSetting(accountId, 'manual_scan_folders', jsonEncode(folders), 'json');
    }
  }

  // ============================================================
  // [NEW] ISSUE #123: Per-Account Background Scan Settings
  // ============================================================

  /// Get account-specific background scan mode
  /// Returns null if not set (will use app-wide default)
  Future<ScanMode?> getAccountBackgroundScanMode(String accountId) async {
    final value = await _getAccountSetting(accountId, 'background_scan_mode');
    if (value == null) return null;
    return ScanMode.values.firstWhere((e) => e.name == value);
  }

  /// Set account-specific background scan mode
  /// Pass null to clear (will use app-wide default)
  Future<void> setAccountBackgroundScanMode(String accountId, ScanMode? mode) async {
    if (mode == null) {
      await _deleteAccountSetting(accountId, 'background_scan_mode');
    } else {
      await _setAccountSetting(accountId, 'background_scan_mode', mode.name, 'string');
    }
  }

  /// Get account-specific background scan folders
  /// Returns null if not set (will use app-wide default)
  Future<List<String>?> getAccountBackgroundScanFolders(String accountId) async {
    final value = await _getAccountSetting(accountId, 'background_scan_folders');
    if (value == null) return null;
    return _parseStringList(value);
  }

  /// Set account-specific background scan folders
  /// Pass null to clear (will use app-wide default)
  Future<void> setAccountBackgroundScanFolders(String accountId, List<String>? folders) async {
    if (folders == null) {
      await _deleteAccountSetting(accountId, 'background_scan_folders');
    } else {
      await _setAccountSetting(accountId, 'background_scan_folders', jsonEncode(folders), 'json');
    }
  }

  // ============================================================
  // Per-Account Days Back Settings
  // ============================================================

  /// Get account-specific manual scan days back
  /// Returns null if not set (will use app-wide default)
  Future<int?> getAccountManualDaysBack(String accountId) async {
    final value = await _getAccountSetting(accountId, 'manual_days_back');
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Set account-specific manual scan days back
  /// Pass null to clear (will use app-wide default)
  Future<void> setAccountManualDaysBack(String accountId, int? daysBack) async {
    if (daysBack == null) {
      await _deleteAccountSetting(accountId, 'manual_days_back');
    } else {
      await _setAccountSetting(accountId, 'manual_days_back', daysBack.toString(), 'int');
    }
  }

  /// Get account-specific background scan days back
  /// Returns null if not set (will use app-wide default)
  Future<int?> getAccountBackgroundDaysBack(String accountId) async {
    final value = await _getAccountSetting(accountId, 'background_days_back');
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Set account-specific background scan days back
  /// Pass null to clear (will use app-wide default)
  Future<void> setAccountBackgroundDaysBack(String accountId, int? daysBack) async {
    if (daysBack == null) {
      await _deleteAccountSetting(accountId, 'background_days_back');
    } else {
      await _setAccountSetting(accountId, 'background_days_back', daysBack.toString(), 'int');
    }
  }

  /// Check if account has any setting overrides
  Future<bool> hasAccountOverrides(String accountId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'account_settings',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get all account setting overrides for display
  Future<Map<String, String>> getAccountOverrides(String accountId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'account_settings',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );

    final overrides = <String, String>{};
    for (final row in results) {
      final key = row['setting_key'] as String;
      final value = row['setting_value'] as String;
      overrides[key] = value;
    }
    return overrides;
  }

  /// Clear all account setting overrides
  Future<void> clearAccountOverrides(String accountId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'account_settings',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    _logger.i('Cleared all setting overrides for account: $accountId');
  }

  // ============================================================
  // Effective Settings (resolves account overrides)
  // ============================================================

  /// Get effective scan mode for an account (resolves override or uses global)
  ///
  /// Resolution order:
  /// 1. Account-specific background/manual scan mode override
  /// 2. Account-specific generic scan mode override
  /// 3. App-wide background/manual scan mode default
  Future<ScanMode> getEffectiveScanMode(String? accountId, {bool isBackground = false}) async {
    if (accountId != null) {
      // Check background/manual-specific override first
      if (isBackground) {
        final bgOverride = await getAccountBackgroundScanMode(accountId);
        if (bgOverride != null) return bgOverride;
      } else {
        final manualOverride = await getAccountManualScanMode(accountId);
        if (manualOverride != null) return manualOverride;
      }
      // Fall back to generic account override
      final override = await getAccountScanMode(accountId);
      if (override != null) return override;
    }
    return isBackground ? await getBackgroundScanMode() : await getManualScanMode();
  }

  /// Get effective folders for an account (resolves override or uses global)
  ///
  /// Resolution order:
  /// 1. Account-specific background/manual scan folders override
  /// 2. Account-specific generic folders override
  /// 3. App-wide background/manual scan folders default
  Future<List<String>> getEffectiveFolders(String? accountId, {bool isBackground = false}) async {
    if (accountId != null) {
      // Check background/manual-specific override first
      if (isBackground) {
        final bgOverride = await getAccountBackgroundScanFolders(accountId);
        if (bgOverride != null) return bgOverride;
      } else {
        final manualOverride = await getAccountManualScanFolders(accountId);
        if (manualOverride != null) return manualOverride;
      }
      // Fall back to generic account override
      final override = await getAccountFolders(accountId);
      if (override != null) return override;
    }
    return isBackground ? await getBackgroundScanFolders() : await getManualScanFolders();
  }

  /// Get effective days back for an account (resolves override or uses global)
  ///
  /// Resolution order:
  /// 1. Account-specific manual/background days back override
  /// 2. App-wide manual/background days back default
  Future<int> getEffectiveDaysBack(String? accountId, {bool isBackground = false}) async {
    if (accountId != null) {
      if (isBackground) {
        final bgOverride = await getAccountBackgroundDaysBack(accountId);
        if (bgOverride != null) return bgOverride;
      } else {
        final manualOverride = await getAccountManualDaysBack(accountId);
        if (manualOverride != null) return manualOverride;
      }
    }
    return isBackground ? await getBackgroundScanDaysBack() : await getManualScanDaysBack();
  }

  /// Get effective background enabled for an account (resolves override or uses global)
  Future<bool> getEffectiveBackgroundEnabled(String? accountId) async {
    if (accountId != null) {
      final override = await getAccountBackgroundEnabled(accountId);
      if (override != null) return override;
    }
    return await getBackgroundScanEnabled();
  }

  // ============================================================
  // Internal Helpers
  // ============================================================

  Future<String?> _getAppSetting(String key) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String;
  }

  Future<void> _setAppSetting(String key, String value, String valueType) async {
    final db = await _dbHelper.database;
    await db.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'value_type': valueType,
        'date_modified': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _logger.d('Set app setting: $key = $value');
  }

  Future<void> _deleteAppSetting(String key) async {
    final db = await _dbHelper.database;
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    _logger.d('Deleted app setting: $key');
  }

  Future<String?> _getAccountSetting(String accountId, String key) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'account_settings',
      where: 'account_id = ? AND setting_key = ?',
      whereArgs: [accountId, key],
    );
    if (results.isEmpty) return null;
    return results.first['setting_value'] as String;
  }

  Future<void> _setAccountSetting(String accountId, String key, String value, String valueType) async {
    final db = await _dbHelper.database;
    await db.insert(
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
    _logger.d('Set account setting: $accountId.$key = $value');
  }

  Future<void> _deleteAccountSetting(String accountId, String key) async {
    final db = await _dbHelper.database;
    await db.delete(
      'account_settings',
      where: 'account_id = ? AND setting_key = ?',
      whereArgs: [accountId, key],
    );
    _logger.d('Deleted account setting: $accountId.$key');
  }

  ScanMode _parseScanMode(String value) {
    switch (value) {
      case 'readonly':
        return ScanMode.readonly;
      case 'testLimit':
        return ScanMode.testLimit;
      case 'testAll':
        return ScanMode.testAll;
      case 'fullScan':
        return ScanMode.fullScan;
      default:
        _logger.w('Unknown scan mode: $value, defaulting to readonly');
        return ScanMode.readonly;
    }
  }

  List<String> _parseStringList(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (e) {
      _logger.w('Failed to parse string list: $value');
    }
    return [];
  }
}
