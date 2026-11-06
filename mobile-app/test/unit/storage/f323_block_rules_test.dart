/// F323 (Sprint 83): the two new quick-action block types, saved and then
/// EVALUATED by the real rule evaluator.
///
/// - 'body': a body rule for the domain of a link (R-1).
/// - 'senderShape': a From-header rule for `news_` plus 4-6 digits (R-3).
///
/// What these tests do NOT catch (one line each):
///   - a real mail body: the bodies are hand-written text, not the output of
///     an IMAP or Gmail fetch (the fetch is covered by f323_popup_body_fetcher);
///   - Manage Rules showing the right label: only the stored columns are
///     read, not the screen;
///   - a body longer than the evaluator's limits (the rule is a plain regex).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/services/rule_evaluator.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import '../../helpers/database_test_helper.dart';

EmailMessage _mail({String from = 'a@b.example', String body = ''}) =>
    EmailMessage(
      id: '1',
      from: from,
      subject: 's',
      body: body,
      headers: {'from': from},
      receivedDate: DateTime(2026, 11, 1),
      folderName: 'INBOX',
    );

void main() {
  late DatabaseTestHelper testHelper;
  late RuleSetProvider provider;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    provider = RuleSetProvider()
      ..initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
    await provider.loadRules();
    await provider.loadSafeSenders();
  });

  tearDown(() async => testHelper.tearDown());

  Future<bool> fires(EmailMessage m) async {
    final r = await RuleEvaluator(
      ruleSet: provider.rules,
      safeSenderList: SafeSenderList(safeSenders: []),
      compiler: PatternCompiler(),
      silent: true,
    ).evaluate(m);
    return r.shouldDelete;
  }

  group('body rule (R-1)', () {
    test('is stored as a body keyword rule and deletes a mail linking there',
        () async {
      final r = await RuleQuickActionService(ruleProvider: provider)
          .createBlockRule(type: 'body', value: 'Scam-Site.com');
      expect(r.success, isTrue, reason: r.displayMessage);
      final db = await testHelper.dbHelper.database;
      final row = (await db.query('rules',
              where: 'pattern_category = ?', whereArgs: ['body']))
          .single;
      expect(row['pattern_sub_type'], 'keyword');
      expect(row['source_domain'], 'scam-site.com');

      expect(await fires(_mail(body: 'Click https://scam-site.com/x now')),
          isTrue);
      expect(await fires(_mail(body: 'see https://www.scam-site.com/x')),
          isTrue);
    });

    test('does not match inside a longer domain or a different one', () async {
      await RuleQuickActionService(ruleProvider: provider)
          .createBlockRule(type: 'body', value: 'evil.com');
      expect(await fires(_mail(body: 'https://notevil.com/a')), isFalse);
      expect(await fires(_mail(body: 'https://evil.community/a')), isFalse);
      expect(await fires(_mail(body: 'https://good.example/a')), isFalse);
      expect(await fires(_mail(body: 'https://x.evil.com/a')), isTrue);
    });

    test('a body rule leaves the sender safe-sender entries alone', () async {
      await provider.addSafeSender(r'^me@b\.example$');
      final r = await RuleQuickActionService(ruleProvider: provider)
          .createBlockRule(
              type: 'body',
              value: 'evil.com',
              senderEmailForConflictCheck: 'me@b.example');
      expect(r.success, isTrue);
      expect(r.conflictsRemoved, 0);
      expect(provider.safeSenders.safeSenders, contains(r'^me@b\.example$'));
    });
  });

  group('sender shape rule (R-3)', () {
    test('deletes news_ plus 4-6 digits at any domain, not letters', () async {
      final r = await RuleQuickActionService(ruleProvider: provider)
          .createBlockRule(type: 'senderShape', value: 'news_digits');
      expect(r.success, isTrue, reason: r.displayMessage);
      expect(await fires(_mail(from: 'news_1234@one.example')), isTrue);
      expect(await fires(_mail(from: 'news_123456@two.example')), isTrue);
      expect(await fires(_mail(from: 'news_abc@one.example')), isFalse);
      expect(await fires(_mail(from: 'news_12345678@one.example')), isFalse);
      expect(await fires(_mail(from: 'news_123@one.example')), isFalse);
    });

    test('an unknown shape value creates no rule', () async {
      final before = provider.rules.rules.length;
      final r = await RuleQuickActionService(ruleProvider: provider)
          .createBlockRule(type: 'senderShape', value: 'something_else');
      expect(r.success, isFalse);
      expect(provider.rules.rules.length, before);
    });
  });
}
