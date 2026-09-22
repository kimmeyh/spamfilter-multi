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
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
      expect(
          source.contains('if (Platform.isAndroid && _backgroundScanEnabled)\n'
              '          _buildAndroidDozeStatusLine(),'),
          isTrue,
          reason: 'Windows has no Doze equivalent and already has its own '
              'deferral line -- showing this there would be wrong, not merely '
              'redundant');
    });

    test('it is shown only when background scanning is ON', () {
      final idx = source.indexOf('_buildAndroidDozeStatusLine(),');
      final before = source.substring(idx - 120, idx);
      expect(before.contains('_backgroundScanEnabled'), isTrue,
          reason: 'a caveat about a feature the user has not enabled is noise');
    });

    test('it does NOT promise a fix', () {
      final idx = source.indexOf('_buildAndroidDozeStatusLine');
      final body = source.substring(idx, idx + 2600);
      for (final overclaim in [
        'will always run',
        'guaranteed',
        'exactly on time',
      ]) {
        expect(body.contains(overclaim), isFalse,
            reason: 'the remedy is still an open decision; this line must be '
                'true under every outcome of it');
      }
    });

    test('it explains what the user can DO', () {
      final idx = source.indexOf('_buildAndroidDozeStatusLine');
      final body = source.substring(idx, idx + 2600);
      expect(body.contains('Opening the app runs any work that was waiting'),
          isTrue,
          reason: 'a caveat with no remedy is just bad news; the '
              'frustration was the uselessness, not the delay');
    });

    test('the Windows sibling is untouched', () {
      expect(source.contains("Key('background_deferral_status_line')"), isTrue,
          reason: 'the two lines are siblings, each describing the platform '
              'the user is actually on');
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
