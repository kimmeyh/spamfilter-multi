import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart'
    show kReloadFailedSuffix;
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/rule_edit_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/f298_reload_harness.dart';

/// F298 (Sprint 80, #496): saving an edited rule must reach RuleSetProvider.
///
/// What these tests do NOT catch: only the Enabled switch is edited, so they
/// do not prove that every field the edit screen can change is reloaded (the
/// reload is one whole-set call, so a field-specific gap is not possible
/// today, but a future partial reload would pass here). They also do not
/// cover the Rules screen refreshing its own list after the pop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = F298Harness();

  setUpAll(DatabaseTestHelper.initializeFfi);
  setUp(h.setUp);
  tearDown(h.tearDown);

  Future<void> openAndSaveDisabled(
      WidgetTester tester, bool failReload, void Function(dynamic p) check) async {
    await tester.runAsync(() async {
      await h.insertRule('example.com');
      final provider = await h.loadedProvider(failReload: failReload);
      final rule = (await RuleDatabaseStore(h.testHelper.dbHelper).loadRules())
          .rules
          .single;
      if (!failReload) {
        expect(provider.rules.rules.single.enabled, isTrue, reason: 'baseline');
      }
      await tester.pumpWidget(h.wrapPushed(
          provider,
          () => RuleEditScreen(
              rule: rule, store: RuleDatabaseStore(h.testHelper.dbHelper))));
      await h.openPushed(tester);

      await tester.tap(find.byType(SwitchListTile)); // Enabled -> off
      await tester.pump();
      final save = find.byKey(const Key('rule_edit_save_button'));
      await tester.ensureVisible(save);
      await tester.pump();
      await tapAndLetDbRun(tester, save,
          until: () => shown('Rule updated'));
      check(provider);
    });
  }

  testWidgets('T-1: Save Changes reaches the provider', (tester) async {
    useTallView(tester);
    await openAndSaveDisabled(tester, false, (p) {
      expect(p.rules.rules.single.enabled, isFalse,
          reason: 'the provider must follow the saved edit without a restart');
    });
  });

  testWidgets('T-2: a failed reload says the edit is saved but not in effect',
      (tester) async {
    useTallView(tester);
    await openAndSaveDisabled(tester, true, (p) {
      expect(find.textContaining(kReloadFailedSuffix.trim()), findsOneWidget);
    });
    // The edit itself was saved.
    await tester.runAsync(() async {
      final db = await h.testHelper.dbHelper.database;
      expect((await db.query('rules')).single['enabled'], 0);
    });
  });
}
