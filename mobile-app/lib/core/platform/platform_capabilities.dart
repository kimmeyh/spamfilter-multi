/// What the code CAN do on the host platform (ADR-0049, F294).
///
/// Each getter is named for what it branches on, never for the device, and its
/// doc comment states the answer on Windows, Android and iOS. A declared
/// ADR-0042 platform exception is a getter here (or in [PlatformPolicy]) plus a
/// test of each answer.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'host_platform.dart';

export 'host_platform.dart' show HostPlatform;

/// How background scans are started without the app open.
enum BackgroundScanMechanism {
  /// Windows Task Scheduler launches the app per account (ADR-0039).
  taskScheduler,

  /// Android WorkManager periodic work plus the Doze alarm (F161, ADR-0042).
  workManager,

  /// No mechanism on this host (iOS until ADR-0050; macOS, Linux).
  none,
}

/// How Gmail sign-in runs.
enum GoogleSignInFlow {
  /// Android: native google_sign_in first, the browser flow if it fails.
  nativeWithBrowserFallback,

  /// iOS: native google_sign_in (unverified until ADR-0050).
  native,

  /// Windows, macOS, Linux: the browser with a loopback redirect and PKCE.
  browserLoopback,
}

/// Which injected OAuth client ID the Gmail flow uses on this host.
enum GmailOAuthClient { desktop, android, ios }

/// Where scan exports and YAML files are written.
enum ExportLocation {
  /// Windows: a folder under the user's Documents.
  documentsFolder,

  /// Android: shared storage through a document URI.
  sharedStorageDocumentUri,

  /// Not decided for this host (iOS until ADR-0050).
  undecided,
}

/// How a scan-complete notification is delivered.
enum NotificationDelivery {
  /// Android: the shared plugin with a notification channel and an HTML body.
  androidChannel,

  /// Windows: the shared plugin as a toast with a plain body.
  windowsToast,

  /// Not decided for this host (iOS until ADR-0050).
  undecided,
}

class PlatformCapabilities {
  /// Builds the capabilities of [host]. Tests may subclass to change one
  /// answer and install it with [debugOverride].
  const PlatformCapabilities(this.host);

  final HostPlatform host;

  static PlatformCapabilities? _override;

  /// The capabilities of the running host, or the test override.
  static PlatformCapabilities get current =>
      _override ?? PlatformCapabilities(detectHostPlatform());

  /// Test seam: set to a fixed host (`PlatformCapabilities(HostPlatform.android)`)
  /// or a subclass; set back to null in tearDown.
  @visibleForTesting
  static set debugOverride(PlatformCapabilities? value) => _override = value;

  bool get _isDesktop =>
      host == HostPlatform.windows ||
      host == HostPlatform.macos ||
      host == HostPlatform.linux;

  bool get _isMobile =>
      host == HostPlatform.android || host == HostPlatform.ios;

  /// Lower-case host name for records and log lines (`windows`, `android`, ...).
  String get hostName => host.name;

  /// SQLite goes through sqflite FFI. Windows: true. Android: false (native
  /// sqflite). iOS: false.
  bool get usesFfiSqlite => _isDesktop;

  /// The app has a desktop window: keyboard shortcuts such as Ctrl+Q and a
  /// programmatic quit. Windows: true. Android: false. iOS: false.
  bool get hasDesktopWindow => _isDesktop;

  /// A notification-area (system tray) icon is available. Windows: true.
  /// Android: false. iOS: false.
  bool get hasSystemTray => host == HostPlatform.windows;

  /// The install can be an MSIX package, and the data directory follows the
  /// packaged desktop layout (dev seeding, the Sprint 19 identity migration).
  /// Windows: true. Android: false. iOS: false.
  bool get canBeMsixPackaged => host == HostPlatform.windows;

  /// How background scans start. Windows: [BackgroundScanMechanism.taskScheduler].
  /// Android: [BackgroundScanMechanism.workManager]. iOS: none until ADR-0050.
  BackgroundScanMechanism get backgroundScanMechanism {
    switch (host) {
      case HostPlatform.windows:
        return BackgroundScanMechanism.taskScheduler;
      case HostPlatform.android:
        return BackgroundScanMechanism.workManager;
      case HostPlatform.ios:
      case HostPlatform.macos:
      case HostPlatform.linux:
      case HostPlatform.other:
        return BackgroundScanMechanism.none;
    }
  }

  /// A mail app's new-mail notification can start a scan (notification
  /// listener, F253 / ADR-0044). Android: true. Windows: false (declared
  /// exception). iOS: false until ADR-0050.
  bool get hasNewMailNotificationTrigger => host == HostPlatform.android;

