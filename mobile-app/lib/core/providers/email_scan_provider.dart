/// Provider-based state management for email scanning
/// 
/// Manages scan progress, results, and email evaluation state
/// for display in UI screens.
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import '../../core/services/auth_results_parser.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/settings_store.dart';
import '../../core/storage/unmatched_email_store.dart';
import '../../core/utils/pattern_normalization.dart';
import '../../util/redact.dart';

/// Scan status states
enum ScanStatus { idle, scanning, paused, completed, error }

/// Email action type for categorization
enum EmailActionType { none, safeSender, delete, moveToJunk, markAsRead }

/// [NEW] PHASE 3.1: Scan mode - read-only, test modes, or full production scan
enum ScanMode {
  readOnly,              // Default: scan only, no modifications
  rulesOnly,             // Process spam rules only, skip safe sender actions
  safeSendersOnly,       // Process safe sender actions only, skip spam rules
  safeSendersAndRules,   // Process both safe sender and spam rule actions
}

/// [NEW] Multi-account & Multi-folder support: Junk folder configuration per provider
class JunkFolderConfig {
  final String provider;  // "aol", "gmail", "outlook", etc.
  final List<String> folderNames;  // ["Junk", "Spam", "Bulk Mail"]
  
  JunkFolderConfig({
    required this.provider,
    required this.folderNames,
  });
}

/// Result of evaluating and acting on a single email
class EmailActionResult {
  final EmailMessage email;
  final EvaluationResult? evaluationResult;
  final EmailActionType action;
  final bool success;
  final String? error;

  EmailActionResult({
    required this.email,
    this.evaluationResult,
    required this.action,
    required this.success,
    this.error,
  });
}

/// Provider for managing email scan state
/// 
/// This provider tracks:
/// - Current scan progress (emails processed, total)
/// - Scan status (idle, scanning, completed, error)
/// - Results by category (deleted, moved, errors)
/// - Current email being processed (for UI updates)
/// 
/// Example in main.dart:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => EmailScanProvider(),
///   child: MyApp(),
/// )
/// ```
/// 
/// Example in UI widget:
/// ```dart
/// class ScanProgressScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final scanProvider = Provider.of<EmailScanProvider>(context);
///     
///     return Column(
///       children: [
///         Text('Status: ${scanProvider.status}'),
///         LinearProgressIndicator(
///           value: scanProvider.progress,
///         ),
///         Text('${scanProvider.processedCount} / ${scanProvider.totalEmails}'),
///       ],
///     );
///   }
/// }
/// ```
class EmailScanProvider extends ChangeNotifier {
  final Logger _logger = Logger();

  // [NEW] SPRINT 4: Scan result persistence stores
  ScanResultStore? _scanResultStore;
  UnmatchedEmailStore? _unmatchedEmailStore;
  int? _currentScanResultId;  // Track current scan result for persistence
  DatabaseHelper? _databaseHelper;  // For email_actions persistence

  // [NEW] MULTI-ACCOUNT SUPPORT: Provider-specific junk folder configuration
  static const Map<String, List<String>> JUNK_FOLDERS_BY_PROVIDER = {
    'aol': ['Bulk Mail', 'Spam'],           // AOL Mail junk folders
    'gmail': ['Spam', 'Trash'],              // Gmail junk folders
    'outlook': ['Junk Email', 'Spam'],       // Outlook.com junk folders
    'yahoo': ['Bulk', 'Spam'],               // Yahoo Mail junk folders
    'icloud': ['Junk', 'Trash'],             // iCloud Mail junk folders
    // 'protonmail': handled via ProtonMail Bridge
    // Custom IMAP servers default to 'Spam' and 'Junk'
  };

  // Scan state
  ScanStatus _status = ScanStatus.idle;
  int _processedCount = 0;
  int _totalEmails = 0;
  EmailMessage? _currentEmail;
  String? _statusMessage;
  String? _currentFolder;  // [NEW] NEW: Track which folder is being scanned
  DateTime? _scanStartTime;  // [NEW] SPRINT 11: Track when scan started for CSV export

  // Results tracking
  final List<EmailActionResult> _results = [];
  int _deletedCount = 0;
  int _movedCount = 0;
  int _safeSendersCount = 0;
  int _noRuleCount = 0;  // [NEW] PHASE 3.1: Emails with no rule match
  int _errorCount = 0;

  /// F91 (Sprint 39): number of source-folder duplicate messages removed
  /// during post-safe-sender-move dedup. Separate from [_deletedCount] (which
  /// counts rule-driven deletes) because these are reconciliation removals of
  /// AOL copy-not-move re-injections, not spam-rule matches. Surfaced in the
  /// scan summary only when greater than zero.
  int _safeSenderDedupCount = 0;

