import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/storage/safe_sender_database_store.dart';
import 'package:spam_filter_mobile/ui/screens/safe_senders_management_screen.dart';

/// Tests for SafeSenderCategory pattern categorization logic
///
/// Verifies that the categorize() method correctly classifies safe sender
/// patterns into Exact Email, Exact Domain, Entire Domain, and Other.
void main() {
  SafeSenderPattern _makePattern(String pattern, {String type = 'custom'}) {
    return SafeSenderPattern(
      pattern: pattern,
      patternType: type,
      dateAdded: DateTime.now().millisecondsSinceEpoch,
    );
  }

  group('SafeSenderCategory.categorize', () {
    group('Exact Email patterns', () {
      test('classifies anchored email pattern with stored type "email"', () {
        final sender = _makePattern(
          r'^user@domain\.com$',
          type: 'email',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.exactEmail),
        );
      });

      test('classifies anchored email pattern by regex structure', () {
        final sender = _makePattern(
          r'^user@domain\.com$',
          type: 'custom',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.exactEmail),
        );
      });

      test('classifies various exact email patterns', () {
        final patterns = [
          r'^scottkimmey1@gmail\.com$',
          r'^noreply\-album\-archive@google\.com$',
          r'^support@id\.me$',
          r'^store\+61395140851@t\.shopifyemail\.com$',
        ];

        for (final pattern in patterns) {
          final sender = _makePattern(pattern, type: 'email');
          expect(
            SafeSenderCategory.categorize(sender),
            equals(SafeSenderCategory.exactEmail),
            reason: 'Pattern "$pattern" should be Exact Email',
          );
        }
      });
    });

    group('Exact Domain patterns', () {
      test('classifies unanchored domain pattern with stored type "domain"', () {
        final sender = _makePattern(
          '@insightfinancialassociates.com',
          type: 'domain',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.exactDomain),
        );
      });

      test('classifies unanchored domain pattern by regex structure', () {
        final sender = _makePattern(
          '@insightfinancialassociates.com',
          type: 'custom',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.exactDomain),
        );
      });

      test('classifies domain pattern without start anchor', () {
        final sender = _makePattern(
          '@example.com',
          type: 'domain',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.exactDomain),
        );
      });
    });

    group('Entire Domain patterns', () {
      test('classifies subdomain pattern with stored type "subdomain"', () {
        final sender = _makePattern(
          r'^[^@\s]+@(?:[a-z0-9-]+\.)*amazon\.com$',
          type: 'subdomain',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.entireDomain),
        );
      });

      test('classifies subdomain pattern by regex structure', () {
        final sender = _makePattern(
          r'^[^@\s]+@(?:[a-z0-9-]+\.)*microsoft\.com$',
          type: 'custom',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.entireDomain),
        );
      });

      test('classifies various entire domain patterns', () {
        final patterns = [
          r'^[^@\s]+@(?:[a-z0-9-]+\.)*github\.com$',
          r'^[^@\s]+@(?:[a-z0-9-]+\.)*email\.apple\.com$',
          r'^[^@\s]+@(?:[a-z0-9-]+\.)*teams\.microsoft\.com$',
          r'^[^@\s]+@(?:[a-z0-9-]+\.)*mit\.edu$',
        ];

        for (final pattern in patterns) {
          final sender = _makePattern(pattern, type: 'subdomain');
          expect(
            SafeSenderCategory.categorize(sender),
            equals(SafeSenderCategory.entireDomain),
            reason: 'Pattern "$pattern" should be Entire Domain',
          );
        }
      });

      test('subdomain type takes priority over anchored email structure', () {
        // This pattern has ^ and $ and @ (looks like exact email)
        // but contains subdomain wildcard, so should be Entire Domain
        final sender = _makePattern(
          r'^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$',
          type: 'subdomain',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.entireDomain),
        );
      });
    });

    group('Other patterns', () {
      test('classifies custom pattern without @ as Other', () {
        final sender = _makePattern(
          r'.*newsletter.*',
          type: 'custom',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.other),
        );
      });

      test('classifies pattern without @ as Other', () {
        final sender = _makePattern(
          r'^some-pattern-without-at$',
          type: 'custom',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.other),
        );
      });

      test('classifies empty-like pattern as Other', () {
        final sender = _makePattern(
          'something',
          type: 'custom',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.other),
        );
      });
    });

    group('stored patternType takes precedence', () {
      test('email type overrides ambiguous pattern', () {
        // Pattern might look like domain (has @ without ^) but type says email
        final sender = _makePattern(
          r'^user@domain\.com$',
          type: 'email',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.exactEmail),
        );
      });

      test('domain type overrides ambiguous pattern', () {
        final sender = _makePattern(
          '@example.com',
          type: 'domain',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.exactDomain),
        );
      });

      test('subdomain type detected by pattern content', () {
        // Even with type "custom", the subdomain regex pattern is detected
        final sender = _makePattern(
          r'^[^@\s]+@(?:[a-z0-9-]+\.)*google\.com$',
          type: 'custom',
        );
        expect(
          SafeSenderCategory.categorize(sender),
          equals(SafeSenderCategory.entireDomain),
        );
      });
    });
  });

  group('SafeSenderCategory enum', () {
    test('has exactly 4 categories', () {
      expect(SafeSenderCategory.values.length, equals(4));
    });

    test('each category has a non-empty label', () {
      for (final category in SafeSenderCategory.values) {
        expect(category.label.isNotEmpty, isTrue);
      }
    });

    test('labels are unique', () {
      final labels = SafeSenderCategory.values.map((c) => c.label).toSet();
      expect(labels.length, equals(SafeSenderCategory.values.length));
    });

    test('category labels match expected values', () {
      expect(SafeSenderCategory.exactEmail.label, equals('Exact Email'));
      expect(SafeSenderCategory.exactDomain.label, equals('Exact Domain'));
      expect(SafeSenderCategory.entireDomain.label, equals('Entire Domain'));
      expect(SafeSenderCategory.other.label, equals('Other'));
    });
  });
}
