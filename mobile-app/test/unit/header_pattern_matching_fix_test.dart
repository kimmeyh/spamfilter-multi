import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';
import 'package:spam_filter_mobile/core/services/rule_evaluator.dart';

/// Test suite to verify the header pattern matching bug fix
///
/// This test validates that email addresses from the actual scan results PDF
/// (where 225/251 emails showed "No rule") now correctly match the patterns
/// in rules.yaml.
///
/// Bug: Header patterns were checking "from:email@domain.com" instead of just "email@domain.com"
/// Fix: Updated _matchesHeaderList to check From header value directly
void main() {
  group('Header Pattern Matching Fix - Real Scan Results', () {
    late RuleEvaluator evaluator;
    late PatternCompiler compiler;

    setUp(() {
      compiler = PatternCompiler();
    });

    /// Helper to create test email with From header
    EmailMessage createEmail(String from, String subject) {
      return EmailMessage(
        id: 'test-${from.hashCode}',
        from: from,
        subject: subject,
        body: '',
        headers: {'From': from, 'Subject': subject},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );
    }

    /// Helper to create SpamAutoDeleteHeader rule with header patterns
    RuleSet createRuleSetWithHeaderPatterns(List<String> patterns) {
      return RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          Rule(
            name: 'SpamAutoDeleteHeader',
            enabled: true,
            isLocal: true,
            executionOrder: 1,
            conditions: RuleConditions(
              type: 'OR',
              from: [],
              header: patterns,
              subject: [],
              body: [],
            ),
            actions: RuleActions(
              delete: true,
              moveToFolder: null,
            ),
            exceptions: RuleExceptions(
              from: [],
              header: [],
              subject: [],
              body: [],
            ),
          ),
        ],
      );
    }

    group('ishask.info domain (multiple occurrences in PDF)', () {
      test('info@ishask.info matches ishask.info pattern', () async {
        // Arrange
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*ishask\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'info@ishask.info',
          'Final WARNING: kimmeyharold Your Cloud account will be suspended',
        );

        // Act
        final result = await evaluator.evaluate(email);

        // Assert
        expect(result.shouldDelete, isTrue,
            reason: 'info@ishask.info should match @ishask.info pattern');
        expect(result.matchedRule, equals('SpamAutoDeleteHeader'));
      });

      test('multiple ishask.info emails all match', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*ishask\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );

        final testEmails = [
          'info@ishask.info',
          'noreply@ishask.info',
          'alert@mail.ishask.info',
          'security@sub.domain.ishask.info',
        ];

        for (final email in testEmails) {
          final message = createEmail(email, 'Test Subject');
          final result = await evaluator.evaluate(message);

          expect(result.shouldDelete, isTrue,
              reason: '$email should match ishask.info pattern');
        }
      });
    });

    group('cominally.info domain (multiple occurrences in PDF)', () {
      test('reply@cominally.info matches cominally.info pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*cominally\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'reply@cominally.info',
          'kimmeyharold Your Netflix account will be deactivated today',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
        expect(result.matchedRule, equals('SpamAutoDeleteHeader'));
      });

      test('info@cominally.info matches cominally.info pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*cominally\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'info@cominally.info',
          'Have Sex for up to 4 Hours with this',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });
    });

    group('properature.me domain (multiple occurrences in PDF)', () {
      test('reply@properature.me matches properature.me pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*properature\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'reply@properature.me',
          'Your device is severely damaged by (39) viruses',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });
    });

    group('offreshop.info domain (multiple occurrences in PDF)', () {
      test('kimmeyharold@offreshop.info matches offreshop.info pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*offreshop\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'kimmeyharold@offreshop.info',
          'Fuck Her So Hard And Deep — Make Her Pussy Clench And Cum',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });
    });

    group('chubaix.org domain (multiple occurrences in PDF)', () {
      test('info@chubaix.org matches chubaix.org pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*chubaix\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'info@chubaix.org',
          'Final Notice: kimmeyharold Your photos and videos will be deleted',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });
    });

    group('Additional domains from PDF', () {
      test('hello@mail.whatsinai.com matches whatsinai.com pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*whatsinai\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'hello@mail.whatsinai.com',
          'How to Stay Informed About AI Without Feeling Overwhelmed',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });

      test('info@goinggoing.com matches goinggoing.com pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*goinggoing\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'info@goinggoing.com',
          'Last chance! Extra 25% off select styles online',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });

      test('hello@historyfacts.com matches historyfacts.com pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*historyfacts\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'hello@historyfacts.com',
          'Why dimes and quarters have ridged edges',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });

      test('info@sterilizerauto​clavesolutions.com matches pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*sterilizerauto​clavesolutions\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'info@sterilizerauto​clavesolutions.com',
          'WANTED: Dead or Alive',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });

      test('noreply@popmenu.com matches popmenu.com pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*popmenu\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'noreply@popmenu.com',
          'Eat Well, Sip Better This January',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue);
      });
    });

    group('Complex email addresses with subdomains', () {
      test('email from subdomain matches parent domain pattern', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*ishask\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'alert@mail.server.ishask.info',
          'Multi-level subdomain test',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue,
            reason: 'Pattern should match any subdomain level');
      });
    });

    group('Verify From header is checked (not from:email format)', () {
      test('pattern WITHOUT from: prefix matches email address', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@ishask\.info$', // Pattern WITHOUT "from:" prefix
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'info@ishask.info',
          'Test',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isTrue,
            reason: 'Pattern should match email address directly, not "from:email"');
      });

      test('pattern WITH from: prefix does NOT match (validates fix)', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'from:.*@ishask\.info$', // Pattern WITH "from:" prefix (old broken way)
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'info@ishask.info',
          'Test',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isFalse,
            reason: 'Pattern with from: prefix should NOT match because From header value is just the email');
      });
    });

    group('Batch test - all PDF domains', () {
      test('all 20+ domains from PDF should match their patterns', () async {
        // Sample of domains that appeared in the "No rule" results
        final testCases = [
          {'email': 'info@ishask.info', 'pattern': r'@(?:[a-z0-9-]+\.)*ishask\.[a-z0-9.-]+$'},
          {'email': 'A.telqk@hellomag.gr', 'pattern': r'@(?:[a-z0-9-]+\.)*hellomag\.[a-z0-9.-]+$'},
          {'email': 'reply@cominally.info', 'pattern': r'@(?:[a-z0-9-]+\.)*cominally\.[a-z0-9.-]+$'},
          {'email': 'reply@properature.me', 'pattern': r'@(?:[a-z0-9-]+\.)*properature\.[a-z0-9.-]+$'},
          {'email': 'info@cominally.info', 'pattern': r'@(?:[a-z0-9-]+\.)*cominally\.[a-z0-9.-]+$'},
          {'email': 'RoundUp@apocalypto.org.uk', 'pattern': r'@(?:[a-z0-9-]+\.)*apocalypto\.[a-z0-9.-]+$'},
          {'email': 'guardians@marketing.mlbemail.com', 'pattern': r'@(?:[a-z0-9-]+\.)*mlbemail\.[a-z0-9.-]+$'},
          {'email': 'info@edcpub.com', 'pattern': r'@(?:[a-z0-9-]+\.)*edcpub\.[a-z0-9.-]+$'},
          {'email': 'email@b.oriental-trading.com', 'pattern': r'@(?:[a-z0-9-]+\.)*oriental-trading\.[a-z0-9.-]+$'},
          {'email': 'kimmeyharold@offreshop.info', 'pattern': r'@(?:[a-z0-9-]+\.)*offreshop\.[a-z0-9.-]+$'},
          {'email': 'bgsztiemu@maisejm.skyicemail.in.net', 'pattern': r'@(?:[a-z0-9-]+\.)*skyicemail\.[a-z0-9.-]+$'},
          {'email': 'hello@email.goodnewsinstead.com', 'pattern': r'@(?:[a-z0-9-]+\.)*goodnewsinstead\.[a-z0-9.-]+$'},
          {'email': 'info@goinggoing.com', 'pattern': r'@(?:[a-z0-9-]+\.)*goinggoing\.[a-z0-9.-]+$'},
          {'email': 'hello@historyfacts.com', 'pattern': r'@(?:[a-z0-9-]+\.)*historyfacts\.[a-z0-9.-]+$'},
          {'email': 'noreply@popmenu.com', 'pattern': r'@(?:[a-z0-9-]+\.)*popmenu\.[a-z0-9.-]+$'},
          {'email': 'info@chubaix.org', 'pattern': r'@(?:[a-z0-9-]+\.)*chubaix\.[a-z0-9.-]+$'},
          {'email': 'info@sterilizerauto​clavesolutions.com', 'pattern': r'@(?:[a-z0-9-]+\.)*sterilizerauto​clavesolutions\.[a-z0-9.-]+$'},
          {'email': 'hello@mail.whatsinai.com', 'pattern': r'@(?:[a-z0-9-]+\.)*whatsinai\.[a-z0-9.-]+$'},
          {'email': 'daniel-cybersecurityhq@mail.beehiiv.com', 'pattern': r'@(?:[a-z0-9-]+\.)*beehiiv\.[a-z0-9.-]+$'},
          {'email': 'DoNotReply@speedeon.info', 'pattern': r'@(?:[a-z0-9-]+\.)*speedeon\.[a-z0-9.-]+$'},
        ];

        int matchCount = 0;
        final failures = <String>[];

        for (final testCase in testCases) {
          final ruleSet = createRuleSetWithHeaderPatterns([testCase['pattern']!]);
          evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
          final email = createEmail(testCase['email']!, 'Test');
          final result = await evaluator.evaluate(email);

          if (result.shouldDelete) {
            matchCount++;
          } else {
            failures.add('${testCase['email']} did not match pattern ${testCase['pattern']}');
          }
        }

        expect(matchCount, equals(testCases.length),
            reason: 'All ${testCases.length} test emails should match their patterns. Failures: ${failures.join(", ")}');
      });
    });

    group('Non-matching cases (should still work correctly)', () {
      test('legitimate email does not match spam patterns', () async {
        final ruleSet = createRuleSetWithHeaderPatterns([
          r'@(?:[a-z0-9-]+\.)*ishask\.[a-z0-9.-]+$',
          r'@(?:[a-z0-9-]+\.)*cominally\.[a-z0-9.-]+$',
        ]);
        evaluator = RuleEvaluator(
          ruleSet: ruleSet,
          safeSenderList: SafeSenderList(safeSenders: []),
          compiler: compiler,
        );
        final email = createEmail(
          'sender@legitimate-company.com',
          'Your order has shipped',
        );

        final result = await evaluator.evaluate(email);

        expect(result.shouldDelete, isFalse,
            reason: 'Legitimate emails should not match spam patterns');
        expect(result.matchedRule, isEmpty);
      });
    });
  });
}
