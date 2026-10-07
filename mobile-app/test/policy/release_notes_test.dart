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
      // NORMALISE LINE ENDINGS FIRST.
      //
      // This searched for '\n---\n' against the raw file, which cannot match
      // '\r\n---\r\n'. Every file in this repo is on Windows, so any tool that
      // rewrites one -- an editor, a Python script, git's autocrlf -- can flip
      // it to CRLF and make this gate report "no --- separator" about a file
      // whose separator is plainly there on line 10.
      //
      // Hit on 2026-09-09, one day after this gate was written: a Python
      // rewrite of the release notes converted them to CRLF and the gate failed
      // with a message pointing at a missing rule rather than at line endings.
      // A gate that fails for a reason its message does not name is worse than
      // no gate, because the reader debugs the wrong thing.
      final content = f.readAsStringSync().replaceAll('\r\n', '\n');
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

  test('the Windows notes fit Partner Center\'s 1,500-character limit', () {
    // Microsoft: "What's new in this version ... This field has a 1500
    // character limit" (learn.microsoft.com, Add and edit Store listing info
    // for MSIX app). This repo's process doc said 10,000 -- that is the
    // DESCRIPTION field. Found 2026-10-04: the 0.17.0 notes (1,521 characters
    // by this count) were refused as 15 over. Partner Center's own count
    // differs slightly from every count here, so this measures the STRICTEST
    // one (each line break as two characters, as pasted on Windows) against
    // the documented 1,500 -- which also satisfies Harold's rule of "15 less
    // than the rejected length" (1,506).
    const windowsLimit = 1500;
    final v = currentVersion();
    final f = File('../docs/store-assets/RELEASE_NOTES_${v}_windows.md');
    if (!f.existsSync()) return;
    final content = f.readAsStringSync().replaceAll('\r\n', '\n');
    final sep = content.indexOf('\n---\n');
    if (sep < 0) return; // the identifier test reports a missing separator
    var shipped = content.substring(sep + 5);
    final auditTail = shipped.indexOf('**Excluded from this file**');
    if (auditTail > -1) shipped = shipped.substring(0, auditTail);
    final strictest = shipped.trim().replaceAll('\n', '\r\n').length;
    expect(strictest, lessThanOrEqualTo(windowsLimit),
        reason: 'the Windows notes measure $strictest characters (line breaks '
            'counted as two) against Partner Center\'s $windowsLimit-character '
            '"What\'s new in this version" limit. Shorten them.');
  });

  test('shipped paragraphs are ONE line each (no hard wrapping)', () {
    // Harold, 2026-10-04: the 0.17.0 Windows notes were hard-wrapped at ~100
    // columns like the derivation header above them. A line break inside a
    // paragraph is a real character: pasted into Partner Center's "What's new"
    // field or Play's release-notes field it becomes a broken line on the
    // listing. Each paragraph is one line; paragraphs are separated by a blank
    // line. A block whose every line is a list item ("- ") is a deliberate
    // list and is allowed.
    final v = currentVersion();
    for (final store in ['windows', 'play']) {
      final f = File('../docs/store-assets/RELEASE_NOTES_${v}_$store.md');
      if (!f.existsSync()) continue;
      final content = f.readAsStringSync().replaceAll('\r\n', '\n');
      final sep = content.indexOf('\n---\n');
      if (sep < 0) continue; // the identifier test reports a missing separator
      var shipped = content.substring(sep + 5);
      final auditTail = shipped.indexOf('**Excluded from this file**');
      if (auditTail > -1) shipped = shipped.substring(0, auditTail);
      shipped = shipped.replaceAll(RegExp(r'</?en-US>'), '\n');

      final wrapped = shipped
          .split(RegExp(r'\n\s*\n'))
          .map((p) => p.trim())
          .where((p) => p.contains('\n'))
          .where((p) => !p.split('\n').every((l) => l.trimLeft().startsWith('- ')))
          .toList();
      expect(wrapped, isEmpty,
          reason: 'the $store release notes hard-wrap ${wrapped.length} '
              'paragraph(s); the first starts "${wrapped.isEmpty ? '' : wrapped.first.split('\n').first}". '
              'Put each paragraph on ONE line -- the line breaks are pasted '
              'into the store field as real breaks (STORE_RELEASE_PROCESS.md '
              'Step 1b).');
    }
  });
}
