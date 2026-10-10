/// F264 (Sprint 77) T-2 / T-11: the "Scan every" control and the Android-only
/// Background rows, driven through the REAL SettingsScreen over a real (FFI)
/// database -- the path a user takes (Settings > Background), not a seam.
///
/// Covers AC-2 (240 -> 120 schedules; the old fixed-list gate refused it), AC-4
/// (4 minutes: inline message, nothing stored, no schedule call), AC-11 (the
/// one Android note, exactly once), AC-14 (the per-account new-mail switch is
/// reachable on Android and hidden on Windows, both branches).
///
/// F281 (Sprint 78, Alternative D): the row is a preset drop-down plus
/// "Custom..."; the Custom dialog validates 5 minutes to 24 hours with Save
/// disabled until valid (25 hours refused; 24 stores and schedules 1440), and
/// the control is HIDDEN while the account's background scanning is off, on
/// both platforms, with the saved value kept for when it is turned on (F2 = 1).
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
  final dropdown = find.byKey(const Key('scan_interval_dropdown'));
  final saveButton = find.byKey(const Key('scan_interval_custom_save'));

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

  /// The interval the drop-down shows, in minutes.
  int shownMinutes(WidgetTester tester) =>
      tester.widget<DropdownButton<int>>(dropdown).value!;

  /// Opens the drop-down and picks the entry labelled [label], with real-time
  /// waits so the database write behind the commit finishes.
  Future<void> pick(WidgetTester tester, String label) async {
    // The menu route animates in; its frames are pumped OUTSIDE runAsync.
    await tester.ensureVisible(dropdown);
    await tester.pump();
    await tester.tap(dropdown);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(label).last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // The commit's database write needs the real event loop.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Opens "Custom..." and types [text] into its number box.
  Future<void> openCustomAndType(WidgetTester tester, String text) async {
    await pick(tester, 'Custom...');
    expect(find.byKey(const Key('scan_interval_custom_dialog')), findsOneWidget);
    await tester.enterText(numberField, text);
    await tester.pump();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(saveButton).onPressed != null;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
    });
  }

  Future<int?> stored(WidgetTester tester) => tester.runAsync<int?>(
      () => SettingsStore().getAccountBackgroundFrequency(acct));

  testWidgets('F281 D: the presets are 5, 10, 15, 30 minutes and 1, 2, 4, 12, '
      '24 hours, then Custom...', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15);
    final items = tester
        .widget<DropdownButton<int>>(dropdown)
        .items!
        .map((i) => i.value)
        .toList();
    expect(items, [5, 10, 15, 30, 60, 120, 240, 720, 1440, -1]);
  });

  testWidgets('AC-2: 240 minutes shows as 4 hours; picking 2 hours saves AND '
      'schedules 120 (the old fixed-list gate refused it)', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 240);
    expect(find.byKey(const Key('scan_interval_control')), findsOneWidget);
    expect(shownMinutes(tester), 240);

    await pick(tester, '2 hours');

    expect(scheduler.scheduled, [(accountId: acct, minutes: 120)],
        reason: 'before F264 this saved the override and returned without '
            'scheduling, because ScanFrequency.fromMinutes(120) was "disabled"');
    expect(await stored(tester), 120);
    expect(find.text('Background scan scheduled every 2 hours'), findsOneWidget);
  });

  testWidgets('AC-4: Custom 4 minutes shows the floor message, Save stays '
      'disabled, nothing is stored or scheduled', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15);
    await openCustomAndType(tester, '4');

    expect(message, findsOneWidget);
    expect(tester.widget<Text>(message).data,
        'Minimum is 5 minutes, to limit battery use');
    expect(saveEnabled(tester), isFalse);
    expect(scheduler.scheduled, isEmpty);
    expect(await stored(tester), 15, reason: 'the stored value stays what it was');
  });

  testWidgets('the message clears when the entry becomes valid; Custom 45 '
      'saves, schedules once and reads "45 minutes (custom)"', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15);
    await openCustomAndType(tester, '4');
    expect(message, findsOneWidget);
    await tester.enterText(numberField, '45');
    await tester.pump();
    expect(message, findsNothing);
    expect(saveEnabled(tester), isTrue);

    await tapSave(tester);

    expect(scheduler.scheduled, [(accountId: acct, minutes: 45)]);
    expect(await stored(tester), 45);
    expect(shownMinutes(tester), 45);
    expect(find.text('45 minutes (custom)'), findsWidgets);
  });

  testWidgets('F281 AC-2: Custom at 2 hours, 25 shows "Maximum is 24 hours" '
      'with Save disabled; 24 stores and schedules 1440 once', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 120);
    await openCustomAndType(tester, '25');
    expect(tester.widget<Text>(message).data, 'Maximum is 24 hours');
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(numberField, '24');
    await tester.pump();
    await tapSave(tester);

    expect(scheduler.scheduled, [(accountId: acct, minutes: 1440)]);
    expect(await stored(tester), 1440);
  });

  testWidgets('Cancel in Custom changes nothing', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15);
    await openCustomAndType(tester, '45');
    await tester.runAsync(() async {
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 400));
    });
    expect(scheduler.scheduled, isEmpty);
    expect(await stored(tester), 15);
    expect(shownMinutes(tester), 15);
  });

  testWidgets('an untypable stored value (125 minutes) opens as 2 hours and is '
      'converted in storage', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 125);
    expect(shownMinutes(tester), 120);
    expect(await stored(tester), 120);
  });

  testWidgets('the Custom number box holds only 2 digits', (tester) async {
    await openBackgroundTab(tester, storedMinutes: 15);
    await openCustomAndType(tester, '12');
    // A third digit is refused by the formatter (the edit is rejected).
    await tester.enterText(numberField, '123');
    await tester.pump();
    expect(tester.widget<TextField>(numberField).controller!.text, '12');
  });

  for (final android in [false, true]) {
    final platform = android ? 'Android' : 'Windows';
    testWidgets('F281 AC-3 ($platform): background scanning OFF hides "Scan '
        'every"; the saved value is kept and shown when it is on (F2 = 1)',
        (tester) async {
      SettingsScreen.debugIsAndroid = android;
      await openBackgroundTab(tester,
          storedMinutes: 30, backgroundEnabled: false);
      expect(find.byKey(const Key('scan_interval_control')), findsNothing);

      await openBackgroundTab(tester, storedMinutes: 30);
      expect(find.byKey(const Key('scan_interval_control')), findsOneWidget);
      expect(shownMinutes(tester), 30);
      expect(scheduler.scheduled, isEmpty,
          reason: 'opening the screen schedules nothing');
    });
  }

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
