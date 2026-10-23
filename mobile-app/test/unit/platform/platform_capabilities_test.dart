import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/platform/host_platform.dart';
import 'package:my_email_spam_filter/core/platform/platform_capabilities.dart';
import 'package:my_email_spam_filter/core/platform/platform_policy.dart';

/// ADR-0049 (Sprint 80, F294): every getter of [PlatformCapabilities] and
/// [PlatformPolicy] is asserted for Windows, Android and iOS, matching the
/// answers in its doc comment. An ADR-0042 platform exception is a getter plus
/// a test of each answer; this file is that test.
///
/// **What this does NOT catch.** It proves each getter's ANSWER, not that a
/// call site asks the right getter: a site wired to the wrong getter still
/// passes here, and is caught only by the behavior tests of that site (for
/// example the F220 lifecycle, F209 inset and scan-complete notifier tests,
/// which run both branches through `debugOverride`). The iOS answers are
/// assumptions until ADR-0050 and are pinned here so a change is deliberate.
/// It does not exercise `detectHostPlatform()` on a real Android or iOS device.
void main() {
  const windows = PlatformCapabilities(HostPlatform.windows);
  const android = PlatformCapabilities(HostPlatform.android);
  const ios = PlatformCapabilities(HostPlatform.ios);

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
    PlatformPolicy.debugOverride = null;
  });

  group('PlatformCapabilities: Windows', () {
    test('desktop answers', () {
      expect(windows.hostName, 'windows');
      expect(windows.usesFfiSqlite, isTrue);
      expect(windows.hasDesktopWindow, isTrue);
      expect(windows.hasSystemTray, isTrue);
      expect(windows.canBeMsixPackaged, isTrue);
      expect(windows.backgroundScanMechanism,
          BackgroundScanMechanism.taskScheduler);
      expect(windows.hasNewMailNotificationTrigger, isFalse);
      expect(windows.socketsCloseWhenBackgrounded, isFalse);
      expect(windows.drawsUnderSystemBars, isFalse);
      expect(windows.googleSignInFlow, GoogleSignInFlow.browserLoopback);
      expect(windows.hasNativeGoogleSignIn, isFalse);
      expect(windows.usesCustomSchemeOAuthRedirect, isFalse);
      expect(windows.gmailOAuthClient, GmailOAuthClient.desktop);
      expect(windows.renewsGmailWithStoredRefreshToken, isFalse);
      expect(windows.reusesStoredGmailAccessToken, isTrue);
      expect(windows.canUpgradeGmailScopesInteractively, isTrue);
      expect(windows.usesSystemFileSheet, isFalse);
      expect(windows.exportLocation, ExportLocation.documentsFolder);
      expect(windows.hasBatteryOptimizationSetting, isFalse);
      expect(windows.requestsNotificationPermissionAtRuntime, isFalse);
      expect(windows.notificationDelivery, NotificationDelivery.windowsToast);
      expect(windows.pathSeparator, r'\');
    });
  });

  group('PlatformCapabilities: Android', () {
    test('mobile answers', () {
      expect(android.hostName, 'android');
      expect(android.usesFfiSqlite, isFalse);
      expect(android.hasDesktopWindow, isFalse);
      expect(android.hasSystemTray, isFalse);
      expect(android.canBeMsixPackaged, isFalse);
      expect(android.backgroundScanMechanism,
          BackgroundScanMechanism.workManager);
      expect(android.hasNewMailNotificationTrigger, isTrue);
      expect(android.socketsCloseWhenBackgrounded, isTrue);
      expect(android.drawsUnderSystemBars, isTrue);
      expect(android.googleSignInFlow,
          GoogleSignInFlow.nativeWithBrowserFallback);
      expect(android.hasNativeGoogleSignIn, isTrue);
      expect(android.usesCustomSchemeOAuthRedirect, isTrue);
      expect(android.gmailOAuthClient, GmailOAuthClient.android);
      expect(android.renewsGmailWithStoredRefreshToken, isTrue);
      expect(android.reusesStoredGmailAccessToken, isFalse);
      expect(android.canUpgradeGmailScopesInteractively, isFalse);
      expect(android.usesSystemFileSheet, isTrue);
      expect(android.exportLocation, ExportLocation.sharedStorageDocumentUri);
      expect(android.hasBatteryOptimizationSetting, isTrue);
      expect(android.requestsNotificationPermissionAtRuntime, isTrue);
      expect(android.notificationDelivery, NotificationDelivery.androidChannel);
      expect(android.pathSeparator, '/');
    });
  });

  group('PlatformCapabilities: iOS (assumed until ADR-0050)', () {
    test('answers', () {
      expect(ios.hostName, 'ios');
      expect(ios.usesFfiSqlite, isFalse);
      expect(ios.hasDesktopWindow, isFalse);
      expect(ios.hasSystemTray, isFalse);
      expect(ios.canBeMsixPackaged, isFalse);
      expect(ios.backgroundScanMechanism, BackgroundScanMechanism.none);
      expect(ios.hasNewMailNotificationTrigger, isFalse);
      expect(ios.socketsCloseWhenBackgrounded, isTrue);
      expect(ios.drawsUnderSystemBars, isFalse);
      expect(ios.googleSignInFlow, GoogleSignInFlow.native);
      expect(ios.hasNativeGoogleSignIn, isTrue);
      expect(ios.usesCustomSchemeOAuthRedirect, isTrue);
      expect(ios.gmailOAuthClient, GmailOAuthClient.ios);
      expect(ios.renewsGmailWithStoredRefreshToken, isFalse);
      expect(ios.reusesStoredGmailAccessToken, isFalse);
      expect(ios.canUpgradeGmailScopesInteractively, isFalse);
      expect(ios.usesSystemFileSheet, isTrue);
      expect(ios.exportLocation, ExportLocation.undecided);
      expect(ios.hasBatteryOptimizationSetting, isFalse);
      expect(ios.requestsNotificationPermissionAtRuntime, isTrue);
      expect(ios.notificationDelivery, NotificationDelivery.undecided);
      expect(ios.pathSeparator, '/');
    });
  });

  group('PlatformCapabilities: other desktop hosts follow the desktop rules',
      () {
    test('macOS and Linux are desktop with no scheduler', () {
      for (final host in [HostPlatform.macos, HostPlatform.linux]) {
        final c = PlatformCapabilities(host);
        expect(c.usesFfiSqlite, isTrue, reason: host.name);
        expect(c.hasDesktopWindow, isTrue, reason: host.name);
        expect(c.hasSystemTray, isFalse, reason: host.name);
        expect(c.backgroundScanMechanism, BackgroundScanMechanism.none,
            reason: host.name);
        expect(c.googleSignInFlow, GoogleSignInFlow.browserLoopback,
            reason: host.name);
      }
    });
  });

  group('PlatformPolicy', () {
    test('Windows prefers flat surfaces and shows the Exit button', () {
      const p = PlatformPolicy(HostPlatform.windows);
      expect(p.prefersFlatSurfaces, isTrue);
      expect(p.showsExitButton, isTrue);
    });

    test('Android uses Material 3 surfaces and no Exit button', () {
      const p = PlatformPolicy(HostPlatform.android);
      expect(p.prefersFlatSurfaces, isFalse);
      expect(p.showsExitButton, isFalse);
    });

    test('iOS uses neither', () {
      const p = PlatformPolicy(HostPlatform.ios);
      expect(p.prefersFlatSurfaces, isFalse);
      expect(p.showsExitButton, isFalse);
    });
  });

  group('the test seam', () {
    test('current is the detected host until an override is set', () {
      expect(PlatformCapabilities.current.host, detectHostPlatform());
      expect(PlatformPolicy.current.host, detectHostPlatform());
    });

    test('debugOverride replaces current and null resets it', () {
      PlatformCapabilities.debugOverride = android;
      PlatformPolicy.debugOverride =
          const PlatformPolicy(HostPlatform.android);
      expect(PlatformCapabilities.current.hasNewMailNotificationTrigger,
          isTrue);
      expect(PlatformPolicy.current.showsExitButton, isFalse);

      PlatformCapabilities.debugOverride = null;
      PlatformPolicy.debugOverride = null;
      expect(PlatformCapabilities.current.host, detectHostPlatform());
      expect(PlatformPolicy.current.host, detectHostPlatform());
    });

    test('a subclass can change one answer and keep the rest', () {
      PlatformCapabilities.debugOverride = _NoTray();
      expect(PlatformCapabilities.current.hasSystemTray, isFalse);
      expect(PlatformCapabilities.current.hasDesktopWindow, isTrue);
    });
  });
}

class _NoTray extends PlatformCapabilities {
  const _NoTray() : super(HostPlatform.windows);

  @override
  bool get hasSystemTray => false;
}
