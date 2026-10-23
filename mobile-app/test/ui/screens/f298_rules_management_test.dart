import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart'
    show kReloadFailedSuffix;
import 'package:my_email_spam_filter/ui/screens/rules_management_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';
import '../../helpers/f298_reload_harness.dart';

/// F298 (Sprint 80, #496): Manage Rules writes (enable/disable, delete) must
/// reach RuleSetProvider, so Review No Rule Items and the next manual scan use
/// the new rules without a restart.
///
/// What these tests do NOT catch: they drive the real screen against a real
/// temp database, but they do not prove Review No Rule Items re-reads the
/// provider (that is the provider's contract, covered by the F297 tests), and
/// they do not cover the Edit button's route (see f298_rule_edit_test.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = F298Harness();

  setUpAll(DatabaseTestHelper.initializeFfi);
  setUp(h.setUp);
  tearDown(h.tearDown);

  Future<void> openDetails(WidgetTester tester) async {
    await tapAndPump(tester, find.byTooltip('View rule details'));
  }

  testWidgets('T-1a: Disable in the details dialog reaches the provider',
      (tester) async {
    useTallView(tester);
    await tester.runAsync(() async {
      await h.insertRule('example.com');
      final provider = await h.loadedProvider();
      expect(provider.rules.rules.single.enabled, isTrue, reason: 'baseline');
      await mountAndLoadDbWidget(
          tester, h.wrap(provider, const RulesManagementScreen()));

      await openDetails(tester);
      await tapAndLetDbRun(tester, inDialog('Disable'),
          until: () => !provider.rules.rules.single.enabled);

      expect(provider.rules.rules.single.enabled, isFalse,
          reason: 'the provider must follow the database without a restart');
    });
  });

  testWidgets('T-1b: Delete reaches the provider', (tester) async {
    useTallView(tester);
    await tester.runAsync(() async {
      await h.insertRule('example.com');
      final provider = await h.loadedProvider();
      expect(provider.rules.rules, hasLength(1), reason: 'baseline');
      await mountAndLoadDbWidget(
          tester, h.wrap(provider, const RulesManagementScreen()));

      await openDetails(tester);
      await tapAndPump(tester, inDialog('Delete')); // details dialog
      await tapAndLetDbRun(tester, inDialog('Delete'),
          until: () => shown('Deleted:')); // confirm dialog

      expect(provider.rules.rules, isEmpty);
    });
  });

  testWidgets('T-2: a failed reload says the change is saved but not in effect',
      (tester) async {
    useTallView(tester);
    await tester.runAsync(() async {
      await h.insertRule('example.com');
      final provider = await h.loadedProvider(failReload: true);
      await mountAndLoadDbWidget(
          tester, h.wrap(provider, const RulesManagementScreen()));

      await openDetails(tester);
      await tapAndPump(tester, inDialog('Delete'));
      await tapAndLetDbRun(tester, inDialog('Delete'),
          until: () => shown('Deleted:'));

      expect(find.textContaining(kReloadFailedSuffix.trim()), findsOneWidget,
          reason: 'the user must be told the delete is saved but not yet '
              'in effect');
      final db = await h.testHelper.dbHelper.database;
      expect(await db.query('rules'), isEmpty,
          reason: 'the delete itself must still have been saved');
    });
  });
}
