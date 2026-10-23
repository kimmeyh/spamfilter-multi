import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart'
    show kReloadFailedSuffix;
import 'package:my_email_spam_filter/ui/screens/manual_rule_create_screen.dart';
import 'package:my_email_spam_filter/ui/testing/widget_keys.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/f298_reload_harness.dart';

/// F298 (PR #490 7.7.1, silent-failure review finding 1): Manual Rule Create
/// inserts straight into `rules` / `safe_senders`, so its Save must reload
/// RuleSetProvider like the other screens F298 fixed.
///
/// Unlike manual_rule_create_screen_test.dart, these tests DO press the
/// Confirm dialog's Save: the screen is pushed (F298Harness.wrapPushed), so
/// its pop on success has a route to return to, and each file runs alone.
///
/// What these tests do NOT catch: the duplicate path (nothing is written, so
/// nothing is reloaded), the TLD and Body Phrase types (same save method,
/// same reload), and Settings > Reset to Defaults (the source gate
/// f298_rule_write_reload_gate_test.dart covers that it reloads, not that the
/// reload runs).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = F298Harness();

  setUpAll(DatabaseTestHelper.initializeFfi);
  setUp(h.setUp);
  tearDown(h.tearDown);

  Future<void> createVia(WidgetTester tester, ManualRuleMode mode,
      {bool failReload = false,
      required void Function(dynamic provider) check}) async {
    useTallView(tester);
    await tester.runAsync(() async {
      final provider = await h.loadedProvider(failReload: failReload);
      if (!failReload) {
        expect(provider.rules.rules, isEmpty, reason: 'baseline');
      }
      expect(provider.safeSenders.safeSenders, isEmpty, reason: 'baseline');
      await tester.pumpWidget(
          h.wrapPushed(provider, () => ManualRuleCreateScreen(mode: mode)));
      await h.openPushed(tester);

      await tester.enterText(find.byType(TextFormField), 'spam-example.com');
      await tester.pump();
      await tapAndLetDbRun(tester, find.byKey(WidgetKeys.saveRuleButton),
          until: () => find.byType(AlertDialog).evaluate().isNotEmpty);
      await tapAndLetDbRun(
          tester, find.byKey(WidgetKeys.confirmDialogSaveButton),
          until: () => shown('Block rule created') || shown('Safe sender added'));
      check(provider);
    });
  }

  testWidgets('T-1: a block rule created here reaches the provider',
      (tester) async {
    await createVia(tester, ManualRuleMode.blockRule, check: (p) {
      expect(p.rules.rules, hasLength(1),
          reason: 'the new rule must be in use without a restart');
    });
  });

  testWidgets('T-2: a safe sender created here reaches the provider',
      (tester) async {
    await createVia(tester, ManualRuleMode.safeSender, check: (p) {
      expect(p.safeSenders.safeSenders, hasLength(1),
          reason: 'the new safe sender must be in use without a restart');
    });
  });

  testWidgets('T-3: a failed reload says "saved, not yet in effect"',
      (tester) async {
    await createVia(tester, ManualRuleMode.safeSender, failReload: true,
        check: (_) {
      expect(find.textContaining(kReloadFailedSuffix.trim()), findsOneWidget);
    });
  });
}
