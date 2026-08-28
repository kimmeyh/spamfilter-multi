import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GP-2 policy gate (Sprint 64, Issue #373; executes ADR-0027 Option B).
///
/// Release signing is BUILD-TIME INJECTED: the keystore and the signing JSON
/// live outside the repository, gradle reads four -P properties (env-var
/// fallback), and a Release task without them must fail loudly instead of
/// silently debug-signing (the pre-GP-2 state shipped debug-signed release
/// builds). These tests pin the source wiring; the signed artifact itself is
/// verified at the release-chain validation (fingerprint check).
void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('gradle sources all four signing parameters by property name', () {
    for (final prop in [
      'androidKeystorePath',
      'androidKeystorePassword',
      'androidKeyAlias',
      'androidKeyPassword',
    ]) {
      expect(gradle, contains(prop),
          reason: 'build.gradle.kts must read the $prop gradle property');
    }
  });

  test('a release build without signing parameters fails loudly', () {
    expect(gradle, contains('GP-2: release signing parameters are missing'),
        reason: 'the GradleException loud-fail must name the missing '
            'parameters and the supplying script');
    expect(gradle, isNot(contains('TODO: Add your own signing config')),
        reason: 'the pre-GP-2 debug-signing TODO must be gone');
  });

  test('no keystore or signing JSON is tracked anywhere in the repository', () {
    final tracked = Process.runSync('git', ['ls-files'], workingDirectory: '..')
        .stdout
        .toString()
        .split('\n');
    final offenders = tracked.where((f) =>
        f.endsWith('.jks') ||
        f.endsWith('.keystore') ||
        f.endsWith('android-signing.json'));
    expect(offenders, isEmpty,
        reason: 'signing material must never be committed (ADR-0027)');
  });

  test('.gitignore bans keystore files and the signing JSON', () {
    final gitignore = File('../.gitignore').readAsStringSync();
    for (final rule in ['*.jks', '*.keystore', 'android-signing.json']) {
      expect(gitignore, contains(rule),
          reason: '.gitignore must carry the $rule rule');
    }
  });
}
