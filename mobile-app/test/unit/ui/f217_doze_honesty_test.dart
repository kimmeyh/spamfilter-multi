/// F217 (Sprint 72): the app must not imply background scans are reliable when
/// the OS does not guarantee it.
///
/// **Harold's report**: *"from experience, it is very frustrating to a user
/// that Android background jobs only run when the app is open and in view. This
/// completely renders 'background' jobs as useless."*
///
/// **The mechanism is documented, not guessed.** Android's own guidance states
/// that Doze *"doesn't let JobScheduler run"*, and WorkManager uses
/// JobScheduler internally, so periodic work is deferred to maintenance
/// windows. This app schedules with only a `networkType: connected`
/// constraint, so nothing in our own configuration defers the work -- which is
/// what makes the OS the cause rather than our scheduling.
///
/// **Why this ships before the remedy is decided.** Whether to request a
/// battery-optimization exemption is an open question with a Play-policy
/// dimension (Google restricts that permission to apps whose CORE FUNCTION is
/// broken by Doze). Honest messaging is correct under every outcome, so it
/// lands first rather than waiting.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they prove the line
/// exists, is Android-gated, and does not over-promise. They CANNOT prove
/// background scans actually run more reliably -- that needs Harold's device
/// over real intervals, and it is the only evidence that matters for the
/// card's value.
/// SOURCE-TEXT VERIFIED: these assert the CAVEAT TEXT exists and says what it
/// should. They cannot prove the caveat is true of the running OS, nor that a
/// user reads it before enabling background scans. What settles it is the S24+
/// over real Doze windows -- which is what F235 then measured at ~1 hour.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart'
    show kAndroidBackgroundNote;

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
  });

  group('F217: the Android timing caveat', () {
    test('the line exists and is keyed for testing', () {
      expect(source.contains("Key('android_doze_status_line')"), isTrue);
      expect(source.contains('_buildAndroidDozeStatusLine'), isTrue);
    });

    test('it is ANDROID-gated, not shown everywhere', () {
      // F264 (Sprint 77): the gate is now the screen's Android seam
      // (`showsAndroidBackgroundRows`, `debugIsAndroid ?? Platform.isAndroid`)
      // so a widget test can drive both branches; the real check is unchanged.
      expect(
          source.contains('if (SettingsScreen.showsAndroidBackgroundRows &&\n'
              '            _backgroundScanEnabled)\n'
              '          _buildAndroidDozeStatusLine(),'),
          isTrue,
          reason: 'Windows has no Doze equivalent -- showing this there would '
              'be wrong, not merely redundant');
      expect(
          source.contains(
              'debugIsAndroid ?? Platform.isAndroid'),
          isTrue,
          reason: 'the seam must fall back to the real platform');
    });

    test('it is shown only when background scanning is ON', () {
      final idx = source.indexOf('_buildAndroidDozeStatusLine(),');
      final before = source.substring(idx - 120, idx);
      expect(before.contains('_backgroundScanEnabled'), isTrue,
          reason: 'a caveat about a feature the user has not enabled is noise');
    });

    test('it does NOT promise a fix', () {
      for (final overclaim in [
        'will always run',
        'guaranteed',
        'exactly on time',
      ]) {
        expect(kAndroidBackgroundNote.contains(overclaim), isFalse,
            reason: 'the remedy is still an open decision; this line must be '
                'true under every outcome of it');
      }
    });

    test('it explains what the user can DO', () {
      expect(kAndroidBackgroundNote.contains('Opening the app runs any work '
          'that was waiting.'), isTrue,
          reason: 'a caveat with no remedy is just bad news; the '
              'frustration was the uselessness, not the delay');
    });

    test('F264 Q12: the note is EXACTLY the Product Owner\'s wording', () {
      expect(
          kAndroidBackgroundNote,
          'Android runs background scans when the phone allows. While the '
          'phone is idle, expect up to about 45 minutes between scans, even '
          'with a shorter interval. Opening the app runs any work that was '
          'waiting.');
    });

    test('F264 AC-11: the old "about an hour" sentence is gone from lib/ui and '
        'the note is built once', () {
      // What this does NOT catch: the claim reworded elsewhere (Help content
      // is covered by help_platform_claims_test).
      for (final f in Directory('lib/ui').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final text = f.readAsStringSync();
        // Doc comments may quote the replaced sentence; code strings must not.
        final code = text.split('\n').where((l) => !l.trimLeft().startsWith('//'));
        expect(code.any((l) => l.contains('up to about an hour')), isFalse,
            reason: '${f.path} still carries the F217 sentence');
      }
      expect('_buildAndroidDozeStatusLine(),'.allMatches(source).length, 1,
          reason: 'one call site -> the note appears once');
      expect('kAndroidBackgroundNote'.allMatches(source).length, greaterThan(0));
    });

    test('F243: the Windows "pause while this app is open" texts are gone',
        () {
      // F243 (Sprint 75): Windows background scans now RUN while the app is
      // open (the per-account scan claim decides), so both Windows texts that
      // said they pause -- this file's former sibling line and the Scan
      // History hint -- would now be false claims to the user.
      //
      // What this does NOT catch: the same claim reworded and reintroduced
      // somewhere else (Help content is checked separately by
      // help_platform_claims_test).
      final history =
          File('lib/ui/screens/scan_history_screen.dart').readAsStringSync();
      for (final src in [source, history]) {
        expect(src.contains('pause while this app is open'), isFalse);
        expect(src.contains("Key('background_deferral_status_line')"), isFalse);
        expect(src.contains("Key('scan_history_deferral_hint')"), isFalse);
      }
    });
  });

  group('F217: our own scheduling is not the cause', () {
    test('the periodic task constrains only network, not battery or idle', () {
      final scheduler =
          File('lib/core/services/background_scan_scheduler.dart')
              .readAsStringSync();

      expect(scheduler.contains('Constraints(networkType: NetworkType.connected)'),
          isTrue);
      expect(scheduler.contains('requiresBatteryNotLow: true'), isFalse,
          reason: 'a battery constraint of OURS would defer the work and would '
              'be the cheap explanation -- it is absent, which is what makes '
              'the OS the cause');
      expect(scheduler.contains('requiresDeviceIdle: true'), isFalse,
          reason: 'same argument: an idle constraint would be our own doing');
    });
  });
}
