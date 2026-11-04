// F322 (Sprint 83) T-1 / T-3: the notification CHOICE in the shared notifier.
//
// What these tests do NOT catch: whether Android really lists the two channels
// or honors a user silencing one (an OS behavior; the emulator rehearsal and
// phone check settle it), whether `getNotificationChannels` returns an empty
// list on Android 7.x (a plugin fact read from its source, not exercised
// here), and that a worker reaches `post` (the source gate in
// scan_notification_text_test.dart covers that).
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/platform/platform_capabilities.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_complete_notifier.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late List<NotificationDetails> shown;
  var choice = ScanNotifyChoice.noRuleOnly;
  var android8Plus = true;

  setUp(() {
    shown = [];
    choice = ScanNotifyChoice.noRuleOnly;
    android8Plus = true;
    ScanCompleteNotifier.showOverride = ({
      required int id,
      required String title,
      required String body,
      required NotificationDetails details,
    }) async =>
        shown.add(details);
    ScanCompleteNotifier.choiceOverride = () async => choice;
    ScanCompleteNotifier.channelsSupportedOverride = () async => android8Plus;
  });

  tearDown(() {
    ScanCompleteNotifier.showOverride = null;
    ScanCompleteNotifier.choiceOverride = null;
    ScanCompleteNotifier.channelsSupportedOverride = null;
    PlatformCapabilities.debugOverride = null;
  });

  Future<ScanNotificationOutcome> post(HostPlatform host, int noRule) {
    PlatformCapabilities.debugOverride = PlatformCapabilities(host);
    return ScanCompleteNotifier.post(
      accountId: 'kimmeyharold@aol.com',
      mode: ScanMode.readOnly,
      noRule: noRule,
      deleted: 1,
      safe: 0,
      errors: 0,
    );
  }

  group('T-1 Windows and iPhone: the in-app choice (shared code)', () {
    for (final host in [HostPlatform.windows, HostPlatform.ios]) {
      test('${host.name}: "Only when one or more No Rule items", No Rule 0 posts '
          'nothing and reports a skip, not a failure', () async {
        expect(await post(host, 0), ScanNotificationOutcome.skippedByChoice);
        expect(shown, isEmpty);
      });

      test('${host.name}: "Only when one or more No Rule items", No Rule 1 posts '
          'one notification', () async {
        expect(await post(host, 1), ScanNotificationOutcome.posted);
        expect(shown, hasLength(1));
      });

      test('${host.name}: "Every completed scan" posts for No Rule 0 and 1',
          () async {
        choice = ScanNotifyChoice.every;
        expect(await post(host, 0), ScanNotificationOutcome.posted);
        expect(await post(host, 1), ScanNotificationOutcome.posted);
        expect(shown, hasLength(2));
      });
    }

    test('a choice that cannot be read notifies (never hides a scan)',
        () async {
      ScanCompleteNotifier.choiceOverride =
          () async => throw StateError('db unavailable');
      expect(await post(HostPlatform.windows, 0),
          ScanNotificationOutcome.posted);
    });
  });

  group('T-1 Android 7.x (no channels): the in-app choice applies', () {
    setUp(() => android8Plus = false);

    test('"Only when one or more No Rule items", No Rule 0 posts nothing',
        () async {
      expect(await post(HostPlatform.android, 0),
          ScanNotificationOutcome.skippedByChoice);
      expect(shown, isEmpty);
    });

    test('"Every completed scan", No Rule 0 posts', () async {
      choice = ScanNotifyChoice.every;
      expect(
          await post(HostPlatform.android, 0), ScanNotificationOutcome.posted);
      expect(shown, hasLength(1));
    });

    test('No Rule 1 posts with the default choice', () async {
      expect(
          await post(HostPlatform.android, 1), ScanNotificationOutcome.posted);
    });
  });

  group('T-3 Android 8.0+: the channel is the choice', () {
    test('No Rule 0 posts on the "nothing to review" channel, even with the '
        'in-app choice on "Only when one or more No Rule items"', () async {
      expect(
          await post(HostPlatform.android, 0), ScanNotificationOutcome.posted);
      final a = shown.single.android!;
      expect(a.channelId, ScanCompleteNotifier.nothingToReviewChannelId);
      expect(a.channelName, 'Scans with nothing to review');
      expect(a.importance, Importance.low);
    });

    test('No Rule 1 posts on the "No Rule items" channel', () async {
      await post(HostPlatform.android, 1);
      final a = shown.single.android!;
      expect(a.channelId, ScanCompleteNotifier.noRuleChannelId);
      expect(a.channelName, 'Scans with No Rule items');
      expect(a.importance, Importance.low);
    });

    test('the two channel ids differ and neither is the retired one', () {
      final ids = {
        ScanCompleteNotifier.noRuleChannelId,
        ScanCompleteNotifier.nothingToReviewChannelId,
        ScanCompleteNotifier.retiredChannelId,
        'sign_in_needed_channel',
      };
      expect(ids, hasLength(4));
    });
  });

  group('T-1 AC-2: the sign-in-needed notification is never gated', () {
    for (final c in ScanNotifyChoice.values) {
      test('posts with the choice ${c.name}', () async {
        choice = c;
        PlatformCapabilities.debugOverride =
            const PlatformCapabilities(HostPlatform.windows);
        expect(
            await ScanCompleteNotifier.postSignInNeeded(
                accountId: 'kimmeyh@gmail.com'),
            isTrue);
        expect(shown, hasLength(1));
      });
    }

    test('on Android 8.0+ it still uses its own channel', () async {
      PlatformCapabilities.debugOverride =
          const PlatformCapabilities(HostPlatform.android);
      await ScanCompleteNotifier.postSignInNeeded(accountId: 'a@b.com');
      expect(shown.single.android!.channelId, 'sign_in_needed_channel');
    });
  });

  group('the saved choice (SettingsStore, no schema change)', () {
    late DatabaseTestHelper helper;
    late SettingsStore store;

    setUpAll(DatabaseTestHelper.initializeFfi);
    setUp(() async {
      helper = DatabaseTestHelper();
      await helper.setUp();
      store = SettingsStore(helper.dbHelper);
    });
    tearDown(() async => helper.tearDown());

    test('Q2 = 1: the default is "Only when one or more No Rule items"',
        () async {
      expect(await store.getScanNotifyChoice(), ScanNotifyChoice.noRuleOnly);
    });

    test('a saved value round-trips', () async {
      await store.setScanNotifyChoice(ScanNotifyChoice.every);
      expect(await store.getScanNotifyChoice(), ScanNotifyChoice.every);
      await store.setScanNotifyChoice(ScanNotifyChoice.noRuleOnly);
      expect(await store.getScanNotifyChoice(), ScanNotifyChoice.noRuleOnly);
    });

    test('an unrecognized stored value reads as the default', () async {
      await store.setScanNotifyChoice(ScanNotifyChoice.every);
      final db = await helper.dbHelper.database;
      await db.update('app_settings', {'value': 'bogus'},
          where: 'key = ?', whereArgs: [SettingsStore.keyScanNotifyChoice]);
      expect(await store.getScanNotifyChoice(), ScanNotifyChoice.noRuleOnly);
    });
  });
}
