import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sprint 77 R76-1 (Issue #464, Harold Q15 = 1): the debug-build-only mail
/// notification poster (`com.android.shell`, used by `adb shell cmd
/// notification post` on the emulator) must NEVER be accepted by a release
/// build.
///
/// SOURCE-TEXT VERIFIED. The behavior of the policy is pinned by the JVM test
/// `MailNotificationPolicyTest` (run: `gradlew :app:testDevDebugUnitTest` from
/// mobile-app/android). That test cannot see the CALL SITE, so this gate pins
/// the wiring: the listener hands `BuildConfig.DEBUG` to the policy, never a
/// literal, and the release list never names a debug package.
///
/// What this does NOT catch: a release APK that was built with a changed
/// BuildConfig (for example a custom build type that sets debug = true), or a
/// new debug package added to the wrong set under a name this test does not
/// know. The inspection of a built release APK is the stronger check.
void main() {
  const dir = 'android/app/src/main/kotlin/com/myemailspamfilter';
  final policy = File('$dir/MailNotificationPolicy.kt').readAsStringSync();
  final listener = File('$dir/MailNotificationListener.kt').readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  String block(String source, String startMarker) {
    final start = source.indexOf(startMarker);
    expect(start, greaterThanOrEqualTo(0), reason: 'missing "$startMarker"');
    final end = source.indexOf(')', start);
    return source.substring(start, end);
  }

  test('the release allowlist block does not name any debug-only package', () {
    final releaseBlock = block(policy, 'val MAIL_APP_PACKAGES');
    final debugBlock = block(policy, 'val DEBUG_ONLY_PACKAGES');
    final debugPackages = RegExp(r'"([a-z0-9_.]+)"')
        .allMatches(debugBlock)
        .map((m) => m.group(1)!)
        .toList();
    expect(debugPackages, isNotEmpty);
    for (final p in debugPackages) {
      expect(releaseBlock, isNot(contains('"$p"')),
          reason: '$p is debug-only and must not be in MAIL_APP_PACKAGES');
    }
  });

  test('the listener passes BuildConfig.DEBUG, never a literal, to the policy',
      () {
    expect(listener, contains('debugBuild = BuildConfig.DEBUG'));
    expect(listener, isNot(contains('debugBuild = true')));
  });

  test('the policy defaults to the RELEASE allowlist', () {
    expect(policy, contains('debugBuild: Boolean = false'));
    expect(policy, contains('if (debugBuild) MAIL_APP_PACKAGES + DEBUG_ONLY_PACKAGES'));
  });

  test('BuildConfig generation is enabled so BuildConfig.DEBUG compiles', () {
    expect(gradle, contains('buildConfig = true'));
  });
}
