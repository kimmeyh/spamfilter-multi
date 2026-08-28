// SEC-9 (Sprint 64) policy gate: the Android OAuth client id literal must
// not reappear in gradle or Dart source outside the gitignored secrets
// files. Previously it was hardcoded in THREE places:
//   1. android/app/build.gradle.kts:43 (appAuthRedirectScheme placeholder)
//   2. android/app/src/main/AndroidManifest.xml:39 (redirect intent-filter
//      scheme -- this literal made the gradle placeholder above dead code;
//      SEC-9 both sources the value AND wires the placeholder into use)
//   3. lib/adapters/email_providers/gmail_windows_oauth_handler.dart
//      (_androidClientId and the derived _mobileRedirectUri)
//
// SEC-9 moved sourcing to build-time injection (gradle property +
// --dart-define, both fed from secrets.*.json's ANDROID_GMAIL_CLIENT_ID key
// -- a single source of truth). This gate is the F119-style regression pin:
// if the literal id fragment reappears in any of these files, the sourcing
// has regressed back to a hardcoded literal.
//
// The id itself is NOT a secret (it ships in every APK/manifest by nature --
// see the card's non-functional-requirements note) -- this gate is about
// MAINTAINABILITY (one place to change per flavor/environment), not
// concealment. secrets.*.json files are gitignored and deliberately NOT
// scanned; the template file uses a placeholder value, never the real id.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android OAuth client id project-number fragment. Matching on the
/// project-number prefix (not the full id) catches both the exact current id
/// AND any other real id from the same GCP project that might get pasted in
/// by mistake during a future edit.
const _idFragment = '577022808534';

/// Files that must NOT contain the literal fragment after SEC-9.
const _bannedSites = <String>[
  'android/app/build.gradle.kts',
  'android/app/src/main/AndroidManifest.xml',
];

void main() {
  group('Android OAuth client id sourcing (SEC-9)', () {
    for (final path in _bannedSites) {
      test('$path does not hardcode the client id fragment', () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist.');
        final content = file.readAsStringSync();
        expect(
          content.contains(_idFragment),
          isFalse,
          reason: 'SEC-9: $path hardcodes the Android OAuth client id '
              'fragment ($_idFragment). The id must be sourced from a '
              'gradle property (androidGmailClientId) or a manifest '
              'placeholder (\${appAuthRedirectScheme}), never a literal.',
        );
      });
    }

    test('every lib/**/*.dart file is free of the client id fragment', () {
      final offenders = <String>[];
      final libDir = Directory('lib');
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        if (content.contains(_idFragment)) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'SEC-9: the following lib/ Dart file(s) hardcode the '
            'Android OAuth client id fragment ($_idFragment): $offenders. '
            'The id must be sourced via String.fromEnvironment '
            '(ANDROID_GMAIL_CLIENT_ID), never a literal.',
      );
    });

    test('build.gradle.kts sources the id from the androidGmailClientId '
        'gradle property', () {
      final content = File('android/app/build.gradle.kts').readAsStringSync();
      expect(content, contains('androidGmailClientId'),
          reason: 'SEC-9: build.gradle.kts must read the gradle property '
              'androidGmailClientId (set by build-with-secrets.ps1 via '
              '-PandroidGmailClientId, fed from secrets.*.json).');
      expect(content, contains('appAuthRedirectScheme'),
          reason: 'SEC-9: the manifestPlaceholder must still be set so the '
              'manifest\'s \${appAuthRedirectScheme} placeholder resolves.');
    });

    test('build.gradle.kts fails a RELEASE build loudly when the property '
        'is missing (R-4 / F119 lesson)', () {
      final content = File('android/app/build.gradle.kts').readAsStringSync();
      expect(content, contains('GradleException'),
          reason: 'SEC-9 R-4: a missing androidGmailClientId must fail a '
              'release build with an actionable GradleException, not '
              'compile with an empty/placeholder redirect scheme.');
      expect(content, contains('isReleaseBuild'),
          reason: 'SEC-9: the loud-fail must be conditioned on the build '
              'being a release build (CI\'s debug Android-build-verification '
              'job passes no client-id property per the F127 decision and '
              'must keep compiling with a warning, not fail).');
    });

    test('AndroidManifest.xml wires the redirect scheme through the '
        'gradle-fed placeholder', () {
      final content = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(content, contains(r'${appAuthRedirectScheme}'),
          reason: 'SEC-9: the manifest intent-filter scheme must reference '
              'the gradle placeholder, not a literal -- otherwise the '
              'placeholder set in build.gradle.kts is dead code.');
    });

    test('gmail_windows_oauth_handler.dart sources the Android client id '
        'via String.fromEnvironment(ANDROID_GMAIL_CLIENT_ID)', () {
      final content = File(
              'lib/adapters/email_providers/gmail_windows_oauth_handler.dart')
          .readAsStringSync();
      expect(content, contains('String.fromEnvironment('),
          reason: 'SEC-9: _androidClientId must be injected via '
              '--dart-define(-from-file), mirroring the Windows _clientId '
              'pattern.');
      expect(content, contains("'ANDROID_GMAIL_CLIENT_ID'"),
          reason: 'SEC-9: the dart-define key must be ANDROID_GMAIL_CLIENT_ID.');
      expect(content, contains('static const String _androidClientId'),
          reason: 'SEC-9: _androidClientId must be a compile-time const '
              '(String.fromEnvironment requires const context).');
    });

    test('secrets.dev.json.template documents ANDROID_GMAIL_CLIENT_ID with '
        'a placeholder value, not the real id', () {
      final content = File('secrets.dev.json.template').readAsStringSync();
      expect(content, contains('ANDROID_GMAIL_CLIENT_ID'),
          reason: 'SEC-9: the template must document the key so a new '
              'developer knows to fill it in.');
      expect(
        content.contains(_idFragment),
        isFalse,
        reason: 'SEC-9: the template must use a placeholder value, never '
            'the real client id -- the template is a tracked, non-gitignored '
            'file.',
      );
    });
  });
}
