import 'package:logger/logger.dart';

import '../../util/redact.dart';

/// Service for detecting and managing background execution mode
///
/// Handles parsing of command-line arguments to detect if the app
/// is launched in background scanning mode (via Task Scheduler).
class BackgroundModeService {
  static final Logger _logger = Logger();

  /// Flag indicating if app is running in background mode
  static bool _isBackgroundMode = false;

  /// The account id to scan in background mode, parsed from
  /// `--account-id=<id>` (Sprint 42, F98 / ADR-0039). Null means the legacy
  /// iterate-all-accounts behavior (backward compatibility for un-migrated
  /// Task Scheduler entries during the transition).
  static String? _backgroundAccountId;

  /// Launch flag for background scanning
  static const String backgroundScanFlag = '--background-scan';

  /// Launch flag carrying the per-account id, e.g. `--account-id=gmail-a@b.com`.
  static const String accountIdFlagPrefix = '--account-id=';

  /// Initialize background mode detection
  ///
  /// Parses command-line arguments to check for background scan flag
  /// Should be called early in app initialization (main.dart)
  static void initialize(List<String> args) {
    _logger.i('Initializing background mode service with args: $args');

    // Check if background scan flag is present
    _isBackgroundMode = args.contains(backgroundScanFlag);

    // F98: parse optional --account-id=<id> so the scheduled launch is
    // account-scoped. Absent -> null -> legacy all-accounts behavior.
    _backgroundAccountId = null;
    for (final arg in args) {
      if (arg.startsWith(accountIdFlagPrefix)) {
        final value = arg.substring(accountIdFlagPrefix.length).trim();
        if (value.isNotEmpty) {
          _backgroundAccountId = value;
        }
        break;
      }
    }

    if (_isBackgroundMode) {
      _logger.i('*** BACKGROUND MODE DETECTED ***'
          '${_backgroundAccountId != null ? ' (account: ${Redact.accountId(_backgroundAccountId)})' : ' (all accounts -- legacy)'}');
    } else {
      _logger.i('Running in normal (foreground) mode');
    }
  }

  /// The per-account id parsed from `--account-id=<id>`, or null for the legacy
  /// all-accounts background scan. Only meaningful when [isBackgroundMode].
  static String? get backgroundAccountId => _backgroundAccountId;

  /// Check if app is running in background mode
  static bool get isBackgroundMode => _isBackgroundMode;

  /// Check if app is running in foreground mode
  static bool get isForegroundMode => !_isBackgroundMode;

  /// Log current mode (for debugging)
  static void logCurrentMode() {
    _logger.d('Current mode: ${_isBackgroundMode ? "BACKGROUND" : "FOREGROUND"}');
  }

  /// Reset mode (for testing)
  static void resetForTesting() {
    _isBackgroundMode = false;
    _backgroundAccountId = null;
  }

  /// Set mode manually (for testing)
  static void setModeForTesting({required bool isBackground}) {
    _isBackgroundMode = isBackground;
  }
}
