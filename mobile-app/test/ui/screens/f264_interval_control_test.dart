/// F264 (Sprint 77) T-2 / T-11: the "Scan every" control and the Android-only
/// Background rows, driven through the REAL SettingsScreen over a real (FFI)
/// database -- the path a user takes (Settings > Background), not a seam.
///
/// Covers AC-2 (240 -> 120 schedules; the old fixed-list gate refused it), AC-4
/// (4 minutes: inline message, nothing stored, no schedule call), AC-5 (Hours +
/// 99 -> 5940 stored and scheduled once), AC-11 (the one Android note, exactly
/// once), AC-14 (the per-account new-mail switch is reachable on Android and
/// hidden on Windows, both branches).
///
/// What these do NOT catch: Task Scheduler or WorkManager accepting the value
/// (phone and Windows validation), the keyboard's own Done key on a device (the
/// test sends the Done action), or the real mail-app notification path.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/background_scan_scheduler.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

class _RecordingScheduler implements BackgroundScanScheduler {
  final List<({String accountId, int minutes})> scheduled = [];
  final List<String> cancelled = [];

  @override
  bool get isSupported => true;
  @override
  String get mechanismLabel => 'test';
  @override
  Future<bool> isScheduled(String accountId) async => false;
  @override
  Future<bool> schedule(
      {required String accountId, required int intervalMinutes}) async {
    scheduled.add((accountId: accountId, minutes: intervalMinutes));
    return true;
  }

  @override
  Future<bool> cancel(String accountId) async {
    cancelled.add(accountId);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);

  const acct = 'gmail-a@example.com';
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fakeSecureStorage = <String, String>{};

