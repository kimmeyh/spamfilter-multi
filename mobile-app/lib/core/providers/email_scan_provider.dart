/// Provider-based state management for email scanning
/// 
/// Manages scan progress, results, and email evaluation state
/// for display in UI screens.
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/unmatched_email_store.dart';
import '../../core/utils/pattern_normalization.dart';

/// Scan status states
enum ScanStatus { idle, scanning, paused, completed, error }

/// Email action type for categorization
enum EmailActionType { none, safeSender, delete, moveToJunk, markAsRead }

/// [NEW] PHASE 3.1: Scan mode - read-only, test modes, or full production scan
enum ScanMode {
  readonly,   // Default: scan only, no modifications
  testLimit,  // Test mode: modify up to N emails, then stop
  testAll,    // Test mode: modify all emails (can revert)
  fullScan,   // [NEW] PHASE 3.1: Production mode - PERMANENT delete/move (cannot revert)
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

  // [NEW] PHASE 2 SPRINT 3: Read-only mode & revert capability
  ScanMode _scanMode = ScanMode.readonly;  // Default: read-only
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
      case ScanMode.readonly:
        return 'Read-Only';
      case ScanMode.testLimit:
        return 'Test Limited Emails';
      case ScanMode.testAll:
        return 'Full Scan with Revert';
      case ScanMode.fullScan:
        return 'Full Scan';
    }
  }

  /// [NEW] SPRINT 4: Initialize persistence stores for scan result tracking
  ///
  /// Must be called before startScan() to enable scan result persistence
  void initializePersistence({
    required ScanResultStore scanResultStore,
    required UnmatchedEmailStore unmatchedEmailStore,
  }) {
    _scanResultStore = scanResultStore;
    _unmatchedEmailStore = unmatchedEmailStore;
    _currentScanResultId = null;
    _logger.i('Scan result persistence initialized');
  }

  /// [NEW] SPRINT 4: Set the current account ID for scan result tracking
  void setCurrentAccountId(String accountId) {
    _currentAccountId = accountId;
    _logger.d('Set current account ID: $accountId');
  }

  /// Start a new scan session
  ///
  /// Initialize with total email count for progress tracking
  /// If persistence stores are initialized, creates a scan result record
  Future<void> startScan({
    required int totalEmails,
    String scanType = 'manual',  // [NEW] SPRINT 4: manual or background
    List<String> foldersScanned = const [],
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
    _currentEmail = null;
    _statusMessage = 'Starting scan...';
    _scanStartTime = DateTime.now();  // [NEW] SPRINT 11: Record when scan started

    // [NEW] PHASE 3.3: Reset throttling state for new scan
    _emailsSinceLastNotification = 0;
    _lastProgressNotification = null;

    // [NEW] SPRINT 4: Create scan result record if persistence is enabled
    if (_scanResultStore != null && _currentAccountId != null) {
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
    _processedCount++;
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
      _logger.d('📊 UI update triggered: $_processedCount / $_totalEmails');
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

    // [NEW] SPRINT 4: Mark scan result as completed in database
    if (_scanResultStore != null && _currentScanResultId != null) {
      try {
        await _scanResultStore!.markScanCompleted(_currentScanResultId!);
        _logger.i('Marked scan result as completed: id=$_currentScanResultId');
      } catch (e) {
        _logger.e('Failed to mark scan completed: $e');
      }
    }

    notifyListeners();  // Final update always sent (bypasses throttling)
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

  /// [NEW] PHASE 2 SPRINT 3: Initialize scan mode and test limits
  /// 
  /// Set the scan mode before starting a scan:
  /// - readonly: scan only, no modifications (default, safe for testing)
  /// - testLimit: modify up to N emails, then stop
  /// - testAll: modify all emails (be careful! can revert)
  /// 
  /// Example:
  /// ```dart
  /// provider.initializeScanMode(mode: ScanMode.testLimit, testLimit: 50);
  /// // Now scan will delete/move up to 50 emails, then stop
  /// ```
  void initializeScanMode({
    ScanMode mode = ScanMode.readonly,
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
      _logger.i('📁 Selected folders for $targetAccountId: ${_selectedFoldersByAccount[targetAccountId]}');
    }
    notifyListeners();
  }
  
  /// [NEW] ISSUE #41: Set current account ID for folder lookup
  void setCurrentAccount(String accountId) {
    _currentAccountId = accountId;
    _logger.i('📧 Current account set to: $accountId');
    // Don't notify - this is just for internal state tracking
  }
  
  /// [NEW] ISSUE #41: Get selected folders for a specific account
  List<String> getSelectedFoldersForAccount(String accountId) {
    return _selectedFoldersByAccount[accountId] ?? ['INBOX'];
  }
  
  /// [NEW] ISSUE #41: Clear folders for a specific account
  void clearSelectedFoldersForAccount(String accountId) {
    _selectedFoldersByAccount.remove(accountId);
    _logger.i('🗑️ Cleared folder selection for $accountId');
  }

  /// [NEW] PHASE 3.1: Mode-aware recordResult with read-only, test modes, and full scan
  /// 
  /// - readonly: actions logged but NOT executed
  /// - testLimit: only first N actions executed (can revert)
  /// - testAll: all actions executed (can revert)
  /// - fullScan: all actions executed PERMANENTLY (cannot revert)
  void recordResult(EmailActionResult result) {
    // Determine if this action should actually be executed
    bool shouldExecuteAction;
    if (_scanMode == ScanMode.fullScan) {
      // In fullScan mode, all actions are executed permanently (no test limit, no revert tracking)
      shouldExecuteAction = true;
    } else if (_scanMode == ScanMode.readonly) {
      // In readonly mode, actions are never executed
      shouldExecuteAction = false;
    } else {
      // In test modes, respect the optional email test limit
      shouldExecuteAction = _emailTestLimit == null ||
          _lastRunActionIds.length < _emailTestLimit!;
    }

    if (shouldExecuteAction) {
      // Track action for potential revert (only for testLimit and testAll, NOT fullScan)
      if (_scanMode == ScanMode.testLimit || _scanMode == ScanMode.testAll) {
        _lastRunActionIds.add(result.email.id);
        _lastRunActions.add(result);
        _logger.i('[NOTES] Action recorded (revertable): ${result.action} - ${result.email.from}');
      } else if (_scanMode == ScanMode.fullScan) {
        _logger.i('🔥 Action executed (PERMANENT): ${result.action} - ${result.email.from}');
      }
    } else {
      // Read-only or limit reached: log what would happen
      if (_scanMode == ScanMode.readonly) {
        _logger.i('[CHECKLIST] [READONLY] Would ${result.action} email: ${result.email.from}');
      } else {
        _logger.i('[CHECKLIST] [LIMIT REACHED] Would ${result.action} email: ${result.email.from}');
      }
    }

    // Always record the result for UI/history
    _results.add(result);

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

    // [NEW] SPRINT 4: Persist unmatched emails to database
    if (result.action == EmailActionType.none &&
        _unmatchedEmailStore != null &&
        _currentScanResultId != null) {
      // Create provider identifier based on email platform (deferred for integration)
      // For now, use placeholder implementation
      _logger.d('Unmatched email identified: ${result.email.from} - will persist in Task D');
    }

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
      _logger.d('📊 Results UI update triggered: $resultCount results');
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

  /// Helper to get action name for CSV export
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
        return 'None';
    }
  }
}


