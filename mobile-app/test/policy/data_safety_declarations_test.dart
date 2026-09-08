import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'section_scope.dart';

/// GP-10 Data safety declarations policy gate (Sprint 65, Issue #380).
///
/// **What this protects.** Play's Data safety form and the published privacy
/// policy describe the same underlying app behaviour (shared Dart code), so
/// the two texts must never disagree. A wrong "does not collect" answer in
/// either place is a policy violation, not a typo, and the kind of drift that
/// rots silently once both documents exist as plain repo text with nobody
/// re-reading them side by side.
///
/// This gate is structural, per `feedback_source_gates_verify_shape`: it
/// proves the recorded declarations section exists and that its specific,
/// checkable factual claims (the body-preview cap, the "no sharing" claim,
/// the deletion claim) do not contradict `docs/legal/PRIVACY_POLICY.md`. It
/// cannot verify that Play Console itself was filled in correctly -- that is
/// Harold's console-side confirmation (AC-1 / the task's Definition of Done).
void main() {
  final setupDoc = File('../docs/GOOGLE_PLAY_ACCOUNT_SETUP.md');
  final privacyPolicyDoc = File('../docs/legal/PRIVACY_POLICY.md');

  test('the Data safety declarations section exists', () {
    expect(setupDoc.existsSync(), isTrue,
        reason: 'GOOGLE_PLAY_ACCOUNT_SETUP.md is the recorded home of the '
            'Play account and submission state');
    final content = setupDoc.readAsStringSync();
    expect(content, contains('Data safety declarations (as submitted)'),
        reason: 'GP-10 records the submitted declarations here so the next '
            'submission re-verifies against code instead of re-deriving '
            'answers from memory');
  });

  test('the declarations record the privacy policy URL used on the form', () {
    final content = setupDoc.readAsStringSync();
    expect(content, contains('https://myemailspamfilter.com/legal/PRIVACY_POLICY.html'),
        reason: 'R-3 requires the published privacy policy URL to be linked '
            'from the Data safety form; the recorded URL must match the one '
            'the privacy policy itself publishes');
  });

  test('the declarations cover every mandatory Play data category', () {
    final content = setupDoc.readAsStringSync();
    const categories = <String>[
      'Personal info',
      'Financial info',
      'Location',
      'Email and other messages',
      'Photos/videos',
      'Files/docs',
      'Contacts',
      'App activity',
      'App info and performance',
      'Device or other IDs',
    ];
    final missing = categories.where((c) => !content.contains(c)).toList();
    expect(missing, isEmpty,
        reason: 'every Play Data safety category must be explicitly '
            'answered (collected or not) -- an unaddressed category is an '
            'incomplete declaration, not a "no" by default. Missing: $missing');
  });

  test('the body-preview retention claim matches the privacy policy exactly', () {
    final setupContent = setupDoc.readAsStringSync();
    final policyContent = privacyPolicyDoc.readAsStringSync();

    // The privacy policy states the exact cap in prose; the Data safety
    // section must cite the same number. A drifted number here (e.g. someone
    // raises kBodyPreviewMaxLength without updating the doc) is exactly the
    // silent-rot case R-2/AC-3 exists to catch.
    expect(policyContent, contains('at most 100 characters'),
        reason: 'this test assumes the privacy policy states the 100-char '
            'body preview cap; if this fails, the privacy policy wording '
            'changed and the Data safety section below must be re-checked '
            'against the new wording');
    expect(setupContent, contains('100 characters'),
        reason: 'the Data safety declarations must cite the same body '
            'preview cap the privacy policy promises publicly');
  });

  test('the "no data sharing" claim agrees between both documents', () {
    final setupContent = setupDoc.readAsStringSync();
    final policyContent = privacyPolicyDoc.readAsStringSync();

    expect(policyContent, contains('We share data with no one'),
        reason: 'this test assumes the privacy policy\'s current no-sharing '
            'wording; if this fails, re-check the Data safety section '
            'against the new wording');

    final dataSafetySection =
        sectionFrom(setupContent, 'Data safety declarations (as submitted)');
    expect(dataSafetySection, isNotNull,
        reason: 'the Data safety declarations section is missing');
    expect(dataSafetySection, contains('No data is shared with any third party'),
        reason: 'the Data safety section must assert no sharing in every '
            'category, matching the privacy policy\'s "We share data with '
            'no one"');
  });

  test('the deletion claim agrees between both documents', () {
    // Markdown source wraps this sentence across lines in the privacy
    // policy, so whitespace is normalized to a single space before matching
    // -- otherwise a harmless line-wrap edit would falsely trip this gate.
    String normalizeWhitespace(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

    final setupContent = normalizeWhitespace(setupDoc.readAsStringSync());
    final policyContent = normalizeWhitespace(privacyPolicyDoc.readAsStringSync());
    const deletionClaim =
        "deletes that account's credentials, scan history, and settings";

    expect(policyContent, contains(deletionClaim),
        reason: 'this test assumes the privacy policy\'s current account '
            'deletion wording; if this fails, re-check the Data safety '
            'section against the new wording');

    final dataSafetySection =
        sectionFrom(setupContent, 'Data safety declarations (as submitted)');
    expect(dataSafetySection, isNotNull,
        reason: 'the Data safety declarations section is missing');
    expect(dataSafetySection, contains(deletionClaim),
        reason: 'the Data safety section must record the same deletion '
            'behaviour the privacy policy promises publicly -- a mismatch '
            'here means Play would be told a different deletion story than '
            'the public policy tells users');
  });

  test('the Data safety section does not claim collection the privacy policy denies', () {
    // A contradiction that matters most in practice: claiming to collect a
    // category the privacy policy's "short version" explicitly denies
    // collecting anything beyond email access. Financial info and Location
    // are categories with no supporting code path at all (no payment SDK,
    // no geolocation package) -- if either flips to "collected" here without
    // the privacy policy being updated first, that is the exact drift this
    // gate exists to catch.
    final setupContent = setupDoc.readAsStringSync();
    final dataSafetyStart = setupContent.indexOf('Data safety declarations (as submitted)');
    final nextSectionStart = setupContent.indexOf('\n## ', dataSafetyStart + 1);
    final dataSafetySection = nextSectionStart > -1
        ? setupContent.substring(dataSafetyStart, nextSectionStart)
        : setupContent.substring(dataSafetyStart);

    // Captures ONLY the "Collected" column (the text between the category
    // name's closing pipe and the very next pipe) -- an earlier version of
    // this regex used a greedy `[^\n]*` up to the LAST pipe on the line,
    // which matched the whole row and could pass even when the Collected
    // column itself said "Yes" (the word "No" still appeared later in the
    // row, in the Shared column). Mutation-verified: flipping Collected to
    // "Yes" now fails this check as intended.
    final financialRow =
        RegExp(r'\| Financial info \|([^|]*)\|').firstMatch(dataSafetySection);
    final locationRow =
        RegExp(r'\| Location \|([^|]*)\|').firstMatch(dataSafetySection);
    expect(financialRow, isNotNull, reason: 'Financial info row must exist');
    expect(locationRow, isNotNull, reason: 'Location row must exist');
    expect(financialRow!.group(1)!.trim(), equals('No'),
        reason: 'no payment/billing code exists in the app; Financial info '
            'Collected column must be declared No');
    expect(locationRow!.group(1)!.trim(), equals('No'),
        reason: 'no location permission or geolocation package exists in '
            'the app; Location Collected column must be declared No');
  });
}