  late DatabaseTestHelper testHelper;
  late _RecordingScheduler scheduler;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    scheduler = _RecordingScheduler();
    BackgroundScanSchedulerFactory.overrideForTest(scheduler);
    fakeSecureStorage
      ..clear()
      ..['saved_accounts'] = acct;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          return fakeSecureStorage[call.arguments['key'] as String];
        case 'write':
          fakeSecureStorage[call.arguments['key'] as String] =
              call.arguments['value'] as String;
          return null;
        case 'readAll':
          return Map<String, String>.from(fakeSecureStorage);
      }
      return null;
    });
  });

  tearDown(() async {
    BackgroundScanSchedulerFactory.overrideForTest(null);
    SettingsScreen.debugIsAndroid = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

  final numberField = find.byKey(const Key('scan_interval_number'));
  final message = find.byKey(const Key('scan_interval_message'));

  /// Seeds the account, opens Settings > Background and returns once loaded.
  Future<void> openBackgroundTab(
    WidgetTester tester, {
    required int storedMinutes,
    bool backgroundEnabled = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final store = SettingsStore();
      await store.setAccountBackgroundEnabled(acct, backgroundEnabled);
      await store.setAccountBackgroundFrequency(acct, storedMinutes);
      await mountAndLoadDbWidget(
          tester,
          MaterialApp(
              home: SettingsScreen(key: UniqueKey(), accountId: acct)));
      await tester.tap(find.text('Background'));
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
    });
  }

  /// Types [text] into the number box and presses Done, with real-time waits
  /// so the database write behind the commit finishes.
  Future<void> typeAndSubmit(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      await tester.enterText(numberField, text);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
    });
  }

  String numberText(WidgetTester tester) =>
      tester.widget<TextField>(numberField).controller!.text;

  testWidgets('AC-2: 240 minutes shown as 4 Hours; typing 2 saves AND '
      'schedules 120 (the old fixed-list gate refused it)', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 240);
    expect(find.byKey(const Key('scan_interval_control')), findsOneWidget);
    expect(numberText(tester), '4');
    expect(find.text('Hours'), findsOneWidget,
        reason: '240 minutes is a whole number of hours and shows as hours');

    await typeAndSubmit(tester, '2');

    expect(scheduler.scheduled, [(accountId: acct, minutes: 120)],
        reason: 'before F264 this saved the override and returned without '
            'scheduling, because ScanFrequency.fromMinutes(120) was "disabled"');
    final stored = await tester
        .runAsync(() => SettingsStore().getAccountBackgroundFrequency(acct));
    expect(stored, 120);
    expect(find.text('Background scan scheduled every 2 hours'), findsOneWidget);
  });

  testWidgets('AC-4: 4 minutes shows the floor message, stores nothing and '
      'schedules nothing', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15);
    expect(find.text('Minutes'), findsOneWidget);

    await typeAndSubmit(tester, '4');

    expect(message, findsOneWidget);
    expect(tester.widget<Text>(message).data,
        'Minimum is 5 minutes, to limit battery use');
    expect(scheduler.scheduled, isEmpty);
    final stored = await tester
        .runAsync(() => SettingsStore().getAccountBackgroundFrequency(acct));
    expect(stored, 15, reason: 'the stored value stays what it was');
  });

  testWidgets('the message clears when the entry becomes valid and 5 is '
      'accepted', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15);
    await typeAndSubmit(tester, '4');
    expect(message, findsOneWidget);
    await typeAndSubmit(tester, '5');
    expect(message, findsNothing);
    expect(scheduler.scheduled, [(accountId: acct, minutes: 5)]);
  });

  testWidgets('AC-5: at 2 hours, typing 99 stores and schedules 5940 once',
      (tester) async {
    await openBackgroundTab(tester, storedMinutes: 120);
    expect(numberText(tester), '2');

    await typeAndSubmit(tester, '99');

    expect(scheduler.scheduled, [(accountId: acct, minutes: 5940)]);
    final stored = await tester
        .runAsync(() => SettingsStore().getAccountBackgroundFrequency(acct));
    expect(stored, 5940);
  });

  testWidgets('background scanning OFF: a valid change is stored but nothing '
      'is scheduled', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15, backgroundEnabled: false);
    await typeAndSubmit(tester, '30');
    expect(scheduler.scheduled, isEmpty);
    final stored = await tester
        .runAsync(() => SettingsStore().getAccountBackgroundFrequency(acct));
    expect(stored, 30);
  });

  testWidgets('an untypable stored value (125 minutes) opens as 2 Hours and is '
      'converted in storage', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 125);
    expect(numberText(tester), '2');
    expect(find.text('Hours'), findsOneWidget);
    final stored = await tester
        .runAsync(() => SettingsStore().getAccountBackgroundFrequency(acct));
    expect(stored, 120);
  });

  testWidgets('the control holds only 2 digits', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15);
    await tester.runAsync(() async {
      await tester.enterText(numberField, '12');
      await tester.pump();
      // A third digit is refused by the formatter (the edit is rejected).
      await tester.enterText(numberField, '123');
      await tester.pump();
    });
    expect(numberText(tester), '12');
  });

  group('AC-14 / Q10 / AC-11: the Android-only Background rows', () {
    testWidgets('Android: the per-account new-mail switch and the ONE timing '
        'note are shown, the note exactly once', (tester) async {
      SettingsScreen.debugIsAndroid = true;
      await openBackgroundTab(tester, storedMinutes: 15);

      expect(find.byKey(const Key('new_mail_trigger_row')), findsOneWidget);
      expect(find.byKey(const Key('new_mail_trigger_switch')), findsOneWidget);
      expect(find.text('Scan when new mail arrives'), findsOneWidget);
      expect(find.text(kAndroidBackgroundNote), findsOneWidget,
          reason: 'AC-11: the note appears once');
      expect(
          find.textContaining('up to about an hour'), findsNothing,
          reason: 'the old F217 sentence is gone');
    });

    testWidgets('Windows: the new-mail switch and the Android note are '
        'hidden, the interval control is the same', (tester) async {
      SettingsScreen.debugIsAndroid = false;
      await openBackgroundTab(tester, storedMinutes: 15);

      expect(find.byKey(const Key('new_mail_trigger_row')), findsNothing);
      expect(find.byKey(const Key('android_doze_status_line')), findsNothing);
      expect(find.byKey(const Key('scan_interval_control')), findsOneWidget,
          reason: 'one interval control on BOTH platforms (Q11)');
    });

    testWidgets('Android with background scanning off: the switch shows, the '
        'timing note does not', (tester) async {
      SettingsScreen.debugIsAndroid = true;
      await openBackgroundTab(tester, storedMinutes: 15, backgroundEnabled: false);
      expect(find.byKey(const Key('new_mail_trigger_row')), findsOneWidget,
          reason: 'review M-1: the switch is not gated on the background switch');
      expect(find.byKey(const Key('android_doze_status_line')), findsNothing);
    });
  });
}
