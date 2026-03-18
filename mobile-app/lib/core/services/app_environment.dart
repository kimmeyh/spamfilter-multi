/// Application environment configuration.
///
/// Reads APP_ENV from --dart-define at build time to determine whether
/// the app is running in production or development mode. This enables
/// side-by-side operation of production and development builds on the
/// same machine per ADR-0035.
///
/// Usage:
///   flutter build windows --dart-define=APP_ENV=prod
///   flutter run -d windows --dart-define=APP_ENV=dev
///
/// Default: dev (development mode)
library;

/// Application environment singleton
class AppEnvironment {
  static const String _envKey = 'APP_ENV';
  static const String _defaultEnv = 'dev';

  /// The current environment, read from --dart-define=APP_ENV
  static const String current = String.fromEnvironment(
    _envKey,
    defaultValue: _defaultEnv,
  );

  /// Whether the app is running in development mode
  static bool get isDev => current == 'dev';

  /// Whether the app is running in production mode
  static bool get isProd => current == 'prod';

  /// Display suffix for window title and About screen
  /// Returns ' [DEV]' for dev, empty string for prod
  static String get displaySuffix => isDev ? ' [DEV]' : '';

  /// Data directory suffix appended to the base app data path
  /// Returns '_Dev' for dev, empty string for prod
  static String get dataDirSuffix => isDev ? '_Dev' : '';

  /// Task Scheduler task name suffix
  /// Returns '_Dev' for dev, empty string for prod
  static String get taskNameSuffix => isDev ? '_Dev' : '';

  /// Background scan log file prefix
  /// Returns 'dev_' for dev, empty string for prod
  static String get logPrefix => isDev ? 'dev_' : '';

  /// Mutex name for single-instance enforcement
  static String get mutexName => 'Global\\MyEmailSpamFilter_${isDev ? 'Development' : 'Production'}';

  /// Full display name for window title
  /// e.g., 'MyEmailSpamFilter [DEV]' or 'MyEmailSpamFilter'
  static String get windowTitle => 'MyEmailSpamFilter$displaySuffix';

  /// Environment description for logging
  static String get description => isProd ? 'Production' : 'Development';
}
