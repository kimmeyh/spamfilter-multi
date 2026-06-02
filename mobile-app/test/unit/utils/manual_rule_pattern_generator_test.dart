/// Unit tests for ManualRulePatternGenerator (F25 Sub-feature 2 utility).
///
/// Covers the four explicit generators and the auto-detection path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/utils/manual_rule_pattern_generator.dart';

void main() {
  group('ManualRulePatternGenerator', () {
    // -------------------------------------------------------------------------
    // Explicit generators
    // -------------------------------------------------------------------------

    group('generateTopLevelDomain', () {
      test('generates TLD pattern from bare TLD without dot', () {
        final result = ManualRulePatternGenerator.generateTopLevelDomain('cc');
        expect(result.isSuccess, isTrue);
        expect(result.pattern, r'@.*\.cc$');
        expect(result.typeLabel, 'Top-Level Domain');
      });

      test('generates TLD pattern from TLD with leading dot', () {
        final result = ManualRulePatternGenerator.generateTopLevelDomain('.xyz');
        expect(result.isSuccess, isTrue);
        expect(result.pattern, r'@.*\.xyz$');
      });

      test('generates TLD pattern and pattern matches target email', () {
        final result = ManualRulePatternGenerator.generateTopLevelDomain('com');
        expect(result.isSuccess, isTrue);
        final regex = RegExp(result.pattern, caseSensitive: false);
        expect(regex.hasMatch('user@example.com'), isTrue);
        expect(regex.hasMatch('user@example.org'), isFalse);
      });

      test('returns failure for invalid TLD', () {
        final result =
            ManualRulePatternGenerator.generateTopLevelDomain('notarealthing12345');
        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
      });

      test('returns failure for empty input', () {
        final result = ManualRulePatternGenerator.generateTopLevelDomain('');
        expect(result.isSuccess, isFalse);
      });
    });

    group('generateEntireDomain', () {
      test('generates entire-domain pattern from bare domain', () {
        final result =
            ManualRulePatternGenerator.generateEntireDomain('example.com');
        expect(result.isSuccess, isTrue);
        expect(result.pattern, r'@(?:[a-z0-9-]+\.)*example\.com$');
        expect(result.typeLabel, 'Entire Domain');
      });

      test('pattern matches domain and subdomains', () {
        final result =
            ManualRulePatternGenerator.generateEntireDomain('example.com');
        final regex = RegExp(result.pattern, caseSensitive: false);
        expect(regex.hasMatch('user@example.com'), isTrue);
        expect(regex.hasMatch('user@mail.example.com'), isTrue);
        expect(regex.hasMatch('user@sub.mail.example.com'), isTrue);
        expect(regex.hasMatch('user@notexample.com'), isFalse);
      });

      test('extracts domain from email input', () {
        final result = ManualRulePatternGenerator.generateEntireDomain(
            'spam@badsite.org');
        expect(result.isSuccess, isTrue);
        expect(result.pattern, r'@(?:[a-z0-9-]+\.)*badsite\.org$');
      });

      test('extracts domain from URL input', () {
        final result = ManualRulePatternGenerator.generateEntireDomain(
            'https://badsite.org/page?q=1');
        expect(result.isSuccess, isTrue);
        expect(result.pattern, r'@(?:[a-z0-9-]+\.)*badsite\.org$');
      });

      test('returns failure for invalid domain', () {
        final result = ManualRulePatternGenerator.generateEntireDomain(
            'not-a-domain-at-all-xyz-fake');
        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('generateExactDomain', () {
      test('generates exact-domain pattern from bare domain', () {
        final result =
            ManualRulePatternGenerator.generateExactDomain('example.com');
        expect(result.isSuccess, isTrue);
        expect(result.pattern, r'@example\.com$');
        expect(result.typeLabel, 'Exact Domain');
      });

      test('pattern does not match subdomains', () {
        final result =
            ManualRulePatternGenerator.generateExactDomain('example.com');
        final regex = RegExp(result.pattern, caseSensitive: false);
        expect(regex.hasMatch('user@example.com'), isTrue);
        expect(regex.hasMatch('user@sub.example.com'), isFalse);
      });

      test('extracts domain from email input', () {
        final result =
            ManualRulePatternGenerator.generateExactDomain('user@test.io');
        expect(result.isSuccess, isTrue);
        expect(result.pattern, r'@test\.io$');
      });
    });

    group('generateExactEmail', () {
      test('generates exact-email pattern', () {
        final result = ManualRulePatternGenerator.generateExactEmail(
            'spam@example.com');
        expect(result.isSuccess, isTrue);
        expect(result.pattern, r'^spam@example\.com$');
        expect(result.typeLabel, 'Exact Email');
      });

      test('pattern matches only the specific address', () {
        final result = ManualRulePatternGenerator.generateExactEmail(
            'spam@example.com');
        final regex = RegExp(result.pattern, caseSensitive: false);
        expect(regex.hasMatch('spam@example.com'), isTrue);
        expect(regex.hasMatch('other@example.com'), isFalse);
        expect(regex.hasMatch('spam@other.com'), isFalse);
      });

      test('returns failure for non-email input', () {
        final result =
            ManualRulePatternGenerator.generateExactEmail('example.com');
        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
      });
    });

    // -------------------------------------------------------------------------
    // Auto-detection (Sub-feature 2 entry point)
    // -------------------------------------------------------------------------

    group('generateFromPlaintext', () {
      test('leading dot without @ -> TLD', () {
        final result =
            ManualRulePatternGenerator.generateFromPlaintext('.xyz');
        expect(result.isSuccess, isTrue);
        expect(result.typeLabel, 'Top-Level Domain');
        expect(result.pattern, r'@.*\.xyz$');
      });

      test('input containing @ -> exact email', () {
        final result = ManualRulePatternGenerator.generateFromPlaintext(
            'spam@example.com');
        expect(result.isSuccess, isTrue);
        expect(result.typeLabel, 'Exact Email');
        expect(result.pattern, r'^spam@example\.com$');
      });

      test('URL with protocol -> entire domain', () {
        final result = ManualRulePatternGenerator.generateFromPlaintext(
            'https://badsite.com/page');
        expect(result.isSuccess, isTrue);
        expect(result.typeLabel, 'Entire Domain');
        expect(result.pattern, r'@(?:[a-z0-9-]+\.)*badsite\.com$');
      });

      test('bare domain with dot -> entire domain', () {
        final result =
            ManualRulePatternGenerator.generateFromPlaintext('example.com');
        expect(result.isSuccess, isTrue);
        expect(result.typeLabel, 'Entire Domain');
        expect(result.pattern, r'@(?:[a-z0-9-]+\.)*example\.com$');
      });

      test('bare word without dot -> TLD attempt', () {
        // A bare word like "com" is a valid TLD; "com" should produce TLD result.
        final result =
            ManualRulePatternGenerator.generateFromPlaintext('com');
        // "com" is a valid IANA TLD so it should succeed
        expect(result.isSuccess, isTrue);
        expect(result.typeLabel, 'Top-Level Domain');
      });

      test('empty input -> failure', () {
        final result = ManualRulePatternGenerator.generateFromPlaintext('');
        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
      });

      test('input with leading/trailing spaces is trimmed', () {
        final result =
            ManualRulePatternGenerator.generateFromPlaintext('  .cc  ');
        expect(result.isSuccess, isTrue);
        expect(result.typeLabel, 'Top-Level Domain');
      });

      test('generated pattern compiles as valid regex', () {
        for (final input in [
          '.org',
          'example.com',
          'spam@example.com',
          'https://example.com',
        ]) {
          final result = ManualRulePatternGenerator.generateFromPlaintext(input);
          if (result.isSuccess) {
            expect(
              () => RegExp(result.pattern, caseSensitive: false),
              returnsNormally,
              reason: 'Pattern for "$input" should compile: ${result.pattern}',
            );
          }
        }
      });
    });

    // -------------------------------------------------------------------------
    // PatternGenerationResult contract
    // -------------------------------------------------------------------------

    group('PatternGenerationResult', () {
      test('success result has isSuccess true', () {
        final result = PatternGenerationResult.success(
          pattern: r'@example\.com$',
          typeLabel: 'Exact Domain',
        );
        expect(result.isSuccess, isTrue);
        expect(result.error, isNull);
        expect(result.pattern, r'@example\.com$');
      });

      test('failure result has isSuccess false', () {
        final result = PatternGenerationResult.failure(
          typeLabel: 'Exact Domain',
          error: 'Something went wrong',
        );
        expect(result.isSuccess, isFalse);
        expect(result.pattern, isEmpty);
        expect(result.error, 'Something went wrong');
      });
    });
  });
}
