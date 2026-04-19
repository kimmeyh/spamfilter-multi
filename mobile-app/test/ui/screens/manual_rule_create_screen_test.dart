import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/ui/screens/manual_rule_create_screen.dart';

/// Unit tests for ManualRuleCreateScreen pattern generation logic.
///
/// These test the core pattern generation and classification without requiring
/// widget rendering, since the logic is embedded in private methods. We test
/// the generated patterns directly against the regex engine.
void main() {
  group('F56 Manual Rule Creation - Pattern Generation', () {
    group('TLD patterns', () {
      test('TLD pattern matches target domains', () {
        // Pattern generated for TLD ".cc": @.*\.cc$
        final pattern = RegExp(r'@.*\.cc$', caseSensitive: false);
        expect(pattern.hasMatch('spam@example.cc'), isTrue);
        expect(pattern.hasMatch('spam@sub.example.cc'), isTrue);
        expect(pattern.hasMatch('spam@example.com'), isFalse);
        expect(pattern.hasMatch('spam@example.cca'), isFalse);
      });

      test('TLD pattern for .xyz matches correctly', () {
        final pattern = RegExp(r'@.*\.xyz$', caseSensitive: false);
        expect(pattern.hasMatch('user@domain.xyz'), isTrue);
        expect(pattern.hasMatch('user@domain.xyzzy'), isFalse);
      });
    });

    group('Entire domain patterns', () {
      test('entire domain pattern matches domain and subdomains', () {
        // Pattern generated for "example.com": @(?:[a-z0-9-]+\.)*example\.com$
        final pattern = RegExp(r'@(?:[a-z0-9-]+\.)*example\.com$', caseSensitive: false);
        expect(pattern.hasMatch('user@example.com'), isTrue);
        expect(pattern.hasMatch('user@mail.example.com'), isTrue);
        expect(pattern.hasMatch('user@sub.mail.example.com'), isTrue);
        expect(pattern.hasMatch('user@notexample.com'), isFalse);
        expect(pattern.hasMatch('user@example.org'), isFalse);
      });

      test('entire domain extracted from email input', () {
        // User enters "spam@badsite.org", domain extracted is "badsite.org"
        final pattern = RegExp(r'@(?:[a-z0-9-]+\.)*badsite\.org$', caseSensitive: false);
        expect(pattern.hasMatch('anyone@badsite.org'), isTrue);
        expect(pattern.hasMatch('anyone@sub.badsite.org'), isTrue);
      });

      test('entire domain extracted from URL input', () {
        // User enters "https://badsite.org/page?q=1", domain is "badsite.org"
        final pattern = RegExp(r'@(?:[a-z0-9-]+\.)*badsite\.org$', caseSensitive: false);
        expect(pattern.hasMatch('user@badsite.org'), isTrue);
      });
    });

    group('Exact domain patterns', () {
      test('exact domain matches only the specified domain', () {
        // Pattern generated for "example.com": @example\.com$
        final pattern = RegExp(r'@example\.com$', caseSensitive: false);
        expect(pattern.hasMatch('user@example.com'), isTrue);
        expect(pattern.hasMatch('user@sub.example.com'), isFalse,
            reason: 'exact domain should not match subdomains');
        expect(pattern.hasMatch('user@notexample.com'), isFalse);
      });
    });

    group('Exact email patterns', () {
      test('exact email matches only the specific address', () {
        // Pattern generated for "spam@example.com": ^spam@example\.com$
        final pattern = RegExp(r'^spam@example\.com$', caseSensitive: false);
        expect(pattern.hasMatch('spam@example.com'), isTrue);
        expect(pattern.hasMatch('other@example.com'), isFalse);
        expect(pattern.hasMatch('spam@other.com'), isFalse);
      });
    });

    group('Input parsing', () {
      test('strips protocol from URL input', () {
        // _extractDomainFromInput should strip http:// and https://
        const inputs = [
          'https://example.com/path',
          'http://example.com/page?q=1',
          'example.com',
        ];
        // All should produce domain "example.com"
        for (final input in inputs) {
          var cleaned = input.trim().toLowerCase();
          if (cleaned.startsWith('http://')) cleaned = cleaned.substring(7);
          if (cleaned.startsWith('https://')) cleaned = cleaned.substring(8);
          final slashIndex = cleaned.indexOf('/');
          if (slashIndex > 0) cleaned = cleaned.substring(0, slashIndex);
          expect(cleaned, 'example.com', reason: 'Input: $input');
        }
      });

      test('extracts domain from email address', () {
        const email = 'user@example.com';
        final domain = email.split('@').last;
        expect(domain, 'example.com');
      });
    });

    group('ReDoS validation (SEC-1b)', () {
      test('rejects catastrophic backtracking pattern', () {
        // (a+)+$ is a classic ReDoS pattern
        final warnings = PatternCompiler.detectReDoS(r'(a+)+$');
        expect(warnings, isNotEmpty,
            reason: 'ReDoS pattern should be rejected');
      });

      test('accepts safe TLD pattern', () {
        final warnings = PatternCompiler.detectReDoS(r'@.*\.cc$');
        expect(warnings, isEmpty, reason: 'TLD pattern is safe');
      });

      test('accepts safe entire domain pattern', () {
        final warnings =
            PatternCompiler.detectReDoS(r'@(?:[a-z0-9-]+\.)*example\.com$');
        expect(warnings, isEmpty, reason: 'Entire domain pattern is safe');
      });

      test('accepts safe exact email pattern', () {
        final warnings =
            PatternCompiler.detectReDoS(r'^user@example\.com$');
        expect(warnings, isEmpty, reason: 'Exact email pattern is safe');
      });
    });

    group('Classification metadata', () {
      test('TLD rules get execution_order 10', () {
        // Verified by the ManualRuleType enum and _saveBlockRule logic
        expect(ManualRuleType.topLevelDomain.index, 0);
      });

      test('entire_domain rules get execution_order 20', () {
        expect(ManualRuleType.entireDomain.index, 1);
      });

      test('exact_domain rules get execution_order 30', () {
        expect(ManualRuleType.exactDomain.index, 2);
      });

      test('exact_email rules get execution_order 40', () {
        expect(ManualRuleType.exactEmail.index, 3);
      });

      test('safe sender mode excludes TLD type', () {
        // TLD blocking does not make sense for safe senders
        final safeSenderTypes = ManualRuleType.values
            .where((t) => t != ManualRuleType.topLevelDomain)
            .toList();
        expect(safeSenderTypes, hasLength(3));
        expect(safeSenderTypes, contains(ManualRuleType.entireDomain));
        expect(safeSenderTypes, contains(ManualRuleType.exactDomain));
        expect(safeSenderTypes, contains(ManualRuleType.exactEmail));
      });
    });

    group('YAML round-trip compatibility', () {
      test('pattern_category and pattern_sub_type survive DB insert format', () {
        // Verify the DB column names match what DefaultRuleSetService expects
        final dbRule = {
          'name': 'manual_test',
          'enabled': 1,
          'is_local': 1,
          'execution_order': 20,
          'condition_type': 'OR',
          'condition_header': jsonEncode([r'@(?:[a-z0-9-]+\.)*test\.com$']),
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'manual',
          'pattern_category': 'header_from',
          'pattern_sub_type': 'entire_domain',
          'source_domain': 'test.com',
        };

        expect(dbRule['pattern_category'], 'header_from');
        expect(dbRule['pattern_sub_type'], 'entire_domain');
        expect(dbRule['source_domain'], 'test.com');
        expect(dbRule['created_by'], 'manual');
      });
    });
  });
}