  // [NEW] PHASE 2 SPRINT 3: Read-only mode & revert capability
  ScanMode _scanMode = ScanMode.readOnly;  // Default: read-only
  int? _emailTestLimit;  // How many emails to actually modify (for testLimit mode)
  final List<String> _lastRunActionIds = [];  // Track email IDs of actions for revert
  final List<EmailActionResult> _lastRunActions = [];  // Track actual actions for revert

  // [NEW] PHASE 3.2: Folder selection for scan
  // [NEW] ISSUE #41 FIX: Store folders per-account to prevent cross-account folder leakage
  final Map<String, List<String>> _selectedFoldersByAccount = {};  // accountId -> folders
  String? _currentAccountId;  // Track current account for folder lookup

  // [NEW] PHASE 3.3: Progressive update throttling (Issue #36)
  // [UPDATED] ISSUE #128: Reduced from 3s to 2s for more responsive folder updates
  DateTime? _lastProgressNotification;
  int _emailsSinceLastNotification = 0;
  static const int _progressEmailInterval = 10;  // Update every 10 emails
  static const Duration _progressTimeInterval = Duration(seconds: 2);  // OR every 2 seconds (was 3s)

  // Getters
  ScanStatus get status => _status;
  int get processedCount => _processedCount;
  int get totalEmails => _totalEmails;
  EmailMessage? get currentEmail => _currentEmail;
  String? get statusMessage => _statusMessage;
  String? get currentFolder => _currentFolder;  // [NEW] NEW: Get current folder being scanned
  DateTime? get scanStartTime => _scanStartTime;  // [NEW] SPRINT 11: Get scan start timestamp
  List<EmailActionResult> get results => _results;
  int get deletedCount => _deletedCount;
  int get movedCount => _movedCount;
  int get safeSendersCount => _safeSendersCount;
  int get noRuleCount => _noRuleCount;  // [NEW] PHASE 3.1: Emails with no rule match
  int get errorCount => _errorCount;

  /// F91 (Sprint 39): count of source-folder duplicates removed during
  /// post-safe-sender-move dedup (AOL copy-not-move reconciliation).
  int get safeSenderDedupCount => _safeSenderDedupCount;

  /// F91 (Sprint 39): record [count] source-folder duplicates removed during
  /// post-safe-sender-move dedup. Called by EmailScanner after it moves the
  /// re-injected copies to Trash. Notifies listeners so the summary updates.
  void recordSafeSenderDedup(int count) {
    if (count <= 0) return;
    _safeSenderDedupCount += count;
    notifyListeners();
  }
  double get progress => _totalEmails == 0 ? 0 : _processedCount / _totalEmails;

  // [NEW] SPRINT 5: Convenience getters for test compatibility
  bool get isComplete => _status == ScanStatus.completed;
  bool get hasError => _status == ScanStatus.error;

  // [NEW] PHASE 3.1: Scan mode getters
  ScanMode get scanMode => _scanMode;
  int? get emailTestLimit => _emailTestLimit;
  bool get hasActionsToRevert => _lastRunActionIds.isNotEmpty;
  int get revertableActionCount => _lastRunActionIds.length;
  
  // [NEW] PHASE 3.2: Folder selection getter
  // [NEW] ISSUE #41 FIX: Return folders for current account only
  List<String> get selectedFolders => 
      _currentAccountId != null 
          ? (_selectedFoldersByAccount[_currentAccountId] ?? ['INBOX'])
          : ['INBOX'];
  
  // [NEW] ISSUE #41: Get current account ID
  String? get currentAccountId => _currentAccountId;
  
  /// Get human-readable scan mode name for UI display
  String getScanModeDisplayName() {
    switch (_scanMode) {
      case ScanMode.readOnly:
        return 'Read-Only';
      case ScanMode.rulesOnly:
        // [UPDATED] ISSUE #123+#124: Repurposed testLimit for "rules only" mode
        return 'Process Rules Only';
      case ScanMode.safeSendersOnly:
        return 'Process Safe Senders Only';
      case ScanMode.safeSendersAndRules:
        return 'Process Safe Senders + Rules';
    }
  }

  /// [NEW] SPRINT 4: Initialize persistence stores for scan result tracking
  ///
  /// Must be called before startScan() to enable scan result persistence
  void initializePersistence({
    required ScanResultStore scanResultStore,
    required UnmatchedEmailStore unmatchedEmailStore,
    DatabaseHelper? databaseHelper,
  }) {
    _scanResultStore = scanResultStore;
    _unmatchedEmailStore = unmatchedEmailStore;
    _databaseHelper = databaseHelper;
    _currentScanResultId = null;
    _logger.i('Scan result persistence initialized');
  }

