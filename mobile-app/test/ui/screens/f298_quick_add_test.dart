import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart'
    show
        kReloadFailedSuffix,
        kConflictingRuleCheckFailedSuffix;
import 'package:my_email_spam_filter/core/storage/database_helper.dart'
    show RuleDatabaseProvider;
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/safe_sender_quick_add_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/f298_reload_harness.dart';

/// F298 (Sprint 80, #496): the quick-add screens write straight to the
/// stores, so each must reload RuleSetProvider -- covering the new entry AND
/// the conflicting entries it removes (safe sender quick add removes matching
/// rules). Sprint 86 (F307) removed the rule quick-add page; its reload cases
/// went with it. Rule creation from the No Rule Review pop-up reloads through
/// rule_quick_action_service.dart.
///
/// What these tests do NOT catch: the RED-authentication warning dialog path
/// of the safe sender screen (it only gates the save; the reload is after it),
/// a save whose pop is ignored by the caller, a safe sender save that fails
/// after it (nothing is removed then, so nothing needs reloading), or a
/// reload after SEVERAL removals (each test uses one conflicting entry).
/// T-3b (PR #490 7.7.1) fails the REMOVAL; it does not fail the initial
/// load of the conflict candidates (same catch, same warning).

/// PR #490 7.7.1: removing a conflicting rule fails.
class _DeleteFailsRuleStore extends RuleDatabaseStore {
  _DeleteFailsRuleStore(RuleDatabaseProvider provider) : super(provider);

  @override
  Future<void> deleteRule(String ruleName) async =>
      throw StateError('simulated deleteRule failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = F298Harness();
  const sender = 'spammer@spam.com';
  const safePattern = r'^spammer@spam\.com$';

  setUpAll(DatabaseTestHelper.initializeFfi);
  setUp(h.setUp);
  tearDown(h.tearDown);

  EmailMessage email() => EmailMessage(
        id: 'm1',
        from: sender,
        subject: 'Buy now',
        body: 'body',
        headers: {'from': sender},
        receivedDate: DateTime(2026, 10, 19),
        folderName: 'INBOX',
      );

  RuleDatabaseStore ruleStore() => RuleDatabaseStore(h.testHelper.dbHelper);
  SafeSenderDatabaseStore safeStore() =>
      SafeSenderDatabaseStore(h.testHelper.dbHelper);

  Future<void> saveSafeSenderScreen(WidgetTester tester, bool failReload,
      void Function(dynamic p) check) async {
    useTallView(tester);
    await tester.runAsync(() async {
      // A rule whose from-condition matches the sender: it conflicts.
      await h.insertRule('AutoDeleteSpamCom',
          fromPattern: safePattern, column: 'condition_from');
      final provider = await h.loadedProvider(failReload: failReload);
      if (!failReload) {
        expect(provider.rules.rules, hasLength(1), reason: 'baseline');
      }
      expect(provider.safeSenders.safeSenders, isEmpty, reason: 'baseline');
      await tester.pumpWidget(h.wrapPushed(
          provider,
          () => SafeSenderQuickAddScreen(
              email: email(),
              safeSenderStore: safeStore(),
              ruleStore: ruleStore())));
      await h.openPushed(tester);
      await tester.pump(const Duration(milliseconds: 300));

      final save = find.text('Save Safe Sender');
      await tester.ensureVisible(save);
      await tester.pump();
      await tapAndLetDbRun(tester, save,
          until: () => shown('Safe sender added'));
      check(provider);
    });
  }

  testWidgets('T-3b (PR #490 7.7.1): safe sender quick add whose conflicting '
      'rule cannot be removed says so', (tester) async {
    useTallView(tester);
    await tester.runAsync(() async {
      await h.insertRule('AutoDeleteSpamCom',
          fromPattern: safePattern, column: 'condition_from');
      final provider = await h.loadedProvider();
      await tester.pumpWidget(h.wrapPushed(
          provider,
          () => SafeSenderQuickAddScreen(
              email: email(),
              safeSenderStore: safeStore(),
              ruleStore: _DeleteFailsRuleStore(h.testHelper.dbHelper))));
      await h.openPushed(tester);
      await tester.pump(const Duration(milliseconds: 300));

      final save = find.text('Save Safe Sender');
      await tester.ensureVisible(save);
      await tester.pump();
      await tapAndLetDbRun(tester, save,
          until: () => shown('Safe sender added'));

      expect(find.textContaining(kConflictingRuleCheckFailedSuffix.trim()),
          findsOneWidget);
      expect(provider.safeSenders.safeSenders, [safePattern]);
    });
  });

  testWidgets('T-1b: safe sender quick add reaches the provider (sender '
      'added and conflicting rule removed)', (tester) async {
    await saveSafeSenderScreen(tester, false, (p) {
      expect(p.safeSenders.safeSenders, [safePattern]);
      expect(p.rules.rules, isEmpty,
          reason: 'the removed conflicting rule must also be reloaded');
    });
  });

  testWidgets('T-2b: safe sender quick add says "saved, not yet in effect" '
      'when the reload fails', (tester) async {
    await saveSafeSenderScreen(tester, true, (p) {
      expect(find.textContaining(kReloadFailedSuffix.trim()), findsOneWidget);
    });
  });
}
