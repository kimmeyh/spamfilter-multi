/// F180 (Sprint 63): deferred body fetch -- header-first evaluation with the
/// full body fetched per-message only when body rules require it.
///
/// Two layers of proof:
/// 1. ORACLE EQUIVALENCE (RuleEvaluator.evaluateWithoutBody): for every
///    message class (header-matched, subject-matched, body-matched,
///    body-exception, no-match with and without body rules, AND-type
///    short-circuit, rule-order priority), the staged outcome (oracle, then
///    full evaluate when the oracle defers) is IDENTICAL to a direct full
///    evaluation. Body matching is always against the FULL body -- Harold's
///    planning requirement; truncated matching was rejected by design.
/// 2. PIPELINE FETCH SEQUENCE (real scanInbox + a recording platform): the
///    scan performs a body fetch for exactly the messages the oracle
///    deferred, and ZERO body fetches when the rule set has no body rules
///    or body exceptions (R-6 -- the bundled seed set's configuration).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/services/rule_evaluator.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import '../../helpers/database_test_helper.dart';

class _FakeCredStore extends SecureCredentialsStore {
  @override
  Future<Credentials?> getCredentials(String accountId) async =>
      Credentials(email: 'test@test.com', password: 'irrelevant');
}

Rule _rule({
  required String name,
  required int order,
  List<String> header = const [],
  List<String> subject = const [],
  List<String> body = const [],
  String type = 'OR',
  RuleExceptions? exceptions,
}) {
  return Rule(
    name: name,
    enabled: true,
    isLocal: true,
    executionOrder: order,
    conditions: RuleConditions(
        type: type, header: header, subject: subject, body: body),
    actions: RuleActions(delete: true),
    exceptions: exceptions,
  );
}

EmailMessage _msg({
  required String id,
  required String from,
  String subject = 'a subject',
  String body = '',
}) {
  return EmailMessage(
    id: id,
    from: from,
    subject: subject,
    body: body,
    headers: {'From': from, 'Subject': subject},
    receivedDate: DateTime(2026, 1, 1),
    folderName: 'INBOX',
  );
}

/// Header-only recording platform: [fetchMessages] serves messages with
/// EMPTY bodies (the F180 adapter contract) and [fetchFullBody] supplies the
/// real body on demand, recording every call. Mirrors the readonly-mode
/// test's _CountingPlatform interface shape.
class _HeaderOnlyRecordingProvider
    with BatchOperationsMixin
    implements SpamFilterPlatform {
  static final Map<String, String> fullBodies = {};
  static final List<String> bodyFetchIds = [];
  static List<EmailMessage> served = [];

  @override
  String get platformId => 'test';
  @override
  String get displayName => 'Header-Only Test Platform';
  @override
  AuthMethod get supportedAuthMethod => AuthMethod.appPassword;
  @override
  Future<void> loadCredentials(Credentials credentials) async {}
  @override
  void setDeletedRuleFolder(String? folderName) {}

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    return served
        .map((m) => EmailMessage(
              id: m.id,
              from: m.from,
              subject: m.subject,
              body: '',
              headers: m.headers,
              receivedDate: m.receivedDate,
              folderName: folderNames.first,
            ))
        .toList();
  }

  @override
  Future<EmailMessage> fetchFullBody(EmailMessage message) async {
    bodyFetchIds.add(message.id);
    return EmailMessage(
      id: message.id,
      from: message.from,
      subject: message.subject,
      body: fullBodies[message.id] ?? '',
      headers: message.headers,
      receivedDate: message.receivedDate,
      folderName: message.folderName,
    );
  }

  @override
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  }) async {}

  @override
  Future<void> moveToFolder({
    required EmailMessage message,
    required String targetFolder,
  }) async {}

  @override
  Future<void> markAsRead({required EmailMessage message}) async {}

  @override
  Future<void> applyFlag({
    required EmailMessage message,
    required String flagName,
  }) async {}

  @override
  Future<List<FolderInfo>> listFolders() async => [
        FolderInfo(
          id: 'INBOX',
          displayName: 'Inbox',
          canonicalName: CanonicalFolder.inbox,
          messageCount: 0,
          isWritable: true,
        ),
      ];

  @override
  Future<ConnectionStatus> testConnection() async =>
      ConnectionStatus.success();

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  }) async =>
      [];
}