  /// [NEW] SPRINT 4: Set the current account ID for scan result tracking
  void setCurrentAccountId(String accountId) {
    _currentAccountId = accountId;
    _logger.d('Set current account ID: ${Redact.accountId(accountId)}');
  }

  /// Start a new scan session
  ///
  /// Initialize with total email count for progress tracking
  /// If persistence stores are initialized, creates a scan result record
  Future<void> startScan({
    required int totalEmails,
    String scanType = 'manual',  // [NEW] SPRINT 4: manual or background
    List<String> foldersScanned = const [],
    bool persist = true,  // [FIX] SPRINT 17: Allow UI-only startScan without creating db record
  }) async {
    _status = ScanStatus.scanning;
    _processedCount = 0;
    _totalEmails = totalEmails;
    _results.clear();
    _deletedCount = 0;
    _movedCount = 0;
    _safeSendersCount = 0;
    _noRuleCount = 0;  // [NEW] FIX: Reset no-rule count on new scan
    _errorCount = 0;
    _safeSenderDedupCount = 0;  // F91 (Sprint 39): reset dedup count on new scan
    _currentEmail = null;
    _statusMessage = 'Starting scan...';
    _scanStartTime = DateTime.now();  // [NEW] SPRINT 11: Record when scan started

    // [NEW] PHASE 3.3: Reset throttling state for new scan
    _emailsSinceLastNotification = 0;
    _lastProgressNotification = null;

    // [NEW] SPRINT 4: Create scan result record if persistence is enabled
    if (persist && _scanResultStore != null && _currentAccountId != null) {
      try {
        final scanResult = ScanResult(
          accountId: _currentAccountId!,
          scanType: scanType,
          scanMode: _scanMode.toString().split('.').last,  // 'readonly', 'testLimit', etc.
          startedAt: DateTime.now().millisecondsSinceEpoch,
          totalEmails: totalEmails,
          foldersScanned: foldersScanned.isNotEmpty ? foldersScanned : ['INBOX'],
          status: 'in_progress',
        );

        _currentScanResultId = await _scanResultStore!.addScanResult(scanResult);
        _logger.i('Created scan result record: id=$_currentScanResultId, type=$scanType');
      } catch (e) {
        _logger.e('Failed to create scan result: $e');
        // Continue without persistence
      }
    }

    _logger.i('Started scan of $totalEmails emails');
    notifyListeners();
  }

  /// [NEW] ISSUE #128: Increment total emails found during folder-by-folder fetch
  ///
  /// Call this as emails are discovered to update the "Found" count progressively
  void incrementFoundEmails(int count) {
    _totalEmails += count;
    _logger.d('Found emails updated: $_totalEmails total');
    notifyListeners();
  }

  /// Mark current email and update progress
  /// 
  /// [NEW] PHASE 3.3: Throttles UI updates to every 10 emails OR 3 seconds (whichever comes first)
  /// to avoid performance issues with large scans
  void updateProgress({
    required EmailMessage email,
    String? message,
  }) {
    _currentEmail = email;
    // Note: processedCount is now incremented in recordResult() so that
    // processed/deleted/safe counts all update together after batch operations.
    _statusMessage = message ?? 'Processing ${email.from}...';
    _logger.d('Progress: $_processedCount / $_totalEmails');
    
    // [NEW] PHASE 3.3: Throttle UI updates (10 emails OR 3 seconds, whichever comes first)
    _emailsSinceLastNotification++;
    final now = DateTime.now();
    final shouldNotify = _emailsSinceLastNotification >= _progressEmailInterval ||
        _lastProgressNotification == null ||
        now.difference(_lastProgressNotification!) >= _progressTimeInterval;
    
    if (shouldNotify) {
      _emailsSinceLastNotification = 0;
      _lastProgressNotification = now;
      _logger.d('[PROGRESS] UI update triggered: $_processedCount / $_totalEmails');
      notifyListeners();
    }
  }

  /// Pause the scan
  void pauseScan() {
    _status = ScanStatus.paused;
    _statusMessage = 'Scan paused';
    _logger.i('Paused scan at $_processedCount / $_totalEmails');
    notifyListeners();
  }

  /// Resume the scan
  void resumeScan() {
    if (_status == ScanStatus.paused) {
      _status = ScanStatus.scanning;
      _statusMessage = 'Resuming scan...';
      _logger.i('Resumed scan');
      notifyListeners();
    }
  }

