import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/ui/screens/safe_senders_management_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';
import '../../helpers/f298_reload_harness.dart';

/// F270 v1 (Sprint 83, T-2): "Suggested safe senders" on Manage Safe Senders.
///
/// The view is 344 logical pixels wide (the Fold cover screen), so every test
/// also proves the section does not overflow there. Addresses use `.example`
/// domains.
///
/// What these tests do NOT catch: the real Android and iPhone render of the
/// section (one shared widget; only the Windows host runs here), and a
/// production database whose rows differ from the seeded shape.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = F298Harness();
  const sender = 'orders@shop.example';
  const header = 'Suggested safe senders (1)';

  setUpAll(DatabaseTestHelper.initializeFfi);
  setUp(h.setUp);
  tearDown(h.tearDown);

  void narrowView(WidgetTester tester) {
    tester.view.physicalSize = const Size(344, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> seed({String auth = 'green', int times = 3}) async {
    await h.testHelper.createTestAccount('acct');
    final scanId = await h.testHelper.createTestScanResult('acct');
    final db = await h.testHelper.dbHelper.database;
    for (var i = 0; i < times; i++) {
      await db.insert('unmatched_emails', {
        'scan_result_id': scanId,
        'provider_identifier_type': 'uid',
        'provider_identifier_value': 'u$i',
        'from_email': 'Shop <$sender>',
        'folder_name': 'INBOX',
        'availability_status': 'unknown',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'auth_classification': auth,
      });
    }
  }

  Future<void> mount(WidgetTester tester, {Finder? ready}) async {
    final provider = await h.loadedProvider();
    await mountAndLoadDbWidget(
        tester, h.wrap(provider, const SafeSendersManagementScreen()),
        readyWhen: ready ?? find.text(header));
  }

  testWidgets('the section lists the sender with Accept and Reject, no overflow',
      (tester) async {
    narrowView(tester);
    await tester.runAsync(() async {
      await seed();
      await mount(tester);
      expect(find.text(header), findsOneWidget);
      expect(find.text(sender), findsOneWidget);
      expect(find.text('3 No Rule emails'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('no section when nothing qualifies (a yellow email)',
      (tester) async {
    narrowView(tester);
    await tester.runAsync(() async {
      await seed(auth: 'yellow');
      await mount(tester, ready: find.text('No safe senders configured'));
      expect(find.textContaining('Suggested safe senders'), findsNothing);
    });
  });

  testWidgets('Accept offers three choices, recommended marked; the tap adds it',
      (tester) async {
    narrowView(tester);
    await tester.runAsync(() async {
      await seed();
      final provider = await h.loadedProvider();
      await mountAndLoadDbWidget(
          tester, h.wrap(provider, const SafeSendersManagementScreen()),
          readyWhen: find.text(header));
      await tapAndPump(tester, find.text('Accept'));
      expect(find.text('Add as safe sender'), findsOneWidget);
      expect(find.text('Exact Email: $sender'), findsOneWidget);
      expect(find.text('Exact Domain: @shop.example'), findsOneWidget);
      expect(find.text('Entire Domain: @*.shop.example (recommended)'),
          findsOneWidget);
      expect(find.textContaining('(recommended)'), findsOneWidget);
      await tapAndLetDbRun(
          tester, find.text('Entire Domain: @*.shop.example (recommended)'),
          until: () => shown('Added entire domain'));
      expect(provider.safeSenders.safeSenders, [
        RuleQuickActionService.safeSenderPatternFor(
            'entireDomain', 'shop.example')
      ]);
      // The row is gone once the pattern is saved.
      for (var i = 0; i < 50 && shown(header); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      expect(find.textContaining('Suggested safe senders'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Reject hides the row and it stays hidden after a restart',
      (tester) async {
    narrowView(tester);
    await tester.runAsync(() async {
      await seed();
      await mount(tester);
      await tapAndLetDbRun(tester, find.text('Reject'),
          until: () => shown('Suggestion hidden for'));
      expect(find.text(sender), findsNothing);
      // Restart: a new screen on the same database.
      await tester.pumpWidget(const SizedBox());
      await mount(tester, ready: find.text('No safe senders configured'));
      expect(find.textContaining('Suggested safe senders'), findsNothing);
    });
  });

  testWidgets('a failed check shows its error, not an empty list',
      (tester) async {
    narrowView(tester);
    await tester.runAsync(() async {
      final db = await h.testHelper.dbHelper.database;
      await db.execute('DROP TABLE unmatched_emails');
      await mount(tester,
          ready: find.textContaining('could not be checked'));
      expect(find.textContaining('Suggested safe senders could not be checked'),
          findsOneWidget);
    });
  });
}
