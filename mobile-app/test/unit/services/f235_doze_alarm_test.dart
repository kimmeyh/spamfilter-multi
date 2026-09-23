/// F235 (Sprint 73): background scans must fire while the device is in Doze.
///
/// **The defect.** WorkManager runs on JobScheduler, which Doze suspends, so
/// periodic scans frequently did not fire at all while the phone was idle.
/// Harold: *"background jobs only run when the app is open and in view. This
/// completely renders 'background' jobs as useless."*
///
/// **R-1, determined from Android's own documentation before any code was
/// written**: `setAndAllowWhileIdle()` fires in Doze with NO permission and no
/// Play policy exposure. Both exact variants need SCHEDULE_EXACT_ALARM or
/// USE_EXACT_ALARM and carry a justification burden. The cost is a ~1 hour
/// delivery window, which is still strictly better than not firing.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they pin the Dart
/// contract, the fallback behavior and the manifest. They CANNOT prove an
/// alarm actually fires while a real phone is dozing, nor that the schedule
/// survives a real reboot. Both need Harold's device over real intervals, and
/// they are the only evidence that matters for this card's VALUE.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/android_doze_alarm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F235: the Dart bridge', () {
    final calls = <MethodCall>[];

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidDozeAlarm.channel, null);
      calls.clear();
    });

    void mock(Future<Object?>? Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidDozeAlarm.channel, (call) {
        calls.add(call);
        return handler(call);
      });
    }

    test('schedule passes the account and interval through', () async {
      mock((_) async => true);

      final ok = await AndroidDozeAlarm.schedule(
        accountId: 'imap-user@example.com',
        intervalMinutes: 15,
      );

      expect(ok, isTrue);
      expect(calls.single.method, 'schedule');
      expect(calls.single.arguments['accountId'], 'imap-user@example.com');
      expect(calls.single.arguments['intervalMinutes'], 15);
    });

    test('THE FALLBACK: a missing native side returns false, never throws',
        () async {
      // This is the case that protects the user. If the channel is absent --
      // an older install, a unit test, a platform without the receiver -- the
      // caller must fall back to WorkManager. Throwing here would risk
      // disabling scheduling ENTIRELY, which is worse than the defect being
      // fixed.
      mock((_) async => throw MissingPluginException('no native side'));

      expect(
        await AndroidDozeAlarm.schedule(
            accountId: 'a', intervalMinutes: 15),
        isFalse,
      );
      expect(await AndroidDozeAlarm.cancel('a'), isFalse);
      expect(await AndroidDozeAlarm.isScheduled('a'), isFalse);
    });

    test('a PlatformException also degrades rather than throwing', () async {
      mock((_) async => throw PlatformException(code: 'ERR'));

      expect(
        await AndroidDozeAlarm.schedule(
            accountId: 'a', intervalMinutes: 15),
        isFalse,
      );
    });

    test('a null return is treated as failure, not success', () async {
      // The unhappy input: a native side that returns nothing. Treating null
      // as success would silently claim an alarm that was never armed.
      mock((_) async => null);

      expect(
        await AndroidDozeAlarm.schedule(
            accountId: 'a', intervalMinutes: 15),
        isFalse,
      );
    });

    test('cancel forwards the account id', () async {
      mock((_) async => true);

      expect(await AndroidDozeAlarm.cancel('imap-x@example.com'), isTrue);
      expect(calls.single.method, 'cancel');
      expect(calls.single.arguments['accountId'], 'imap-x@example.com');
    });
  });

  group('F235: the scheduler keeps WorkManager as a safety net', () {
    late String source;

    setUpAll(() {
      source = File('lib/core/services/background_scan_scheduler.dart')
          .readAsStringSync();
    });

    test('the alarm is armed AND the periodic task is still registered', () {
      expect(source.contains('AndroidDozeAlarm.schedule('), isTrue);
      expect(source.contains('registerPeriodicTask('), isTrue,
          reason: 'an alarm does NOT survive a reboot the way WorkManager '
              'persisted work does, so removing the periodic task would trade '
              'one failure mode for another');
    });

    test('a failed arming is reported, not swallowed', () {
      expect(source.contains('F235: Doze alarm not armed'), isTrue,
          reason: 'silent degradation is how the original defect went '
              'unnoticed for so long');
    });

    test('cancel tears the alarm down too', () {
      expect(source.contains('AndroidDozeAlarm.cancel('), isTrue,
          reason: 'an alarm left armed for a disabled account keeps waking the '
              'device -- the exact battery complaint this must not create');
    });
  });

  group('F235: the manifest', () {
    late String manifest;

    setUpAll(() {
      manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    });

    test('RECEIVE_BOOT_COMPLETED is declared', () {
      expect(
          manifest.contains(
              'android:name="android.permission.RECEIVE_BOOT_COMPLETED"'),
          isTrue,
          reason: 'without the boot receiver the schedule silently stops after '
              'every restart -- a regression against WorkManager');
    });

    test('NEITHER exact-alarm permission is declared', () {
      // The R-1 determination in one assertion. Both carry a Play
      // justification burden, and setAndAllowWhileIdle needs neither.
      expect(
          manifest.contains(
              'android:name="android.permission.SCHEDULE_EXACT_ALARM"'),
          isFalse);
      expect(
          manifest.contains(
              'android:name="android.permission.USE_EXACT_ALARM"'),
          isFalse);
    });

    test('both receivers are declared and NOT exported', () {
      expect(manifest.contains('android:name=".DozeAlarmReceiver"'), isTrue);
      expect(manifest.contains('android:name=".BootReceiver"'), isTrue);
      // Nothing outside the app has any business triggering a mail scan.
      final exported = RegExp(r'android:exported="true"').allMatches(manifest);
      final receiverBlock = manifest.substring(
          manifest.indexOf('.DozeAlarmReceiver') - 200,
          manifest.indexOf('.BootReceiver') + 400);
      expect(receiverBlock.contains('android:exported="false"'), isTrue);
      expect(exported.length, lessThanOrEqualTo(2),
          reason: 'only the launcher activity and the OAuth activity should be '
              'exported');
    });
  });

  group('F235: the native side uses the inexact call', () {
    test('setAndAllowWhileIdle, not setExactAndAllowWhileIdle', () {
      final kotlin = File(
              'android/app/src/main/kotlin/com/myemailspamfilter/DozeAlarmScheduler.kt')
          .readAsStringSync();

      expect(kotlin.contains('am.setAndAllowWhileIdle('), isTrue);
      expect(kotlin.contains('setExactAndAllowWhileIdle('), isFalse,
          reason: 'the exact variant needs a permission with a Play '
              'justification burden -- the whole point of R-1');
    });

    test('the alarm re-arms BEFORE running the scan', () {
      final kotlin = File(
              'android/app/src/main/kotlin/com/myemailspamfilter/DozeAlarmScheduler.kt')
          .readAsStringSync();

      final rearm = kotlin.indexOf('DozeAlarmScheduler.schedule(context, accountId, interval)');
      final enqueue = kotlin.indexOf('DozeScanTrigger.enqueue(');
      expect(rearm, greaterThan(-1));
      expect(enqueue, greaterThan(-1));
      expect(rearm, lessThan(enqueue),
          reason: 'if the scan throws, the schedule must survive -- an alarm '
              'chain that breaks on one bad scan stops silently and forever');
    });
  });
}