  /// Complete the scan successfully
  /// 
  /// [NEW] PHASE 3.3: Always calls notifyListeners() to ensure final UI update,
  /// regardless of throttling state (provides complete final counts)
  /// [NEW] SPRINT 4: Complete scan and persist final results
  Future<void> completeScan() async {
    _status = ScanStatus.completed;
    _currentEmail = null;
    _currentFolder = null;  // [NEW] ISSUE #128: Clear folder on completion
    final modeName = getScanModeDisplayName();
    // [UPDATED] ISSUE #128: Show "Scan complete." message
    _statusMessage = 'Scan complete.';
    _logger.i('Completed scan - $modeName: '
        '$_deletedCount deleted, $_movedCount moved, $_safeSendersCount safe senders, $_errorCount errors');

    // [NEW] SPRINT 4: Mark scan result as completed and persist final counts
    if (_scanResultStore != null && _currentScanResultId != null) {
      try {
        // Persist final counts before marking as completed
        await _scanResultStore!.updateScanResultFields(_currentScanResultId!, {
          'total_emails': _totalEmails,
          'processed_count': _processedCount,
          'deleted_count': _deletedCount,
          'moved_count': _movedCount,
          'safe_sender_count': _safeSendersCount,
          'no_rule_count': _noRuleCount,
          'error_count': _errorCount,
        });
        await _scanResultStore!.markScanCompleted(_currentScanResultId!);
        _logger.i('Marked scan result as completed with counts: id=$_currentScanResultId');

        // Persist individual email actions for historical "View Results" display
        await _persistEmailActions();
      } catch (e) {
        _logger.e('Failed to mark scan completed: $e');
      }
    }

    notifyListeners();  // Final update always sent (bypasses throttling)

    // SEC-14 (Sprint 33): enforce unmatched-email retention after every scan.
    // Runs independently of UI navigation so stale data is purged even if the
    // user never opens the app after an automated background scan.
    if (_unmatchedEmailStore != null) {
      try {
        final retentionDays = await SettingsStore(_databaseHelper)
            .getUnmatchedRetentionDays();
        final deleted =
            await _unmatchedEmailStore!.deleteOlderThan(retentionDays);
        if (deleted > 0) {
          _logger.i('Post-scan retention cleanup removed $deleted unmatched '
              'emails older than $retentionDays days');
        }
      } catch (e) {
        _logger.w('Post-scan retention cleanup failed: $e');
      }
    }
  }

  /// Persist individual email actions to database for historical "View Results"
  ///
  /// Batch-inserts all results at scan completion for performance.
  /// Allows "View Results" to display detailed email list from past scans.
  Future<void> _persistEmailActions() async {
    if (_databaseHelper == null || _currentScanResultId == null || _results.isEmpty) {
      return;
    }

    try {
      final actions = _results.map((r) => <String, dynamic>{
        'scan_result_id': _currentScanResultId!,
        'email_id': r.email.id,
        'email_from': r.email.from,
        'email_subject': r.email.subject,
        'email_received_date': r.email.receivedDate.millisecondsSinceEpoch,
        'email_folder': r.email.folderName,
        'action_type': r.action.name,
        'matched_rule_name': r.evaluationResult?.matchedRule,
        'matched_pattern': r.evaluationResult?.matchedPattern,
        'is_safe_sender': r.action == EmailActionType.safeSender ? 1 : 0,
        'success': r.success ? 1 : 0,
        'error_message': r.error,
        // F91 (Sprint 39): persist the captured RFC 5322 Message-ID (null
        // when the message had no Message-ID header or the provider did not
        // fetch headers). Used to recognize already-rescued safe-sender
        // messages re-injected by AOL's copy-not-move behavior.
        'rfc5322_message_id': r.email.messageIdHeader,
        // F96 (Sprint 43): persist the SPF/DKIM/DMARC classification computed
        // from the LIVE-scan headers (full Authentication-Results present here)
        // so the off-scan quick-add paths can re-hydrate it and fire the RED
        // anti-phishing warning. classifyHeaders returns GREY when no auth
        // headers were present; we store that name as-is (re-hydration treats a
        // stored GREY identically to "no snapshot").
        'auth_classification':
            AuthResultsParser.classifyHeaders(r.email.headers).name,
      }).toList();

      await _databaseHelper!.insertEmailActionBatch(actions);
      _logger.i('Persisted ${actions.length} email actions for scan $_currentScanResultId');

      // F39 (Sprint 46): persist the "No rule" subset to unmatched_emails --
      // the data source for the cross-account Review "No Rule" Items screen
      // and the SEC-14 retention pipeline. Manual testing found this table
      // had NO production writer: a Sprint 4 placeholder ("will persist in
      // Task D") only logged, so the review screen always showed 0 items
      // while scan_results.no_rule_count said otherwise.
      if (_unmatchedEmailStore != null) {
        final unmatched = _results
            .where((r) => r.action == EmailActionType.none)
            .map((r) => UnmatchedEmail(
                  scanResultId: _currentScanResultId!,
                  providerIdentifierType: 'email_id',
                  providerIdentifierValue: r.email.id,
                  fromEmail: r.email.from,
                  subject: r.email.subject,
                  // SEC-14: body content deliberately NOT persisted here; the
                  // review screen shows sender + subject only.
                  folderName: r.email.folderName,
                  emailDate: r.email.receivedDate,
                  createdAt: DateTime.now(),
                  // F96: same scan-time SPF/DKIM/DMARC snapshot as the
                  // email_actions row, so the review screen's safe-sender
                  // bulk action can fire the RED anti-phishing warning.
                  authClassification:
                      AuthResultsParser.classifyHeaders(r.email.headers).name,
                ))
            .toList();
        if (unmatched.isNotEmpty) {
          await _unmatchedEmailStore!.addUnmatchedEmailBatch(unmatched);
          _logger.i('Persisted ${unmatched.length} unmatched ("No rule") '
              'emails for scan $_currentScanResultId');
        }
      }
    } catch (e) {
      _logger.e('Failed to persist email actions: $e');
    }
  }

