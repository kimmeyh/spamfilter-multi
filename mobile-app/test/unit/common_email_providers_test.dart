import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/data/common_email_providers.dart';

void main() {
  group('CommonEmailProviders', () {
    group('isCommonProvider', () {
      test('recognizes Gmail domains', () {
        expect(CommonEmailProviders.isCommonProvider('gmail.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('googlemail.com'), isTrue);
      });

      test('recognizes AOL domains', () {
        expect(CommonEmailProviders.isCommonProvider('aol.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('aim.com'), isTrue);
      });

      test('recognizes Yahoo domains', () {
        expect(CommonEmailProviders.isCommonProvider('yahoo.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('yahoo.co.uk'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('yahoo.co.jp'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('ymail.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('rocketmail.com'), isTrue);
      });

      test('recognizes Microsoft domains', () {
        expect(CommonEmailProviders.isCommonProvider('outlook.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('hotmail.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('live.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('msn.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('hotmail.co.uk'), isTrue);
      });

      test('recognizes Proton domains', () {
        expect(CommonEmailProviders.isCommonProvider('protonmail.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('proton.me'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('pm.me'), isTrue);
      });

      test('recognizes iCloud domains', () {
        expect(CommonEmailProviders.isCommonProvider('icloud.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('me.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('mac.com'), isTrue);
      });

      test('recognizes Zoho domains', () {
        expect(CommonEmailProviders.isCommonProvider('zoho.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('zohomail.com'), isTrue);
      });

      test('recognizes GMX domains', () {
        expect(CommonEmailProviders.isCommonProvider('gmx.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('gmx.net'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('gmx.de'), isTrue);
      });

      test('recognizes Mail.com domains', () {
        expect(CommonEmailProviders.isCommonProvider('mail.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('email.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('usa.com'), isTrue);
      });

      test('recognizes ISP email domains', () {
        expect(CommonEmailProviders.isCommonProvider('comcast.net'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('att.net'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('verizon.net'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('cox.net'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('sbcglobal.net'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('bellsouth.net'), isTrue);
      });

      test('recognizes Yandex domains', () {
        expect(CommonEmailProviders.isCommonProvider('yandex.com'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('yandex.ru'), isTrue);
      });

      test('does not recognize business/organizational domains', () {
        expect(CommonEmailProviders.isCommonProvider('company.com'), isFalse);
        expect(CommonEmailProviders.isCommonProvider('example.org'), isFalse);
        expect(CommonEmailProviders.isCommonProvider('mybank.com'), isFalse);
        expect(CommonEmailProviders.isCommonProvider('newsletter.io'), isFalse);
      });

      test('does not recognize subdomains of providers', () {
        // Subdomains are not provider domains themselves
        expect(CommonEmailProviders.isCommonProvider('mail.gmail.com'), isFalse);
        expect(CommonEmailProviders.isCommonProvider('smtp.yahoo.com'), isFalse);
      });

      test('handles case-insensitive lookup', () {
        expect(CommonEmailProviders.isCommonProvider('Gmail.COM'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('YAHOO.COM'), isTrue);
        expect(CommonEmailProviders.isCommonProvider('Outlook.Com'), isTrue);
      });

      test('handles whitespace in domain', () {
        expect(CommonEmailProviders.isCommonProvider(' gmail.com '), isTrue);
        expect(CommonEmailProviders.isCommonProvider('  aol.com  '), isTrue);
      });
    });

    group('getProviderName', () {
      test('returns correct provider for Gmail', () {
        expect(CommonEmailProviders.getProviderName('gmail.com'), 'Gmail');
        expect(CommonEmailProviders.getProviderName('googlemail.com'), 'Gmail');
      });

      test('returns correct provider for Microsoft', () {
        expect(CommonEmailProviders.getProviderName('outlook.com'), 'Microsoft');
        expect(CommonEmailProviders.getProviderName('hotmail.com'), 'Microsoft');
        expect(CommonEmailProviders.getProviderName('live.com'), 'Microsoft');
        expect(CommonEmailProviders.getProviderName('msn.com'), 'Microsoft');
      });

      test('returns correct provider for Yahoo', () {
        expect(CommonEmailProviders.getProviderName('yahoo.com'), 'Yahoo');
        expect(CommonEmailProviders.getProviderName('ymail.com'), 'Yahoo');
      });

      test('returns correct provider for Proton', () {
        expect(CommonEmailProviders.getProviderName('protonmail.com'), 'Proton');
        expect(CommonEmailProviders.getProviderName('proton.me'), 'Proton');
        expect(CommonEmailProviders.getProviderName('pm.me'), 'Proton');
      });

      test('returns null for unknown domains', () {
        expect(CommonEmailProviders.getProviderName('company.com'), isNull);
        expect(CommonEmailProviders.getProviderName('unknown.org'), isNull);
      });

      test('handles case-insensitive lookup', () {
        expect(CommonEmailProviders.getProviderName('GMAIL.COM'), 'Gmail');
      });
    });

    group('getProviderForEmail', () {
      test('returns provider name from full email address', () {
        expect(CommonEmailProviders.getProviderForEmail('user@gmail.com'), 'Gmail');
        expect(CommonEmailProviders.getProviderForEmail('user@yahoo.com'), 'Yahoo');
        expect(CommonEmailProviders.getProviderForEmail('user@outlook.com'), 'Microsoft');
      });

      test('returns null for non-provider email', () {
        expect(CommonEmailProviders.getProviderForEmail('user@company.com'), isNull);
      });

      test('returns null for invalid email', () {
        expect(CommonEmailProviders.getProviderForEmail('no-at-sign'), isNull);
        expect(CommonEmailProviders.getProviderForEmail('@'), isNull);
      });

      test('handles case-insensitive email', () {
        expect(CommonEmailProviders.getProviderForEmail('User@Gmail.COM'), 'Gmail');
      });
    });

    group('provider metadata', () {
      test('domainCount returns total number of domains', () {
        // Should be at least the count of explicitly listed domains
        expect(CommonEmailProviders.domainCount, greaterThan(40));
      });

      test('providerCount returns total number of providers', () {
        expect(CommonEmailProviders.providerCount, greaterThanOrEqualTo(15));
      });

      test('all providers have at least one domain', () {
        for (final provider in CommonEmailProviders.providers) {
          expect(provider.domains, isNotEmpty,
              reason: '${provider.name} should have at least one domain');
        }
      });

      test('all providers have a non-empty name', () {
        for (final provider in CommonEmailProviders.providers) {
          expect(provider.name, isNotEmpty);
        }
      });

      test('no duplicate domains across providers', () {
        final allDomains = <String>[];
        for (final provider in CommonEmailProviders.providers) {
          allDomains.addAll(provider.domains);
        }
        expect(allDomains.length, equals(allDomains.toSet().length),
            reason: 'No domain should appear in multiple providers');
      });
    });
  });
}
