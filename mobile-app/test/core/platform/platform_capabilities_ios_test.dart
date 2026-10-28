import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/platform/host_platform.dart';
import 'package:my_email_spam_filter/core/platform/platform_capabilities.dart';
import 'package:my_email_spam_filter/core/platform/platform_policy.dart';

/// Sprint 81 Task 3 (F67b, R-7): every [PlatformCapabilities] and
/// [PlatformPolicy] member is evaluated with the host set to iOS through the
/// `debugOverride` seams, and the test fails when a member throws, still
/// returns a placeholder (`undecided`, `none`), or still carries an
/// "until ADR-0050" or "(assumed" note in its doc comment (ADR-0050 supplied
/// those answers).
///
/// A completeness check reads the two source files and fails when a public
/// getter exists that this file does not evaluate, so a new member cannot ship
/// without an iOS answer being looked at here.
///
/// **What this does NOT catch.** It proves the iOS ANSWER is decided and
/// matches ADR-0050, not that the answer is TRUE on a device: the members the
/// ADR marks unverified (`renewsGmailWithStoredRefreshToken`,
/// `drawsUnderSystemBars`, Files app visibility of the export folder) are
/// pinned to their safe answers here and settle only on a real iPhone (F67c).
/// It also does not prove a call site asks the right getter, and it does not
/// compile or run any Swift.
void main() {
  tearDown(() {
    PlatformCapabilities.debugOverride = null;
    PlatformPolicy.debugOverride = null;
  });

  /// Every public [PlatformCapabilities] member, evaluated on the iOS host
  /// that is installed as `PlatformCapabilities.current`.
  final Map<String, Object? Function(PlatformCapabilities)> members = {
    'host': (c) => c.host,
    'hostName': (c) => c.hostName,
    'usesFfiSqlite': (c) => c.usesFfiSqlite,
    'hasDesktopWindow': (c) => c.hasDesktopWindow,
    'hasSystemTray': (c) => c.hasSystemTray,
    'canBeMsixPackaged': (c) => c.canBeMsixPackaged,
    'backgroundScanMechanism': (c) => c.backgroundScanMechanism,
    'hasNewMailNotificationTrigger': (c) => c.hasNewMailNotificationTrigger,
    'socketsCloseWhenBackgrounded': (c) => c.socketsCloseWhenBackgrounded,
    'drawsUnderSystemBars': (c) => c.drawsUnderSystemBars,
    'googleSignInFlow': (c) => c.googleSignInFlow,
    'hasNativeGoogleSignIn': (c) => c.hasNativeGoogleSignIn,
    'usesCustomSchemeOAuthRedirect': (c) => c.usesCustomSchemeOAuthRedirect,
    'gmailOAuthClient': (c) => c.gmailOAuthClient,
    'renewsGmailWithStoredRefreshToken': (c) =>
        c.renewsGmailWithStoredRefreshToken,
    'reusesStoredGmailAccessToken': (c) => c.reusesStoredGmailAccessToken,
    'canUpgradeGmailScopesInteractively': (c) =>
        c.canUpgradeGmailScopesInteractively,
    'usesSystemFileSheet': (c) => c.usesSystemFileSheet,
    'exportLocation': (c) => c.exportLocation,
    'hasBatteryOptimizationSetting': (c) => c.hasBatteryOptimizationSetting,
    'requestsNotificationPermissionAtRuntime': (c) =>
        c.requestsNotificationPermissionAtRuntime,
    'notificationDelivery': (c) => c.notificationDelivery,
    'pathSeparator': (c) => c.pathSeparator,
  };

  /// The ADR-0050 answer for each iOS member.
  const expected = <String, Object?>{
    'host': HostPlatform.ios,
    'hostName': 'ios',
    'usesFfiSqlite': false,
    'hasDesktopWindow': false,
    'hasSystemTray': false,
    'canBeMsixPackaged': false,
    'backgroundScanMechanism': BackgroundScanMechanism.bgAppRefresh,
    'hasNewMailNotificationTrigger': false,
    'socketsCloseWhenBackgrounded': true,
    'drawsUnderSystemBars': false,
    'googleSignInFlow': GoogleSignInFlow.native,
    'hasNativeGoogleSignIn': true,
    'usesCustomSchemeOAuthRedirect': true,
    'gmailOAuthClient': GmailOAuthClient.ios,
    'renewsGmailWithStoredRefreshToken': false,
    'reusesStoredGmailAccessToken': false,
    'canUpgradeGmailScopesInteractively': false,
    'usesSystemFileSheet': true,
    'exportLocation': ExportLocation.appDocumentsInFilesApp,
    'hasBatteryOptimizationSetting': false,
    'requestsNotificationPermissionAtRuntime': true,
    'notificationDelivery': NotificationDelivery.iosAlert,
    'pathSeparator': '/',
  };

  /// Enum values that mean "no answer for this host".
  bool isPlaceholder(Object? v) =>
      v == BackgroundScanMechanism.none ||
      v == ExportLocation.undecided ||
      v == NotificationDelivery.undecided;

  /// Public getter names declared in [source] (a class body line such as
  /// `  bool get usesFfiSqlite => ...` or `  Foo get bar {`), excluding
  /// private names and the static `current`.
  Set<String> publicGetters(String source) {
    final re = RegExp(r'^  (?!static )[\w<>?]+ get ([a-zA-Z]\w*)\b',
        multiLine: true);
    return {for (final m in re.allMatches(source)) m.group(1)!};
  }

  group('every PlatformCapabilities member on iOS', () {
    test('none throws, none is a placeholder, each matches ADR-0050', () {
      PlatformCapabilities.debugOverride =
          const PlatformCapabilities(HostPlatform.ios);
      final c = PlatformCapabilities.current;
      expect(c.host, HostPlatform.ios,
          reason: 'the override must reach PlatformCapabilities.current');

      final problems = <String>[];
      for (final entry in members.entries) {
        final Object? value;
        try {
          value = entry.value(c);
        } catch (e) {
          problems.add('${entry.key} threw $e');
          continue;
        }
        if (isPlaceholder(value)) {
          problems.add('${entry.key} is still the placeholder $value');
        }
        if (value != expected[entry.key]) {
          problems.add('${entry.key} is $value, ADR-0050 says '
              '${expected[entry.key]}');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('the member map covers every public getter in the source', () {
      final source =
          File('lib/core/platform/platform_capabilities.dart')
              .readAsStringSync();
      // `host` is a final field, not a getter, so the scan cannot see it.
      final declared = {...publicGetters(source), 'host'};
      expect(declared, isNotEmpty,
          reason: 'the getter scan matched nothing, so it would be vacuous');
      expect(members.keys.toSet(), declared,
          reason: 'add the new member to `members` and `expected`, with its '
              'ADR-0050 iOS answer');
      expect(expected.keys.toSet(), declared);
    });

    test('no doc comment still says "until ADR-0050" or "(assumed"', () {
      final source =
          File('lib/core/platform/platform_capabilities.dart')
              .readAsStringSync();
      expect(source, isNot(contains('until ADR-0050')));
      expect(source, isNot(contains('(assumed')));
    });
  });

  group('every PlatformPolicy member on iOS', () {
    test('none throws and iOS uses neither flat surfaces nor an Exit button',
        () {
      PlatformPolicy.debugOverride = const PlatformPolicy(HostPlatform.ios);
      final p = PlatformPolicy.current;
      expect(p.host, HostPlatform.ios);
      expect(p.prefersFlatSurfaces, isFalse);
      expect(p.showsExitButton, isFalse);

      final source =
          File('lib/core/platform/platform_policy.dart').readAsStringSync();
      expect(publicGetters(source), {'prefersFlatSurfaces', 'showsExitButton'},
          reason: 'a new PlatformPolicy member needs an iOS check here');
    });
  });
}