  /// [NEW] SPRINT 4: Mark scan as failed with error and persist error state
  Future<void> errorScan(String errorMessage) async {
    _status = ScanStatus.error;
    _statusMessage = 'Scan failed: $errorMessage';
    _currentEmail = null;
    _logger.e('Scan error: $errorMessage');

    // [NEW] SPRINT 4: Mark scan result as error in database
    if (_scanResultStore != null && _currentScanResultId != null) {
      try {
        await _scanResultStore!.markScanError(_currentScanResultId!, errorMessage);
        _logger.i('Marked scan result as error: id=$_currentScanResultId');
      } catch (e) {
        _logger.e('Failed to mark scan error: $e');
      }
    }

    notifyListeners();
  }

  /// Reset scan state to idle
  void reset() {
    _status = ScanStatus.idle;
    _processedCount = 0;
    _totalEmails = 0;
    _currentEmail = null;
    _statusMessage = null;
    _results.clear();
    _deletedCount = 0;
    _movedCount = 0;
    _safeSendersCount = 0;
    _noRuleCount = 0;  // [NEW] PHASE 3.1: Reset no-rule count
    _errorCount = 0;
    _safeSenderDedupCount = 0;  // F91 (Sprint 39): reset dedup count

    // [NEW] PHASE 3.3: Reset throttling state
    _emailsSinceLastNotification = 0;
    _lastProgressNotification = null;
    
    _logger.i('Reset scan state');
    notifyListeners();
  }

  /// Get summary of scan results
  Map<String, dynamic> getSummary() {
    return {
      'status': _status.toString(),
      'total_emails': _totalEmails,
      'processed': _processedCount,
      'deleted': _deletedCount,
      'moved': _movedCount,
      'safe_senders': _safeSendersCount,
      'safe_sender_dedup': _safeSenderDedupCount,  // F91 (Sprint 39)
      'errors': _errorCount,
      'progress': progress,
    };
  }

  /// [NEW] MULTI-FOLDER SUPPORT: Get junk folder names for provider
  /// 
  /// Returns list of junk folder names for the given email provider.
  /// Supports multiple folders per provider (e.g., AOL has both "Bulk Mail" and "Spam").
  /// 
  /// Example:
  /// ```dart
  /// final junkFolders = provider.getJunkFoldersForProvider('aol');
  /// // Returns: ['Bulk Mail', 'Spam']
  /// 
  /// // Scan both Inbox and all Junk folders
  /// await scanFolder(accountId, 'aol', 'Inbox');
  /// for (var folder in junkFolders) {
  ///   await scanFolder(accountId, 'aol', folder);
  /// }
  /// ```
  List<String> getJunkFoldersForProvider(String platformId) {
    return JUNK_FOLDERS_BY_PROVIDER[platformId] ?? ['Spam', 'Junk'];
  }

  /// [NEW] MULTI-FOLDER SUPPORT: Set current folder being scanned
  /// 
  /// Updates the provider state to reflect which folder is being scanned.
  /// Useful for UI display: "Scanning: Inbox (40/88)" vs "Scanning: Bulk Mail (88/88)"
  void setCurrentFolder(String folderName) {
    _currentFolder = folderName;
    _logger.d('Scanning folder: $folderName');
    notifyListeners();
  }

  /// [NEW] MULTI-FOLDER SUPPORT: Get human-readable scan status with folder
  /// 
  /// Returns status message including current folder being scanned.
  /// Example: "Scanning Inbox: 40/88 emails processed"
  String getDetailedStatus() {
    if (_currentFolder == null) {
      return '$_statusMessage ($_processedCount / $_totalEmails)';
    }
    return 'Scanning $_currentFolder: $_processedCount / $_totalEmails';
  }

