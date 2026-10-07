/// F253 (Sprint 76): Settings > Background > "Scan when new mail arrives".
///
/// What this does NOT catch: Android binding the listener and delivering a
/// real notification, the component enable/disable taking effect, or the scan
/// it starts (Fold validation, AC-5); the listener's decision rule is covered
/// by the JVM test `android/app/src/test/.../MailNotificationPolicyTest.kt`.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/android_background_scan_worker.dart';
import 'package:my_email_spam_filter/core/services/background_scan_trigger.dart';
import 'package:my_email_spam_filter/core/services/new_mail_trigger.dart';
import 'package:my_email_spam_filter/ui/widgets/new_mail_trigger_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late bool enabled;
  late bool granted;
  late bool saveWorks;
  late bool readWorks;
  late String? lastResult;
  Completer<void>? holdFirstRead;

  setUp(() {
    calls = [];
    enabled = false;
    granted = false;
    saveWorks = true;
    readWorks = true;
    lastResult = null;
    holdFirstRead = null;
    messenger.setMockMethodCallHandler(NewMailTrigger.channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isEnabled':
          final hold = holdFirstRead;
          if (hold != null) {
            holdFirstRead = null;
            final before = enabled;
            await hold.future;
            return before; // a read that started before the user's tap
          }
          if (!readWorks) throw PlatformException(code: 'x');
          return enabled;
        case 'isAccessGranted':
          return granted;
        case 'setEnabled':
          if (!saveWorks) return null;
          enabled = (call.arguments as Map)['enabled'] as bool;
          return true;
        case 'openAccessSettings':
          return true;
        case 'lastResult':
          return lastResult;
      }
      return null;
    });
  });

  tearDown(
      () => messenger.setMockMethodCallHandler(NewMailTrigger.channel, null));

  Future<void> pumpRow(WidgetTester tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NewMailTriggerRow())));
    await tester.pump();
  }

  String status(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('new_mail_trigger_status')))
      .data!;

  SwitchListTile tile(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(const Key('new_mail_trigger_switch')));

  testWidgets('OFF by default and asks for nothing', (tester) async {
    await pumpRow(tester);
    expect(tile(tester).value, isFalse);
    expect(status(tester), startsWith('Off.'));
    expect(calls, isNot(contains('openAccessSettings')),
        reason: 'access is requested only from the switch, never on display');
  });

  testWidgets('turning it on saves the switch and opens Notification access',
      (tester) async {
    await pumpRow(tester);
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    expect(enabled, isTrue);
    expect(calls, contains('openAccessSettings'));
    expect(status(tester), startsWith('Needs Notification access'));
  });

  testWidgets('on with access granted says so, and names the privacy limit',
      (tester) async {
    enabled = true;
    granted = true;
    await pumpRow(tester);
    expect(status(tester), startsWith('On, for all accounts'));
    expect(status(tester), contains('never its content'));
    expect(find.byKey(const Key('new_mail_trigger_open_access')), findsNothing);
  });

  testWidgets('access granted in Android settings shows on return',
      (tester) async {
    enabled = true;
    await pumpRow(tester);
    expect(status(tester), startsWith('Needs Notification access'));
    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(status(tester), startsWith('On, for all accounts'));
  });

  testWidgets('review HIGH-2: a change the phone did not confirm is reverted '
      'and reported', (tester) async {
    saveWorks = false;
    await pumpRow(tester);
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    expect(tile(tester).value, isFalse, reason: 'must not show ON');
    expect(find.byKey(const Key('new_mail_trigger_problem')), findsOneWidget);
    expect(calls, isNot(contains('openAccessSettings')));
  });

  testWidgets('review MEDIUM-1: an unreadable state is shown as unknown and '
      'the switch is disabled, never drawn OFF', (tester) async {
    readWorks = false;
    await pumpRow(tester);
    expect(status(tester), 'Status unavailable.');
    expect(tile(tester).onChanged, isNull);
  });

  testWidgets('the last trigger outcome is shown while on', (tester) async {
    enabled = true;
    granted = true;
    lastResult = '${DateTime(2026, 10, 5, 18, 30).millisecondsSinceEpoch}'
        '|FAILED: IllegalStateException: boom';
    await pumpRow(tester);
    final line = tester
        .widget<Text>(find.byKey(const Key('new_mail_trigger_last')))
        .data!;
    expect(line, contains('2026-10-05 18:30'));
    expect(line, contains('FAILED: IllegalStateException'));
  });

  testWidgets('review L-2: a refresh that started before the tap cannot '
      'overwrite it', (tester) async {
    await pumpRow(tester); // OFF, readable
    // A resume starts a read that captures OFF and is held in flight...
    holdFirstRead = Completer<void>();
    final held = holdFirstRead!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    // ...the user turns the switch ON meanwhile...
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    // ...and the stale read (OFF) lands afterwards.
    held.complete();
    await tester.pump();
    await tester.pump();
    expect(tile(tester).value, isTrue,
        reason: 'the stale read must not overwrite the user\'s tap');
  });

  test('the worker start line names the mail app', () {
    final line = describeBackgroundTrigger(
      isTest: false,
      inputData: {
        kTriggerSourceKey: 'notification',
        kTriggerAppKey: 'com.google.android.gm',
        kTriggerAtMsKey: 1000,
      },
      now: DateTime.fromMillisecondsSinceEpoch(6000),
    );
    expect(line, 'trigger=notification app=com.google.android.gm delay=5s');
  });

  group('review H-1: a notification-triggered run never asks for a retry', () {
    test('notification and Doze-alarm runs opt out of retry; periodic keeps it',
        () {
      expect(retryOnFailureFor({kTriggerSourceKey: 'notification'}), isFalse);
      // 7.7.1 review H-1: the KEEP Doze one-off had the same trap.
      expect(retryOnFailureFor({kTriggerSourceKey: 'doze-alarm'}), isFalse);
      expect(retryOnFailureFor({'accountId': 'a'}), isTrue);
      expect(retryOnFailureFor(null), isTrue);
    });

    // PREVENTION (7.7.1 review H-1, Harold's prevention-first rule): every
    // trigger the native code declares is a ONE-OFF enqueued with KEEP, and a
    // KEEP one-off that asks for a retry swallows every later trigger while
    // it waits in backoff. So EVERY declared source must opt out of retry --
    // a future trigger added in Kotlin fails here until it does, instead of
    // being found on a phone. What this does NOT catch: a one-off enqueued
    // without a `SOURCE_` constant, or a source string built at runtime.
    test('every native trigger source opts out of retry', () {
      final sources = <String>{};
      final kotlinDir =
          Directory('android/app/src/main/kotlin/com/myemailspamfilter');
      for (final f in kotlinDir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.kt')) continue;
        for (final m in RegExp(r'const val SOURCE_\w+\s*=\s*"([^"]+)"')
            .allMatches(f.readAsStringSync())) {
          sources.add(m.group(1)!);
        }
      }
      expect(sources, containsAll(['doze-alarm', 'notification']),
          reason: 'the gate must see the sources it guards');
      for (final s in sources) {
        expect(retryOnFailureFor({kTriggerSourceKey: s}), isFalse,
            reason: 'trigger "$s" would retry under KEEP and block later triggers');
      }
    });

    test('a failed run returns done when retry is off, retry when on', () {
      expect(workerResult(allSucceeded: false, retryOnFailure: false), isTrue);
      expect(workerResult(allSucceeded: false, retryOnFailure: true), isFalse);
      expect(workerResult(allSucceeded: true, retryOnFailure: true), isTrue);
    });

    test('the dispatcher passes the trigger into executeScan', () {
      // SOURCE-TEXT VERIFIED: the WorkManager dispatcher runs only inside a
      // plugin isolate; the gate pins that it feeds the retry decision.
      final src = File('lib/core/services/android_background_scan_worker.dart')
          .readAsStringSync();
      expect(src.contains('retryOnFailure: retryOnFailureFor(inputData),'),
          isTrue);
    });
  });

  group('source gates', () {
    final listener = File(
            'android/app/src/main/kotlin/com/myemailspamfilter/MailNotificationListener.kt')
        .readAsStringSync();

    test('AC-4: the listener never reads the notification content', () {
      // SOURCE-TEXT VERIFIED: the privacy promise is about what the code
      // reads, which no runtime test on a host can observe.
      // Code only: the KDoc names these accessors to say they are NOT used.
      final code = listener
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//[^\n]*'), '');
      for (final forbidden in [
        'sbn.notification',
        'getNotification(',
        '.extras',
        'tickerText',
        'EXTRA_',
        // Review L-1: inherited accessors that return full notifications.
        'activeNotifications',
        'getActiveNotifications',
        'getSnoozedNotifications',
        'sbn?.let',
        'sbn.let',
      ]) {
        expect(code.contains(forbidden), isFalse,
            reason: 'MailNotificationListener must not touch $forbidden');
      }
      // The only two reads of the posted notification.
      final reads = RegExp(r'sbn\.(\w+)').allMatches(code).map((m) => m.group(1));
      expect(reads.toSet(), {'packageName', 'postTime'});
    });

    test('the triggerApp key matches Kotlin', () {
      // SOURCE-TEXT VERIFIED: a compile-time literal shared across languages.
      final trigger = File(
              'android/app/src/main/kotlin/com/myemailspamfilter/DozeScanTrigger.kt')
          .readAsStringSync();
      final m = RegExp(r'KEY_TRIGGER_APP\s*=\s*"([^"]+)"').firstMatch(trigger);
      expect(m?.group(1), kTriggerAppKey);
    });

    test('review M-1: Settings shows the switch on Android regardless of the '
        'selected account\'s background switch', () {
      // SOURCE-TEXT VERIFIED: behind Platform.isAndroid, unreachable from a
      // host widget test.
      final src = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
      expect(src.contains('if (Platform.isAndroid) const NewMailTriggerRow(),'),
          isTrue);
    });

    test('turning it off disables the listener and cancels a queued scan', () {
      // SOURCE-TEXT VERIFIED: PackageManager and WorkManager are device APIs.
      expect(listener.contains('COMPONENT_ENABLED_STATE_DISABLED'), isTrue);
      expect(listener.contains('DozeScanTrigger.cancelNewMailScan(context)'),
          isTrue);
    });

    test('the throttle advances only after a successful enqueue', () {
      // SOURCE-TEXT VERIFIED: ordering inside a device-only service.
      final enqueue = listener.indexOf('DozeScanTrigger.enqueueAllAccounts(');
      final stamp = listener.indexOf('.putLong(KEY_LAST_TRIGGER_MS, now)');
      expect(enqueue, greaterThan(-1));
      expect(stamp, greaterThan(enqueue));
    });

    test('the manifest declares the listener behind the BIND permission', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('android:name=".MailNotificationListener"'),
          isTrue);
      expect(
          manifest.contains(
              'android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"'),
          isTrue);
    });
  });
}
