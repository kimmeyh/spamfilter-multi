/// Sprint 68 IMP-3: the in-app provider setup steps must not go stale while the
/// standalone document stays current.
///
/// **The defect this exists for.** `docs/APP_PASSWORD_SETUP.md` was written from
/// each vendor's current page and was correct. The IN-APP dialog -- which is
/// what a user actually sees at setup time -- had **four of six iCloud steps
/// wrong**: it sent them to `appleid.apple.com` (Apple moved to
/// `account.apple.com`), told them to open "Account Security" (now "Sign-In and
/// Security"), look under "App Passwords" (now "App-Specific Passwords") and
/// click "Generate password" (now "Generate an app-specific password"), plus a
/// "Select Other (specify)" step that no longer exists at all.
///
/// It was not merely unhelpful. Apple shows a card genuinely called **Account
/// Security** on that page -- it is the Two-Factor Authentication panel -- so
/// the stale wording pointed at a real control that does something else, and
/// Harold landed in it and had to ask where app passwords were.
///
/// **A correct document beside incorrect in-app copy is not a correct product.**
///
/// **What this gate deliberately does and does not check.** It does NOT compare
/// prose: the doc is a walkthrough with preconditions and failure modes, the
/// in-app steps are six short lines, and asserting they match textually would be
/// brittle enough to train bypass. It checks the two things that are exact
/// tokens and are precisely what went stale: the URLs the steps name, and the
/// retired labels that must never come back.
///
/// Freshness against the VENDOR is still a human job -- `F201`'s periodic
/// re-review owns that, and no gate can watch someone else's website. This gate
/// owns the cheaper half: app and doc must not disagree with each other.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen =
      File('lib/ui/screens/platform_selection_screen.dart').readAsStringSync();
  final doc = File('../docs/APP_PASSWORD_SETUP.md').readAsStringSync();

  /// Only the user-visible step text. Comments in this file legitimately cite
  /// the RETIRED strings to explain what changed and why -- reading raw file
  /// text would flag that history as a defect, which is exactly backwards.
  List<String> stepStrings() => RegExp(r"_buildStep\(\s*\d+\s*,\s*(.+?)\),\s*$",
          multiLine: true, dotAll: true)
      .allMatches(screen)
      .map((m) => m.group(1)!)
      .toList();

  test('the matcher self-checks: it reads steps and ignores comments', () {
    final steps = stepStrings();
    expect(steps, isNotEmpty,
        reason: 'no _buildStep(...) calls parsed. If the setup steps were '
            'refactored into another shape, UPDATE THIS GATE with them -- a '
            'pattern that matches nothing passes everything.');
    expect(steps.join(' '), isNot(contains('appleid.apple.com')),
        reason: 'the retired Apple URL appears in a STEP. It is allowed in a '
            'comment (this file explains what changed); it is not allowed in '
            'text a user follows.');
  });

  test('every URL the in-app steps name also appears in APP_PASSWORD_SETUP.md',
      () {
    final urlPattern = RegExp(r'[a-z0-9.-]+\.(?:com|org|net)(?:/[^\s\x27"]*)?');
    final offenders = <String>[];

    for (final step in stepStrings()) {
      for (final m in urlPattern.allMatches(step)) {
        final url = m.group(0)!;
        if (!doc.contains(url)) {
          offenders.add('in-app step names "$url", which does not appear in '
              'docs/APP_PASSWORD_SETUP.md');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'The in-app setup steps and the setup document disagree about '
            'where to send the user. The DOCUMENT is written from the vendors\' '
            'own pages and is the reference; fix the app text, or update both '
            'together if the vendor moved.\n\n${offenders.join('\n')}');
  });

  test('retired vendor labels do not reappear in the steps', () {
    // Each entry is a string a vendor USED to show. They are recorded here
    // rather than in a comment because a name that came back would be invisible
    // to review -- it reads as plausible, which is how it survived in the first
    // place.
    const retired = <String, String>{
      'appleid.apple.com': 'Apple moved to account.apple.com',
      'Account Security': 'Apple renamed this to "Sign-In and Security". A card '
          'called "Account Security" still exists on that page and is the '
          'Two-Factor Authentication panel -- pointing at it sends the user to '
          'the wrong control, which is what happened.',
      // SUBSTRING SHADOW: a bare 'App Passwords' contains-matches inside the
      // CORRECT 'App-Specific Passwords', so the naive check flagged the fix
      // as the defect. Same class as the Sprint 66 provider gate that passed
      // while catching nothing. Anchored on the retired phrasing instead.
      'under "App Passwords"': 'Apple calls these "App-Specific Passwords"',
      'Generate app password': 'Yahoo and AOL renamed this to "Create app '
          'password", under "External connections"',
      'Other App': 'the Yahoo/AOL dropdown step no longer exists',
      'Other (specify)': 'the Apple step no longer exists',
    };

    final steps = stepStrings().join('\n');
    final offenders = <String>[];
    retired.forEach((label, why) {
      if (steps.contains(label)) offenders.add('"$label" -- $why');
    });

    expect(offenders, isEmpty,
        reason: 'A retired vendor UI label reappeared in the in-app setup '
            'steps. These are not typos -- they were correct once, which is '
            'why they survive review.\n\n${offenders.join('\n')}');
  });
}
