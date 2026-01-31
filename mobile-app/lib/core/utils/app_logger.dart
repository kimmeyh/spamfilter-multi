import 'package:logger/logger.dart';

/// Centralized logging utility with keyword prefixes for easy filtering in logcat
///
/// Use this instead of print() or direct Logger() calls to enable consistent
/// keyword-based filtering of logs in adb logcat and console output.
///
/// Keyword Prefixes:
/// - [EMAIL]: Email operations (fetch, parse, send)
/// - [RULES]: Rule loading and management
/// - [EVAL]: Rule evaluation and pattern matching
/// - [DB]: Database operations
/// - [AUTH]: Authentication and OAuth
/// - [SCAN]: Email scanning progress
/// - [ERROR]: Errors and exceptions
/// - [PERF]: Performance metrics
/// - [UI]: UI events and state changes
/// - [DEBUG]: General debug messages
///
/// Example Usage:
/// ```dart
/// AppLogger.email('Fetched 50 messages from INBOX for user@example.com');
/// AppLogger.rules('Loaded 250 rules from rules.yaml');
/// AppLogger.eval('Email from spam@example.com matched rule "SpamAutoDelete"');
/// AppLogger.error('Failed to delete email', error: e, stackTrace: st);
/// ```
///
/// Filtering in adb logcat:
/// ```bash
/// # Show only email operations
/// adb logcat -s flutter | grep '\[EMAIL\]'
///
/// # Show rules + evaluation
/// adb logcat -s flutter | grep -E '\[RULES\]|\[EVAL\]'
///
/// # Show only errors
/// adb logcat -s flutter | grep '\[ERROR\]'
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    printer: SimplePrinter(printTime: false),
  );

  /// Log email operations (fetching, parsing, sending)
  ///
  /// Example: `AppLogger.email('Fetched 50 messages from INBOX for user@gmail.com')`
  static void email(String message) {
    _logger.i('[EMAIL] $message');
  }

  /// Log rule operations (loading, saving, updating)
  ///
  /// Example: `AppLogger.rules('Loaded 250 rules from rules.yaml in 45ms')`
  static void rules(String message) {
    _logger.i('[RULES] $message');
  }

  /// Log rule evaluation and pattern matching
  ///
  /// Example: `AppLogger.eval('Email from spam@example.com matched rule "SpamAutoDelete" (pattern: @example\\.com)')`
  static void eval(String message) {
    _logger.d('[EVAL] $message');
  }

  /// Log database operations
  ///
  /// Example: `AppLogger.database('Migrated 250 rules to database')`
  static void database(String message) {
    _logger.i('[DB] $message');
  }

  /// Log authentication and OAuth operations
  ///
  /// Example: `AppLogger.auth('OAuth token refreshed for user@gmail.com')`
  static void auth(String message) {
    _logger.i('[AUTH] $message');
  }

  /// Log scanning progress and status
  ///
  /// Example: `AppLogger.scan('Processing email 50/150 (33%)')`
  static void scan(String message) {
    _logger.i('[SCAN] $message');
  }

  /// Log errors with optional error object and stack trace
  ///
  /// Example: `AppLogger.error('Failed to delete email: IMAP connection lost', error: e, stackTrace: st)`
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e('[ERROR] $message', error: error, stackTrace: stackTrace);
  }

  /// Log performance metrics and timing
  ///
  /// Example: `AppLogger.perf('Rule evaluation completed: 150 emails in 8.5s (57ms/email)')`
  static void perf(String message) {
    _logger.i('[PERF] $message');
  }

  /// Log UI events (verbose, primarily for debugging UI state)
  ///
  /// Example: `AppLogger.ui('User clicked Start Scan button')`
  static void ui(String message) {
    _logger.d('[UI] $message');
  }

  /// General debug messages
  ///
  /// Example: `AppLogger.debug('Initializing email scanner with folder: INBOX')`
  static void debug(String message) {
    _logger.d('[DEBUG] $message');
  }

  /// Log informational messages (use specific methods above when possible)
  ///
  /// Example: `AppLogger.info('App initialized successfully')`
  static void info(String message) {
    _logger.i('[INFO] $message');
  }

  /// Log warnings
  ///
  /// Example: `AppLogger.warning('Rule "OldPattern" uses deprecated wildcard syntax')`
  static void warning(String message) {
    _logger.w('[WARNING] $message');
  }
}
