import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart' show Rule;
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart'
    show kReloadFailedSuffix;
import 'package:my_email_spam_filter/core/storage/database_helper.dart'
    show RuleDatabaseProvider;
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/rule_quick_add_screen.dart';
import 'package:my_email_spam_filter/ui/screens/safe_sender_quick_add_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/f298_reload_harness.dart';

/// F298 (Sprint 80, #496): the two quick-add screens write straight to the
/// stores, so each must reload RuleSetProvider -- covering the new entry AND
/// the conflicting entries it removes (rule quick add removes matching safe
/// senders; safe sender quick add removes matching rules).
///
/// What these tests do NOT catch: the RED-authentication warning dialog path
/// of the safe sender screen (it only gates the save; the reload is after it),
/// a save whose pop is ignored by the caller, a safe sender save that fails
/// after it (nothing is removed then, so nothing needs reloading), or a
/// reload after SEVERAL removals (each test uses one conflicting entry).

/// A rule store whose addRule always fails, to reach the catch path after the
/// conflicting safe senders were already removed.
class _AddFailsRuleStore extends RuleDatabaseStore {
  _AddFailsRuleStore(RuleDatabaseProvider provider) : super(provider);

  @override
  Future<void> addRule(Rule rule) async =>
      throw StateError('F298 test: simulated addRule failure');
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

  Future<void> saveRuleScreen(WidgetTester tester, bool failReload,
      void Function(dynamic p) check) async {
    useTallView(tester);
    await tester.runAsync(() async {
      await h.insertSafeSender(safePattern); // conflicts with the new rule
      final provider = await h.loadedProvider(failReload: failReload);
      expect(provider.rules.rules, isEmpty, reason: 'baseline');
      expect(provider.safeSenders.safeSenders, [safePattern],
          reason: 'baseline');
      await tester.pumpWidget(h.wrapPushed(
          provider,
          () => RuleQuickAddScreen(
              email: email(),
              ruleStore: ruleStore(),
              safeSenderStore: safeStore())));
      await h.openPushed(tester);
      await tester.pump(const Duration(milliseconds: 300));

      final save = find.text('Save Rule');
      await tester.ensureVisible(save);
      await tester.pump();
      await tapAndLetDbRun(tester, save,
          until: () => shown('Rule Conflict Detected'));
      // The seeded safe sender also trips the conflict WARNING; confirm it.
      expect(find.text('Rule Conflict Detected'), findsOneWidget);
      await tapAndLetDbRun(tester, find.text('Save Anyway'),
          until: () => shown('Rule added') || shown('Failed to add rule'));
      check(provider);
    });
  }

  testWidgets('T-1a: rule quick add reaches the provider (rule added and '
      'conflicting safe sender removed)', (tester) async {
    await saveRuleScreen(tester, false, (p) {
      expect(p.rules.rules.map((r) => r.name), ['AutoDeleteSpamCom']);
      expect(p.safeSenders.safeSenders, isEmpty,
          reason: 'the removed conflicting safe sender must also be reloaded');
    });
  });

  testWidgets('T-2a: rule quick add says "saved, not yet in effect" when the '
      'reload fails', (tester) async {
    await saveRuleScreen(tester, true, (p) {
      expect(find.textContaining(kReloadFailedSuffix.trim()), findsOneWidget);
    });
  });

  testWidgets('T-1c: rule quick add whose rule save FAILS still reloads the '
      'safe sender it already removed', (tester) async {
    useTallView(tester);
    await tester.runAsync(() async {
      await h.insertSafeSender(safePattern);
      final provider = await h.loadedProvider();
      expect(provider.safeSenders.safeSenders, [safePattern],
          reason: 'baseline');
      await tester.pumpWidget(h.wrapPushed(
          provider,
          () => RuleQuickAddScreen(
              email: email(),
              ruleStore: _AddFailsRuleStore(h.testHelper.dbHelper),
              safeSenderStore: safeStore())));
      await h.openPushed(tester);
      await tester.pump(const Duration(milliseconds: 300));

      final save = find.text('Save Rule');
      await tester.ensureVisible(save);
      await tester.pump();
      await tapAndLetDbRun(tester, save,
          until: () => shown('Rule Conflict Detected'));
      await tapAndLetDbRun(tester, find.text('Save Anyway'),
          until: () => shown('Rule added') || shown('Failed to add rule'));

      expect(find.textContaining('Failed to add rule'), findsOneWidget,
          reason: 'the failed rule save is still reported');
      final db = await h.testHelper.dbHelper.database;
      expect(await db.query('safe_senders'), isEmpty,
          reason: 'the conflicting safe sender was removed before the failure');
      expect(provider.safeSenders.safeSenders, isEmpty,
          reason: 'the provider must not keep a safe sender the database lost');
    });
  });

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
