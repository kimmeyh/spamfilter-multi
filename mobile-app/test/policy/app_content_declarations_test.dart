import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GP-18 App content declarations policy gate (Sprint 65, Issue #381).
///
/// **What this protects.** Play's "App content" checklist gates a
/// CLOSED-track rollout, not only production -- an unanswered conditional
/// item is an incomplete setup and blocks the rollout the same way a wrong
/// answer would. This gate is structural, per
/// `feedback_source_gates_verify_shape`: it asserts every required
/// declaration category is present BY NAME in the recorded section, which is
/// exactly the failure mode a silently-skipped conditional item would
/// produce -- the category heading simply would not be there. It cannot
/// verify the console-side answers actually submitted match this document;
/// that is Harold's console-side confirmation (AC-1).
///
/// **The second test (AC-3) is a real credential-hygiene gate, not a shape
/// check.** R-2 chose Demo Mode over a dedicated test account specifically
/// so no reviewer credential would ever need to exist. This test proves that
/// choice held: no password-shaped or bare-email-shaped literal (the
/// signature of a real account) appears anywhere in the App content /
/// App access sections this task added.
void main() {
  final setupDoc = File('../docs/GOOGLE_PLAY_ACCOUNT_SETUP.md');

  test('the App content declarations section exists', () {
    expect(setupDoc.existsSync(), isTrue,
        reason: 'GOOGLE_PLAY_ACCOUNT_SETUP.md is the recorded home of the '
            'Play account state');
    final content = setupDoc.readAsStringSync();
    expect(content, contains('App content declarations (as submitted)'),
        reason: 'GP-18 records every App content checklist answer here so '
            'the next submission re-verifies from this document instead of '
            're-deriving from memory');
  });

  test('every required App content checklist item is present by name '
      '(R-1: conditional items answered, never skipped)', () {
    final content = setupDoc.readAsStringSync();

    // Each of these is a distinct checklist item Play's App content section
    // asks about. A missing heading here means that item was never answered
    // at all -- the exact "conditional item skipped" failure R-1 calls out.
    const requiredItems = <String>[
      'Content rating questionnaire',
      'Target audience and content',
      'Ads declaration',
      'Government apps',
      'Financial features',
      'News app',
      'Health apps',
    ];

    final missing = <String>[];
    for (final item in requiredItems) {
      if (!content.contains(item)) {
        missing.add(item);
      }
    }
    expect(missing, isEmpty,
        reason: 'the following required App content checklist item(s) have '
            'no recorded section, which means they were never answered: '
            '$missing');
  });

  test('conditional items are recorded as answered, not left blank', () {
    // R-1 draws a specific distinction: a conditional item must be answered
    // "not applicable" / "No", never left as a bare heading with no answer
    // column filled in. Checking for the literal answer word next to each
    // topic is a coarse but real proxy for "this was actually answered".
    final content = setupDoc.readAsStringSync();

    final declarationsStart =
        content.indexOf('App content declarations (as submitted)');
    expect(declarationsStart, greaterThan(-1));
    final accessStart = content.indexOf('## App access');
    expect(accessStart, greaterThan(declarationsStart));
    final section = content.substring(declarationsStart, accessStart);

    // Government/financial/news/health are the conditional items R-1 names
    // explicitly. Each must carry an explicit "No" answer in its QUESTION
    // ROW (the table data row, not the section heading, which also contains
    // the topic word and would otherwise match first).
    for (final questionText in [
      'Is this a government app?',
      'Does the app provide financial services',
      'Is this a news app?',
      'Does the app provide health-related services',
    ]) {
      final questionIndex = section.indexOf(questionText);
      expect(questionIndex, greaterThan(-1),
          reason: 'expected to find the question row "$questionText"');
      // The answer column ("No") appears on the same table row, shortly
      // after the question text.
      final windowEnd = (questionIndex + 120).clamp(0, section.length);
      final window = section.substring(questionIndex, windowEnd);
      expect(window.contains('| No |'), isTrue,
          reason: 'the "$questionText" row must record an explicit No '
              'answer, not an empty cell -- R-1 requires conditional items '
              'to be ANSWERED as not-applicable, never skipped. Found: '
              '"$window"');
    }
  });

  test('the Ads declaration matches what pubspec.yaml actually declares', () {
    final content = setupDoc.readAsStringSync();
    final adsIndex = content.indexOf('### Ads declaration');
    expect(adsIndex, greaterThan(-1));
    final adsSection = content.substring(adsIndex, adsIndex + 800);
    expect(adsSection.contains('| No |'), isTrue,
        reason: 'the Ads declaration must record No, not an empty cell');

    // Check the FACT, not the document's claim about itself.
    //
    // This assertion previously required the justification prose to contain
    // the phrase "verified by grep". That is a document asserting its own
    // diligence: it passes if somebody types the phrase without running
    // anything, and it never touches the thing that actually determines the
    // answer. Concrete failure it would have missed (Sprint 65 Phase 5.1.1
    // review): someone adds google_mobile_ads to pubspec.yaml, the
    // declaration still reads No, the prose still says "verified by grep",
    // the gate stays green, and a FALSE "contains ads: No" ships to Play.
    //
    // So read the dependency manifest instead. If an ad SDK ever appears,
    // this fails and the declaration has to be revisited -- which is the
    // whole point of a gate.
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    const adSdkMarkers = [
      'google_mobile_ads',
      'admob',
      'applovin',
      'unity_ads',
      'facebook_audience_network',
      'ironsource',
      'appodeal',
    ];
    for (final marker in adSdkMarkers) {
      expect(pubspec.contains(marker), isFalse,
          reason: 'pubspec.yaml declares "$marker", but the Play Ads '
              'declaration records "No". One of the two is wrong, and a '
              'false ads declaration is a compliance defect. Either remove '
              'the dependency or change the declaration to Yes and complete '
              "Play's ads questionnaire.");
    }
  });

  test('the App access section exists with step-by-step reviewer '
      'instructions naming the exact on-screen text', () {
    final content = setupDoc.readAsStringSync();
    final accessIndex = content.indexOf('## App access');
    expect(accessIndex, greaterThan(-1),
        reason: 'GP-18 R-2 requires a recorded App access decision and '
            'instructions, not just the content declarations');
    final accessSection = content.substring(accessIndex);

    // The instructions must name the EXACT on-screen text a reviewer taps,
    // per the task's own requirement -- a paraphrase would leave a reviewer
    // unable to find the button.
    //
    // "Try Demo Mode instead" is listed SEPARATELY from "Try Demo Mode", and
    // that is the point rather than redundancy. There are two Demo Mode
    // entry points with DIFFERENT labels: the zero-account screen offers
    // "Try Demo Mode instead" (empty_state.dart), while the provider screen
    // offers a "Try Demo Mode" card (platform_selection_screen.dart). A
    // fresh install -- which is exactly what a Play reviewer gets -- lands on
    // the FORMER.
    //
    // Sprint 65 Manual Validation caught the instructions naming only the
    // provider-screen label and asserting the first screen was "Select Email
    // Provider", which a fresh install never shows. This gate did not catch
    // it because "Try Demo Mode" is a SUBSTRING of "Try Demo Mode instead",
    // so the assertion passed while the instructions were wrong. Requiring
    // the longer string too closes that hole.
    for (final exactText in [
      'Try Demo Mode instead',
      'Try Demo Mode',
      'Start Demo Scan (Testing)',
      'No Accounts Yet',
    ]) {
      expect(accessSection, contains(exactText),
          reason: 'the App access instructions must name the exact '
              'on-screen text "$exactText" a reviewer taps, not a '
              'paraphrase of it');
    }
  });

  test('R-2 decision and R-3 on-device walk are both recorded', () {
    final content = setupDoc.readAsStringSync();
    expect(content, contains('R-2'),
        reason: 'the App access decision (option a vs b) must be recorded, '
            'not left implicit');
    expect(content, contains('R-3: end-to-end reviewer-path walk'),
        reason: 'R-3 requires the reviewer path to be WALKED on a real '
            'device before submission, not assumed from the source trace '
            'alone -- this must have a recorded place to capture that');
  });

  test('AC-3: no credential-shaped literal exists anywhere in the App '
      'content / App access sections', () {
    // R-2 chose Demo Mode specifically so no reviewer credential would ever
    // need to exist. This proves that decision held in the document: no
    // password-shaped literal, and no bare personal-looking email address
    // (distinct from the app's own published contact addresses, which are
    // deliberately public and already covered by GP-16's own section).
    final content = setupDoc.readAsStringSync();
    final declarationsStart =
        content.indexOf('App content declarations (as submitted)');
    expect(declarationsStart, greaterThan(-1));
    // End the scanned range at whichever GP-19 section comes first. Sprint 66
    // inserted "Tester onboarding instructions" between the declarations and
    // the roster, and the original end-anchor silently swallowed it.
    final endCandidates = [
      content.indexOf('Tester onboarding instructions'),
      content.indexOf('Closed-test tester roster'),
    ].where((i) => i > declarationsStart);
    expect(endCandidates, isNotEmpty,
        reason: 'could not find a section boundary after the App content '
            'declarations -- update this gate rather than widening its range');
    final section =
        content.substring(declarationsStart, endCandidates.reduce((a, b) => a < b ? a : b));

    // Look for a credential VALUE, not the WORDS for one.
    //
    // The original list included the bare phrases "app password" and "App
    // Password", which made the gate unable to tell "a tester must create an
    // app password" from an actual pasted secret. GP-19's tester instructions
    // use that phrase legitimately dozens of times -- the gate fired on
    // correct documentation, which is a false positive that trains people to
    // weaken gates.
    //
    // The real leak shape is an assignment: a key that names a secret,
    // followed by a value. That is what these patterns match, and it is what
    // the App access decision (Demo Mode over a test account) exists to keep
    // out of this file.
    final credentialPatterns = <RegExp>[
      // Dart's RegExp has no inline (?i) flag -- use caseSensitive: false.
      RegExp(r'\b(password|passwd|pwd|secret|token|api[_ ]?key)\s*[:=]\s*\S+',
          caseSensitive: false),
      RegExp(r'\bapp[- ]password\s*[:=]\s*\S+', caseSensitive: false),
    ];
    final foundMarkers = credentialPatterns
        .map((p) => p.firstMatch(section)?.group(0))
        .where((m) => m != null)
        .toList();
    expect(foundMarkers, isEmpty,
        reason: 'the App content / App access sections must never carry a '
            'credential VALUE -- found: $foundMarkers. This is exactly the '
            'leak that choosing Demo Mode over a test account avoids. Note '
            'this matches an assignment, not the words: documentation may '
            'freely SAY "app password" while never containing one.');

    // Bare email-address shape, EXCLUDING addresses this test can prove are
    // NOT a reviewer credential: the developer's own already-public address
    // (recorded and reasoned about elsewhere in this same file under
    // ACCOUNT CREATED), the RFC 2606 reserved example.com domain, and any
    // address that is one of the app's OWN hardcoded Demo Mode sample
    // senders (mock_email_data.dart) -- these are fictional decoy addresses
    // quoted here as evidence for the R-2 decision, already public in
    // tracked source, and never anything a reviewer would authenticate
    // with.
    final mockDataContent =
        File('lib/core/services/mock_email_data.dart').readAsStringSync();

    final emailShape = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
    final matches = emailShape
        .allMatches(section)
        .map((m) => m.group(0)!)
        .where((email) =>
            email != 'myemailspamfilter.dev@gmail.com' &&
            !email.endsWith('@example.com') &&
            !mockDataContent.contains(email))
        .toList();
    expect(matches, isEmpty,
        reason: 'an email address other than the already-approved public '
            'developer address, an @example.com illustrative address, or a '
            'known Demo Mode sample sender was found in the App content / '
            'App access sections -- this could be an accidentally-recorded '
            'reviewer credential. Found: $matches');
  });
}
