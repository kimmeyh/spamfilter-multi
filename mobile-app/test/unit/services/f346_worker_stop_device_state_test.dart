/// F346 (Sprint 86, Issue #582): the line written when WorkManager stops the
/// background worker also names the phone's power-save, device-idle and
/// thermal state, so a `reason=deviceState raw=4` stop can be explained.
///
/// ADR-0042: Android only (declared exception). Windows has no stop event;
/// workmanager_apple 0.9.11 never calls `onTaskStopped` from its BGTask
/// expiration handlers (`WorkmanagerPlugin.swift:524`).
///
/// What these tests do NOT catch: whether the channel is registered on the
/// WorkManager background engine on a real phone (the host test fakes the
/// reader; a `powerSave=` value other than `unknown` in a phone log, or the
/// Task 7 emulator run, proves it), and whether the Kotlin plugin reads the
/// right PowerManager property.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart' show StopReason;

import 'package:my_email_spam_filter/core/services/android_background_scan_worker.dart';
import 'package:my_email_spam_filter/core/services/android_device_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F346 device state on a worker stop', () {
    test('the stop line carries powerSave=, deviceIdle= and thermal= values',
        () async {
      // Does NOT catch: a phone whose reader returns a different shape.
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.fromRawValue(4),
          write: (d) async => lines.add(d),
          closeScans: () async => 0,
          readDeviceState: () async =>
              {'powerSave': true, 'deviceIdle': false, 'thermal': 'severe'});
      expect(lines, hasLength(1));
      expect(lines.single, contains('reason=deviceState raw=4'));
      expect(lines.single,
          endsWith('powerSave=true deviceIdle=false thermal=severe'));
    });

    test('a reader that throws logs unknown for each value and completes',
        () async {
      // Does NOT catch: a reader that throws synchronously outside the
      // future (the production reader is an async channel call).
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.fromRawValue(4),
          write: (d) async => lines.add(d),
          closeScans: () async => 0,
          readDeviceState: () async => throw StateError('no channel'));
      expect(lines.single,
          endsWith('powerSave=unknown deviceIdle=unknown thermal=unknown'));
    });

    test('a reader that never answers times out and the row closes first',
        () async {
      // Does NOT catch: a slow reader on a phone that answers at 400 ms (the
      // line is then still written, only later).
      final order = <String>[];
      final lines = <String>[];
      final sw = Stopwatch()..start();
      await onWorkerStopped('t', StopReason.fromRawValue(4),
          write: (d) async {
            order.add('write');
            lines.add(d);
          },
          closeScans: () async {
            order.add('close');
            return 1;
          },
          readDeviceState: () => Completer<Object?>().future);
      expect(order.first, 'close');
      expect(lines.first,
          endsWith('powerSave=unknown deviceIdle=unknown thermal=unknown'));
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('a value the phone cannot give reads unknown, not missing', () async {
      // Does NOT catch: a Kotlin field that returns a wrong but valid value.
      expect(
          await describeDeviceState(
              reader: () async =>
                  {'powerSave': null, 'deviceIdle': true, 'thermal': null}),
          'powerSave=unknown deviceIdle=true thermal=unknown');
      expect(await describeDeviceState(reader: () async => 'not a map'),
          'powerSave=unknown deviceIdle=unknown thermal=unknown');
    });

    test('with no seam and no channel (host) the default path reads unknown',
        () async {
      // Proves the production default path swallows MissingPluginException,
      // which is what the background engine would raise without the plugin.
      // Does NOT catch: the plugin being registered on a real phone.
      expect(await describeDeviceState(),
          'powerSave=unknown deviceIdle=unknown thermal=unknown');
    });
  });
}