  /// Open network connections are closed when the app goes to the background,
  /// so a running foreground scan must be failed (ADR-0042 Sprint 70
  /// exception). Android: true. Windows: false (minimizing closes nothing).
  /// iOS: true (assumed; ADR-0050).
  bool get socketsCloseWhenBackgrounded => _isMobile;

  /// The app draws under the status and navigation bars (edge-to-edge), so
  /// content needs the system insets. Android: true. Windows: false.
  /// iOS: false until ADR-0050 (SafeArea handles it differently).
  bool get drawsUnderSystemBars => host == HostPlatform.android;

  /// How Gmail sign-in runs. Android: native, then the browser.
  /// Windows: browser with a loopback redirect. iOS: native (ADR-0050).
  GoogleSignInFlow get googleSignInFlow {
    switch (host) {
      case HostPlatform.android:
        return GoogleSignInFlow.nativeWithBrowserFallback;
      case HostPlatform.ios:
        return GoogleSignInFlow.native;
      case HostPlatform.windows:
      case HostPlatform.macos:
      case HostPlatform.linux:
      case HostPlatform.other:
        return GoogleSignInFlow.browserLoopback;
    }
  }

  /// Native Google sign-in exists on this host. Android: true. iOS: true.
  /// Windows: false.
  bool get hasNativeGoogleSignIn => _isMobile;

  /// The browser OAuth flow redirects through a custom URL scheme rather than
  /// a loopback server. Android: true. iOS: true. Windows: false.
  bool get usesCustomSchemeOAuthRedirect => _isMobile;

  /// Which OAuth client ID applies. Windows: desktop. Android: android.
  /// iOS: ios.
  GmailOAuthClient get gmailOAuthClient {
    switch (host) {
      case HostPlatform.android:
        return GmailOAuthClient.android;
      case HostPlatform.ios:
        return GmailOAuthClient.ios;
      case HostPlatform.windows:
      case HostPlatform.macos:
      case HostPlatform.linux:
      case HostPlatform.other:
        return GmailOAuthClient.desktop;
    }
  }

  /// Gmail access is renewed from the stored refresh token without UI
  /// (Sprint 76). Android: true. Windows: false (Windows reuses the stored
  /// access token and its own refresh path). iOS: unknown until ADR-0050.
  bool get renewsGmailWithStoredRefreshToken => host == HostPlatform.android;

  /// A Gmail session starts from the stored access token of a prior browser
  /// sign-in. Windows: true. Android: false. iOS: false.
  bool get reusesStoredGmailAccessToken => host == HostPlatform.windows;

  /// A Gmail "insufficient scopes" error can be fixed by an interactive
  /// re-sign-in during the call. Windows: true. Android: false. iOS: false.
  bool get canUpgradeGmailScopesInteractively => host == HostPlatform.windows;

  /// Files are saved and picked through the system share / document sheet
  /// rather than a path the user types. Android: true. iOS: true.
  /// Windows: false.
  bool get usesSystemFileSheet => _isMobile;

  /// Where exports are written. Windows: Documents. Android: shared storage
  /// through a document URI. iOS: undecided (ADR-0050).
  ExportLocation get exportLocation {
    switch (host) {
      case HostPlatform.windows:
        return ExportLocation.documentsFolder;
      case HostPlatform.android:
        return ExportLocation.sharedStorageDocumentUri;
      case HostPlatform.ios:
      case HostPlatform.macos:
      case HostPlatform.linux:
      case HostPlatform.other:
        return ExportLocation.undecided;
    }
  }

  /// The OS has a per-app battery-optimization setting that limits background
  /// work (Doze, app standby), so Settings offers Battery > Unrestricted next
  /// to the background switch (F252). Android: true. Windows: false.
  /// iOS: false (no per-app equivalent; ADR-0050).
  bool get hasBatteryOptimizationSetting => host == HostPlatform.android;

  /// Notifications need a runtime permission request before the first one is
  /// shown. Android: true (Android 13+). Windows: false. iOS: true (assumed;
  /// ADR-0050).
  bool get requestsNotificationPermissionAtRuntime => _isMobile;

  /// How a scan-complete notification is shown. Windows:
  /// [NotificationDelivery.windowsToast]. Android:
  /// [NotificationDelivery.androidChannel]. iOS: undecided (ADR-0050).
  NotificationDelivery get notificationDelivery {
    switch (host) {
      case HostPlatform.windows:
        return NotificationDelivery.windowsToast;
      case HostPlatform.android:
        return NotificationDelivery.androidChannel;
      case HostPlatform.ios:
      case HostPlatform.macos:
      case HostPlatform.linux:
      case HostPlatform.other:
        return NotificationDelivery.undecided;
    }
  }

  /// The path separator used when a path is shown to the user.
  /// Windows: a backslash. Android: a slash. iOS: a slash.
  String get pathSeparator => host == HostPlatform.windows ? '\\' : '/';
}
