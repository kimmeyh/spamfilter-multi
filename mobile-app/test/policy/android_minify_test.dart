import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GP-9 policy gate (Sprint 64, Issue #374): R8/ProGuard + Dart obfuscation.
///
/// No Dart test can see minification itself -- R8 runs on the Kotlin/Java
/// side of the Android build, entirely outside the Dart test runner, and
/// Dart obfuscation only affects the compiled release artifact. These tests
/// pin the SOURCE WIRING (the release buildType enables R8, proguard-rules.pro
/// exists with reasoned keep rules) as a regression guard. The BEHAVIOR proof
/// -- that the minified/obfuscated build actually compiles, runs, and every
/// app surface still works -- is the release-chain validation recorded in
/// docs/sprints/SPRINT_64_PLAN.md Task 7 (GP-9) and the sprint's Manual
/// Validation, not this test.
void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('release buildType enables R8 minification and resource shrinking',
      () {
    expect(gradle, contains('isMinifyEnabled = true'),
        reason: 'GP-9: release builds must enable R8 code shrinking');
    expect(gradle, contains('isShrinkResources = true'),
        reason: 'GP-9: release builds must enable resource shrinking');
    expect(gradle, contains('proguard-rules.pro'),
        reason: 'GP-9: release buildType must reference proguard-rules.pro');
  });

  test('proguard-rules.pro exists with reasoned keep rules', () {
    final file = File('android/app/proguard-rules.pro');
    expect(file.existsSync(), isTrue,
        reason: 'GP-9: android/app/proguard-rules.pro must exist');
    final content = file.readAsStringSync();
    expect(content, contains('-keep'),
        reason: 'GP-9: proguard-rules.pro must contain at least one keep '
            'rule (the WorkManager reflection-instantiation gap)');
  });

  test('build-with-secrets.ps1 wires Dart obfuscation into the release path',
      () {
    final script =
        File('scripts/build-with-secrets.ps1').readAsStringSync();
    expect(script, contains('--obfuscate'),
        reason: 'GP-9: release builds must pass --obfuscate');
    expect(script, contains('--split-debug-info='),
        reason: 'GP-9: release builds must pass --split-debug-info=<dir>');
    expect(script, contains('.myemailspamfilter\\symbols'),
        reason: 'GP-9: symbol files must be written outside the repository');
  });
}
