/// F253 (Sprint 76), made per account by F264 (Sprint 77): Settings >
/// Background > "Scan when new mail arrives".
///
/// What this does NOT catch: Android binding the listener and delivering a
/// real notification, the component enable/disable taking effect, or the scan
/// it starts (Fold validation, AC-5); the listener's decision rule and the
/// package-to-provider table are covered by the JVM test
/// `android/app/src/test/.../MailNotificationPolicyTest.kt`.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/android_background_scan_worker.dart';
import 'package:my_email_spam_filter/core/services/background_scan_trigger.dart';
import 'package:my_email_spam_filter/core/services/new_mail_trigger.dart';
import 'package:my_email_spam_filter/core/services/notification_account_filter.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/widgets/new_mail_trigger_row.dart';

/// In-memory stand-in for the two per-account new-mail methods. The row talks
/// to [SettingsStore] only through these, so no database is needed.
class _FakeSettings extends SettingsStore {
  final Map<String, bool> values = {};
  bool readWorks = true;
  Completer<void>? holdFirstRead;

  @override
  Future<bool?> getAccountNewMailTrigger(String accountId) async {
    final hold = holdFirstRead;
    if (hold != null) {
      holdFirstRead = null;
      final before = values[accountId];
      await hold.future;
      return before; // a read that started before the user's tap
    }
    if (!readWorks) throw StateError('unreadable');
    return values[accountId];
  }

