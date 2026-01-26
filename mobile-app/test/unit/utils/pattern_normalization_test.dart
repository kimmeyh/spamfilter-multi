import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/utils/pattern_normalization.dart';

void main() {
  group('PatternNormalization', () {
    group('normalizeFromHeader', () {
      test('normalizes simple email address', () {
        expect(
          PatternNormalization.normalizeFromHeader('User@Example.COM'),
          'user@example.com',
        );
      });

      test('extracts email from "Name <email>" format', () {
        expect(
          PatternNormalization.normalizeFromHeader('John Doe <john@example.com>'),
          'john@example.com',
        );
      });

      test('extracts email from "email (Name)" format', () {
        expect(
          PatternNormalization.normalizeFromHeader('john@example.com (John Doe)'),
          'john@example.com',
        );
      });

      test('handles complex Name <email> format with mixed case', () {
        expect(
          PatternNormalization.normalizeFromHeader('Jane SMITH <Jane.Smith@Company.COM>'),
          'jane.smith@company.com',
        );
      });

      test('removes extra whitespace in Name <email> format', () {
        expect(
          PatternNormalization.normalizeFromHeader('  Name  <  email@example.com  >  '),
          'email@example.com',
        );
      });

      test('keeps valid email characters: dots and hyphens', () {
        expect(
          PatternNormalization.normalizeFromHeader('user.name+tag@my-domain.com'),
          'user.name+tag@my-domain.com',
        );
      });

      test('removes invalid characters', () {
        expect(
          PatternNormalization.normalizeFromHeader('user#name@example!com'),
          'username@examplecom',
        );
      });

      test('returns empty string for null input', () {
        expect(PatternNormalization.normalizeFromHeader(null), '');
      });

      test('returns empty string for empty input', () {
        expect(PatternNormalization.normalizeFromHeader(''), '');
      });

      test('returns empty string for malformed input', () {
        expect(
          PatternNormalization.normalizeFromHeader('<>'),
          '',
        );
      });
    });

    group('normalizeSubject', () {
      test('converts to lowercase', () {
        expect(
          PatternNormalization.normalizeSubject('URGENT: Action Required'),
          'urgent: action required',
        );
      });

      test('collapses multiple spaces to single space', () {
        expect(
          PatternNormalization.normalizeSubject('Multiple   Spaces   Here'),
          'multiple spaces here',
        );
      });

      test('trims leading and trailing whitespace', () {
        expect(
          PatternNormalization.normalizeSubject('  Trimmed Subject  '),
          'trimmed subject',
        );
      });

      test('preserves punctuation', () {
        expect(
          PatternNormalization.normalizeSubject('Re: FW: Subject?!'),
          're: fw: subject?!',
        );
      });

      test('returns empty string for null input', () {
        expect(PatternNormalization.normalizeSubject(null), '');
      });

      test('returns empty string for empty input', () {
        expect(PatternNormalization.normalizeSubject(''), '');
      });

      test('handles newlines and tabs', () {
        expect(
          PatternNormalization.normalizeSubject('Subject\nWith\tNewlines'),
          'subject with newlines',
        );
      });
    });

    group('normalizeBodyText', () {
      test('converts to lowercase', () {
        expect(
          PatternNormalization.normalizeBodyText('This Is BODY TEXT'),
          'this is body text',
        );
      });

      test('collapses multiple spaces to single space', () {
        expect(
          PatternNormalization.normalizeBodyText('Text   with   many    spaces'),
          'text with many spaces',
        );
      });

      test('removes 3+ repeated characters', () {
        expect(
          PatternNormalization.normalizeBodyText('Click!!!!! here'),
          'click! here',
        );
      });

      test('removes repeated punctuation marks', () {
        expect(
          PatternNormalization.normalizeBodyText('Wow........ Amazing!!!'),
          'wow. amazing!',
        );
      });

      test('keeps 1-2 repeated characters', () {
        expect(
          PatternNormalization.normalizeBodyText('See!! this!! pattern!!'),
          'see!! this!! pattern!!',
        );
      });

      test('trims whitespace', () {
        expect(
          PatternNormalization.normalizeBodyText('  Body text  '),
          'body text',
        );
      });

      test('returns empty string for null input', () {
        expect(PatternNormalization.normalizeBodyText(null), '');
      });

      test('returns empty string for empty input', () {
        expect(PatternNormalization.normalizeBodyText(''), '');
      });
    });

    group('extractUrls', () {
      test('extracts https:// URLs', () {
        final result = PatternNormalization.extractUrls(
          'Visit https://example.com for more info',
        );
        expect(result, contains('https://example.com'));
      });

      test('extracts http:// URLs', () {
        final result = PatternNormalization.extractUrls(
          'Check http://example.com now',
        );
        expect(result, contains('http://example.com'));
      });

      test('extracts www. URLs', () {
        final result = PatternNormalization.extractUrls(
          'Go to www.example.com',
        );
        expect(result, contains('www.example.com'));
      });

      test('extracts multiple URLs', () {
        final result = PatternNormalization.extractUrls(
          'Visit https://first.com and http://second.com and www.third.com',
        );
        expect(result.length, 3);
      });

      test('handles URLs with paths and parameters', () {
        final result = PatternNormalization.extractUrls(
          'Click https://example.com/path?param=value',
        );
        expect(result, isNotEmpty);
      });

      test('returns empty list for null input', () {
        expect(PatternNormalization.extractUrls(null), isEmpty);
      });

      test('returns empty list for empty input', () {
        expect(PatternNormalization.extractUrls(''), isEmpty);
      });

      test('returns empty list when no URLs found', () {
        expect(
          PatternNormalization.extractUrls('No URLs here'),
          isEmpty,
        );
      });

      test('converts extracted URLs to lowercase', () {
        final result = PatternNormalization.extractUrls(
          'Visit HTTPS://EXAMPLE.COM',
        );
        expect(result.first, 'https://example.com');
      });
    });

    group('extractDomain', () {
      test('extracts domain from https URL', () {
        expect(
          PatternNormalization.extractDomain('https://www.example.com/path'),
          'example.com',
        );
      });

      test('extracts domain from http URL', () {
        expect(
          PatternNormalization.extractDomain('http://mail.example.com'),
          'mail.example.com',
        );
      });

      test('extracts domain from www URL', () {
        expect(
          PatternNormalization.extractDomain('www.example.com'),
          'example.com',
        );
      });

      test('removes www prefix', () {
        expect(
          PatternNormalization.extractDomain('https://www.spam.com'),
          'spam.com',
        );
      });

      test('handles subdomains', () {
        expect(
          PatternNormalization.extractDomain('https://mail.subdomain.example.com'),
          'mail.subdomain.example.com',
        );
      });

      test('removes port number', () {
        expect(
          PatternNormalization.extractDomain('https://example.com:8080/path'),
          'example.com',
        );
      });

      test('removes path', () {
        expect(
          PatternNormalization.extractDomain('https://example.com/long/path/here'),
          'example.com',
        );
      });

      test('removes query parameters', () {
        expect(
          PatternNormalization.extractDomain('https://example.com?param=value'),
          'example.com',
        );
      });

      test('converts to lowercase', () {
        expect(
          PatternNormalization.extractDomain('HTTPS://EXAMPLE.COM'),
          'example.com',
        );
      });

      test('returns empty string for null input', () {
        expect(PatternNormalization.extractDomain(null), '');
      });

      test('returns empty string for empty input', () {
        expect(PatternNormalization.extractDomain(''), '');
      });

      test('handles complex TLDs', () {
        expect(
          PatternNormalization.extractDomain('https://example.co.uk/path'),
          'example.co.uk',
        );
      });
    });
  });
}
