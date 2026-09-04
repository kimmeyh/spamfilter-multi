import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SEC-4 policy gate (Sprint 64, Issue #377).
///
/// Cleartext traffic is disabled app-wide via network_security_config.xml,
/// making the TLS-only policy explicit and visible to Play reviewers.
/// This gate asserts the config file exists and is referenced from the manifest.
///
/// Merged-manifest proof (live verification that the setting is actually
/// effective on the built APK/AAB) is part of chain validation, not unit test --
/// it is confirmed in the release-build test plan.
void main() {
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  final configFile = File('android/app/src/main/res/xml/network_security_config.xml');

  test('network_security_config.xml exists', () {
    expect(configFile.existsSync(), isTrue,
        reason: 'SEC-4: network_security_config.xml must be present in '
            'android/app/src/main/res/xml/');
  });

  test('network_security_config.xml contains cleartextTrafficPermitted="false"', () {
    final content = configFile.readAsStringSync();
    expect(content, contains('cleartextTrafficPermitted="false"'),
        reason: 'network_security_config.xml must disable cleartext traffic app-wide');
  });

  test(
      'config has the RUNTIME-valid app-wide structure: '
      'network-security-config root with a base-config child', () {
    // Chain-validation lesson (2026-08-28): a domain-config ROOT passed AAPT
    // (well-formedness only) but crashed the app at startup -- Android's
    // runtime schema parser rejects it, and even parseable domain-config
    // scoping would apply the policy to one domain instead of app-wide. The
    // attribute grep above proves the SETTING exists; this test pins the
    // STRUCTURE that makes it valid and app-wide. Live startup on a release
    // build remains the behavior proof (source gates verify shape).
    final content = configFile.readAsStringSync();
    final stripped =
        content.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    expect(stripped, contains('<network-security-config>'),
        reason: 'root element must be network-security-config');
    expect(stripped, contains('<base-config cleartextTrafficPermitted="false"'),
        reason: 'app-wide policy lives on base-config, not domain-config');
    expect(stripped, isNot(contains('<domain-config')),
        reason: 'no domain-scoped carve-outs are expected in this app');
  });

  test('AndroidManifest.xml references @xml/network_security_config', () {
    final manifest = manifestFile.readAsStringSync();
    expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'),
        reason: 'application element must reference the network security config');
  });
}
