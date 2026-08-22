/// F167 (Sprint 61): Help content must not describe a Windows-only capability
/// as if it were available everywhere, and must not promise an Android
/// capability that does not exist yet.
///
/// Governed by ADR-0042 (cross-platform parity): differences are allowed where
/// a platform genuinely cannot do something, but they must be EXPLICIT and
/// MINIMAL. Help text is where an unstated difference does the most damage --
/// a user following instructions for a feature their platform does not have
/// concludes the app is broken.
///
/// The defect this pins (found 2026-08-18): `background_scanning.md` named
/// BOTH platform mechanisms -- "the app wakes up the Windows Task Scheduler
/// (or Android WorkManager)". Naming mechanisms per platform is what creates
/// the drift: the text has to be revisited every time a platform's
/// implementation changes, and it was already wrong (Android has no scheduler
/// until F161).
///
/// **Harold's steering, 2026-08-18** -- which changed the fix: "we have not
/// delivered to customers an Android package yet. The scheduler will need to
/// be in place (key requirement) before shipment, so we need to delete the
/// help text about it." So there is NO user to warn: Android ships WITH the
/// scheduler or it does not ship. A "not available on Android yet" caveat
/// would document a limitation no customer will ever encounter, and would
/// then be stale text someone has to remember to remove.
///
/// The rule this leaves: describe the CAPABILITY, not the per-platform
/// mechanism. "The operating system's scheduler" is true on every platform
/// the app ships to, needs no caveat, and cannot drift.
///
/// This is a CONTENT gate, not a behavior gate: it asserts what the shipped
/// Markdown says. It is deliberately narrow -- a broad "no platform words in
/// Help" rule would be wrong, since naming a platform is exactly how an honest
/// platform difference gets communicated.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F167: Help content platform claims (ADR-0042)', () {
    late String backgroundScanning;

    setUpAll(() {
      backgroundScanning =
          File('assets/content/help/background_scanning.md').readAsStringSync();
    });

    test(
        'background-scanning Help names no per-platform scheduler mechanism',
        () {
      // Naming mechanisms is what makes this text drift -- it must be revisited
      // whenever a platform's implementation changes, and it was already wrong
      // about Android. Describing the CAPABILITY instead is true everywhere.
      final mechanismNames = [
        RegExp(r'Android\s+WorkManager', caseSensitive: false),
        RegExp(r'Windows\s+Task\s+Scheduler', caseSensitive: false),
      ];

      for (final pattern in mechanismNames) {
        expect(pattern.hasMatch(backgroundScanning), isFalse,
            reason: 'user-facing Help should describe the capability (the '
                'operating-system scheduler), not the per-platform '
                'mechanism. Naming mechanisms guarantees the text drifts as '
                'implementations change -- it already had, claiming Android '
                'WorkManager scheduling that does not exist.');
      }
    });

    test(
        'background-scanning Help carries no Android-limitation caveat '
        '(Android ships WITH the scheduler or not at all)', () {
      // Harold, 2026-08-18: Android has never shipped to customers, and the
      // scheduler is a KEY REQUIREMENT before it does. So a "not on Android
      // yet" caveat would warn a user who will never exist, and would become
      // stale text the moment F161 lands.
      final staleCaveats = [
        RegExp(r'Windows feature today', caseSensitive: false),
        RegExp(r'no scheduled scan runs yet', caseSensitive: false),
        RegExp(r'not (yet )?available on Android', caseSensitive: false),
      ];

      for (final pattern in staleCaveats) {
        expect(pattern.hasMatch(backgroundScanning), isFalse,
            reason: 'no Android-limitation caveat belongs here: Android ships '
                'with the scheduler in place or it does not ship, so the '
                'caveat would document a limitation no customer encounters '
                'and would then need remembering to delete');
      }
    });

    test(
        'selection Help scopes its desktop and touch idioms to the right '
        'platforms', () {
      final review =
          File('assets/content/help/review_no_rule_items.md').readAsStringSync();

      // F143 established both idioms; F169/F172 did not change them. The risk
      // is a future edit describing one idiom as universal.
      expect(RegExp(r'On Windows desktop').hasMatch(review), isTrue,
          reason: 'Ctrl+click / Shift+click / right-click are desktop idioms '
              'and must be scoped, not stated as universal');
      expect(RegExp(r'On Android and iOS').hasMatch(review), isTrue,
          reason: 'long-press-then-tap is the touch idiom and must be scoped '
              'to the platforms where the code actually enables it -- the '
              'wording was corrected in the PR #335 review after it claimed '
              '"on a touch screen", which is wrong on Windows touchscreens');
    });
  });
}
