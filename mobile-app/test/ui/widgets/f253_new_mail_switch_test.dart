/// F253 (Sprint 76): Settings > Background > "Scan when new mail arrives".
///
/// What this does NOT catch: Android binding the listener and delivering a
/// real notification, or the scan it starts (Fold validation, AC-5); the
/// listener's decision rule is covered by the JVM test
/// `android/app/src/test/.../MailNotificationPolicyTest.kt`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  setUp(() {
    calls = [];
    enabled = false;
    granted = false;
    messenger.setMockMethodCallHandler(NewMailTrigger.channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isEnabled':
          return enabled;
        case 'isAccessGranted':
          return granted;
        case 'setEnabled':
          enabled = (call.arguments as Map)['enabled'] as bool;
          return true;
        case 'openAccessSettings':
          return true;
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

  bool switchValue(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(const Key('new_mail_trigger_switch')))
      .value;

  testWidgets('OFF by default and asks for nothing', (tester) async {
    await pumpRow(tester);
    expect(switchValue(tester), isFalse);
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
    expect(status(tester), startsWith('On.'));
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
    expect(status(tester), startsWith('On.'));
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

    test('placement: Settings shows the switch on Android with background on',
        () {
      // SOURCE-TEXT VERIFIED: behind Platform.isAndroid, unreachable from a
      // host widget test.
      final src = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
      expect(
          src.contains('if (Platform.isAndroid && _backgroundScanEnabled)\n'
              '          const NewMailTriggerRow(),'),
          isTrue);
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
