import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sprint 77 R76-1 (Issue #464, Harold Q15 = 1): the debug-build-only mail
/// notification poster (`com.android.shell`, used by `adb shell cmd
/// notification post` on the emulator) must NEVER be accepted by a release
/// build.
///
/// SOURCE-TEXT VERIFIED: what would settle the behavior is inspecting a built
/// RELEASE APK's notification handling on a device. The behavior of the policy is pinned by the JVM test
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

  // A table is `private val NAME: Map<...> = mapOf(` ... a line holding only
  // `    )`. Ending at the first ')' (the original form) stops inside the first
  // `setOf(...)` since F264 turned the lists into package -> provider maps.
  String block(String source, String startMarker) {
    final start = source.indexOf(startMarker);
    expect(start, greaterThanOrEqualTo(0), reason: 'missing "$startMarker"');
    final end = source.indexOf(RegExp(r'\n\s*\)\s*\n'), start);
    expect(end, greaterThan(start), reason: 'no closing line for "$startMarker"');
    return source.substring(start, end);
  }

  test('the release allowlist block does not name any debug-only package', () {
    final releaseBlock = block(policy, 'private val MAIL_APPS');
    final debugBlock = block(policy, 'private val DEBUG_ONLY_APPS');
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
    // Lead merge (Sprint 77): the PROVIDER mapping is the second wiring point
    // -- a literal there would map the debug poster to accounts in release.
    // Sprint 77 F-PRECHECK: both wiring points now live in
    // MailNotificationPolicy.decide(), which the listener calls with
    // BuildConfig.DEBUG; decide() hands that SAME flag to the mapping and to
    // the allowlist check, never a literal.
    expect(listener, contains('MailNotificationPolicy.decide('));
    expect(policy, contains('val providers = encodeProviders(packageName, debugBuild)'));
    expect(policy, contains('            debugBuild = debugBuild,\n        )'));
  });

  test('the policy defaults to the RELEASE allowlist', () {
    expect(policy, contains('debugBuild: Boolean = false'));
    expect(policy, contains('if (debugBuild) MAIL_APP_PACKAGES + DEBUG_ONLY_PACKAGES'));
  });

  test('BuildConfig generation is enabled so BuildConfig.DEBUG compiles', () {
    expect(gradle, contains('buildConfig = true'));
  });
}
