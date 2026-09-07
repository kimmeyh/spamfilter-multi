import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GP-17 closed-test roster policy gate (Sprint 65, Issue #384).
///
/// **What this protects.** The 12-tester / 14-continuous-day closed test is the
/// longest item on the path to a live Play listing, and the date it unlocks is
/// easy to get wrong in two specific ways:
///
/// 1. **A guessed application date.** The 14 days run per-tester from OPT-IN,
///    and Google checks backward from the moment you apply. The valid date
///    therefore depends on the LAST tester to opt in, not the first. If the
///    roster does not carry per-tester opt-in dates, that date gets estimated
///    from memory weeks later -- and applying early is a rejection.
/// 2. **Tester personal data in a public repository.** The roster lives in the
///    repo, so it records roles and dates only. An email address here would be
///    a privacy leak in version control, which survives deletion.
///
/// This gate is structural: it asserts the record EXISTS and is shaped to hold
/// the right facts. It cannot verify that the dates written into it are true --
/// that is Harold's console-side confirmation (AC-2). Per
/// `feedback_source_gates_verify_shape`, a source gate proves shape, not
/// behaviour.
void main() {
  final setupDoc = File('../docs/GOOGLE_PLAY_ACCOUNT_SETUP.md');

  test('the closed-test roster section exists', () {
    expect(setupDoc.existsSync(), isTrue,
        reason: 'GOOGLE_PLAY_ACCOUNT_SETUP.md is the recorded home of the '
            'Play account state');
    final content = setupDoc.readAsStringSync();
    expect(content, contains('Closed-test tester roster'),
        reason: 'GP-17 records the roster here so the earliest valid '
            'production-access application date is a computed fact rather '
            'than a recollection');
  });

  test('the roster records the fields the application actually depends on', () {
    final content = setupDoc.readAsStringSync();

    // Opt-in confirmation, not invitation: a tester counts only after they
    // open the link AND complete opt-in, so the roster must distinguish the
    // two or the count is wrong.
    expect(content, contains('Opt-in CONFIRMED'),
        reason: 'an invitation is not an opt-in; the roster must track the '
            'confirmation separately');
    expect(content, contains('Earliest valid production-access application date'),
        reason: 'the date must be recorded and derived from the LAST opt-in, '
            'not estimated later');
    expect(content, contains('Tester feedback log'),
        reason: 'production access is a substantive review asking what testers '
            'reported and what changed as a result -- thin answers are a '
            'documented rejection cause, so the feedback is a deliverable');
  });

  test('the roster contains no tester email addresses', () {
    // The roster is in version control, where a leak survives deletion. The
    // section deliberately records roles only.
    final content = setupDoc.readAsStringSync();
    final rosterStart = content.indexOf('Closed-test tester roster');
    expect(rosterStart, greaterThan(-1));
    final roster = content.substring(rosterStart);

    // A bare address shape. The doc legitimately mentions the published
    // contact address in other sections, which is why this is scoped to the
    // roster section rather than the whole file.
    final emailShape = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
    final matches = emailShape.allMatches(roster).map((m) => m.group(0)).toList();
    expect(matches, isEmpty,
        reason: 'the roster records ROLES and dates only -- a tester email '
            'address committed here is a privacy leak that survives deletion. '
            'Found: $matches');
  });
}