  /// Initialize scan mode before starting a scan.
  ///
  /// Scan modes:
  /// - readOnly: scan only, no modifications (default)
  /// - rulesOnly: execute spam rules only, skip safe sender actions
  /// - safeSendersOnly: execute safe sender actions only, skip spam rules
  /// - safeSendersAndRules: execute both safe sender and spam rule actions
  void initializeScanMode({
    ScanMode mode = ScanMode.readOnly,
    int? testLimit,
  }) {
    _scanMode = mode;
    _emailTestLimit = testLimit;
    _lastRunActionIds.clear();
    _lastRunActions.clear();
    
    String modeStr = mode.toString().split('.').last;
    String limitStr = (testLimit != null) ? ' (limit: $testLimit)' : '';
    _logger.i('Initialized scan mode: $modeStr$limitStr');
    notifyListeners();
  }

  /// [NEW] PHASE 3.2: Set selected folders for scan
  /// [NEW] ISSUE #41 FIX: Store folders per-account to prevent cross-account folder leakage
  void setSelectedFolders(List<String> folders, {String? accountId}) {
    final targetAccountId = accountId ?? _currentAccountId;
    if (targetAccountId == null) {
      _logger.w('[WARNING] No account ID specified for folder selection');
      return;
    }
    
    if (folders.isEmpty) {
      _logger.w('[WARNING] No folders selected for $targetAccountId, defaulting to INBOX');
      _selectedFoldersByAccount[targetAccountId] = ['INBOX'];
    } else {
      _selectedFoldersByAccount[targetAccountId] = List.from(folders);  // Create copy to avoid mutation
      _logger.i('[FOLDERS] Selected folders for $targetAccountId: ${_selectedFoldersByAccount[targetAccountId]}');
    }
    notifyListeners();
  }
  
  /// [NEW] ISSUE #41: Set current account ID for folder lookup
  void setCurrentAccount(String accountId) {
    _currentAccountId = accountId;
    _logger.i('[EMAIL] Current account set to: ${Redact.accountId(accountId)}');
    // Don't notify - this is just for internal state tracking
  }
  
  /// [NEW] ISSUE #41: Get selected folders for a specific account
  List<String> getSelectedFoldersForAccount(String accountId) {
    return _selectedFoldersByAccount[accountId] ?? ['INBOX'];
  }
  
  /// [NEW] ISSUE #41: Clear folders for a specific account
  void clearSelectedFoldersForAccount(String accountId) {
    _selectedFoldersByAccount.remove(accountId);
    _logger.i('[CLEARED] Folder selection for ${Redact.accountId(accountId)}');
  }

  /// Mode-aware recordResult.
  ///
  /// - readOnly: actions logged but NOT executed
  /// - rulesOnly: spam rule actions executed (can revert)
  /// - safeSendersOnly: safe sender actions executed (can revert)
  /// - safeSendersAndRules: all actions executed PERMANENTLY (cannot revert)
  void recordResult(EmailActionResult result) {
    _logger.d('[RECORD] recordResult called: action=${result.action}, email=${result.email.from}, success=${result.success}');

    // Determine if this action should actually be executed
    bool shouldExecuteAction;
    if (_scanMode == ScanMode.safeSendersAndRules) {
      // In fullScan mode, all actions are executed permanently (no test limit, no revert tracking)
      shouldExecuteAction = true;
    } else if (_scanMode == ScanMode.readOnly) {
      // In readonly mode, actions are never executed
      shouldExecuteAction = false;
    } else {
      // In test modes, respect the optional email test limit
      shouldExecuteAction = _emailTestLimit == null ||
          _lastRunActionIds.length < _emailTestLimit!;
    }

    if (shouldExecuteAction) {
      // Track action for potential revert (only for testLimit and testAll, NOT fullScan)
      if (_scanMode == ScanMode.rulesOnly || _scanMode == ScanMode.safeSendersOnly) {
        _lastRunActionIds.add(result.email.id);
        _lastRunActions.add(result);
        _logger.i('[NOTES] Action recorded (revertable): ${result.action} - ${result.email.from}');
      } else if (_scanMode == ScanMode.safeSendersAndRules) {
        _logger.i('[WARNING] Action executed (PERMANENT): ${result.action} - ${result.email.from}');
      }
    } else {
      // Read-only or limit reached: log what would happen
      if (_scanMode == ScanMode.readOnly) {
        _logger.i('[CHECKLIST] [READONLY] Would ${result.action} email: ${result.email.from}');
      } else {
        _logger.i('[CHECKLIST] [LIMIT REACHED] Would ${result.action} email: ${result.email.from}');
      }
    }

    // Always record the result for UI/history
    _results.add(result);
    _processedCount++;

    // [NEW] PHASE 3.1: Always update counts based on rule evaluation (what WOULD happen)
    // This ensures bubbles show proposed actions even in Read-Only mode
    switch (result.action) {
      case EmailActionType.delete:
        _deletedCount++;
        break;
      case EmailActionType.moveToJunk:
        _movedCount++;
        break;
      case EmailActionType.safeSender:
        _safeSendersCount++;
        break;
      case EmailActionType.none:
        _noRuleCount++;  // [NEW] PHASE 3.1: Track emails with no rule match
        break;
      case EmailActionType.markAsRead:
        break;
    }

    if (!result.success) {
      _errorCount++;
    }

    // Unmatched ("No rule") emails are persisted in batch at scan completion
    // by _persistEmailActions (F39, Sprint 46) -- the Sprint 4 per-email
    // placeholder that used to live here never wrote anything.

    // [NEW] SPRINT 12: Notify listeners with 2-second throttling
    // This ensures Results page updates during scan in real-time
    // Always notify on first result, then every 2 seconds thereafter
    final now = DateTime.now();
    final resultCount = _results.length;
    final shouldNotify = resultCount == 1 ||
        _lastProgressNotification == null ||
        now.difference(_lastProgressNotification!) >= const Duration(seconds: 2);

    if (shouldNotify) {
      _lastProgressNotification = now;
      _logger.d('[PROGRESS] Results UI update triggered: $resultCount results');
      notifyListeners();
    }
  }