  @override
  Future<void> setAccountNewMailTrigger(String accountId, bool? enabled) async {
    if (enabled == null) {
      values.remove(accountId);
    } else {
      values[accountId] = enabled;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const acct = 'gmail-a@gmail.com';
  const other = 'aol-b@aol.com';

  late List<String> calls;
  late bool nativeEnabled; // the ONE native "any account on" flag
  late bool granted;
  late bool saveWorks;
  late String? lastResult;
  late _FakeSettings settings;

  setUp(() {
    calls = [];
    nativeEnabled = false;
    granted = false;
    saveWorks = true;
    lastResult = null;
    settings = _FakeSettings();
    messenger.setMockMethodCallHandler(NewMailTrigger.channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isAccessGranted':
          return granted;
        case 'setEnabled':
          if (!saveWorks) return null;
          nativeEnabled = (call.arguments as Map)['enabled'] as bool;
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

  Future<void> pumpRow(WidgetTester tester,
      {String account = acct, String? platformId = 'gmail'}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NewMailTriggerRow(
      accountId: account,
      platformId: platformId,
      settingsStore: settings,
      getSavedAccountIds: () async => [acct, other],
    ))));
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

  testWidgets('F264: the title no longer says "all accounts"', (tester) async {
    await pumpRow(tester);
    final title = tester.widget<SwitchListTile>(
        find.byKey(const Key('new_mail_trigger_switch'))).title as Text;
    expect(title.data, 'Scan when new mail arrives');
  });

  testWidgets('turning it on saves THIS account, syncs the native flag and '
      'opens Notification access', (tester) async {
    await pumpRow(tester);
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    expect(settings.values[acct], isTrue,
        reason: 'the switch is stored per account in the app database');
    expect(settings.values.containsKey(other), isFalse,
        reason: 'a neighbouring account must not change');
    expect(nativeEnabled, isTrue,
        reason: 'the native "any account on" flag follows the switches');
    expect(calls, contains('openAccessSettings'));
    expect(status(tester), startsWith('Needs Notification access'));
  });

  testWidgets('F264: the native flag stays on while ANY account has it on and '
      'goes off only with the last one', (tester) async {
    settings.values[other] = true;
    nativeEnabled = true;
    await pumpRow(tester);
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    expect(settings.values[acct], isTrue);
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    expect(settings.values[acct], isFalse);
    expect(nativeEnabled, isTrue, reason: 'the other account still has it on');
    settings.values[other] = false;
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    expect(nativeEnabled, isFalse,
        reason: 'no account has it on, so the listener flag turns off');
  });

  testWidgets('on with access granted names this account\'s mail apps and '
      'the privacy limit', (tester) async {
    settings.values[acct] = true;
    granted = true;
    await pumpRow(tester);
    expect(status(tester), startsWith('On for this account'));
    expect(status(tester), contains('Gmail, Samsung Email or Outlook'));
    expect(status(tester), isNot(contains('AOL')));
    expect(status(tester), contains('never its content'));
    expect(find.byKey(const Key('new_mail_trigger_open_access')), findsNothing);
  });

  test('the apps named for each provider', () {
    expect(NewMailTriggerRow.appsFor('gmail'), 'Gmail, Samsung Email or Outlook');
    expect(NewMailTriggerRow.appsFor('gmail-imap'),
        'Gmail, Samsung Email or Outlook');
    expect(NewMailTriggerRow.appsFor('aol'), 'AOL, Samsung Email or Outlook');
    expect(NewMailTriggerRow.appsFor('yahoo'),
        'Yahoo Mail, Samsung Email or Outlook');
    expect(NewMailTriggerRow.appsFor('icloud'), 'Samsung Email or Outlook');
    expect(NewMailTriggerRow.appsFor(null), 'Samsung Email or Outlook');
  });

  testWidgets('access granted in Android settings shows on return',
      (tester) async {
    settings.values[acct] = true;
    await pumpRow(tester);
    expect(status(tester), startsWith('Needs Notification access'));
    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(status(tester), startsWith('On for this account'));
  });

  testWidgets('review HIGH-2: a change the phone did not confirm is reverted '
      'and reported', (tester) async {
    saveWorks = false;
    await pumpRow(tester);
    await tester.tap(find.byKey(const Key('new_mail_trigger_switch')));
    await tester.pump();
    expect(tile(tester).value, isFalse, reason: 'must not show ON');
    expect(settings.values[acct], isFalse,
        reason: 'the stored value is put back too, so the stores agree');
    expect(find.byKey(const Key('new_mail_trigger_problem')), findsOneWidget);
    expect(calls, isNot(contains('openAccessSettings')));
  });

  testWidgets('review MEDIUM-1: an unreadable state is shown as unknown and '
      'the switch is disabled, never drawn OFF', (tester) async {
    settings.readWorks = false;
    await pumpRow(tester);
    expect(status(tester), 'Status unavailable.');
    expect(tile(tester).onChanged, isNull);
  });

  testWidgets('the last trigger outcome is shown while on', (tester) async {
    settings.values[acct] = true;
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
    settings.holdFirstRead = Completer<void>();
    final held = settings.holdFirstRead!;
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

  group('F264: the dispatcher selects accounts for a notification run', () {
    test('only a notification run carries a provider set', () {
      expect(
          notificationProvidersFor({
            kTriggerSourceKey: 'notification',
            kTriggerProvidersKey: 'gmail',
          }),
          'gmail');
      expect(notificationProvidersFor({kTriggerSourceKey: 'doze-alarm'}),
          isNull,
          reason: 'an alarm run is account-specific and keeps its own rules');
      expect(notificationProvidersFor({'accountId': 'a'}), isNull);
      expect(notificationProvidersFor(null), isNull);
      expect(notificationProvidersFor({kTriggerSourceKey: 'notification'}),
          kAnyProvider,
          reason: 'a build that sent no set degrades to the old behavior for '
              'accounts whose own switch is on, never to scanning nothing');
    });

    test('the worker applies the filter, reads the account\'s own switch, and '
        'the listener sends the provider set', () {
      // SOURCE-TEXT VERIFIED: executeScan drives the whole scan pipeline and
      // the listener is a device-only service, so neither can run on a host.
      // This pins the call sites the pure-function tests cannot see ("correct
      // abstraction, wrong wiring"). What it does NOT catch: the filter being
      // called with wrong arguments of the right shape -- the matrix test
      // pins the function, Fold validation pins the end-to-end behavior.
      final worker = File('lib/core/services/android_background_scan_worker.dart')
          .readAsStringSync();
      expect(
          worker.contains('notificationProviders != null &&\n'
              '            !accountSelectedByNotification('),
          isTrue);
      expect(worker.contains('getAccountNewMailTrigger(id) == true'), isTrue);
      expect(worker.contains('backgroundEnabled: backgroundEnabled,'), isTrue);
      final listenerSrc = File(
              'android/app/src/main/kotlin/com/myemailspamfilter/MailNotificationListener.kt')
          .readAsStringSync();
      expect(
          listenerSrc.contains(
              'providers = MailNotificationPolicy.encodeProviders(pkg, debugBuild = BuildConfig.DEBUG),'),
          isTrue);
    });

    test('the dispatcher passes the provider set into executeScan', () {
      // SOURCE-TEXT VERIFIED (same reason as the retry gate above).
      final src = File('lib/core/services/android_background_scan_worker.dart')
          .readAsStringSync();
      expect(
          src.contains(
              'notificationProviders: notificationProvidersFor(inputData),'),
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

    test('the triggerApp and triggerProviders keys match Kotlin', () {
      // SOURCE-TEXT VERIFIED: a compile-time literal shared across languages.
      final trigger = File(
              'android/app/src/main/kotlin/com/myemailspamfilter/DozeScanTrigger.kt')
          .readAsStringSync();
      final m = RegExp(r'KEY_TRIGGER_APP\s*=\s*"([^"]+)"').firstMatch(trigger);
      expect(m?.group(1), kTriggerAppKey);
      final p =
          RegExp(r'KEY_TRIGGER_PROVIDERS\s*=\s*"([^"]+)"').firstMatch(trigger);
      expect(p?.group(1), kTriggerProvidersKey);
    });

    test('the "every provider" marker matches Kotlin', () {
      final policy = File(
              'android/app/src/main/kotlin/com/myemailspamfilter/MailNotificationPolicy.kt')
          .readAsStringSync();
      final m = RegExp(r'ANY_PROVIDER\s*=\s*"([^"]+)"').firstMatch(policy);
      expect(m?.group(1), kAnyProvider);
    });

    test('the mail apps named in the status line match the Kotlin table', () {
      // SOURCE-TEXT VERIFIED: the display text in `NewMailTriggerRow.appsFor`
      // is a second copy of knowledge the Kotlin table owns, so this pins the
      // three provider-specific rows and the two every-provider rows. What
      // this does NOT catch: a Kotlin table edited in a shape this regex does
      // not read (the assertions below would then fail, not pass).
      final policy = File(
              'android/app/src/main/kotlin/com/myemailspamfilter/MailNotificationPolicy.kt')
          .readAsStringSync();
      // Only the RELEASE table: the debug-only poster table (R76-1, Q15) has
      // the same shape and must not be read as a mail app.
      final start = policy.indexOf('private val MAIL_APPS');
      final releaseTable =
          policy.substring(start, policy.indexOf(RegExp(r'\n\s*\)\s*\n'), start));
      final rows = {
        for (final m in RegExp(r'"([\w.]+)" to (setOf\((\w+)\)|null)')
            .allMatches(releaseTable))
          m.group(1)!: m.group(3), // null for the every-provider rows
      };
      expect(rows, {
        'com.google.android.gm': 'GMAIL',
        'com.aol.mobile.aolapp': 'AOL',
        'com.yahoo.mobile.client.android.mail': 'YAHOO',
        'com.samsung.android.email.provider': null,
        'com.microsoft.office.outlook': null,
      });
      expect(NewMailTriggerRow.appsFor('gmail'), startsWith('Gmail, '));
      expect(NewMailTriggerRow.appsFor('aol'), startsWith('AOL, '));
      expect(NewMailTriggerRow.appsFor('yahoo'), startsWith('Yahoo Mail, '));
    });

    test('review M-1 / F264 Q10: the switch is gated by the Android seam, '
        'not on the account\'s background switch, and hidden on Windows', () {
      // SOURCE-TEXT VERIFIED: behind a platform seam; the widget test on the
      // real Settings path (f264_interval_control_test) drives both branches.
      final src = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
      expect(
          src.contains('if (SettingsScreen.showsAndroidBackgroundRows)\n'
              '          NewMailTriggerRow('),
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
