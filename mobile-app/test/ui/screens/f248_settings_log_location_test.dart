/// F248 (Sprint 76) R-6 / R-7: Settings shows WHERE the diagnostic log is
/// written, and the export folder row is named for what it governs with a
/// visible "Reset to default".
///
/// Before: on the Fold (2026-10-04) the log landed in
/// Documents/diagnostics/diagnostics and nobody could tell without a test; the
/// reset was a bare X with only a tooltip ("not seeing a reset option"), and
/// the row was titled "CSV Export Directory" although it also decides where
/// YAML exports and the log go.
///
/// Mounts the REAL SettingsScreen over a real (FFI) test database.
///
/// What this does NOT catch: the folder being reachable on a phone over MTP,
/// and the platform default label text (no folder chosen) on Android.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:my_email_spam_filter/core/services/app_environment.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;
  late Directory exportDir;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    exportDir = await Directory.systemTemp.createTemp('f248_export_');
    DiagnosticLogger.invalidateCache();
  });

  tearDown(() async {
    DiagnosticLogger.invalidateCache();
    await testHelper.tearDown();
    if (await exportDir.exists()) await exportDir.delete(recursive: true);
  });

  testWidgets('with logging on, Settings says where the log is written; the '
      'export folder row reads "Export folder" with a visible "Reset to '
      'default" that clears the choice', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await SettingsStore().setDiagnosticLogEnabled(true);
      await SettingsStore().setCsvExportDirectory(exportDir.path);
      await mountAndLoadDbWidget(
          tester, MaterialApp(home: SettingsScreen(key: UniqueKey())));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // R-7: the row's name and a reset the user can SEE.
    expect(find.text('Export folder'), findsOneWidget);
    expect(find.text('CSV Export Directory'), findsNothing);
    final reset = find.byKey(const Key('export_folder_reset'));
    expect(reset, findsOneWidget);
    expect(find.descendant(of: reset, matching: find.text('Reset to default')),
        findsOneWidget,
        reason: 'visible text, not an icon with only a tooltip');

    // R-6: the folder the log actually goes to.
    final location = find.byKey(const Key('diagnostic_log_location'));
    await tester.scrollUntilVisible(location, 200.0,
        scrollable: find.byType(Scrollable).first);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    final expected = path.join(
        exportDir.path, 'diagnostics${AppEnvironment.dataDirSuffix}');
    expect(
        find.descendant(
            of: location, matching: find.text('Writing to: $expected')),
        findsOneWidget);

    // The reset clears the stored choice.
    await tester.scrollUntilVisible(reset, -200.0,
        scrollable: find.byType(Scrollable).first);
    await tester.runAsync(() async {
      await tester.tap(reset);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    final stored =
        await tester.runAsync(() => SettingsStore().getCsvExportDirectory());
    expect(stored, isNull);
    expect(find.byKey(const Key('export_folder_reset')), findsNothing,
        reason: 'nothing to reset once the default applies');

    // Unmount and let pending timers run out: after the reset the "Writing
    // to:" FutureBuilder re-reads the setting inside fake time, and sqflite
    // arms a 10 s lock-guard timer for that query.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
}
