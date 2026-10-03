/// Sprint 75 Task 7 (R-2), PR #440 test-review MINOR-8: Settings > General
/// "Hide sender details in exports" (F206 Part C, `export_redacted_toggle`)
/// actually PERSISTS through `SettingsStore.setExportRedacted` /
/// `getExportRedacted`, and a fresh Settings screen reflects the persisted
/// value on its next load -- not just that the switch flips on screen.
///
/// Mounts the REAL SettingsScreen over a real (FFI) test database; this is a
/// cross-account General-tab setting, so no account needs to be configured.
///
/// What this does NOT catch: that every export writer
/// (`live_scan_logger.dart`, `scan_sheet_export.dart`) actually HONORS the
/// flag by redacting sender/subject/message-id -- that is a property of the
/// export writers, not of this toggle, and is covered (or not) by their own
/// tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  testWidgets(
      'toggling "Hide sender details in exports" persists through '
      'SettingsStore, and a freshly-opened Settings screen shows the '
      'persisted value', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final toggle = find.byKey(const Key('export_redacted_toggle'));

    await tester.runAsync(() async {
      await mountAndLoadDbWidget(
          tester, MaterialApp(home: SettingsScreen(key: UniqueKey())));
    });
    await tester.scrollUntilVisible(toggle, 200.0,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(toggle).value, isFalse,
        reason: 'off by default (F206 Part C)');

    await tester.runAsync(() async {
      await tester.tap(toggle);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // The on-screen switch flips immediately (local setState).
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    // It actually persisted through the store, not just local widget state.
    final persisted = await tester
        .runAsync(() => SettingsStore().getExportRedacted());
    expect(persisted, isTrue,
        reason: 'the toggle must write through SettingsStore.setExportRedacted');

    // A brand-new Settings screen instance (simulating leaving and
    // re-entering Settings) must load the persisted value, not default off.
    await tester.runAsync(() async {
      await mountAndLoadDbWidget(
          tester, MaterialApp(home: SettingsScreen(key: UniqueKey())));
    });
    await tester.scrollUntilVisible(toggle, 200.0,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(toggle).value, isTrue,
        reason: 'a fresh screen must read the persisted value back, not '
            'default to off');
  });
}
