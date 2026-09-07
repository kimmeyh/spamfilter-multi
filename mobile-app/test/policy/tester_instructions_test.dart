import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tester onboarding instructions gate (GP-19, Sprint 66, Issue #387).
///
/// **Why this is gated at all.** Sprint 66 was replanned around one fact: an
/// app password does not expire, so a tester signs in ONCE and stays connected
/// for the full 14 days, whereas Google Sign-In on an unverified app expires
/// after about 7 days and would sign every tester out mid-test. That decision
/// only pays off if the instructions actually tell testers to pick App
/// Password -- an instruction naming the wrong option would reintroduce the
/// exact problem the replan removed, during the one window whose evidence
/// Google reviews.
///
/// **The label is asserted in its FULL form.** Sprint 65's Manual Validation
/// found a gate passing while the instructions were wrong, because the
/// asserted string was a SUBSTRING of the real label. `App Password (IMAP)` is
/// a substring of `App Password (IMAP) (Recommended)`, which is the same trap.
/// This gate asserts the full label and is registered in
/// `ui_string_assertion_shadow_test.dart` so the shadow check covers it too.
void main() {
  final setupDoc = File('../docs/GOOGLE_PLAY_ACCOUNT_SETUP.md');

  test('tester onboarding instructions exist', () {
    expect(setupDoc.existsSync(), isTrue);
    expect(setupDoc.readAsStringSync(),
        contains('Tester onboarding instructions'),
        reason: 'GP-19 R-2 requires something that can actually be SENT to a '
            'tester. Recruitment is the long pole and cannot start without it');
  });

  test('the instructions name App Password, and explicitly steer away from '
      'Google Sign-In', () {
    final content = setupDoc.readAsStringSync();
    final start = content.indexOf('Tester onboarding instructions');
    final section = content.substring(start);

    // Full label, not a prefix -- see this file's header for why.
    expect(section, contains('App Password (IMAP)'),
        reason: 'the instructions must name the exact on-screen option; a '
            'paraphrase leaves a tester guessing');

    // Naming the right option is not enough. The wrong option sits directly
    // beneath it on the same screen and is the more familiar choice, so the
    // instructions must actively steer away from it.
    expect(section.contains('Google Sign-In'), isTrue,
        reason: 'the instructions must mention Google Sign-In in order to tell '
            'testers NOT to use it -- it is the adjacent option on the same '
            'screen and the one a user would otherwise reach for');
  });

  test('the 2-Step Verification prerequisite is stated', () {
    // The single most likely support question. An app password cannot be
    // created without it, and a tester who hits that wall usually stops rather
    // than asking.
    final content = setupDoc.readAsStringSync();
    final start = content.indexOf('Tester onboarding instructions');
    expect(content.substring(start), contains('2-Step Verification'),
        reason: 'creating an app password requires 2-Step Verification to be '
            'enabled first. Stating it up front prevents the most predictable '
            'drop-off in the recruitment funnel');
  });

  test('the instructions distinguish an invitation from an opt-in', () {
    // The 14-day clock starts on OPT-IN. A tester who installs the app but
    // never completes the join does not count, and that failure is invisible
    // unless each opt-in is confirmed.
    final content = setupDoc.readAsStringSync();
    final start = content.indexOf('Tester onboarding instructions');
    final section = content.substring(start);
    expect(section.toLowerCase(), contains('opt'),
        reason: 'the instructions must make clear that joining the test is the '
            'step that counts -- an invitation starts no clock');
  });
}