  /// [NEW] PHASE 2 SPRINT 3: Revert all actions from last run
  /// 
  /// Reverts all delete/move operations performed in last scan.
  /// Restores emails from trash/junk back to their original folders.
  /// 
  /// Example:
  /// ```dart
  /// if (provider.hasActionsToRevert) {
  ///   await provider.revertLastRun();
  ///   // Emails restored
  /// }
  /// ```
  Future<void> revertLastRun() async {
    if (_lastRunActionIds.isEmpty) {
      _logger.w('No actions to revert');
      return;
    }

    _statusMessage = 'Reverting ${_lastRunActionIds.length} actions...';
    notifyListeners();

    try {
      _logger.i('[PENDING] Starting revert of ${_lastRunActionIds.length} email actions');

      // Process reversions in reverse order (undo in opposite sequence)
      for (var i = _lastRunActions.length - 1; i >= 0; i--) {
        final action = _lastRunActions[i];
        try {
          switch (action.action) {
            case EmailActionType.delete:
              // Restore from trash to original folder
              _logger.d('[PENDING] Restoring deleted email: ${action.email.from}');
              // await _restoreFromTrash(action.email.id, action.email.folderName);
              break;
            case EmailActionType.moveToJunk:
              // Move from junk back to inbox
              _logger.d('[PENDING] Restoring moved email: ${action.email.from}');
              // await _moveFromJunkToInbox(action.email.id);
              break;
            default:
              // No revert needed for other action types
              break;
          }
        } catch (e) {
          _logger.e('Error reverting action for ${action.email.from}: $e');
        }
      }

      _lastRunActionIds.clear();
      _lastRunActions.clear();
      _statusMessage = 'Revert completed successfully';
      _logger.i('[OK] Revert completed');
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Revert failed: $e';
      _logger.e('Revert error: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// [NEW] PHASE 2 SPRINT 3: Clear revert history without reverting
  ///
  /// Confirms and accepts last run's actions permanently.
  /// Once called, actions cannot be reverted.
  void confirmLastRun() {
    if (_lastRunActionIds.isNotEmpty) {
      _logger.i('[OK] Confirmed ${_lastRunActionIds.length} actions - can no longer revert');
      _lastRunActionIds.clear();
      _lastRunActions.clear();
      notifyListeners();
    }
  }

  /// Export scan results to CSV format
  ///
  /// [NEW] SPRINT 11: Enhanced with additional columns:
  /// - Scan Date (when scan was performed)
  /// - Received Date (when email was received)
  /// - Match Condition (which rule condition matched, if available)
  /// - Email ID (unique identifier for tracking)
  ///
  /// Returns CSV string that can be saved to file or displayed in UI
  String exportResultsToCSV() {
    final buffer = StringBuffer();

    // CSV Header - Enhanced with new columns
    buffer.writeln(
        '"Scan Date","Received Date","From","Folder","Subject","Rule","Match Condition","Action","Status","Email ID"');

    // Format scan date (when this scan was performed)
    final scanDate = _scanStartTime != null
        ? _scanStartTime!.toIso8601String()
        : 'Unknown';

    // CSV Rows
    for (final result in _results) {
      final receivedDate = result.email.receivedDate.toIso8601String();
      final from = _escapeCsv(result.email.from);
      final folder = _escapeCsv(result.email.folderName);
      // Clean subject for CSV (remove tabs, extra spaces, repeated punctuation)
      final cleanedSubject = PatternNormalization.cleanSubjectForDisplay(result.email.subject);
      final subject = _escapeCsv(cleanedSubject);
      final rule = _escapeCsv(result.evaluationResult?.matchedRule ?? 'No rule');

      // Extract matched pattern from evaluation result (if available)
      final matchCondition = _escapeCsv(
        result.evaluationResult?.matchedPattern ?? 'N/A',
      );

      final action = _getActionName(result.action);
      final status = result.success ? 'Success' : 'Failed';
      final emailId = _escapeCsv(result.email.id);

      buffer.writeln(
          '"$scanDate","$receivedDate","$from","$folder","$subject","$rule","$matchCondition","$action","$status","$emailId"');
    }

    return buffer.toString();
  }

  /// Helper to escape CSV values (handle quotes and commas)
  String _escapeCsv(String value) {
    // Replace double quotes with two double quotes (CSV standard)
    return value.replaceAll('"', '""');
  }

  /// Helper to get action name for CSV/Excel export
  /// F45: "No rule" instead of "None" for emails with no matching rule
  String _getActionName(EmailActionType action) {
    switch (action) {
      case EmailActionType.delete:
        return 'Delete';
      case EmailActionType.moveToJunk:
        return 'Move to Junk';
      case EmailActionType.safeSender:
        return 'Safe Sender';
      case EmailActionType.markAsRead:
        return 'Mark as Read';
      case EmailActionType.none:
        return 'No rule';
    }
  }

  /// F45: Export scan results to Excel (.xlsx) format
  ///
  /// Field order (per Sprint 25 retrospective):
  /// Scan Date/Time, Received Date/Time, Status, Folder, Action, Rule,
  /// From, Subject, Match Condition, Email ID
  ///
  /// Returns list of row data (each row is a list of cell values).
  /// The caller is responsible for writing to the Excel file.
  /// Returns empty list if no results.
  /// F110 (Sprint 43): the emails in this scan that FAILED at least one
  /// authentication check (SPF/DKIM/DMARC hard-fail), each paired with the
  /// comma-separated list of failed checks -- e.g. `(from, 'SPF,DMARC')`.
  ///
  /// Used by the per-account scan log to write one phishing line per failed
  /// email naming the SENDER (sender addresses are permitted in logs per the
  /// narrowed ADR-0030 -- only the app user's own configured account addresses
  /// are redacted). Emails with no auth failure are omitted. Returns empty when
  /// no email failed.
  List<({String from, String failedChecks})> getAuthFailures() {
    final failures = <({String from, String failedChecks})>[];
    for (final result in _results) {
      final failed =
          AuthResultsParser.failedChecksFromHeaders(result.email.headers);
      if (failed.isNotEmpty) {
        failures.add((from: result.email.from, failedChecks: failed.join(',')));
      }
    }
    return failures;
  }

  List<List<String>> getExcelRows() {
    if (_results.isEmpty) return [];

    final scanDate = _scanStartTime != null
        ? _scanStartTime!.toIso8601String()
        : 'Unknown';

    final rows = <List<String>>[];

    for (final result in _results) {
      final receivedDate = result.email.receivedDate.toIso8601String();
      final status = result.success ? 'Success' : 'Failed';
      final folder = result.email.folderName;
      final action = _getActionName(result.action);
      final rule = result.evaluationResult?.matchedRule ?? 'No rule';
      final from = result.email.from;
      final subject = PatternNormalization.cleanSubjectForDisplay(result.email.subject);
      final matchCondition = result.evaluationResult?.matchedPattern ?? 'N/A';
      final emailId = result.email.id;
      // F110 (Sprint 43): "Phishing SPF/DKIM/DMARC" -- the comma-separated list
      // of authentication checks this email HARD-FAILED (e.g. "SPF,DMARC").
      // Blank when nothing failed. Every scanned email keeps its row; this
      // column just flags the failures so a reviewer can spot likely spoofs.
      final phishing =
          AuthResultsParser.failedChecksFromHeaders(result.email.headers)
              .join(',');

      rows.add([
        scanDate,
        receivedDate,
        status,
        folder,
        action,
        rule,
        from,
        subject,
        matchCondition,
        emailId,
        phishing,
      ]);
    }

    return rows;
  }
}


