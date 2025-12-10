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
  });
}
