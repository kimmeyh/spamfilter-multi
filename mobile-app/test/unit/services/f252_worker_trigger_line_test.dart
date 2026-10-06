/// F252 (Sprint 76): the Android worker's start line names what started it,
/// and for the Doze alarm how long Android held the scan back afterwards.
///
/// What this does NOT catch: whether Android actually DELIVERS the alarm or
/// releases the work while idle -- that is the R-6 measurement on the Fold,
/// which is the point of having the line. The Kotlin side is covered here only
/// by source parity (the keys and the fire-time capture); there is no JVM test
/// harness in this project.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/background_scan_trigger.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1000000000);

  group('describeBackgroundTrigger', () {
    test('an alarm-started worker reads doze-alarm with the delay in seconds',
        () {
      final line = describeBackgroundTrigger(
        isTest: false,
        inputData: {
          'accountId': 'a',
          kTriggerSourceKey: 'doze-alarm',
          kTriggerAtMsKey: now.millisecondsSinceEpoch - 42400,
        },
        now: now,
      );
      expect(line, 'trigger=doze-alarm delay=42s');
    });

    test('a periodic worker (account id only) reads periodic', () {
      expect(
          describeBackgroundTrigger(
              isTest: false, inputData: {'accountId': 'a'}, now: now),
          'trigger=periodic');
      expect(describeBackgroundTrigger(isTest: false, inputData: null, now: now),
          'trigger=periodic');
    });

    test('the Settings test button reads test, whatever the payload', () {
      expect(
          describeBackgroundTrigger(
              isTest: true,
              inputData: {kTriggerSourceKey: 'doze-alarm'},
              now: now),
          'trigger=test');
    });

    test('a fire time AFTER now is reported as unknown, not as a delay', () {
      final line = describeBackgroundTrigger(
        isTest: false,
        inputData: {
          kTriggerSourceKey: 'doze-alarm',
          kTriggerAtMsKey: now.millisecondsSinceEpoch + 5000,
        },
        now: now,
      );
      expect(line, 'trigger=doze-alarm delay=unknown (clock changed)');
    });

    test('a source with no fire time names the source without a delay', () {
      expect(
          describeBackgroundTrigger(
              isTest: false,
              inputData: {kTriggerSourceKey: 'notification'},
              now: now),
          'trigger=notification');
    });
  });

  group('Kotlin parity (source)', () {
    final trigger = File(
            'android/app/src/main/kotlin/com/myemailspamfilter/DozeScanTrigger.kt')
        .readAsStringSync();
    final scheduler = File(
            'android/app/src/main/kotlin/com/myemailspamfilter/DozeAlarmScheduler.kt')
        .readAsStringSync();

    test('the payload keys match the Dart constants', () {
      // SOURCE-TEXT VERIFIED: the Kotlin payload keys are compile-time
      // literals with no Dart-side runtime; a drift would make every alarm
      // worker log trigger=periodic.
      String kotlinConst(String name) =>
          RegExp('$name\\s*=\\s*"([^"]+)"').firstMatch(trigger)!.group(1)!;
      expect(kotlinConst('KEY_TRIGGER_SOURCE'), kTriggerSourceKey);
      expect(kotlinConst('KEY_TRIGGER_AT_MS'), kTriggerAtMsKey);
    });

    test('F249 part 2 (Harold Q1 = 1): the Doze enqueue uses KEEP, never '
        'REPLACE -- REPLACE cancels a RUNNING scan', () {
      // SOURCE-TEXT VERIFIED: WorkManager's conflict policy is a device-only
      // behavior; the gate pins the policy literal on the alarm path.
      final code = trigger
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//[^\n]*'), '');
      expect(code.contains('ExistingWorkPolicy.REPLACE'), isFalse);
      expect('ExistingWorkPolicy.KEEP'.allMatches(code).length, 2,
          reason: 'both the Doze path and the new-mail path keep running work');
    });

    test('the receiver reads the clock before re-arming and passes it on', () {
      // SOURCE-TEXT VERIFIED: a BroadcastReceiver cannot run off a device; the
      // order is what makes the delay measure Android's hold-back.
      final clock = scheduler.indexOf('val firedAtMs = System.currentTimeMillis()');
      final rearm = scheduler
          .indexOf('DozeAlarmScheduler.schedule(context, accountId, interval)');
      expect(clock, greaterThan(-1));
      expect(clock, lessThan(rearm));
      expect(scheduler.contains('DozeScanTrigger.enqueue(context, accountId, firedAtMs)'),
          isTrue);
    });
  });
}
