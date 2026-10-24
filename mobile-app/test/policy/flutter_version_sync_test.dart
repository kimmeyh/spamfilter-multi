// F296 / Sprint 80 (GitHub #495) -- Flutter SDK version sync gate.
//
// WHY: CI used to pin its own Flutter version (`flutter-version: '3.38.5'`
// in .github/workflows/ci.yml) while local development ran a newer SDK
// (3.47.4). A CI-only analyze or test failure could then appear that no local
// run reproduced, and the reverse. The fix records the version in ONE file,
// the repo-root `.fvmrc` (`{"flutter": "3.47.4"}`). CI reads it through
// `subosito/flutter-action` with `flutter-version-file: .fvmrc`. This test is
// the drift alarm: it FAILS when the recorded version, the CI wiring, or the
// SDK that runs the test stop agreeing.
//
// Checks:
//   (a) .fvmrc exists, is JSON, and its `flutter` key is an exact X.Y.Z.
//   (b) ci.yml AND ios.yml (Sprint 81) have no literal `flutter-version:` key,
//       and every subosito/flutter-action step uses
//       `flutter-version-file: .fvmrc` (the two counts must be equal and at
//       least 1 per file).
//   (c) the SDK running this test (FLUTTER_ROOT) reports the same version as
//       .fvmrc. A missing FLUTTER_ROOT FAILS (it does not skip silently).
//
// What this does NOT catch:
//   - A CI runner that resolves a different SDK than the one the action
//     downloads. Check (b) proves the wiring text, not the downloaded binary.
//   - A workflow file that moves the action into a different file, or into
//     a composite action under .github/actions/. Only ci.yml is scanned.
//   - A stale FLUTTER_ROOT from a different install that a developer runs
//     `flutter test` from. Check (c) compares against the SDK that is actually
//     running, which is the intended target.
//   - A NEW workflow file that sets up Flutter but is not listed in
//     `_workflowPaths`. Add it there when it is created.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repo root, relative to mobile-app/ (the working directory for `flutter test`).
const _fvmrcPath = '../.fvmrc';

/// Every workflow that sets up Flutter. ios.yml joined in Sprint 81 (F67b).
const _workflowPaths = [
  '../.github/workflows/ci.yml',
  '../.github/workflows/ios.yml',
];

final _exactVersion = RegExp(r'^\d+\.\d+\.\d+$');

/// Reads the `flutter` key from .fvmrc. Fails the test with a clear reason on
/// a missing file, bad JSON, a missing key, or a non-exact version.
String _fvmrcVersion() {
  final file = File(_fvmrcPath);
  if (!file.existsSync()) {
    fail('.fvmrc is missing at the repo root ($_fvmrcPath). It is the single '
        'source of the CI Flutter version (F296).');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    fail('.fvmrc is not valid JSON: $e');
  }
  if (decoded is! Map || decoded['flutter'] is! String) {
    fail('.fvmrc must be a JSON object with a string "flutter" key, e.g. '
        '{"flutter": "3.47.4"}.');
  }
  final version = (decoded['flutter'] as String).trim();
  if (!_exactVersion.hasMatch(version)) {
    fail('.fvmrc "flutter" must be an exact X.Y.Z version, found "$version".');
  }
  return version;
}

/// The version of the SDK running this test. Prefers
/// `<FLUTTER_ROOT>/bin/cache/flutter.version.json` ("frameworkVersion") and
/// falls back to `<FLUTTER_ROOT>/version` when that file is absent.
String _localSdkVersion() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.trim().isEmpty) {
    fail('FLUTTER_ROOT is not set in the test environment, so the local SDK '
        'version cannot be checked against .fvmrc. Run the tests through the '
        'Flutter SDK that matches .fvmrc (flutter test) so that FLUTTER_ROOT is '
        'exported. This is a failure, not a skip (F296).');
  }
  final jsonFile = File('$root/bin/cache/flutter.version.json');
  if (jsonFile.existsSync()) {
    final decoded = jsonDecode(jsonFile.readAsStringSync());
    if (decoded is Map && decoded['frameworkVersion'] is String) {
      return (decoded['frameworkVersion'] as String).trim();
    }
    fail('${jsonFile.path} has no string "frameworkVersion" key.');
  }
  final versionFile = File('$root/version');
  if (versionFile.existsSync()) {
    return versionFile.readAsStringSync().trim();
  }
  fail('Neither ${jsonFile.path} nor $root/version exists, so the local SDK '
      'version is unknown.');
}

void main() {
  group('Flutter SDK version sync (F296, Sprint 80)', () {
    test('(a) .fvmrc exists and records an exact X.Y.Z Flutter version', () {
      final version = _fvmrcVersion();
      expect(_exactVersion.hasMatch(version), isTrue);
    });

    for (final workflowPath in _workflowPaths) {
    final name = workflowPath.split('/').last;
    test('(b) $name has no literal flutter-version key and every '
        'flutter-action step reads .fvmrc', () {
      final ci = File(workflowPath);
      expect(ci.existsSync(), isTrue,
          reason: '$name is missing at $workflowPath');
      final lines = ci.readAsLinesSync();

      // A literal pin: `flutter-version: 3.38.5` or `flutter-version: '3.38.5'`.
      // `flutter-version-file:` does NOT match because the colon must follow
      // `flutter-version` directly.
      final literalPin = RegExp(r'^\s*flutter-version:\s*\S');
      final pins = [
        for (var i = 0; i < lines.length; i++)
          if (literalPin.hasMatch(lines[i])) '${i + 1}: ${lines[i].trim()}',
      ];
      expect(pins, isEmpty,
          reason: '$name pins a literal Flutter version. Replace it with '
              '`flutter-version-file: .fvmrc` (F296): $pins');

      final actionUses = RegExp(r'uses:\s*subosito/flutter-action@');
      final actionSteps =
          lines.where((l) => actionUses.hasMatch(l)).length;

      final versionFileLines = RegExp(r'^\s*flutter-version-file:\s*(\S+)\s*$');
      final fileValues = [
        for (final l in lines)
          if (versionFileLines.firstMatch(l) != null)
            versionFileLines.firstMatch(l)!.group(1)!,
      ];

      expect(actionSteps, greaterThanOrEqualTo(1),
          reason: 'No subosito/flutter-action step found in $name. This test '
              'would be vacuous without one.');
      expect(fileValues.length, actionSteps,
          reason: 'Every subosito/flutter-action step must set '
              'flutter-version-file. Found $actionSteps steps and '
              '${fileValues.length} flutter-version-file lines.');
      expect(fileValues.every((v) => v == '.fvmrc'), isTrue,
          reason: 'Every flutter-version-file must be `.fvmrc`, found: '
              '$fileValues');
    });
    }

    test('(c) the local SDK running this test matches .fvmrc', () {
      final recorded = _fvmrcVersion();
      final local = _localSdkVersion();
      expect(local, recorded,
          reason: 'Local Flutter SDK is $local but .fvmrc records $recorded. '
              'Upgrade or downgrade the SDK, or update .fvmrc in the same '
              'commit (CLAUDE.md, CI/CD section).');
    });
  });
}
