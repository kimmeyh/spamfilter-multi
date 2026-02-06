import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/utils/pattern_generation.dart';

void main() {
  group('PatternGeneration', () {
    group('generateExactEmailPattern', () {
      test('generates exact email pattern for simple email', () {
        expect(
          PatternGeneration.generateExactEmailPattern('user@example.com'),
          '^user@example\\.com\$',
        );
      });

      test('generates exact email pattern with special characters in localpart', () {
        expect(
          PatternGeneration.generateExactEmailPattern('user.name+tag@example.com'),
          '^user\\.name\\+tag@example\\.com\$',
        );
      });

      test('generates exact email pattern with hyphens in domain', () {
        expect(
          PatternGeneration.generateExactEmailPattern('user@my-domain.co.uk'),
          '^user@my-domain\\.co\\.uk\$',
        );
      });

      test('returns empty string for null input', () {
        expect(PatternGeneration.generateExactEmailPattern(null), '');
      });

      test('returns empty string for empty input', () {
        expect(PatternGeneration.generateExactEmailPattern(''), '');
      });

      test('escapes all regex special characters', () {
        expect(
          PatternGeneration.generateExactEmailPattern('user*name@exam[ple].com'),
          contains('\\*'),
        );
      });

      test('pattern can be compiled into regex', () {
        final pattern = PatternGeneration.generateExactEmailPattern('user@example.com');
        expect(pattern, isNotEmpty);
        // Should be valid regex without throwing
        RegExp(pattern, caseSensitive: false);
      });

      test('generated pattern matches exact email only', () {
        final pattern = PatternGeneration.generateExactEmailPattern('user@example.com');
        final regex = RegExp(pattern, caseSensitive: false);

        expect(regex.hasMatch('user@example.com'), true);
        expect(regex.hasMatch('other@example.com'), false);
        expect(regex.hasMatch('user@other.com'), false);
      });
    });

    group('generateDomainPattern', () {
      test('generates domain pattern from email', () {
        expect(
          PatternGeneration.generateDomainPattern('user@example.com'),
          '@example\\.com\$',
        );
      });

      test('handles domains with hyphens', () {
        expect(
          PatternGeneration.generateDomainPattern('user@my-domain.com'),
          '@my-domain\\.com\$',
        );
      });

      test('handles complex TLDs', () {
        expect(
          PatternGeneration.generateDomainPattern('user@example.co.uk'),
          '@example\\.co\\.uk\$',
        );
      });

      test('returns empty string for null input', () {
        expect(PatternGeneration.generateDomainPattern(null), '');
      });

      test('returns empty string for empty input', () {
        expect(PatternGeneration.generateDomainPattern(''), '');
      });

      test('returns empty string for email without @', () {
        expect(PatternGeneration.generateDomainPattern('invalidemail'), '');
      });

      test('pattern can be compiled into regex', () {
        final pattern = PatternGeneration.generateDomainPattern('user@example.com');
        expect(pattern, isNotEmpty);
        // Should be valid regex without throwing
        RegExp(pattern, caseSensitive: false);
      });

      test('generated pattern matches any email from domain', () {
        final pattern = PatternGeneration.generateDomainPattern('user@example.com');
        final regex = RegExp(pattern, caseSensitive: false);

        expect(regex.hasMatch('user@example.com'), true);
        expect(regex.hasMatch('admin@example.com'), true);
        expect(regex.hasMatch('support@example.com'), true);
        expect(regex.hasMatch('user@other.com'), false);
      });

      test('does not match subdomains', () {
        final pattern = PatternGeneration.generateDomainPattern('user@example.com');
        final regex = RegExp(pattern, caseSensitive: false);

        expect(regex.hasMatch('user@subdomain.example.com'), false);
      });
    });

    group('generateSubdomainPattern', () {
      test('generates subdomain pattern from email', () {
        expect(
          PatternGeneration.generateSubdomainPattern('user@example.com'),
          '@(?:[a-z0-9-]+\\.)*example\\.com\$',
        );
      });

      test('handles domains with hyphens', () {
        expect(
          PatternGeneration.generateSubdomainPattern('user@my-domain.com'),
          '@(?:[a-z0-9-]+\\.)*my-domain\\.com\$',
        );
      });

      test('handles complex TLDs', () {
        expect(
          PatternGeneration.generateSubdomainPattern('user@example.co.uk'),
          '@(?:[a-z0-9-]+\\.)*example\\.co\\.uk\$',
        );
      });

      test('returns empty string for null input', () {
        expect(PatternGeneration.generateSubdomainPattern(null), '');
      });

      test('returns empty string for empty input', () {
        expect(PatternGeneration.generateSubdomainPattern(''), '');
      });

      test('returns empty string for email without @', () {
        expect(PatternGeneration.generateSubdomainPattern('invalidemail'), '');
      });

      test('pattern can be compiled into regex', () {
        final pattern = PatternGeneration.generateSubdomainPattern('user@example.com');
        expect(pattern, isNotEmpty);
        // Should be valid regex without throwing
        RegExp(pattern, caseSensitive: false);
      });

      test('generated pattern matches domain and all subdomains', () {
        final pattern = PatternGeneration.generateSubdomainPattern('user@example.com');
        final regex = RegExp(pattern, caseSensitive: false);

        expect(regex.hasMatch('user@example.com'), true);
        expect(regex.hasMatch('user@mail.example.com'), true);
        expect(regex.hasMatch('user@sub.domain.example.com'), true);
        expect(regex.hasMatch('user@a.b.c.example.com'), true);
      });

      test('does not match different domain', () {
        final pattern = PatternGeneration.generateSubdomainPattern('user@example.com');
        final regex = RegExp(pattern, caseSensitive: false);

        expect(regex.hasMatch('user@examplecom.net'), false);
        expect(regex.hasMatch('user@other.com'), false);
      });
    });

    group('detectPatternType', () {
      test('detects Type 1: exact email pattern', () {
        // Type 1 has ^ at start and $ at end but no @(?:)
        final pattern = PatternGeneration.generateExactEmailPattern('user@example.com');
        expect(PatternGeneration.detectPatternType(pattern), 1);
      });

      test('detects Type 2: domain pattern', () {
        // Type 2 has @ but not @(?:)
        final pattern = PatternGeneration.generateDomainPattern('user@example.com');
        expect(PatternGeneration.detectPatternType(pattern), 2);
      });

      test('detects Type 3: subdomain pattern', () {
        // Type 3 has @(?:[a-z0-9-]+\.)*
        final pattern = PatternGeneration.generateSubdomainPattern('user@example.com');
        expect(PatternGeneration.detectPatternType(pattern), 3);
      });

      test('returns 0 for unknown/custom pattern', () {
        expect(
          PatternGeneration.detectPatternType('^custom.*pattern\$'),
          0,
        );
      });

      test('returns 0 for null input', () {
        expect(PatternGeneration.detectPatternType(null), 0);
      });

      test('returns 0 for empty input', () {
        expect(PatternGeneration.detectPatternType(''), 0);
      });

      test('prioritizes Type 3 detection over Type 2', () {
        // Type 3 pattern contains @(?:) so should return 3, not 2
        expect(
          PatternGeneration.detectPatternType('@(?:[a-z0-9-]+\\.)*domain\\.com\$'),
          3,
        );
      });
    });

    group('integration tests', () {
      test('generated patterns can be used with RegExp', () {
        final email = 'user@example.com';

        final exactPattern = PatternGeneration.generateExactEmailPattern(email);
        final domainPattern = PatternGeneration.generateDomainPattern(email);
        final subdomainPattern = PatternGeneration.generateSubdomainPattern(email);

        // All patterns should compile without error
        final exactRegex = RegExp(exactPattern, caseSensitive: false);
        final domainRegex = RegExp(domainPattern, caseSensitive: false);
        final subdomainRegex = RegExp(subdomainPattern, caseSensitive: false);

        expect(exactRegex.hasMatch(email), true);
        expect(domainRegex.hasMatch(email), true);
        expect(subdomainRegex.hasMatch(email), true);
      });

      test('pattern types are correctly detected after generation', () {
        final email = 'user@example.com';

        final exactPattern = PatternGeneration.generateExactEmailPattern(email);
        final domainPattern = PatternGeneration.generateDomainPattern(email);
        final subdomainPattern = PatternGeneration.generateSubdomainPattern(email);

        expect(PatternGeneration.detectPatternType(exactPattern), 1);
        expect(PatternGeneration.detectPatternType(domainPattern), 2);
        expect(PatternGeneration.detectPatternType(subdomainPattern), 3);
      });
    });
  });
}
