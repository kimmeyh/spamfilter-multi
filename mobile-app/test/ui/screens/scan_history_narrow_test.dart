/// Sprint 84 5.1.9 rehearsal finding: on a phone-width screen the Scan History
/// type filter (All / Manual / Background) was a Row and overflowed by 26 px
/// at 412 and 360 logical pixels wide. It is now a Wrap. This test pumps the
/// screen at phone widths with an interrupted F342 row (the stopped-by-phone
/// reason) and asserts no layout exception and that the reason is shown.
///
/// Widths: 412 (Fold) and 384 (S24+, 1080 px at 2.8125). Below about 384 the shared
/// AppBar actions overflow on this screen; that predates Sprint 84 and is F351.
///
/// What this does NOT catch: the real phone font (the test font is wider, so
/// this is stricter than a device), and whether the 2-line reason is cut off
/// with an ellipsis on a real Fold cover screen (Manual Validation looks).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/ui/screens/scan_history_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);
  late DatabaseTestHelper testHelper;
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') {
        return (call.arguments as Map)['key'] == 'saved_accounts'
            ? 'aol-user@aol.com'
            : null;
      }
      if (call.method == 'readAll') {
        return <String, String>{'saved_accounts': 'aol-user@aol.com'};
      }
      return null;
    });
    await testHelper.createTestAccount('aol-user@aol.com', platformId: 'aol');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await testHelper.tearDown();
  });

  for (final size in const [Size(412, 900), Size(384, 780)]) {
    testWidgets(
        'Scan History at ${size.width.toInt()} wide: no overflow, the F342 '
        'stopped-by-phone reason is shown', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await testHelper.dbHelper.insertScanResult({
          'account_id': 'aol-user@aol.com',
          'scan_type': 'background',
          'scan_mode': 'readonly',
          'started_at': DateTime.now().millisecondsSinceEpoch,
          'total_emails': 40,
          'processed_count': 12,
          'deleted_count': 0,
          'moved_count': 0,
          'safe_sender_count': 0,
          'no_rule_count': 0,
          'error_count': 0,
          'status': 'interrupted',
          'error_message': BackgroundScanCore.stoppedByPhoneReason,
          'folders_scanned': '["INBOX"]',
        });
        await mountAndLoadDbWidget(
            tester, const MaterialApp(home: ScanHistoryScreen()));
      });
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'no layout overflow at a phone width');
      expect(find.text(BackgroundScanCore.stoppedByPhoneReason), findsOneWidget);
      expect(find.textContaining('Not finished'), findsOneWidget);
      for (final chip in ['All', 'Manual', 'Background']) {
        expect(find.widgetWithText(FilterChip, chip), findsOneWidget, reason: chip);
      }
    });
  }
}
