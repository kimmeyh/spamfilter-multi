/// F196 (Sprint 67): per-store release notes exist for the current version, and
/// the Play file fits Play's limit -- MEASURED, not claimed.
///
/// **Why a gate for prose.** Sprint 66 wrote release notes twice, both under
/// pressure at submission time, and got the count wrong three times in a row on
/// one of them: claimed 486 characters, then 523, actual 485. A limit that is
/// discovered mid-write and estimated by eye is a limit that costs three
/// rewrites. This measures it once, in CI, before anyone opens a console.
///
/// **Why per-store files at all.** `CHANGELOG.md` is the engineering record and
/// makes no distinction between platforms. Windows Submission 23 shipped with
/// nine of its ten entries describing Google Play work that no Store customer
/// could see. Each store's users were being shown the other platform's
/// changelog. ADR-0043 makes the notes a derived artifact, one per store.
///
/// **Deliberately NOT asserted here**: whether the notes are *good*, or whether
/// they describe the right changes. A gate cannot judge prose. What it can do is
/// prove the files exist for the version being shipped, carry real content, and
/// respect the one hard limit -- which is exactly the set of failures that cost
/// time in Sprint 66.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml');

  /// The version being shipped, from the single source of truth (ADR-0043:
  /// one version, all platforms).
  String currentVersion() {
    final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(pubspec.readAsStringSync());
    expect(m, isNotNull, reason: 'could not read `version:` from pubspec.yaml');
    return m!.group(1)!;
  }

  /// Play caps release notes at 500 characters PER LANGUAGE. The tags
  /// themselves are not counted -- the console measures the text between them,
  /// which is what its "Release note for en-US is too long" error refers to.
  const playLimit = 500;

  test('per-store release notes exist for the current version', () {
    final v = currentVersion();
    for (final store in ['windows', 'play']) {
      final f = File('../docs/store-assets/RELEASE_NOTES_${v}_$store.md');
      expect(f.existsSync(), isTrue,
          reason: 'missing ${f.path}. ADR-0043 makes release notes a DERIVED '
              'per-store artifact: each store sees only what applies to it. '
              'Derive it per STORE_RELEASE_PROCESS.md Step 1b -- and if the '
              'derived notes come out empty, that is a signal the release may '
              'not be worth submitting to that store, not a formatting problem.');
    }
  });

  test('the Play notes fit Play\'s 500-character-per-language limit', () {
    final v = currentVersion();
    final f = File('../docs/store-assets/RELEASE_NOTES_${v}_play.md');
    if (!f.existsSync()) return; // covered by the test above

    final m = RegExp(r'<en-US>(.*?)</en-US>', dotAll: true)
        .firstMatch(f.readAsStringSync());
    expect(m, isNotNull,
        reason: 'the Play notes must wrap their text in <en-US> tags -- the '
            'console requires them, and their absence is a silent rejection at '
            'paste time');

    final body = m!.group(1)!.trim();
    expect(body.length, lessThanOrEqualTo(playLimit),
        reason: 'measured ${body.length} characters against Play\'s $playLimit '
            'limit. MEASURE, never estimate: Sprint 66 estimated this three '
            'times running and was wrong every time (486, then 523, actual '
            '485).');
    expect(body, isNotEmpty,
        reason: 'empty release notes tell a tester nothing about why they '
            'should install the update');
  });

  test('neither store\'s notes leak internal identifiers', () {
    // A release note is written for someone deciding whether to care about an
    // update. "F193", "GP-4", "Issue #392" mean nothing to them and read as
    // leaked scaffolding -- the exact tell that a changelog was pasted rather
    // than derived.
    final v = currentVersion();
    final internalMarker =
        // F\d{2,4}: the original capped at 3 digits, so F1234 slipped through --
        // and feature ids are already at F197, so four digits is a matter of
        // time. `(?i)issue\s*#`: the original required a capital I, but a
        // release note would naturally write "issue #392" mid-sentence. Both
        // were MISSES (silently permissive), not false positives -- verified
        // empirically by the Sprint 67 5.1.1 review.
        RegExp(r'\b(F\d{2,4}|GP-\d+|SEC-\d+|issue\s*#\d+)\b', caseSensitive: false);

    for (final store in ['windows', 'play']) {
      final f = File('../docs/store-assets/RELEASE_NOTES_${v}_$store.md');
      if (!f.existsSync()) continue;

      // Only the SHIPPED text is checked. These files carry a derivation
      // header explaining where the content came from, and that header
      // legitimately cites the identifiers -- it is the audit trail, and it is
      // not pasted into any console.
      final content = f.readAsStringSync();
      final sep = content.indexOf('\n---\n');
      expect(sep, greaterThan(-1),
          reason: 'each notes file separates its derivation header from the '
              'shipped text with a --- rule, so this gate can tell them apart');
      final shipped = content.substring(sep);
      // The trailing "Excluded from this file" section is also audit trail.
      final auditTail = shipped.indexOf('**Excluded from this file**');
      final userFacing =
          auditTail > -1 ? shipped.substring(0, auditTail) : shipped;

      final leaks = internalMarker
          .allMatches(userFacing)
          .map((m) => m.group(0))
          .toSet();
      expect(leaks, isEmpty,
          reason: 'the $store release notes show internal identifiers $leaks '
              'in text a user reads. Describe what changed for THEM.');
    }
  });
}
