// F322 (Sprint 83) T-2: Settings > Background > "Scan notifications".
//
// What these tests do NOT catch: that the row is placed on the Background tab
// (the source gate below checks the line is in settings_screen.dart, not its
// position on screen), that Android actually opens its notification settings
// page (native; emulator check), or the real SettingsStore write (the store
// round trip is in test/unit/services/scan_complete_notifier_test.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/platform/platform_capabilities.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/widgets/scan_notifications_row.dart';

class _MemoryStore extends SettingsStore {
  _MemoryStore(this.value, {this.failSave = false});
  ScanNotifyChoice value;
  final bool failSave;

  @override
  Future<ScanNotifyChoice> getScanNotifyChoice() async => value;

  @override
  Future<void> setScanNotifyChoice(ScanNotifyChoice choice) async {
    if (failSave) throw StateError('disk full');
    value = choice;
  }
}

class _UnreadableStore extends _MemoryStore {
  _UnreadableStore() : super(ScanNotifyChoice.noRuleOnly);

  @override
  Future<ScanNotifyChoice> getScanNotifyChoice() async =>
      throw StateError('database is locked');
}

void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  Future<void> pumpRow(
    WidgetTester tester,
    HostPlatform host, {
    required SettingsStore store,
    bool channels = false,
    Future<bool> Function()? open,
  }) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities(host);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScanNotificationsRow(
          settingsStore: store,
          channelsProbe: () async => channels,
          openAndroidSettings: open,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final host in [HostPlatform.windows, HostPlatform.ios]) {
    group('${host.name}: the in-app choice', () {
      testWidgets('shows the title and both values, default on "Only when '
          'there are No Rule items"', (tester) async {
        await pumpRow(tester, host,
            store: _MemoryStore(ScanNotifyChoice.noRuleOnly));
        expect(find.text('Scan notifications'), findsOneWidget);
        expect(find.text('Only when one or more No Rule items'), findsOneWidget);
        await tester.tap(find.byKey(const Key('scan_notifications_choice')));
        await tester.pumpAndSettle();
        expect(find.text('Every completed scan'), findsWidgets);
        expect(find.text('Only when one or more No Rule items'), findsWidgets);
        expect(find.byKey(const Key('scan_notifications_open')), findsNothing);
      });

      // Sprint 83 MV (Harold): the list opened upward over the title. What
      // this does NOT catch: a window so short that Flutter must move the menu
      // up to keep it on screen.
      testWidgets('the list opens BELOW the control, not over the title',
          (tester) async {
        await pumpRow(tester, host,
            store: _MemoryStore(ScanNotifyChoice.noRuleOnly));
        final controlBottom = tester
            .getBottomLeft(find.byKey(const Key('scan_notifications_choice')))
            .dy;
        await tester.tap(find.byKey(const Key('scan_notifications_choice')));
        await tester.pumpAndSettle();
        final firstItemTop =
            tester.getTopLeft(find.text('Every completed scan').last).dy;
        expect(firstItemTop, greaterThanOrEqualTo(controlBottom));
      });

      testWidgets('choosing "Every completed scan" saves it', (tester) async {
        final store = _MemoryStore(ScanNotifyChoice.noRuleOnly);
        await pumpRow(tester, host, store: store);
        await tester.tap(find.byKey(const Key('scan_notifications_choice')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Every completed scan').last);
        await tester.pumpAndSettle();
        expect(store.value, ScanNotifyChoice.every);
      });

      testWidgets('a saved "Every completed scan" is shown on open',
          (tester) async {
        await pumpRow(tester, host, store: _MemoryStore(ScanNotifyChoice.every));
        expect(find.text('Every completed scan'), findsOneWidget);
      });

      testWidgets('a failed save keeps the old value and says so',
          (tester) async {
        final store =
            _MemoryStore(ScanNotifyChoice.noRuleOnly, failSave: true);
        await pumpRow(tester, host, store: store);
        await tester.tap(find.byKey(const Key('scan_notifications_choice')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Every completed scan').last);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('scan_notifications_save_failed')),
            findsOneWidget);
        expect(find.text('Only when one or more No Rule items'), findsOneWidget);
      });
    });
  }

  group('Android 7.x (no channels): the same in-app choice', () {
    testWidgets('shows the two-value choice, not the Android button',
        (tester) async {
      await pumpRow(tester, HostPlatform.android,
          store: _MemoryStore(ScanNotifyChoice.noRuleOnly), channels: false);
      expect(find.byKey(const Key('scan_notifications_choice')),
          findsOneWidget);
      expect(find.byKey(const Key('scan_notifications_open')), findsNothing);
    });
  });

  group('Android 8.0+: the row opens Android notification settings', () {
    testWidgets('shows the help text and the button, no in-app choice',
        (tester) async {
      await pumpRow(tester, HostPlatform.android,
          store: _MemoryStore(ScanNotifyChoice.noRuleOnly), channels: true);
      expect(find.text('Scan notifications'), findsOneWidget);
      expect(find.textContaining('Scans with nothing to review'),
          findsOneWidget);
      expect(find.text('Open notification settings'), findsOneWidget);
      expect(
          find.byKey(const Key('scan_notifications_choice')), findsNothing);
    });

    testWidgets('the button calls the native opener', (tester) async {
      var opened = 0;
      await pumpRow(tester, HostPlatform.android,
          store: _MemoryStore(ScanNotifyChoice.noRuleOnly),
          channels: true,
          open: () async {
            opened++;
            return true;
          });
      await tester.tap(find.byKey(const Key('scan_notifications_open')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byKey(const Key('scan_notifications_open_failed')),
          findsNothing);
    });

    testWidgets('a failed open says so', (tester) async {
      await pumpRow(tester, HostPlatform.android,
          store: _MemoryStore(ScanNotifyChoice.noRuleOnly),
          channels: true,
          open: () async => false);
      await tester.tap(find.byKey(const Key('scan_notifications_open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan_notifications_open_failed')),
          findsOneWidget);
    });
  });

  // 5.1.2 F4. What this does NOT catch: a real database read error (the fake
  // store throws directly).
  testWidgets('a choice that cannot be read says so; saving clears it',
      (tester) async {
    final store = _UnreadableStore();
    await pumpRow(tester, HostPlatform.windows, store: store);
    expect(find.byKey(const Key('scan_notifications_load_failed')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('scan_notifications_choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every completed scan').last);
    await tester.pumpAndSettle();
    expect(store.value, ScanNotifyChoice.every);
    expect(find.byKey(const Key('scan_notifications_load_failed')),
        findsNothing);
  });

  test('source gate: the Background tab builds the row', () {
    final src = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
    final tab = src.substring(src.indexOf('Widget _buildBackgroundScanTab()'));
    expect(tab, contains('const ScanNotificationsRow()'));
  });
}
