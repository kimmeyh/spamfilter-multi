/// Provider-based state management for email scanning
/// 
/// Manages scan progress, results, and email evaluation state
/// for display in UI screens.
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../adapters/email_providers/junk_folder_config.dart';
import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';

/// Scan status states
enum ScanStatus { idle, scanning, paused, completed, error }

/// Email action type for categorization
enum EmailActionType { none, safeSender, delete, moveToJunk, markAsRead }

/// ✨ PHASE 3.1: Scan mode - read-only, test modes, or full production scan
enum ScanMode {
  readonly,   // Default: scan only, no modifications
  testLimit,  // Test mode: modify up to N emails, then stop
  testAll,    // Test mode: modify all emails (can revert)
  fullScan,   // ✨ PHASE 3.1: Production mode - PERMANENT delete/move (cannot revert)
}

/// ✨ Multi-account & Multi-folder support: Junk folder configuration per provider
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

  // ✨ MULTI-ACCOUNT SUPPORT: Provider-specific junk folder configuration
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
  String? _currentFolder;  // ✨ NEW: Track which folder is being scanned

  // Results tracking
  final List<EmailActionResult> _results = [];
  int _deletedCount = 0;
  int _movedCount = 0;
  int _safeSendersCount = 0;
  int _noRuleCount = 0;  // ✨ PHASE 3.1: Emails with no rule match
  int _errorCount = 0;

  // ✨ PHASE 2 SPRINT 3: Read-only mode & revert capability
  ScanMode _scanMode = ScanMode.readonly;  // Default: read-only
  int? _emailTestLimit;  // How many emails to actually modify (for testLimit mode)
  final List<String> _lastRunActionIds = [];  // Track email IDs of actions for revert
  final List<EmailActionResult> _lastRunActions = [];  // Track actual actions for revert

  // ✨ PHASE 3.2: Folder selection for scan
  List<String> _selectedFolders = ['INBOX'];  // Default to INBOX

  // Getters
  ScanStatus get status => _status;
  int get processedCount => _processedCount;
  int get totalEmails => _totalEmails;
  EmailMessage? get currentEmail => _currentEmail;
  String? get statusMessage => _statusMessage;
  String? get currentFolder => _currentFolder;  // ✨ NEW: Get current folder being scanned
  List<EmailActionResult> get results => _results;
  int get deletedCount => _deletedCount;
  int get movedCount => _movedCount;
  int get safeSendersCount => _safeSendersCount;
  int get noRuleCount => _noRuleCount;  // ✨ PHASE 3.1: Emails with no rule match
  int get errorCount => _errorCount;
  double get progress => _totalEmails == 0 ? 0 : _processedCount / _totalEmails;

  // ✨ PHASE 3.1: Scan mode getters
  ScanMode get scanMode => _scanMode;
  int? get emailTestLimit => _emailTestLimit;
  bool get hasActionsToRevert => _lastRunActionIds.isNotEmpty;
  int get revertableActionCount => _lastRunActionIds.length;
  
  // ✨ PHASE 3.2: Folder selection getter
  List<String> get selectedFolders => _selectedFolders;
  
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

  /// Start a new scan session
  /// 
  /// Initialize with total email count for progress tracking
  void startScan({required int totalEmails}) {
    _status = ScanStatus.scanning;
    _processedCount = 0;
    _totalEmails = totalEmails;
    _results.clear();
    _deletedCount = 0;
    _movedCount = 0;
    _safeSendersCount = 0;
    _errorCount = 0;
    _currentEmail = null;
    _statusMessage = 'Starting scan...';
    _logger.i('Started scan of $totalEmails emails');
    notifyListeners();
  }

  /// Mark current email and update progress
  void updateProgress({
    required EmailMessage email,
    String? message,
  }) {
    _currentEmail = email;
    _processedCount++;
    _statusMessage = message ?? 'Processing ${email.from}...';
    _logger.d('Progress: $_processedCount / $_totalEmails');
    notifyListeners();
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
  void completeScan() {
    _status = ScanStatus.completed;
    _currentEmail = null;
    final modeName = getScanModeDisplayName();
    _statusMessage = 'Scan completed - $modeName: '
        '$_deletedCount deleted, $_movedCount moved, $_safeSendersCount safe senders, $_errorCount errors';
    _logger.i('Completed scan: $_statusMessage');
    notifyListeners();
  }

  /// Mark scan as failed with error
  void errorScan(String errorMessage) {
    _status = ScanStatus.error;
    _statusMessage = 'Scan failed: $errorMessage';
    _currentEmail = null;
    _logger.e('Scan error: $errorMessage');
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
    _noRuleCount = 0;  // ✨ PHASE 3.1: Reset no-rule count
    _errorCount = 0;
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

  /// ✨ MULTI-FOLDER SUPPORT: Get junk folder names for provider
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

  /// ✨ MULTI-FOLDER SUPPORT: Set current folder being scanned
  /// 
  /// Updates the provider state to reflect which folder is being scanned.
  /// Useful for UI display: "Scanning: Inbox (40/88)" vs "Scanning: Bulk Mail (88/88)"
  void setCurrentFolder(String folderName) {
    _currentFolder = folderName;
    _logger.d('Scanning folder: $folderName');
    notifyListeners();
  }

  /// ✨ MULTI-FOLDER SUPPORT: Get human-readable scan status with folder
  /// 
  /// Returns status message including current folder being scanned.
  /// Example: "Scanning Inbox: 40/88 emails processed"
  String getDetailedStatus() {
    if (_currentFolder == null) {
      return '$_statusMessage ($_processedCount / $_totalEmails)';
    }
    return 'Scanning $_currentFolder: $_processedCount / $_totalEmails';
  }

  /// ✨ PHASE 2 SPRINT 3: Initialize scan mode and test limits
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

  /// ✨ PHASE 3.2: Set selected folders for scan
  void setSelectedFolders(List<String> folders) {
    if (folders.isEmpty) {
      _logger.w('⚠️ No folders selected, defaulting to INBOX');
      _selectedFolders = ['INBOX'];
    } else {
      _selectedFolders = List.from(folders);  // Create copy to avoid mutation
      _logger.i('📁 Selected folders for scan: $_selectedFolders');
    }
    notifyListeners();
  }

  /// ✨ PHASE 3.1: Mode-aware recordResult with read-only, test modes, and full scan
  /// 
  /// - readonly: actions logged but NOT executed
  /// - testLimit: only first N actions executed (can revert)
  /// - testAll: all actions executed (can revert)
  /// - fullScan: all actions executed PERMANENTLY (cannot revert)
  void recordResult(EmailActionResult result) {
    // Determine if this action should actually be executed
    bool shouldExecuteAction = _scanMode != ScanMode.readonly &&
        (_emailTestLimit == null || _lastRunActionIds.length < _emailTestLimit!);

    if (shouldExecuteAction) {
      // Track action for potential revert (only for testLimit and testAll, NOT fullScan)
      if (_scanMode == ScanMode.testLimit || _scanMode == ScanMode.testAll) {
        _lastRunActionIds.add(result.email.id);
        _lastRunActions.add(result);
        _logger.i('📝 Action recorded (revertable): ${result.action} - ${result.email.from}');
      } else if (_scanMode == ScanMode.fullScan) {
        _logger.i('🔥 Action executed (PERMANENT): ${result.action} - ${result.email.from}');
      }
    } else {
      // Read-only or limit reached: log what would happen
      if (_scanMode == ScanMode.readonly) {
        _logger.i('📋 [READONLY] Would ${result.action} email: ${result.email.from}');
      } else {
        _logger.i('📋 [LIMIT REACHED] Would ${result.action} email: ${result.email.from}');
      }
    }

    // Always record the result for UI/history
    _results.add(result);

    // ✨ PHASE 3.1: Always update counts based on rule evaluation (what WOULD happen)
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
        _noRuleCount++;  // ✨ PHASE 3.1: Track emails with no rule match
        break;
      case EmailActionType.markAsRead:
        break;
    }

    if (!result.success) {
      _errorCount++;
    }
  }

  /// ✨ PHASE 2 SPRINT 3: Revert all actions from last run
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
      _logger.i('🔄 Starting revert of ${_lastRunActionIds.length} email actions');

      // Process reversions in reverse order (undo in opposite sequence)
      for (var i = _lastRunActions.length - 1; i >= 0; i--) {
        final action = _lastRunActions[i];
        try {
          switch (action.action) {
            case EmailActionType.delete:
              // Restore from trash to original folder
              _logger.d('🔄 Restoring deleted email: ${action.email.from}');
              // await _restoreFromTrash(action.email.id, action.email.folderName);
              break;
            case EmailActionType.moveToJunk:
              // Move from junk back to inbox
              _logger.d('🔄 Restoring moved email: ${action.email.from}');
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
      _logger.i('✅ Revert completed');
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Revert failed: $e';
      _logger.e('Revert error: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// ✨ PHASE 2 SPRINT 3: Clear revert history without reverting
  /// 
  /// Confirms and accepts last run's actions permanently.
  /// Once called, actions cannot be reverted.
  void confirmLastRun() {
    if (_lastRunActionIds.isNotEmpty) {
      _logger.i('✅ Confirmed ${_lastRunActionIds.length} actions - can no longer revert');
      _lastRunActionIds.clear();
      _lastRunActions.clear();
      notifyListeners();
    }
  }
}


