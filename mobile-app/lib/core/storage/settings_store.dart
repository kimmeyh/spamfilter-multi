import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../providers/email_scan_provider.dart';
import '../../util/redact.dart';

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
/// await store.setManualScanMode(ScanMode.readOnly);
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
  static const String keyLiveScanDebugCsv = 'live_scan_debug_csv';
  /// F206 (Sprint 74): mask sender, subject and message id in every export.
  static const String keyExportRedacted = 'export_redacted';
  static const String keyManualScanDaysBack = 'manual_scan_days_back';
  static const String keyBackgroundScanDaysBack = 'background_scan_days_back';
  static const String keyScanHistoryRetentionDays = 'scan_history_retention_days';
  static const String keyDisableAuthLogging = 'disable_auth_logging';
  static const String keyUnmatchedRetentionDays = 'unmatched_retention_days';
  static const String keyCertificatePinningEnabled = 'certificate_pinning_enabled';
  static const String keyEncryptDatabase = 'encrypt_database';

  /// F233 (Sprint 72): write a diagnostic log capturing FAILURE paths that
  /// today reach only a debug console. Default OFF.
  static const String keyDiagnosticLogEnabled = 'diagnostic_log_enabled';

  /// F233 (Sprint 72): keep every run's diagnostic log instead of appending to
  /// one rolling file. Harold, 2026-09-21: "a flag to allow saving all log
  /// files (if the user can easily get to them to delete the files)" -- the
  /// parenthetical is why a delete action ships alongside this.
  static const String keyDiagnosticLogKeepAll = 'diagnostic_log_keep_all';

  // ============================================================
  // Default Values
  // ============================================================
  static const ScanMode defaultManualScanMode = ScanMode.readOnly;
  static const List<String> defaultManualScanFolders = ['INBOX'];
  static const bool defaultConfirmDialogsEnabled = true;
  static const bool defaultBackgroundScanEnabled = false;
  static const int defaultBackgroundScanFrequency = 15; // minutes
  static const ScanMode defaultBackgroundScanMode = ScanMode.readOnly;
  static const List<String> defaultBackgroundScanFolders = ['INBOX'];
  /// F202: overall default Safe Senders folder when no account or provider value.
  static const String defaultSafeSenderFolder = 'INBOX';
  static const String? defaultCsvExportDirectory = null; // null means use Downloads folder
  // F113 (Sprint 47): debug-CSV defaults ON for new users (Harold: new users
  // are the most likely to need diagnostics; the files are tiny).
  static const bool defaultBackgroundScanDebugCsv = true;

  // F113 (Sprint 47): provider-keyed default scan folders. When an account
  // has no per-account folder selection, the effective default depends on the
  // provider (derived from the `{platform}-{email}` accountId prefix). AOL and
  // Gmail have distinct well-known spam/bulk folder names; anything else falls
  // back to the generic INBOX. Extensible: add Yahoo/Outlook entries as those
  // providers are activated.
  static const List<String> defaultAolScanFolders = [
    'Inbox',
    'Bulk',
    'Bulk Mail',
  ];
  static const List<String> defaultGmailScanFolders = [
    'INBOX',
    '[Gmail]/Spam',
    'Unwanted',
  ];

  /// F202 (Sprint 74): per-PROVIDER folder defaults for all four folder
  /// settings, keyed by the platform id the account was added with (the
  /// PlatformRegistry key). Harold's rule: *"the development team cannot
  /// choose or override for the providers what they deem as the defaults"* --
  /// so every value here is one HE confirmed from a live account, and an
  /// unknown value is simply absent and falls through to the overall default.
  ///
  /// **Keyed by platform, not provider brand, on purpose.** Gmail has two
  /// adapters with different folder VOCABULARIES: `gmail-imap` speaks IMAP
  /// folder names (`[Gmail]/Spam`, `[Gmail]/Trash`, as Harold confirmed), while
  /// the `gmail` API adapter speaks LABELS -- it maps `spam` to `in:spam` and
  /// passes any other name to `label:<name>`, and it treats a Deleted Rule
  /// folder other than null/`TRASH` as a label ID for `messages.modify`. An
  /// IMAP name there would move nothing, or fail every delete. So the API
  /// entry uses `SPAM` and leaves Deleted Rule unset (the adapter's built-in
  /// trash).
  static const Map<String, ProviderFolderDefaults> providerFolderDefaults = {
    'aol': ProviderFolderDefaults(
      scanFolders: defaultAolScanFolders,
      safeSenderFolder: 'Inbox',
      deletedRuleFolder: 'Trash',
    ),
    'gmail-imap': ProviderFolderDefaults(
      scanFolders: defaultGmailScanFolders,
      safeSenderFolder: 'INBOX',
      deletedRuleFolder: '[Gmail]/Trash',
    ),
    'gmail': ProviderFolderDefaults(
      scanFolders: ['INBOX', 'SPAM', 'Unwanted'],
      safeSenderFolder: 'INBOX',
      // deletedRuleFolder deliberately unset: see the class comment.
    ),
    'yahoo': ProviderFolderDefaults(
      scanFolders: ['Inbox', 'Bulk'],
      safeSenderFolder: 'Inbox',
      deletedRuleFolder: 'Trash',
    ),
    'icloud': ProviderFolderDefaults(
      // Junk folder name not yet confirmed (iCloud creates it on first use):
      // scan folders fall through to the overall default.
      safeSenderFolder: 'INBOX',
      deletedRuleFolder: 'Deleted Messages',
    ),
  };

  /// Best-effort platform id from an accountId, for callers with no database
  /// (the Settings display). AccountId format VARIES (`{platform}-{email}`,
  /// or a bare email), so the platform token is checked first and the email
  /// domain second. Splitting on the first `-` mis-parses a dashed local part
  /// (Copilot review, Sprint 47). A bare Gmail address is taken as the API
  /// adapter -- the default sign-in -- which is also the conservative choice
  /// (its Deleted Rule default is the adapter's own trash).
  static String? inferPlatformId(String accountId) {
    final id = accountId.toLowerCase();
    if (id.startsWith('gmail-imap-')) return 'gmail-imap';
    for (final platform in const ['gmail', 'aol', 'yahoo', 'icloud', 'imap', 'demo']) {
      if (id.startsWith('$platform-')) return platform;
    }
    if (id.contains('@gmail.') || id.contains('@googlemail.')) return 'gmail';
    if (id.contains('@aol.') || id.contains('@verizon.')) return 'aol';
    if (id.contains('@yahoo.') || id.contains('@ymail.')) return 'yahoo';
    if (id.contains('@icloud.') || id.contains('@me.com') || id.contains('@mac.com')) {
      return 'icloud';
    }
    return null;
  }

  /// The provider defaults for [accountId], preferring the platform id stored
  /// when the account was added (R-5) over the string heuristic.
  Future<ProviderFolderDefaults?> _providerDefaultsFor(String accountId) async {
    String? platformId;
    try {
      final db = await _dbHelper.database;
      final rows = await db.query('accounts',
          columns: ['platform_id'],
          where: 'account_id = ?',
          whereArgs: [accountId],
          limit: 1);
      if (rows.isNotEmpty) platformId = rows.first['platform_id'] as String?;
    } catch (_) {
      platformId = null; // fall back to the heuristic
    }
    platformId ??= inferPlatformId(accountId);
    return platformId == null ? null : providerFolderDefaults[platformId];
  }

  /// Sync display helper (Settings): the provider's default SCAN folders for
  /// [accountId], else the overall default. Uses [inferPlatformId] because the
  /// display has no database handle; scanning uses [getEffectiveFolders].
  static List<String> providerDefaultFolders(String accountId) {
    final platform = inferPlatformId(accountId);
    final scan = platform == null ? null : providerFolderDefaults[platform]?.scanFolders;
    return List.from(scan ?? defaultManualScanFolders);
  }
  /// F90 (Sprint 39): live-scan debug CSV export. F113 (Sprint 47) changed
  /// the default to `true` for both dev and prod -- new users are the most
  /// likely to need diagnostics and the CSV files are tiny (matches
  /// `defaultBackgroundScanDebugCsv`, also `true`). The Settings > Manual Scan
  /// tab Debug section exposes a toggle so a user can opt OUT without a code
  /// change. The runtime log file (`{logs}/{prefix}live_scan_v<version>.log`) is
  /// always on regardless of this setting -- it captures scan-lifecycle events
  /// only and is small enough that surprise disk usage is not a concern.
  static const bool defaultLiveScanDebugCsv = true; // F113 (Sprint 47): ON for new users

  /// F233: OFF by default. A diagnostic log is a debugging aid, not something
  /// every user should silently accumulate on disk.
  static const bool defaultDiagnosticLogEnabled = false;

  /// F233: OFF by default -- one rolling file unless the user opts in.
  static const bool defaultDiagnosticLogKeepAll = false;
  static const int defaultManualScanDaysBack = 0; // 0 = all emails
  static const int defaultBackgroundScanDaysBack = 0; // 0 = all emails
  static const int defaultScanHistoryRetentionDays = 90; // F114 (Sprint 47): 7 -> 90 (new-user default)
  static const bool defaultDisableAuthLogging = false; // SEC-19: default OFF preserves debug behavior
  static const int defaultUnmatchedRetentionDays = 90; // F114 (Sprint 47): 30 -> 90 (was SEC-14 30)
  static const bool defaultCertificatePinningEnabled = true; // SEC-8: pinning on by default
  static const bool defaultEncryptDatabase = false; // SEC-11: opt-in until QA gates

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

  /// F90 (Sprint 39): get whether debug CSV/XLSX export is enabled for
  /// live (manual) scans. When true, every live scan appends to a
  /// per-account per-day `live_scan_{email}_{date}.data.csv` and
  /// regenerates the matching `.xlsx` (mirrors background-scan CSV).
  /// The runtime log file `{logs}/{prefix}live_scan_v<version>.log` is
  /// written regardless of this setting.
  Future<bool> getLiveScanDebugCsv() async {
    final value = await _getAppSetting(keyLiveScanDebugCsv);
    if (value == null) return defaultLiveScanDebugCsv;
    return value == 'true';
  }

  /// F90 (Sprint 39): set whether debug CSV/XLSX export is enabled for
  /// live scans.
  Future<void> setLiveScanDebugCsv(bool enabled) async {
    await _setAppSetting(keyLiveScanDebugCsv, enabled.toString(), 'bool');
  }

  /// F206 (Sprint 74, Part C): whether exports REDACT sender, subject and
  /// message id -- for a file shared outside the team. Off by default: the
  /// export's main reader today is the developer diagnosing a scan.
  Future<bool> getExportRedacted() async {
    final value = await _getAppSetting(keyExportRedacted);
    return value == 'true';
  }

  Future<void> setExportRedacted(bool enabled) async {
    await _setAppSetting(keyExportRedacted, enabled.toString(), 'bool');
  }

  // ============================================================
  // F233 (Sprint 72): Diagnostic Logging
  // ============================================================

  /// Whether the diagnostic log is being written.
  ///
  /// **Why this exists**: the failure paths that matter -- `[F38] Re-processing
  /// failed`, `[F38] Delete batch failed`, the adapter's `allFailed` reason --
  /// used a bare `Logger()` with no file sink, so on an installed build they
  /// went nowhere. Two defects that reproduce on demand (F228, F232) could not
  /// be diagnosed because the app never wrote down what happened.
  Future<bool> getDiagnosticLogEnabled() async {
    final value = await _getAppSetting(keyDiagnosticLogEnabled);
    if (value == null) return defaultDiagnosticLogEnabled;
    return value == 'true';
  }

  Future<void> setDiagnosticLogEnabled(bool enabled) async {
    await _setAppSetting(keyDiagnosticLogEnabled, enabled.toString(), 'bool');
  }

  /// Whether to keep every run's log rather than appending to one file.
  Future<bool> getDiagnosticLogKeepAll() async {
    final value = await _getAppSetting(keyDiagnosticLogKeepAll);
    if (value == null) return defaultDiagnosticLogKeepAll;
    return value == 'true';
  }

  Future<void> setDiagnosticLogKeepAll(bool enabled) async {
    await _setAppSetting(keyDiagnosticLogKeepAll, enabled.toString(), 'bool');
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
  // Scan History Settings
  // ============================================================

  /// Get how many days to keep scan history (default 7)
  Future<int> getScanHistoryRetentionDays() async {
    final value = await _getAppSetting(keyScanHistoryRetentionDays);
    if (value == null) return defaultScanHistoryRetentionDays;
    return int.tryParse(value) ?? defaultScanHistoryRetentionDays;
  }

  /// Set how many days to keep scan history
  Future<void> setScanHistoryRetentionDays(int days) async {
    await _setAppSetting(keyScanHistoryRetentionDays, days.toString(), 'int');
  }

  // ============================================================
  // Privacy & Logging Settings (SEC-19, Sprint 33)
  // ============================================================

  /// Get whether detailed auth logging is disabled.
  ///
  /// When true, [Redact.logSafe] becomes a no-op even in debug builds. This
  /// allows users to suppress sensitive auth traces from log output without
  /// rebuilding the app.
  Future<bool> getDisableAuthLogging() async {
    final value = await _getAppSetting(keyDisableAuthLogging);
    if (value == null) return defaultDisableAuthLogging;
    return value == 'true';
  }

  /// Set whether detailed auth logging is disabled.
  Future<void> setDisableAuthLogging(bool disabled) async {
    await _setAppSetting(keyDisableAuthLogging, disabled.toString(), 'bool');
  }

  /// Get how many days unmatched emails are retained before auto-deletion
  /// (SEC-14, Sprint 33). A non-positive value means "retain forever".
  Future<int> getUnmatchedRetentionDays() async {
    final value = await _getAppSetting(keyUnmatchedRetentionDays);
    if (value == null) return defaultUnmatchedRetentionDays;
    return int.tryParse(value) ?? defaultUnmatchedRetentionDays;
  }

  /// Set how many days unmatched emails are retained before auto-deletion.
  /// Pass 0 (or negative) to retain forever.
  Future<void> setUnmatchedRetentionDays(int days) async {
    await _setAppSetting(keyUnmatchedRetentionDays, days.toString(), 'int');
  }

  /// Get whether certificate pinning is enforced for Google OAuth endpoints
  /// (SEC-8, Sprint 33). Default is `true`. Users can disable this if
  /// Google rotates a key before the app ships with the updated hash.
  Future<bool> getCertificatePinningEnabled() async {
    final value = await _getAppSetting(keyCertificatePinningEnabled);
    if (value == null) return defaultCertificatePinningEnabled;
    return value == 'true';
  }

  /// Set whether certificate pinning is enforced.
  Future<void> setCertificatePinningEnabled(bool enabled) async {
    await _setAppSetting(
        keyCertificatePinningEnabled, enabled.toString(), 'bool');
  }

  /// SEC-11 (Sprint 33): opt-in flag for SQLCipher at-rest encryption.
  /// Default is `false`; infrastructure (key + migration) ships disabled
  /// until dedicated platform QA validates the swap.
  Future<bool> getEncryptDatabase() async {
    final value = await _getAppSetting(keyEncryptDatabase);
    if (value == null) return defaultEncryptDatabase;
    return value == 'true';
  }

  /// Set the database encryption flag.
  Future<void> setEncryptDatabase(bool enabled) async {
    await _setAppSetting(keyEncryptDatabase, enabled.toString(), 'bool');
  }

  // ============================================================
  // Export Settings
  // ============================================================

  /// Get the user-chosen export directory.
  /// Returns null if not set -- the platform default applies (F206: Android
  /// Documents, Windows Downloads; see ExportDirectories).
  Future<String?> getCsvExportDirectory() async {
    return await _getAppSetting(keyCsvExportDirectory);
  }

  /// F206 R-7 (Sprint 74): callbacks run whenever the export directory
  /// changes. `DiagnosticLogger` caches the folder it resolved from this
  /// setting, and nothing told it the setting had changed -- so after the
  /// user picked a new folder, logs kept going to the OLD one for the rest
  /// of the session, and "Delete logs" cleared the old one. Notifying from
  /// the SETTER covers every caller, present and future; invalidating at a
  /// UI call site would cover only the calls someone remembered.
  static final List<void Function()> _exportDirectoryListeners = [];

  static void addExportDirectoryListener(void Function() listener) {
    if (!_exportDirectoryListeners.contains(listener)) {
      _exportDirectoryListeners.add(listener);
    }
  }

  /// Set the export directory. Pass null to clear (the platform default
  /// applies).
  Future<void> setCsvExportDirectory(String? directory) async {
    if (directory == null) {
      await _deleteAppSetting(keyCsvExportDirectory);
    } else {
      await _setAppSetting(keyCsvExportDirectory, directory, 'string');
    }
    for (final listener in List.of(_exportDirectoryListeners)) {
      listener();
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

  /// Get account-specific background scan frequency (minutes) override.
  /// Returns null if no override set (use global default). (Sprint 42, F98.)
  Future<int?> getAccountBackgroundFrequency(String accountId) async {
    final value = await _getAccountSetting(accountId, 'background_frequency');
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Set account-specific background scan frequency (minutes) override.
  /// Pass null to clear the override. (Sprint 42, F98.)
  Future<void> setAccountBackgroundFrequency(String accountId, int? minutes) async {
    if (minutes == null) {
      await _deleteAccountSetting(accountId, 'background_frequency');
    } else {
      await _setAccountSetting(accountId, 'background_frequency', minutes.toString(), 'int');
    }
  }

  /// Get effective background frequency for an account: per-account override,
  /// then the global frequency as fallback. (Sprint 42, F98.)
  Future<int> getEffectiveBackgroundFrequency(String? accountId) async {
    if (accountId != null) {
      final override = await getAccountBackgroundFrequency(accountId);
      if (override != null) return override;
    }
    return await getBackgroundScanFrequency();
  }

  /// Read an arbitrary app_settings value by [key], or null if absent.
  /// (Sprint 42, F98 -- used by the per-account migration sentinel.)
  Future<String?> getRawAppSetting(String key) => _getAppSetting(key);

  /// Write an arbitrary app_settings [key]=[value] with [type].
  /// (Sprint 42, F98 -- used by the per-account migration sentinel.)
  Future<void> setRawAppSetting(String key, String value, String type) =>
      _setAppSetting(key, value, type);

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

  /// F202 (Sprint 74): the Safe Senders folder for [accountId], resolved
  /// account -> provider -> overall (`INBOX`). Replaces the hardcoded
  /// `?? 'INBOX'` fallbacks at the scan and re-process call sites.
  Future<String> getEffectiveSafeSenderFolder(String accountId) async {
    final account = await getAccountSafeSenderFolder(accountId);
    if (account != null && account.isNotEmpty) return account;
    final provider = await _providerDefaultsFor(accountId);
    return provider?.safeSenderFolder ?? defaultSafeSenderFolder;
  }

  /// F202 (Sprint 74): the Deleted Rule folder for [accountId], resolved
  /// account -> provider. **Null means "the adapter's own default"** (IMAP
  /// `Trash`; the Gmail API's built-in trash) -- the overall default lives in
  /// the adapters, because the right answer is vocabulary-specific (a folder
  /// name vs a Gmail label id). iCloud now resolves to `Deleted Messages`
  /// instead of a `Trash` folder that does not exist there.
  Future<String?> getEffectiveDeletedRuleFolder(String accountId) async {
    final account = await getAccountDeletedRuleFolder(accountId);
    if (account != null && account.isNotEmpty) return account;
    final provider = await _providerDefaultsFor(accountId);
    return provider?.deletedRuleFolder;
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
    return _parseScanMode(value);
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
    return _parseScanMode(value);
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
    _logger.i('Cleared all setting overrides for account: ${Redact.accountId(accountId)}');
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

  /// Get effective folders for an account.
  ///
  /// Resolution order (F202, Sprint 74 -- the same three tiers for all four
  /// folder settings):
  /// 1. Account-specific background/manual scan folders override
  /// 2. Account-specific generic folders override
  /// 3. The PROVIDER default ([providerFolderDefaults]), if it defines one
  /// 4. The OVERALL default: the app-wide background/manual scan folders.
  ///    Before F202 this tier was unreachable for any real account.
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
      // F113 (Sprint 47) + F202 (Sprint 74): no per-account selection ->
      // the provider default, keyed by the account's stored platform id.
      final provider = await _providerDefaultsFor(accountId);
      final scan = provider?.scanFolders;
      if (scan != null) return List.from(scan);
      // F202: then the OVERALL default (was unreachable for real accounts).
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
    _logger.d('Set account setting: ${Redact.accountId(accountId)}.$key = $value');
  }

  Future<void> _deleteAccountSetting(String accountId, String key) async {
    final db = await _dbHelper.database;
    await db.delete(
      'account_settings',
      where: 'account_id = ? AND setting_key = ?',
      whereArgs: [accountId, key],
    );
    _logger.d('Deleted account setting: ${Redact.accountId(accountId)}.$key');
  }

  ScanMode _parseScanMode(String value) {
    switch (value) {
      // Current names
      case 'readOnly':
        return ScanMode.readOnly;
      case 'rulesOnly':
        return ScanMode.rulesOnly;
      case 'safeSendersOnly':
        return ScanMode.safeSendersOnly;
      case 'safeSendersAndRules':
        return ScanMode.safeSendersAndRules;
      // Legacy names (backwards compatibility with existing DB records)
      case 'readonly':
        return ScanMode.readOnly;
      // F181 DELIBERATE KEEP: the testLimit OPTION is removed, but rows
      // persisted before Issue #123/#124 hold this string -- deleting the
      // case silently degrades those accounts to readOnly.
      case 'testLimit':
        return ScanMode.rulesOnly;
      case 'testAll':
        return ScanMode.safeSendersOnly;
      case 'fullScan':
        return ScanMode.safeSendersAndRules;
      default:
        _logger.w('Unknown scan mode: $value, defaulting to readOnly');
        return ScanMode.readOnly;
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

/// F202 (Sprint 74): one provider's folder defaults. A null field means
/// "not confirmed for this provider" -- the resolver falls through to the
/// overall default rather than guessing (Harold, 2026-09-09).
class ProviderFolderDefaults {
  final List<String>? scanFolders;
  final String? safeSenderFolder;
  final String? deletedRuleFolder;

  const ProviderFolderDefaults({
    this.scanFolders,
    this.safeSenderFolder,
    this.deletedRuleFolder,
  });
}
