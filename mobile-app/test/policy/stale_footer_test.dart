// Sprint 47 retro Proposal 5 -- stale-footer / hardcoded-"Sprint N" gate.
//
// WHY: F117 (Sprint 47) fixed a Help-screen footer that hardcoded
// `'Last updated: Sprint 40 (June 2026)'` -- a user-facing STRING LITERAL that
// silently drifted stale every sprint (nobody remembered to bump it). The fix
// switched the footer to a runtime value (`package_info_plus`). This gate makes
// the fragility class a BUILD FAILURE: no user-facing string literal under
// `lib/ui/` may hardcode a "Sprint <N>" or "Last updated ..." token. Such
// version/recency information must come from a runtime source (package_info,
// pubspec, build metadata), never a literal that a human must remember to edit.
//
// SCOPE: only STRING LITERALS (single- or double-quoted) are checked, and only
// under `lib/ui/`. Code COMMENTS are explicitly ignored -- `// Sprint 46 (...)`
// provenance comments are legitimate and common. This keeps the gate narrow: it
// fires on displayed text, not on developer annotations.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Directory swept (relative to mobile-app/). User-facing widgets live here.
const _sweepDir = 'lib/ui';

/// Stale-footer tokens forbidden inside a user-facing string literal:
///   - `Sprint 40`                 -- a hardcoded sprint number.
///   - `Last updated: ...`         -- a manual recency stamp that drifts.
final _staleTokens = <RegExp>[
  RegExp(r'Sprint\s+\d+', caseSensitive: false),
  RegExp(r'Last\s+updated', caseSensitive: false),
];

/// Extract the text INSIDE single- or double-quoted Dart string literals on a
/// line. Deliberately simple: good enough to catch footer/label literals
/// without a full Dart parser. Raw/adjacent/interpolated strings still expose
/// their literal text, which is all we need to scan.
Iterable<String> _stringLiterals(String line) sync* {
  for (final m in RegExp("'([^']*)'").allMatches(line)) {
    yield m.group(1)!;
  }
  for (final m in RegExp('"([^"]*)"').allMatches(line)) {
    yield m.group(1)!;
  }
}

/// True if the line is a `//` comment (leading whitespace allowed). Such lines
/// are skipped -- provenance comments like `// Sprint 46 follow-up` are fine.
bool _isCommentLine(String line) => line.trimLeft().startsWith('//');

void main() {
  group('stale-footer invariant (Sprint 47 retro Proposal 5)', () {
    test('the matcher self-checks: flags a stale literal, allows clean text '
        'and comments', () {
      // A hardcoded sprint footer string is a violation.
      expect(
        _stringLiterals(r"const footer = 'Last updated: Sprint 40 (June 2026)';")
            .any((s) => _staleTokens.any((t) => t.hasMatch(s))),
        isTrue,
      );
      // A runtime-sourced version string is clean (no Sprint token literal).
      expect(
        _stringLiterals(r"final v = 'Version ${info.version}';")
            .any((s) => _staleTokens.any((t) => t.hasMatch(s))),
        isFalse,
      );
      // A provenance COMMENT is ignored (skipped before literal extraction).
      expect(_isCommentLine('    // Sprint 46 (Harold speed follow-up)'), isTrue);
    });

    test('no user-facing string literal under lib/ui/ hardcodes a "Sprint N" '
        'or "Last updated" token', () {
      final dir = Directory(_sweepDir);
      if (!dir.existsSync()) {
        fail('Expected sweep directory $_sweepDir to exist');
      }

      final violations = <String>[];
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          for (final literal in _stringLiterals(line)) {
            for (final token in _staleTokens) {
              if (token.hasMatch(literal)) {
                violations.add(
                    '${entity.path}:${i + 1}: user-facing literal hardcodes a '
                    'stale token -> ${line.trim()}');
              }
            }
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Stale-footer literal(s) under lib/ui/. Version / recency '
              'text must come from a runtime source (package_info_plus, '
              'pubspec, build metadata), never a hardcoded "Sprint N" / '
              '"Last updated" string that drifts stale. See F117 '
              '(help_screen.dart) for the package_info_plus pattern:\n'
              '${violations.join('\n')}');
    });
  });
}
