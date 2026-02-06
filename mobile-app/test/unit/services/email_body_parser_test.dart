import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/email_body_parser.dart';

/// Unit tests for EmailBodyParser
///
/// Tests cover:
/// - Domain extraction from HTML href attributes
/// - Domain extraction from plain text URLs
/// - Pattern generation for rules
/// - Email address extraction from headers
void main() {
  late EmailBodyParser parser;

  setUp(() {
    parser = EmailBodyParser();
  });

  group('extractDomains', () {
    test('extracts domains from HTML href attributes', () {
      const html = '''
        <a href="https://example.com/page">Link 1</a>
        <a href="http://test.org/path?query=1">Link 2</a>
        <a href="https://sub.domain.example.com/other">Link 3</a>
      ''';

      final result = parser.extractDomains(html, null);

      expect(result.domains, containsAll(['example.com', 'test.org', 'sub.domain.example.com']));
      expect(result.totalUrlsProcessed, 3);
    });

    test('extracts domains from plain text URLs', () {
      const text = '''
        Check out https://plaintext.com/page for more info.
        Also visit http://another-site.org/path today!
      ''';

      final result = parser.extractDomains(null, text);

      expect(result.domains, containsAll(['plaintext.com', 'another-site.org']));
      expect(result.totalUrlsProcessed, 2);
    });

    test('combines domains from both HTML and plain text', () {
      const html = '<a href="https://html-link.com/page">Link</a>';
      const text = 'Visit https://text-link.com/page today!';

      final result = parser.extractDomains(html, text);

      expect(result.domains, containsAll(['html-link.com', 'text-link.com']));
      expect(result.totalUrlsProcessed, 2);
    });

    test('deduplicates same domain from multiple URLs', () {
      const html = '''
        <a href="https://example.com/page1">Link 1</a>
        <a href="https://example.com/page2">Link 2</a>
        <a href="https://example.com/page3">Link 3</a>
      ''';

      final result = parser.extractDomains(html, null);

      expect(result.domains.length, 1);
      expect(result.domains.first, 'example.com');
      expect(result.domainUrls['example.com']!.length, 3);
    });

    test('returns empty result for null inputs', () {
      final result = parser.extractDomains(null, null);

      expect(result.domains, isEmpty);
      expect(result.totalUrlsProcessed, 0);
    });

    test('returns empty result for empty strings', () {
      final result = parser.extractDomains('', '');

      expect(result.domains, isEmpty);
      expect(result.totalUrlsProcessed, 0);
    });

    test('ignores non-HTTP URLs in hrefs', () {
      const html = '''
        <a href="mailto:test@example.com">Email</a>
        <a href="javascript:void(0)">Click</a>
        <a href="https://valid.com/page">Valid</a>
      ''';

      final result = parser.extractDomains(html, null);

      expect(result.domains, ['valid.com']);
      expect(result.totalUrlsProcessed, 1);
    });

    test('handles URLs with ports', () {
      const html = '<a href="https://example.com:8080/page">Link</a>';

      final result = parser.extractDomains(html, null);

      expect(result.domains, ['example.com']);
    });

    test('handles URLs with query parameters', () {
      const html = '<a href="https://example.com/page?param=value&other=123">Link</a>';

      final result = parser.extractDomains(html, null);

      expect(result.domains, ['example.com']);
    });

    test('removes www prefix from domains', () {
      const html = '<a href="https://www.example.com/page">Link</a>';

      final result = parser.extractDomains(html, null);

      expect(result.domains, ['example.com']);
    });

    test('sorts domains alphabetically', () {
      const html = '''
        <a href="https://zebra.com">Z</a>
        <a href="https://apple.com">A</a>
        <a href="https://monkey.com">M</a>
      ''';

      final result = parser.extractDomains(html, null);

      expect(result.domains, ['apple.com', 'monkey.com', 'zebra.com']);
    });
  });

  group('generateDomainBlockPattern', () {
    test('generates pattern for simple domain', () {
      final pattern = parser.generateDomainBlockPattern('spam.com');

      expect(pattern, r'^[^@\s]+@(?:[a-z0-9-]+\.)*spam\.com$');

      // Verify pattern matches expected emails
      final regex = RegExp(pattern);
      expect(regex.hasMatch('user@spam.com'), isTrue);
      expect(regex.hasMatch('user@mail.spam.com'), isTrue);
      expect(regex.hasMatch('user@sub.mail.spam.com'), isTrue);
      expect(regex.hasMatch('user@notspam.com'), isFalse);
    });

    test('escapes special characters in domain', () {
      final pattern = parser.generateDomainBlockPattern('test.co.uk');

      expect(pattern, r'^[^@\s]+@(?:[a-z0-9-]+\.)*test\.co\.uk$');
    });
  });

  group('generateExactEmailPattern', () {
    test('generates pattern for exact email', () {
      final pattern = parser.generateExactEmailPattern('john.doe@example.com');

      expect(pattern, r'^john\.doe@example\.com$');

      // Verify pattern matches exactly
      final regex = RegExp(pattern);
      expect(regex.hasMatch('john.doe@example.com'), isTrue);
      expect(regex.hasMatch('other@example.com'), isFalse);
      expect(regex.hasMatch('john.doe@other.com'), isFalse);
    });

    test('converts email to lowercase', () {
      final pattern = parser.generateExactEmailPattern('John.DOE@Example.COM');

      expect(pattern, r'^john\.doe@example\.com$');
    });
  });

  group('generateBodyDomainPattern', () {
    test('generates pattern for body domain matching', () {
      final pattern = parser.generateBodyDomainPattern('scamsite.com');

      expect(pattern, r'scamsite\.com');

      // Verify pattern matches in body text
      final regex = RegExp(pattern);
      expect(regex.hasMatch('Visit https://scamsite.com today'), isTrue);
      expect(regex.hasMatch('Click scamsite.com/offer'), isTrue);
    });
  });

  group('extractEmailAddress', () {
    test('extracts email from "Name <email>" format', () {
      final email = parser.extractEmailAddress('John Doe <john.doe@example.com>');

      expect(email, 'john.doe@example.com');
    });

    test('handles plain email address', () {
      final email = parser.extractEmailAddress('john.doe@example.com');

      expect(email, 'john.doe@example.com');
    });

    test('converts to lowercase', () {
      final email = parser.extractEmailAddress('John.DOE@Example.COM');

      expect(email, 'john.doe@example.com');
    });

    test('handles complex display names', () {
      final email = parser.extractEmailAddress('"Doe, John" <john.doe@example.com>');

      expect(email, 'john.doe@example.com');
    });

    test('trims whitespace', () {
      final email = parser.extractEmailAddress('  john.doe@example.com  ');

      expect(email, 'john.doe@example.com');
    });
  });

  group('extractDomainFromEmail', () {
    test('extracts domain from email address', () {
      final domain = parser.extractDomainFromEmail('user@example.com');

      expect(domain, 'example.com');
    });

    test('extracts domain from "Name <email>" format', () {
      final domain = parser.extractDomainFromEmail('John Doe <user@example.com>');

      expect(domain, 'example.com');
    });

    test('returns null for invalid email', () {
      final domain = parser.extractDomainFromEmail('not-an-email');

      expect(domain, isNull);
    });

    test('returns null for email starting with @', () {
      final domain = parser.extractDomainFromEmail('@example.com');

      expect(domain, isNull);
    });

    test('handles subdomain emails', () {
      final domain = parser.extractDomainFromEmail('user@mail.example.com');

      expect(domain, 'mail.example.com');
    });
  });
}
