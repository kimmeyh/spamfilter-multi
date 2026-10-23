import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart'
    show kReloadFailedSuffix;
import 'package:my_email_spam_filter/ui/screens/safe_senders_management_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';
import '../../helpers/f298_reload_harness.dart';

/// F298 (Sprint 80, #496): deleting a safe sender on Manage Safe Senders must
/// reach RuleSetProvider, so the next scan no longer treats the sender as safe.
///
/// What these tests do NOT catch: a safe sender removed through another route
/// (a YAML import has its own F297 reload) and the screen refreshing its own
/// list; they check the provider's safe-sender set, not what a scan then does
/// with it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = F298Harness();
  const pattern = r'^friend@example\.com$';

  setUpAll(DatabaseTestHelper.initializeFfi);
  setUp(h.setUp);
  tearDown(h.tearDown);

  Future<void> deleteIt(WidgetTester tester, bool failReload,
      void Function(dynamic p) check) async {
    useTallView(tester);
    await tester.runAsync(() async {
      await h.insertSafeSender(pattern);
      final provider = await h.loadedProvider(failReload: failReload);
      expect(provider.safeSenders.safeSenders, [pattern], reason: 'baseline');
      await mountAndLoadDbWidget(
          tester, h.wrap(provider, const SafeSendersManagementScreen()));

      await tapAndPump(tester, find.byTooltip('View safe sender details'));
      await tapAndPump(tester, inDialog('Delete')); // details dialog
      await tapAndLetDbRun(tester, inDialog('Delete'), // confirm dialog
          until: () => shown('Safe sender deleted'));
      check(provider);
    });
  }

  testWidgets('T-1: Delete reaches the provider', (tester) async {
    await deleteIt(tester, false, (p) {
      expect(p.safeSenders.safeSenders, isEmpty);
    });
  });

  testWidgets('T-2: a failed reload says the delete is saved but not in effect',
      (tester) async {
    await deleteIt(tester, true, (p) {
      expect(find.textContaining(kReloadFailedSuffix.trim()), findsOneWidget);
    });
  });
}
