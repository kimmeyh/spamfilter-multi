// F287 (Sprint 79): the shared background-scan completion notifier.
//
// What these tests do NOT catch: whether Windows actually SHOWS the toast
// (app ID registration, a Task Scheduler process with no window) or whether
// Android renders `<s>` -- those are settled by the 5.1.9 rehearsal on this PC
// and the emulator, not by a host test. They also do not prove a worker calls
// [ScanCompleteNotifier.post]; the source gate in
// scan_notification_text_test.dart covers that.
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/platform/platform_capabilities.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_complete_notifier.dart';
import 'package:my_email_spam_filter/core/services/scan_notification_text.dart';

class _Shown {
  final int id;
  final String title;
  final String body;
  final NotificationDetails details;
  _Shown(this.id, this.title, this.body, this.details);
}

void main() {
  late List<_Shown> shown;

  setUp(() {
    shown = [];
    ScanCompleteNotifier.showOverride = ({
      required int id,
      required String title,
      required String body,
      required NotificationDetails details,
    }) async =>
        shown.add(_Shown(id, title, body, details));
  });

  tearDown(() {
    ScanCompleteNotifier.showOverride = null;
    PlatformCapabilities.debugOverride = null;
  });

  Future<bool> postReadOnly() => ScanCompleteNotifier.post(
        accountId: 'kimmeyharold@aol.com',
        mode: ScanMode.readOnly,
        noRule: 9,
        deleted: 1,
        safe: 0,
        errors: 0,
      );

  test('Android: HTML body with struck counts on the Android channel',
      () async {
    PlatformCapabilities.debugOverride =
        const PlatformCapabilities(HostPlatform.android);
    await postReadOnly();
    expect(shown, hasLength(1));
    final s = shown.single;
    expect(s.title, 'Back. scan k*@aol read-only completed');
    expect(s.body, 'No rule 9 <s>Deleted 1</s> <s>Safe 0</s>');
    expect(s.details.android, isNotNull);
    expect(s.details.android!.channelId, 'background_scan_channel');
    final style = s.details.android!.styleInformation;
    expect(style, isA<DefaultStyleInformation>());
    expect((style as DefaultStyleInformation).htmlFormatContent, isTrue);
    expect(s.details.windows, isNull);
  });

  test('Windows: plain body (no markup), same title and same id', () async {
    PlatformCapabilities.debugOverride =
        const PlatformCapabilities(HostPlatform.windows);
    await postReadOnly();
    final s = shown.single;
    expect(s.title, 'Back. scan k*@aol read-only completed');
    expect(s.body, 'No rule 9 Deleted 1 Safe 0');
    expect(s.body, isNot(contains('<')));
    expect(s.details.windows, isNotNull);
    expect(s.details.android, isNull);
    expect(s.id, ScanNotificationText.notificationId('kimmeyharold@aol.com'));
  });

  test('parity: both platforms post the same id and title per account',
      () async {
    for (final android in [true, false]) {
      PlatformCapabilities.debugOverride = PlatformCapabilities(
          android ? HostPlatform.android : HostPlatform.windows);
      await ScanCompleteNotifier.post(
        accountId: 'kimmeyh@gmail.com',
        mode: ScanMode.safeSendersAndRules,
        noRule: 2,
        deleted: 3,
        safe: 1,
        errors: 1,
      );
    }
    expect(shown[0].id, shown[1].id);
    expect(shown[0].title, 'Back. scan k*@gmail completed');
    expect(shown[1].title, shown[0].title);
    expect(shown[1].body, 'No rule 2 Deleted 3 Safe 1 Errors 1');
  });

  test('a plugin failure never escapes (the scan must not fail)', () async {
    PlatformCapabilities.debugOverride =
        const PlatformCapabilities(HostPlatform.windows);
    ScanCompleteNotifier.showOverride = ({
      required int id,
      required String title,
      required String body,
      required NotificationDetails details,
    }) async =>
        throw StateError('no notifier');
    // Sprint 79 7.7.1 M-4: completes, AND reports that nothing was posted, so
    // the worker's step line cannot read "posted".
    expect(await postReadOnly(), isFalse);
  });

  test('7.7.1 M-4: a posted notification reports true', () async {
    PlatformCapabilities.debugOverride =
        const PlatformCapabilities(HostPlatform.android);
    expect(await postReadOnly(), isTrue);
  });

  // 7.7.1 M-5 / M-4 wiring. What these do NOT catch: whether
  // `areNotificationsEnabled` returns false on a real device with the
  // permission denied (a plugin call; a phone check), and the always-on
  // Windows log text (no host Windows worker run).
  test('source gate: Android asks whether notifications are enabled', () {
    final src = File('lib/core/services/scan_complete_notifier.dart')
        .readAsStringSync();
    expect(src, contains('AndroidFlutterLocalNotificationsPlugin>()'));
    expect(src, contains('?.areNotificationsEnabled()'));
    expect(RegExp(r'if \(enabled == false\) \{\s*throw').hasMatch(src), isTrue);
  });

  test('source gate: both workers log the real outcome, not "done"', () {
    final core =
        File('lib/core/services/background_scan_core.dart').readAsStringSync();
    expect(core, contains("? 'notification posted'"));
    expect(core, isNot(contains("'notification step done'")));
    final win = File('lib/core/services/background_scan_windows_worker.dart')
        .readAsStringSync();
    expect(win, contains('final posted = await ScanCompleteNotifier.post('));
    expect(win, isNot(contains("'Completion notification step done'")));
  });

  test('DEV and PROD never share a Windows app ID or activation GUID', () {
    // Both getters read AppEnvironment; assert the fixed values differ and
    // the GUIDs are well-formed, from the source so no environment is faked.
    final src = File('lib/core/services/scan_complete_notifier.dart')
        .readAsStringSync();
    final guids = RegExp(r"'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'")
        .allMatches(src)
        .map((m) => m.group(1))
        .toSet();
    expect(guids, hasLength(2));
    expect(src, contains("'MyEmailSpamFilter.Dev'"));
    expect(src, contains("'MyEmailSpamFilter.App'"));
  });

  test('the two retired Windows notification services are gone (AC-4)', () {
    expect(
        File('lib/core/services/windows_notification_service.dart')
            .existsSync(),
        isFalse);
    expect(
        File('lib/core/services/windows_toast_notification_service.dart')
            .existsSync(),
        isFalse);
  });
}
