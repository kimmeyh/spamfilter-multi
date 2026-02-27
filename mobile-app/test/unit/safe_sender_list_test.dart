import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';

void main() {
  group('SafeSenderList', () {
    test('checks if email is safe - exact match', () {
      final list = SafeSenderList(safeSenders: [
        r'^admin@example\.com$',
        r'^support@company\.org$',
      ]);

      expect(list.isSafe('admin@example.com'), isTrue);
      expect(list.isSafe('support@company.org'), isTrue);
      expect(list.isSafe('spam@badsite.com'), isFalse);
    });

    test('checks if email is safe - domain pattern', () {
      final list = SafeSenderList(safeSenders: [
        r'^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$',
      ]);

      expect(list.isSafe('user@example.com'), isTrue);
      expect(list.isSafe('admin@mail.example.com'), isTrue);
      expect(list.isSafe('user@subdomain.mail.example.com'), isTrue);
      expect(list.isSafe('user@otherdomain.com'), isFalse);
    });

    test('adds new safe sender', () {
      final list = SafeSenderList(safeSenders: [
        r'^admin@example\.com$',
      ]);

      expect(list.safeSenders.length, equals(1));
      
      list.add(r'^support@company\.org$');
      
      expect(list.safeSenders.length, equals(2));
      expect(list.isSafe('support@company.org'), isTrue);
    });

    test('removes safe sender', () {
      final list = SafeSenderList(safeSenders: [
        r'^admin@example\.com$',
        r'^support@company\.org$',
      ]);

      expect(list.safeSenders.length, equals(2));
      
      list.remove(r'^admin@example\.com$');
      
      expect(list.safeSenders.length, equals(1));
      expect(list.isSafe('admin@example.com'), isFalse);
      expect(list.isSafe('support@company.org'), isTrue);
    });

    test('serializes to and from map', () {
      final original = SafeSenderList(safeSenders: [
        r'^admin@example\.com$',
        r'^support@company\.org$',
      ]);

      final map = original.toMap();
      final restored = SafeSenderList.fromMap(map);

      expect(restored.safeSenders.length, equals(original.safeSenders.length));
      expect(restored.safeSenders, containsAll(original.safeSenders));
    });

    test('handles empty pattern list', () {
      final list = SafeSenderList(safeSenders: []);

      expect(list.isSafe('any@example.com'), isFalse);
    });

    test('handles invalid regex patterns gracefully', () {
      final list = SafeSenderList(safeSenders: [
        r'^admin@example\.com$',
        r'[invalid(regex',
      ]);

      // Valid pattern should still work
      expect(list.isSafe('admin@example.com'), isTrue);
      
      // Invalid pattern should not crash, just not match
      expect(list.isSafe('other@example.com'), isFalse);
    });

    test('case-insensitive email matching', () {
      final list = SafeSenderList(safeSenders: [
        r'^admin@example\.com$',
      ]);

      // SafeSenderList normalizes to lowercase internally
      expect(list.isSafe('admin@example.com'), isTrue);
      expect(list.isSafe('Admin@Example.Com'), isTrue);
      expect(list.isSafe('ADMIN@EXAMPLE.COM'), isTrue);
    });

    test('handles plus-sign subaddressing (RFC 5233)', () {
      // When user saves a safe sender for the normalized email (after + stripping),
      // it should match emails with any + prefix
      // Note: 'acct_14q5YPLkDs2kpeJz' normalizes to 'acct_14q5yplkds2kpejz' (lowercase)
      final list = SafeSenderList(safeSenders: [
        r'^acct_14q5yplkds2kpejz@stripe\.com$',
      ]);

      // Exact match (normalized form)
      expect(list.isSafe('acct_14q5yplkds2kpejz@stripe.com'), isTrue);

      // Plus-sign subaddressing: everything before last + is stripped
      // 'invoice+statements+acct_14q5YPLkDs2kpeJz@stripe.com' normalizes to:
      // 'acct_14q5yplkds2kpejz@stripe.com' (lowercase)
      expect(list.isSafe('invoice+statements+acct_14q5YPLkDs2kpeJz@stripe.com'), isTrue);

      // Single + prefix also works
      expect(list.isSafe('tag+acct_14q5yplkds2kpejz@stripe.com'), isTrue);

      // Different account should NOT match
      expect(list.isSafe('invoice+statements+acct_OTHER@stripe.com'), isFalse);
    });

    test('findMatch returns pattern info for plus-sign emails', () {
      final list = SafeSenderList(safeSenders: [
        r'^acct_14q5yplkds2kpejz@stripe\.com$',
      ]);

      // Test findMatch which is used by RuleEvaluator
      final match = list.findMatch('invoice+statements+acct_14q5YPLkDs2kpeJz@stripe.com');

      expect(match, isNotNull);
      expect(match!.pattern, equals(r'^acct_14q5yplkds2kpejz@stripe\.com$'));
      expect(match.patternType, equals('exact_email'));
    });
  });
}
