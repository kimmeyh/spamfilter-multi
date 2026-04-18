import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/utils/domain_validation.dart';

void main() {
  group('DomainValidation.validateDomain', () {
    test('accepts well-formed domains', () {
      expect(DomainValidation.validateDomain('example.com'), isNull);
      expect(DomainValidation.validateDomain('sub.example.com'), isNull);
      expect(DomainValidation.validateDomain('a-b.c-d.example.com'), isNull);
      expect(DomainValidation.validateDomain('example.co.uk'), isNull);
      expect(DomainValidation.validateDomain('123abc.com'), isNull);
    });

    test('rejects leading dot', () {
      // User feedback: ".junk.com" was being accepted -- now it must be rejected
      final err = DomainValidation.validateDomain('.junk.com');
      expect(err, isNotNull);
      expect(err, contains('cannot start with a dot'));
    });

    test('rejects trailing dot', () {
      final err = DomainValidation.validateDomain('junk.com.');
      expect(err, isNotNull);
      expect(err, contains('cannot end with a dot'));
    });

    test('rejects consecutive dots', () {
      final err = DomainValidation.validateDomain('junk..com');
      expect(err, isNotNull);
      expect(err, contains('consecutive dots'));
    });

    test('rejects single-label domain (no TLD)', () {
      final err = DomainValidation.validateDomain('localhost');
      expect(err, isNotNull);
      expect(err, contains('TLD'));
    });

    test('rejects empty string', () {
      expect(DomainValidation.validateDomain(''), isNotNull);
    });

    test('rejects domain with leading hyphen in label', () {
      final err = DomainValidation.validateDomain('-bad.com');
      expect(err, isNotNull);
      expect(err, contains('hyphen'));
    });

    test('rejects domain with trailing hyphen in label', () {
      final err = DomainValidation.validateDomain('bad-.com');
      expect(err, isNotNull);
      expect(err, contains('hyphen'));
    });

    test('rejects domain with invalid characters', () {
      expect(DomainValidation.validateDomain('bad_domain.com'), isNotNull);
      expect(DomainValidation.validateDomain('bad domain.com'), isNotNull);
      expect(DomainValidation.validateDomain('bad!.com'), isNotNull);
    });

    test('rejects label longer than 63 chars', () {
      final longLabel = 'a' * 64;
      final err = DomainValidation.validateDomain('$longLabel.com');
      expect(err, isNotNull);
      expect(err, contains('63 characters'));
    });

    test('rejects domain longer than 253 chars', () {
      final tooLong = '${'a' * 60}.${'b' * 60}.${'c' * 60}.${'d' * 60}.${'e' * 60}.com';
      // total ~309 chars
      final err = DomainValidation.validateDomain(tooLong);
      expect(err, isNotNull);
      expect(err, contains('253 characters'));
    });

    test('rejects TLD that is too short', () {
      final err = DomainValidation.validateDomain('example.x');
      expect(err, isNotNull);
      expect(err, contains('TLD'));
    });

    test('rejects all-numeric TLD', () {
      final err = DomainValidation.validateDomain('example.123');
      expect(err, isNotNull);
      expect(err, contains('letter'));
    });
  });

  group('DomainValidation.validateTld', () {
    test('accepts valid TLDs', () {
      expect(DomainValidation.validateTld('cc'), isNull);
      expect(DomainValidation.validateTld('com'), isNull);
      expect(DomainValidation.validateTld('xyz'), isNull);
      expect(DomainValidation.validateTld('store'), isNull);
    });

    test('rejects TLD with dots', () {
      final err = DomainValidation.validateTld('co.uk');
      expect(err, isNotNull);
      expect(err, contains('without dots'));
    });

    test('rejects empty TLD', () {
      expect(DomainValidation.validateTld(''), isNotNull);
    });

    test('rejects single-character TLD', () {
      final err = DomainValidation.validateTld('a');
      expect(err, isNotNull);
      expect(err, contains('too short'));
    });

    test('rejects TLD starting with digit', () {
      final err = DomainValidation.validateTld('1cc');
      expect(err, isNotNull);
    });

    test('rejects TLD with @', () {
      expect(DomainValidation.validateTld('cc@'), isNotNull);
    });

    test('rejects TLD with leading hyphen', () {
      final err = DomainValidation.validateTld('-cc');
      expect(err, isNotNull);
    });

    test('rejects TLD with trailing hyphen', () {
      final err = DomainValidation.validateTld('cc-');
      expect(err, isNotNull);
    });
  });

  group('DomainValidation.validateEmail', () {
    test('accepts valid emails', () {
      expect(DomainValidation.validateEmail('user@example.com'), isNull);
      expect(DomainValidation.validateEmail('first.last@example.com'), isNull);
      expect(DomainValidation.validateEmail('user+tag@example.com'), isNull);
      expect(DomainValidation.validateEmail('user_123@sub.example.com'), isNull);
    });

    test('rejects email without @', () {
      final err = DomainValidation.validateEmail('userexample.com');
      expect(err, isNotNull);
      expect(err, contains('@'));
    });

    test('rejects email with multiple @', () {
      final err = DomainValidation.validateEmail('user@@example.com');
      expect(err, isNotNull);
      expect(err, contains('exactly one'));
    });

    test('rejects email with empty local part', () {
      final err = DomainValidation.validateEmail('@example.com');
      expect(err, isNotNull);
      expect(err, contains('username'));
    });

    test('rejects email with invalid domain', () {
      // Domain part fails the validateDomain check -- e.g., leading dot
      final err = DomainValidation.validateEmail('user@.example.com');
      expect(err, isNotNull);
      expect(err, contains('Domain part'));
    });

    test('rejects email with invalid local part characters', () {
      final err = DomainValidation.validateEmail('user!@example.com');
      expect(err, isNotNull);
      expect(err, contains('username'));
    });
  });
}
