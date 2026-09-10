import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dev-version-ahead gate (F190, Sprint 66).
///
/// **The invariant, in Harold's words**: *"if Production version is n.n.n and
/// development includes changes, then in order for the testers of the changes
/// to know it is different from production version is to bump the version."*
///
/// Until F190 the bump happened at Store-release Step 1 -- the very END of the
/// cycle -- so for an entire sprint the dev build reported the SAME version as
/// production. That is backwards: the window where a tester most needs to tell
/// the two apart is precisely while the changes are being tested.
///
/// Sprint 66 produced the symptom. Harold saw `0.13.0 [DEV]` while production
/// showed `0.14.0` and reasonably asked whether the repository was wrong. It
/// was not -- the binary was stale -- but a version that only moves at release
/// cannot answer "is this build newer than production?", so the question had no
/// cheap answer.
///
/// This gate expresses that invariant mechanically rather than leaving it as a
/// rule someone has to remember at the right moment.
///
/// **What it deliberately does NOT do**: it does not check WHICH digit moved.
/// Feature-versus-fix is a judgement about the sprint's content, re-verified at
/// Phase 7.7 once that content is known. Asserting it here would fail honest
/// work in progress -- a sprint may not know yet whether it contains a feature.
void main() {
  final pubspec = File('pubspec.yaml');
  final changelog = File('../CHANGELOG.md');
  final storeStatus = File('../docs/STORE_VERSION_STATUS.md');

  /// Parse "0.14.1" into comparable parts. Returns null if unparseable.
  List<int>? parseVersion(String raw) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(raw.trim());
    if (m == null) return null;
    return [int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)];
  }

  /// Compare semantic versions. Negative when [a] is older than [b].
  int compareVersions(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }

  test('the dev version is AHEAD of the last released version', () {
    final pubspecSource = pubspec.readAsStringSync();
    final devRaw = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspecSource)
        ?.group(1);
    expect(devRaw, isNotNull,
        reason: 'could not read `version:` from pubspec.yaml');

    final dev = parseVersion(devRaw!);
    expect(dev, isNotNull, reason: 'pubspec version "$devRaw" is not semver');

    // The newest RELEASED version is the first [x.y.z] heading in the
    // changelog. [Unreleased] carries no version, so it is skipped naturally.
    final releasedRaw = RegExp(r'^## \[(\d+\.\d+\.\d+)\]', multiLine: true)
        .firstMatch(changelog.readAsStringSync())
        ?.group(1);
    expect(releasedRaw, isNotNull,
        reason: 'could not find a released version heading in CHANGELOG.md');

    final released = parseVersion(releasedRaw!)!;

    expect(compareVersions(dev!, released), greaterThan(0),
        reason: 'The dev version ($devRaw) is not ahead of the last released '
            'version ($releasedRaw). A tester running this build cannot tell '
            'it apart from production, which is the whole point of the bump.\n\n'
            'Bump BOTH `version:` and `msix_config.msix_version` in '
            'pubspec.yaml (Phase 3.7.0b). If the approved plan contains a '
            'feat, bump MINOR and reset PATCH to 0; otherwise bump PATCH. When '
            'in doubt take PATCH -- the KIND is re-verified at Phase 7.7, but '
            'a MISSING bump is invisible until somebody is already confused.');
  });

  /// Sprint 68 IMP-2: the changelog is NOT a sufficient definition of
  /// "released".
  ///
  /// The test above compares dev against the newest `[x.y.z]` heading in
  /// CHANGELOG.md. That heading only appears when `develop` merges to `main`
  /// and the release is cut -- but a version reaches the STORES before that
  /// bookkeeping happens, and can sit under `[Unreleased]` while it is live to
  /// real users.
  ///
  /// Sprint 68 hit exactly that hole. Both stores were live on 0.14.2 while
  /// the newest changelog heading still read 0.14.0, so dev at 0.14.2 was
  /// "ahead of the last released version" and the gate passed -- while being
  /// BYTE-IDENTICAL to what customers were running. F190 exists to stop
  /// precisely that, and the gate that was supposed to enforce F190 could not
  /// see it. Harold caught it by reading the version in his own title bar.
  ///
  /// There is also a second store now. This gate predates Google Play, and a
  /// check that knows only about Windows is half a check.
  ///
  /// `STORE_VERSION_STATUS.md` is a CACHE, not a source of truth -- its own
  /// header says so. That is fine here: a cache that is STALE makes this gate
  /// weaker, never wrong. It can only fail on a version somebody actually
  /// recorded as live.
  test('the dev version is AHEAD of every version recorded as live on a store',
      () {
    if (!storeStatus.existsSync()) {
      // Not a silent pass: the file is the input, and its absence is a real
      // finding rather than a reason to skip.
      fail('docs/STORE_VERSION_STATUS.md is missing. It is the only record of '
          'what is live on each store, and F190 cannot be enforced without it.');
    }

    final devRaw = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec.readAsStringSync())
        ?.group(1);
    expect(devRaw, isNotNull, reason: 'could not read `version:`');
    final dev = parseVersion(devRaw!)!;

    // Rows look like: `| **Live/certified on Store** (cache) | 0.14.2.0 | ...`
    // and `| **Live on Google Play** (cache) | 0.14.2 (versionCode 2) | ...`.
    // Match the LABEL, then take the first semver-shaped token in that row, so
    // the surrounding prose (dates, submission numbers, versionCode) cannot be
    // mistaken for the version.
    final liveRows = RegExp(
      r'^\|\s*\*\*Live[^|]*\*\*[^|]*\|\s*(\d+\.\d+\.\d+)',
      multiLine: true,
    ).allMatches(storeStatus.readAsStringSync()).toList();

    // PR #403 review: `isNotEmpty` catches TOTAL failure but not PARTIAL. If
    // the Store row keeps its format and the Play row is reworded, one row
    // still matches, this guard passes, and the Play version goes UNCHECKED --
    // which is precisely the half-a-check this gate exists to replace.
    // Two stores ship today, so require two rows.
    expect(liveRows.length, greaterThanOrEqualTo(2),
        reason: 'expected one "Live ..." row per shipping store (Microsoft '
            'Store and Google Play) in STORE_VERSION_STATUS.md, found '
            '${liveRows.length}. A row that was reworded, un-bolded, or had '
            'its version moved out of the first cell no longer matches -- '
            'UPDATE THIS GATE with the table rather than letting it check '
            'fewer stores than actually ship.');

    for (final row in liveRows) {
      final liveRaw = row.group(1)!;
      final live = parseVersion(liveRaw)!;
      expect(compareVersions(dev, live), greaterThan(0),
          reason: 'The dev version ($devRaw) is NOT ahead of $liveRaw, which '
              'STORE_VERSION_STATUS.md records as LIVE on a store.\n\n'
              'A tester running this build cannot tell it apart from what '
              'customers already have -- which is the entire point of F190.\n\n'
              'Bump BOTH `version:` and `msix_config.msix_version` at Phase '
              '3.7.0b (plan approval), not at release. MINOR if the approved '
              'plan contains a feat, else PATCH.\n\n'
              'Also bump the `+N` build number: Play requires a strictly '
              'increasing versionCode, and a number already used by a live '
              'submission is refused at upload.');
    }
  });

  test('pubspec version and msix_version agree', () {
    // They are two separate literals and nothing else makes them match. A bump
    // that updates one and not the other ships an MSIX whose Store-visible
    // version disagrees with the app's own About screen.
    final source = pubspec.readAsStringSync();

    final version = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(source)
        ?.group(1);
    final msix = RegExp(r'^\s*msix_version:\s*(\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(source)
        ?.group(1);

    expect(version, isNotNull, reason: 'could not read `version:`');
    expect(msix, isNotNull, reason: 'could not read `msix_version:`');
    expect(msix, equals(version),
        reason: 'msix_version ($msix) does not match version ($version). '
            'Bump BOTH together -- msix_version is what the Microsoft Store '
            'displays, version is what the app reports about itself, and a '
            'mismatch means the two disagree in public.');
  });
}
