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

  // The diagnostic log is ON for these tests (the read runs only then).
  Future<bool> logOn() async => true;

  group('F346 device state on a worker stop', () {
    test('with the diagnostic log OFF the device state is not read '
        '(PR #577 Copilot)', () async {
      // Does NOT catch: a log toggled on DURING the handler (read once).
      var reads = 0;
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.fromRawValue(4),
          write: (d) async => lines.add(d),
          closeScans: () async => 0,
          logEnabled: () async => false,
          readDeviceState: () async {
            reads++;
            return {'powerSave': true, 'deviceIdle': false, 'thermal': 'none'};
          });
      expect(reads, 0);
      expect(lines.single, endsWith('deviceState=not-read (diagnostic log off)'));
    });

    test('a log check that throws still reads the device state', () async {
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.fromRawValue(4),
          write: (d) async => lines.add(d),
          closeScans: () async => 0,
          logEnabled: () async => throw StateError('settings unreadable'),
          readDeviceState: () async =>
              {'powerSave': false, 'deviceIdle': true, 'thermal': 'none'});
      expect(lines.single,
          endsWith('powerSave=false deviceIdle=true thermal=none'));
    });

    test('the stop line carries powerSave=, deviceIdle= and thermal= values',
        () async {
      // Does NOT catch: a phone whose reader returns a different shape.
      final lines = <String>[];
      await onWorkerStopped('t', StopReason.fromRawValue(4),
          write: (d) async => lines.add(d),
          closeScans: () async => 0,
          logEnabled: logOn,
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
          logEnabled: logOn,
          readDeviceState: () async => throw StateError('no channel'));
      expect(lines.single,
          endsWith('powerSave=unknown deviceIdle=unknown thermal=unknown '
              'read=StateError'));
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
          logEnabled: logOn,
          readDeviceState: () => Completer<Object?>().future);
      expect(order.first, 'close');
      expect(lines.first,
          endsWith('powerSave=unknown deviceIdle=unknown thermal=unknown '
              'read=TimeoutException'));
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('the device-state read starts beside the row close, not after it '
        '(Sprint 86 7.7.1 M5)', () async {
      // Does NOT catch: the log write itself being slow (its own 2 s bound).
      final order = <String>[];
      await onWorkerStopped('t', StopReason.fromRawValue(4),
          write: (d) async {},
          closeScans: () async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            order.add('close-end');
            return 0;
          },
          logEnabled: logOn,
          readDeviceState: () async {
            order.add('read-start');
            return {'powerSave': false, 'deviceIdle': false, 'thermal': 'none'};
          });
      expect(order, ['read-start', 'close-end']);
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
      // Sprint 86 7.7.1 L7: the failure is named, so a field log can tell an
      // unregistered plugin from a value the phone cannot give.
      expect(await describeDeviceState(),
          'powerSave=unknown deviceIdle=unknown thermal=unknown '
          'read=MissingPluginException');
    });
  });
}
