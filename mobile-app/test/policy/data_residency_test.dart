import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Data-residency gate (GP-4, Sprint 66, Issue #388).
///
/// **What this protects.** The Gmail OAuth verification submission tells Google
/// that no Gmail-derived data ever leaves the user's device, and asks on that
/// basis for confirmation that the annual third-party security assessment does
/// not apply. That claim is the difference between roughly two weeks of
/// documentation and several weeks plus a recurring assessment fee.
///
/// A claim made to Google is not a comment -- it is a commitment that must stay
/// true for as long as the verification stands. The realistic way it stops
/// being true is not a deliberate decision but an ordinary one: somebody adds a
/// crash reporter to debug a hard bug, or an analytics package to answer a
/// product question. Both are reasonable engineering choices that silently
/// invalidate a filed compliance claim.
///
/// This gate makes that impossible to do quietly. If it fails, the right
/// response is usually NOT to delete the assertion -- it is to decide whether
/// the dependency is worth re-opening the verification for.
void main() {
  final pubspec = File('pubspec.yaml');

  test('no analytics, crash-reporting, or advertising dependency exists', () {
    final source = pubspec.readAsStringSync().toLowerCase();

    // Each of these transmits data off-device by design -- that IS their
    // function. Any one of them contradicts the submission.
    const offDeviceSdks = <String>[
      'firebase_analytics',
      'firebase_crashlytics',
      'crashlytics',
      'sentry',
      'amplitude',
      'mixpanel',
      'segment',
      'appsflyer',
      'google_mobile_ads',
      'admob',
      'datadog',
      'bugsnag',
      'posthog',
    ];

    final found = offDeviceSdks.where(source.contains).toList();

    expect(found, isEmpty,
        reason: 'pubspec.yaml declares $found, which transmits data '
            'off-device. The Gmail OAuth verification submission states that '
            'NO Gmail-derived data leaves the device, and asks Google to '
            'confirm the third-party security assessment does not apply on '
            'that basis (see the data-residency determination in '
            'docs/GOOGLE_PLAY_ACCOUNT_SETUP.md). Adding this dependency may '
            'invalidate a filed compliance claim. Do not simply remove this '
            'assertion -- decide whether the dependency is worth re-opening '
            'the verification for, and update the submission if it is.');
  });

  test('the data-residency determination is recorded with its evidence', () {
    // The determination is what the submission rests on. If it is missing, a
    // resubmission would re-derive it from memory -- which is exactly how a
    // compliance claim drifts from the code it describes.
    final setupDoc = File('../docs/GOOGLE_PLAY_ACCOUNT_SETUP.md');
    expect(setupDoc.existsSync(), isTrue);

    final content = setupDoc.readAsStringSync();
    expect(content, contains('data-residency determination'),
        reason: 'GP-4 records the determination and its code evidence here so '
            'the next submission verifies FROM the document rather than '
            're-deriving it');

    // The enumeration is the evidence. A determination asserting the
    // conclusion without listing the outbound hosts proves nothing -- that is
    // the "document asserting its own diligence" failure caught in Sprint 65.
    expect(content, contains('gmail.googleapis.com'),
        reason: 'the determination must ENUMERATE the outbound hosts, not '
            'merely assert the conclusion');
  });
}