void main() {
  group('F180 oracle equivalence (evaluateWithoutBody vs evaluate)', () {
    final rules = RuleSet(version: '1.0', settings: const {}, rules: [
      _rule(name: 'header-spam', order: 10, header: [r'@spamdomain\.com$']),
      _rule(name: 'subject-spam', order: 20, subject: [r'winner']),
      _rule(name: 'body-spam', order: 30, body: [r'miracle cure']),
      _rule(
          name: 'header-with-body-exception',
          order: 40,
          header: [r'@newsletter\.com$'],
          exceptions: RuleExceptions(body: [r'unsubscribe-token-xyz'])),
    ]);
    final evaluator = RuleEvaluator(
      ruleSet: rules,
      safeSenderList: SafeSenderList(safeSenders: []),
      compiler: PatternCompiler(),
      silent: true,
    );

    EmailMessage withBody(EmailMessage headerOnly, String body) =>
        EmailMessage(
          id: headerOnly.id,
          from: headerOnly.from,
          subject: headerOnly.subject,
          body: body,
          headers: headerOnly.headers,
          receivedDate: headerOnly.receivedDate,
          folderName: headerOnly.folderName,
        );

    Future<void> expectEquivalent(EmailMessage headerOnly, String fullBody,
        {required bool expectFetch}) async {
      final oracle = await evaluator.evaluateWithoutBody(headerOnly);
      final stagedResult = oracle ??
          await evaluator.evaluate(withBody(headerOnly, fullBody));
      final direct =
          await evaluator.evaluate(withBody(headerOnly, fullBody));
      expect(stagedResult.matchedRule, direct.matchedRule,
          reason: 'staged and direct evaluation must pick the same rule');
      expect(stagedResult.shouldDelete, direct.shouldDelete);
      expect(stagedResult.isSafeSender, direct.isSafeSender);
      expect(oracle == null, expectFetch,
          reason: expectFetch
              ? 'this class requires the body'
              : 'this class must decide from headers alone');
    }

    test('header-matched spam decides WITHOUT a body fetch', () async {
      await expectEquivalent(
          _msg(id: '1', from: 'x@spamdomain.com'), 'irrelevant body',
          expectFetch: false);
    });

    test('subject-matched spam decides WITHOUT a body fetch', () async {
      await expectEquivalent(
          _msg(id: '2', from: 'x@ok.com', subject: 'winner winner'),
          'irrelevant body',
          expectFetch: false);
    });

    test(
        'body-rule match requires the fetch and matches the FULL body '
        '(content far past any preview cap)', () async {
      final longBody = '${'padding ' * 5000}miracle cure${' tail' * 100}';
      await expectEquivalent(_msg(id: '3', from: 'x@ok.com'), longBody,
          expectFetch: true);
    });

    test('no-match ham still fetches (body rules exist and could match)',
        () async {
      await expectEquivalent(_msg(id: '4', from: 'x@ok.com'), 'plain note',
          expectFetch: true);
    });

    test('body EXCEPTION defers: the body can rescue a header match',
        () async {
      // Exception present in the body -> rule skipped -> falls through.
      await expectEquivalent(_msg(id: '5', from: 'x@newsletter.com'),
          'contains unsubscribe-token-xyz here',
          expectFetch: true);
      // Exception absent -> rule matches after the fetch.
      await expectEquivalent(
          _msg(id: '6', from: 'x@newsletter.com'), 'ordinary content',
          expectFetch: true);
    });

    test(
        'AND-type with a failed header leg short-circuits to NO without '
        'a fetch; a passed header leg defers on the body leg', () async {
      final andOnly = RuleSet(version: '1.0', settings: const {}, rules: [
        _rule(
            name: 'and-header-body',
            order: 50,
            type: 'AND',
            header: [r'@andonly\.com$'],
            body: [r'combined marker']),
      ]);
      final e = RuleEvaluator(
        ruleSet: andOnly,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: PatternCompiler(),
        silent: true,
      );
      final decided =
          await e.evaluateWithoutBody(_msg(id: '7', from: 'x@ok.com'));
      expect(decided, isNotNull,
          reason: 'failed AND header leg is decidable without the body');
      expect(decided!.matchedRule, isEmpty, reason: 'noMatch is final');

      final deferred =
          await e.evaluateWithoutBody(_msg(id: '8', from: 'x@andonly.com'));
      expect(deferred, isNull,
          reason: 'AND with header leg passed still needs the body leg');
    });

    test(
        'rule ORDER holds: an earlier undecided body rule defers even when '
        'a later header rule would match', () async {
      final ordered = RuleSet(version: '1.0', settings: const {}, rules: [
        _rule(name: 'early-body', order: 1, body: [r'zzz-never-matches']),
        _rule(name: 'late-header', order: 2, header: [r'@spamdomain\.com$']),
      ]);
      final e = RuleEvaluator(
        ruleSet: ordered,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: PatternCompiler(),
        silent: true,
      );
      expect(
          await e.evaluateWithoutBody(
              _msg(id: '9', from: 'x@spamdomain.com')),
          isNull,
          reason: 'the earlier body rule could match and outrank the later '
              'header rule -- the oracle must defer, not jump ahead');
      final full = await e.evaluate(
          _msg(id: '9', from: 'x@spamdomain.com', body: 'harmless'));
      expect(full.matchedRule, 'late-header');
    });

    test('safe-sender match decides WITHOUT a fetch even when body rules '
        'exist (whitelist short-circuits before any rule)', () async {
      final e = RuleEvaluator(
        ruleSet: rules,
        safeSenderList: SafeSenderList(safeSenders: [r'^trusted@ok\.com$']),
        compiler: PatternCompiler(),
        silent: true,
      );
      final oracle =
          await e.evaluateWithoutBody(_msg(id: '11', from: 'trusted@ok.com'));
      expect(oracle, isNotNull,
          reason: 'safe senders are from-based -- never body-dependent');
      expect(oracle!.isSafeSender, isTrue);
    });

    test('no body rules anywhere: no-match is FINAL without a fetch',
        () async {
      final headerOnlyRules =
          RuleSet(version: '1.0', settings: const {}, rules: [
        _rule(name: 'header-spam', order: 10, header: [r'@spamdomain\.com$']),
      ]);
      final e = RuleEvaluator(
        ruleSet: headerOnlyRules,
        safeSenderList: SafeSenderList(safeSenders: []),
        compiler: PatternCompiler(),
        silent: true,
      );
      final oracle =
          await e.evaluateWithoutBody(_msg(id: '10', from: 'x@ok.com'));
      expect(oracle, isNotNull);
      expect(oracle!.matchedRule, isEmpty);
    });
  });

  group('F180 pipeline fetch sequence (real scanInbox, recording provider)',
      () {
    late DatabaseTestHelper testHelper;
    late RuleSetProvider ruleProvider;
    const accountId = 'test-account@test.com';

    setUpAll(() {
      DatabaseTestHelper.initializeFfi();
    });

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      ruleProvider = RuleSetProvider();
      ruleProvider.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      await ruleProvider.loadRules();
      await ruleProvider.loadSafeSenders();

      _HeaderOnlyRecordingProvider.bodyFetchIds.clear();
      _HeaderOnlyRecordingProvider.fullBodies.clear();
      _HeaderOnlyRecordingProvider.served = [];
      final previous = PlatformRegistry.overrideFactoryForTest(
          'test', () => _HeaderOnlyRecordingProvider());
      addTearDown(
          () => PlatformRegistry.overrideFactoryForTest('test', previous));
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    Future<EmailScanProvider> runScan(List<Rule> rules) async {
      for (final rule in rules) {
        await ruleProvider.addRule(rule);
      }
      final scanProvider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      final scanner = EmailScanner(
        platformId: 'test',
        accountId: accountId,
        ruleSetProvider: ruleProvider,
        scanProvider: scanProvider,
        credStore: _FakeCredStore(),
      );
      await scanner.scanInbox(daysBack: 0, folderNames: ['INBOX']);
      return scanProvider;
    }

    test(
        'body fetches happen for EXACTLY the deferred messages; header-'
        'decided spam never fetches; outcomes correct', () async {
      _HeaderOnlyRecordingProvider.served = [
        _msg(id: 'h1', from: 'x@spamdomain.com'), // header rule -> no fetch
        _msg(id: 'b1', from: 'x@ok.com'), // body rule matches -> fetch
        _msg(id: 'n1', from: 'x@ok.com'), // no match -> fetch (body rules)
      ];
      _HeaderOnlyRecordingProvider.fullBodies['b1'] =
          'this offers a miracle cure today';
      _HeaderOnlyRecordingProvider.fullBodies['n1'] = 'plain ham';

      final scanProvider = await runScan([
        _rule(name: 'header-spam', order: 10, header: [r'@spamdomain\.com$']),
        _rule(name: 'body-spam', order: 30, body: [r'miracle cure']),
      ]);

      expect(_HeaderOnlyRecordingProvider.bodyFetchIds..sort(), ['b1', 'n1'],
          reason: 'h1 decided from headers; b1/n1 needed the body');
      expect(scanProvider.deletedCount, 2,
          reason: 'h1 (header rule) + b1 (body rule, matched against the '
              'fetched full body)');
      expect(scanProvider.noRuleCount, 1, reason: 'n1 stays unmatched');
    });

    test('R-6: a rule set with NO body rules performs ZERO body fetches',
        () async {
      _HeaderOnlyRecordingProvider.served = [
        _msg(id: 'h1', from: 'x@spamdomain.com'),
        _msg(id: 'n1', from: 'x@ok.com'),
        _msg(id: 'n2', from: 'y@ok.com'),
      ];
      final scanProvider = await runScan([
        _rule(name: 'header-spam', order: 10, header: [r'@spamdomain\.com$']),
      ]);

      expect(_HeaderOnlyRecordingProvider.bodyFetchIds, isEmpty,
          reason: 'the bundled seed configuration (100% header rules) must '
              'never pay a body fetch');
      expect(scanProvider.deletedCount, 1);
      expect(scanProvider.noRuleCount, 2);
    });
  });
}
