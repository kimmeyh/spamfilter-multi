import 'package:logger/logger.dart';

/// Service for detecting and managing background execution mode
///
/// Handles parsing of command-line arguments to detect if the app
/// is launched in background scanning mode (via Task Scheduler).
class BackgroundModeService {
  static final Logger _logger = Logger();

  /// Flag indicating if app is running in background mode
  static bool _isBackgroundMode = false;

  /// Launch flag for background scanning
  static const String backgroundScanFlag = '--background-scan';

  /// Initialize background mode detection
  ///
  /// Parses command-line arguments to check for background scan flag
  /// Should be called early in app initialization (main.dart)
  static void initialize(List<String> args) {
    _logger.i('Initializing background mode service with args: $args');

    // Check if background scan flag is present
    _isBackgroundMode = args.contains(backgroundScanFlag);

    if (_isBackgroundMode) {
      _logger.i('*** BACKGROUND MODE DETECTED ***');
    } else {
      _logger.i('Running in normal (foreground) mode');
    }
  }

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
  }

  /// Set mode manually (for testing)
  static void setModeForTesting({required bool isBackground}) {
    _isBackgroundMode = isBackground;
  }
}
