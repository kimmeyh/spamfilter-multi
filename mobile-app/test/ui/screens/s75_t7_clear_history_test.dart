/// Sprint 75 Task 7 (R-2), PR #440 test-review MINOR-9: Scan History
/// "Clear history" (F206 Part A, `_confirmClearHistory` in
/// `scan_history_screen.dart`) -- (1) the zero-finished SnackBar fires
/// instead of a dialog when nothing finished can be cleared, and (2) the
/// confirmation dialog states the real scope (account + scan-type filters)
/// and the in-progress count it will NOT touch.
///
/// Mounts the REAL ScanHistoryScreen over a real (FFI) test database, with
/// `flutter_secure_storage` faked the same way f232_scan_history_platform_test
/// does (the screen's `_loadHistory` reads `getSavedAccounts()` through it).
///
/// What these do NOT catch: that tapping "Clear history" actually DELETES
/// the right rows (`ScanResultStore.deleteFinishedScanResults`) -- that is a
/// store-level concern with its own tests; these pin only the SnackBar/dialog
/// text the user reads before deciding.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/screens/scan_history_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

const _accountId = 'user@aol.com';
const _secureChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;

  void mockSecureStorage() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
      if (call.method == 'read') {
        final key = (call.arguments as Map?)?['key'];
        return key == 'saved_accounts' ? _accountId : null;
      }
      if (call.method == 'readAll') {
        return <String, String>{'saved_accounts': _accountId};
      }
      return null;
    });
  }

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    mockSecureStorage();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
    await testHelper.tearDown();
  });

  Future<void> mountScanHistory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await mountAndLoadDbWidget(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RuleSetProvider>(
              create: (_) => RuleSetProvider()),
          ChangeNotifierProvider<EmailScanProvider>(
              create: (_) => EmailScanProvider()),
        ],
        child: const MaterialApp(home: ScanHistoryScreen()),
      ),
    );
  }

  final clearButton = find.byTooltip('Clear scan history');

  testWidgets(
      'nothing finished to clear: a SnackBar says so, and the confirmation '
      'dialog never opens', (tester) async {
    await tester.runAsync(() async {
      await testHelper.createTestAccount(_accountId, platformId: 'aol');
      // Only an IN-PROGRESS scan exists -- not finished, so the count must
      // be zero even though a row exists.
      await testHelper.createTestScanResult(_accountId,
          scanType: 'manual', status: 'in_progress');
      await mountScanHistory(tester);

      await tester.tap(clearButton);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('There is no finished scan history to clear.'),
        findsOneWidget);
    expect(find.text('Clear scan history?'), findsNothing,
        reason: 'an in-progress-only history must not open the destructive '
            'confirmation dialog');

    await tester.pump(const Duration(seconds: 6)); // drain the SnackBar timer
  });

  testWidgets(
      'the confirmation dialog states the real scope and the in-progress '
      'count it will keep', (tester) async {
    await tester.runAsync(() async {
      await testHelper.createTestAccount(_accountId, platformId: 'aol');
      await testHelper.createTestScanResult(_accountId,
          scanType: 'manual', status: 'completed');
      await testHelper.createTestScanResult(_accountId,
          scanType: 'manual', status: 'completed');
      // A background scan, finished, must NOT be counted once the Manual
      // filter below is applied.
      await testHelper.createTestScanResult(_accountId,
          scanType: 'background', status: 'completed');
      // In progress, SAME type as the filter -- must be reported as kept,
      // never counted toward the deletable total.
      await testHelper.createTestScanResult(_accountId,
          scanType: 'manual', status: 'in_progress');
      await mountScanHistory(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Manual'));
      await tester.pump();

      await tester.tap(clearButton);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('Clear scan history?'), findsOneWidget);
    expect(
        find.textContaining(
            'This deletes 2 finished scans (all accounts, manual scans)'),
        findsOneWidget,
        reason: 'the background scan must not inflate the manual-only count');
    expect(find.textContaining('1 scan still in progress will be kept.'),
        findsOneWidget,
        reason: 'the in-progress manual scan must be named as kept, not '
            'counted toward the 2 deletable scans');

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    expect(find.text('Clear scan history?'), findsNothing);
  });
}
