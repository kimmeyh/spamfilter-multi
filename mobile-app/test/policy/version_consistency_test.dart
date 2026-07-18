// F108-followup / Sprint 44 retro IMP-1 -- version-consistency enforcement gate.
//
// WHY: app version literals are embedded in source as log-filename tokens
// (`...background_scan_v0.5.4.log`, `live_scan_v0.5.4.log`) and a Settings
// version-display string (`'Version 0.5.4...'`), in BOTH Dart (`lib/`) and C++
// (`windows/runner/main.cpp`). A version bump must update every one of these to
// match `pubspec.yaml`. Sprint 43's F105 bump MISSED `main.cpp` (it was not on
// the checklist), shipping a stale `v0.5.3` filename for a release -- a SILENT
// drift (the app still builds + runs; only the log filename is wrong), so it
// escaped normal testing. This gate makes that drift a BUILD FAILURE.
//
// FAILS when any recognized version literal under lib/ + windows/runner/ +
// scripts/ + test/ does not match the canonical `version:` in pubspec.yaml.
// (test/ added Sprint 47 retro Proposal 4 -- the F118 fragility class.)
//
// Recognized literal forms (deliberately narrow to the APP-version-bearing
// contexts, so dependency versions in comments -- e.g.
// `flutter_local_notifications v16.2.0` -- date strings, and unrelated X.Y.Z
// are NOT matched):
//   - `_v<MAJOR>.<MINOR>.<PATCH>.log`  -- the background/live-scan log-filename
//     token (the `_v...log` shape is the disambiguator).
//   - `Version <MAJOR>.<MINOR>.<PATCH>` -- the Settings version-display string.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Canonical `MAJOR.MINOR.PATCH` parsed from pubspec.yaml `version: X.Y.Z+B`.
String _canonicalVersion() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
      .firstMatch(pubspec);
  if (m == null) {
    fail('Could not find a `version: X.Y.Z` line in pubspec.yaml');
  }
  return m.group(1)!;
}

/// The two APP-version-literal forms we enforce. Group 1 (or 2) is the X.Y.Z.
///   - `_v0.5.4.log`           -- a scan-log filename token.
///   - `Version 0.5.4`         -- the Settings version-display string.
/// Narrow on purpose: a dependency version in a comment (`v16.2.0`) has no
/// `_..._.log` wrapper and is not preceded by `Version `, so it is NOT matched.
final _versionLiteral = RegExp(
  r'_v(\d+\.\d+\.\d+)\.log|Version\s(\d+\.\d+\.\d+)',
);

/// Extract the X.Y.Z from a match (whichever alternative captured it).
String _versionOf(RegExpMatch m) => m.group(1) ?? m.group(2)!;

/// Directories swept for version literals (relative to mobile-app/).
///
/// `test` was added in Sprint 47 (retro Proposal 4) after F118: two tests had
/// HARDCODED the versioned log filename (`live_scan_v0.5.4.log`) and silently
/// broke on the 0.5.4->0.5.5 bump. The gate previously excluded `test/`, so it
/// could not see that fragility class. Sweeping `test/` too makes a hardcoded
/// version literal in any test a BUILD FAILURE; the correct pattern is to
/// DERIVE the version from pubspec at runtime (see
/// test/unit/services/live_scan_logger_test.dart), which produces no literal
/// and is therefore never flagged.
const _sweepDirs = ['lib', 'windows/runner', 'scripts', 'test'];

/// File extensions that may carry a version literal.
bool _isSweepable(String p) =>
    p.endsWith('.dart') ||
    p.endsWith('.cpp') ||
    p.endsWith('.cc') ||
    p.endsWith('.h') ||
    p.endsWith('.ps1');

void main() {
  group('version-consistency invariant (Sprint 44 retro IMP-1)', () {
    test('the matcher self-checks: flags a stale literal, allows a match', () {
      // Canonical 0.5.4 -> a v0.5.3 log token is a mismatch; v0.5.4 log token /
      // Version 0.5.4 are matches.
      Iterable<String> mismatches(String line, String canonical) =>
          _versionLiteral
              .allMatches(line)
              .map(_versionOf)
              .where((v) => v != canonical);

      expect(mismatches(r'background_scan_v0.5.3.log', '0.5.4'), isNotEmpty);
      expect(mismatches(r'background_scan_v0.5.4.log', '0.5.4'), isEmpty);
      expect(mismatches(r"'Version 0.5.4\${suffix}'", '0.5.4'), isEmpty);
      expect(mismatches(r"'Version 0.5.3'", '0.5.4'), isNotEmpty);
      // A dependency version in a comment is NOT matched (no _..._.log wrapper,
      // not preceded by `Version `). This is the false-positive the narrowed
      // pattern fixes.
      expect(mismatches(r'// flutter_local_notifications v16.2.0 ...', '0.5.4'),
          isEmpty);
      expect(mismatches(r'sqlite3: 3.1.4', '0.5.4'), isEmpty);
    });

    test('every version literal in lib/ + windows/runner/ + scripts/ + test/ '
        'matches pubspec.yaml', () {
      final canonical = _canonicalVersion();
      final violations = <String>[];

      for (final dirName in _sweepDirs) {
        final dir = Directory(dirName);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !_isSweepable(entity.path)) continue;
          // Skip the gate's own CLI -- it intentionally contains stale-version
          // FIXTURE strings (e.g. 'Version 0.5.3') for its self-test.
          if (entity.path.endsWith('check-version-consistency.ps1')) continue;
          // Skip THIS test file -- it too contains deliberate stale-version
          // FIXTURE literals (e.g. 'background_scan_v0.5.3.log', 'Version 0.5.3')
          // in the matcher self-check above. Now that `test/` is swept, this
          // file must be excluded or its own fixtures would be false positives.
          if (entity.path.endsWith('version_consistency_test.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            for (final m in _versionLiteral.allMatches(lines[i])) {
              final found = _versionOf(m);
              if (found != canonical) {
                violations.add(
                    '${entity.path}:${i + 1}: found "$found", expected '
                    '"$canonical" -> ${lines[i].trim()}');
              }
            }
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Stale version literal(s) -- update each to match '
              'pubspec.yaml ($canonical). See the 5-file version checklist in '
              'docs/STORE_RELEASE_PROCESS.md:\n${violations.join('\n')}');
    });
  });
}
