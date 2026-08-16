/// Sprint 60 Manual Validation (Harold, Android re-validation): a DEMO scan
/// appeared in Scan History labeled "Background". The card label was a binary
/// `scanType == 'manual' ? 'Manual' : 'Background'`, so the 'demo' type fell
/// into the Background bucket -- on Android, a platform with NO background
/// scheduler at all (F144/F161), which made the history read as if a
/// background scan had run. Pins the three-way Manual/Demo/Background label.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/scan_history_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  late DatabaseTestHelper testHelper;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();

    // _loadHistory enumerates configured accounts from secure storage's
    // 'saved_accounts' key (same stub shape as the no_rule_review tests).
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') {
        final key = (call.arguments as Map)['key'];
        return key == 'saved_accounts' ? 'aol-user@aol.com' : null;
      }
      if (call.method == 'readAll') {
        return <String, String>{'saved_accounts': 'aol-user@aol.com'};
      }
      return null;
    });

    await testHelper.createTestAccount('aol-user@aol.com', platformId: 'aol');
    await testHelper.createTestAccount('demo@example.com',
        platformId: 'demo');

    await testHelper.createTestScanResult(
      'aol-user@aol.com',
      scanType: 'manual',
      scanMode: 'readonly',
      totalEmails: 5,
    );
    await testHelper.createTestScanResult(
      'demo@example.com',
      scanType: 'demo',
      scanMode: 'readonly',
      totalEmails: 59,
    );
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  testWidgets(
      'a demo scan is badged "Demo", not "Background" (and a manual scan '
      'stays "Manual")', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await mountAndLoadDbWidget(
        tester,
        const MaterialApp(home: ScanHistoryScreen()),
      );
    });
    await tester.pump();

    expect(find.text('Demo'), findsOneWidget,
        reason: 'the demo scan card must carry a Demo badge -- the old '
            'binary label showed it as "Background" (Sprint 60 MV finding)');
    expect(find.text('Manual'), findsWidgets,
        reason: 'the manual scan card keeps its Manual badge (the filter '
            'chip row also contains a Manual chip, hence findsWidgets)');
    // The only "Background" text allowed is the type-filter CHIP; no CARD
    // may carry the Background badge because no background scan was seeded.
    expect(find.text('Background'), findsOneWidget,
        reason: 'exactly one Background text: the filter chip -- a second '
            'one would be a scan card mislabeled as Background');
  });
}
