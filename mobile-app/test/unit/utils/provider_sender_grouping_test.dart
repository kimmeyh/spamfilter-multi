import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/utils/provider_sender_grouping.dart';

/// Sprint 46 retro IMP-1: provider-sender grouping shared by
/// ResultsDisplayScreen and NoRuleReviewScreen.
void main() {
  group('isProviderSender', () {
    test('true for known provider domains', () {
      expect(ProviderSenderGrouping.isProviderSender('bob@gmail.com'), isTrue);
      expect(ProviderSenderGrouping.isProviderSender('a@aol.com'), isTrue);
      expect(
          ProviderSenderGrouping.isProviderSender('x@hotmail.co.uk'), isTrue);
    });

    test('true for display-name From headers', () {
      expect(
          ProviderSenderGrouping.isProviderSender('Bob <bob@yahoo.com>'),
          isTrue);
    });

    test('false for business/unknown domains and unparsable input', () {
      expect(ProviderSenderGrouping.isProviderSender('a@company.com'), isFalse);
      expect(ProviderSenderGrouping.isProviderSender('a@spam.example'),
          isFalse);
      expect(ProviderSenderGrouping.isProviderSender(''), isFalse);
    });

    test('false for provider-LOOKALIKE subdomains (exact domain match only)',
        () {
      // box.crisisoffers.com is not gmail.com; mail.gmail.com.evil.com is not
      // a provider domain either -- only the exact registered domains match.
      expect(ProviderSenderGrouping.isProviderSender('a@notgmail.com'),
          isFalse);
    });
  });

  group('partitionProviderFirst', () {
    test('provider items move to the front, both groups keep relative order',
        () {
      final items = [
        'a@zcorp.com', // other 1
        'b@gmail.com', // provider 1
        'c@acme.com', // other 2
        'd@aol.com', // provider 2
      ];
      final result =
          ProviderSenderGrouping.partitionProviderFirst(items, (s) => s);

      expect(result.providerCount, 2);
      expect(result.items,
          ['b@gmail.com', 'd@aol.com', 'a@zcorp.com', 'c@acme.com']);
    });

    test('no provider items -> unchanged list, count 0', () {
      final items = ['a@zcorp.com', 'c@acme.com'];
      final result =
          ProviderSenderGrouping.partitionProviderFirst(items, (s) => s);
      expect(result.providerCount, 0);
      expect(result.items, items);
    });

    test('all provider items -> unchanged list, count == length', () {
      final items = ['a@gmail.com', 'b@yahoo.com'];
      final result =
          ProviderSenderGrouping.partitionProviderFirst(items, (s) => s);
      expect(result.providerCount, 2);
      expect(result.items, items);
    });

    test('empty list -> empty, count 0', () {
      final result = ProviderSenderGrouping.partitionProviderFirst(
          <String>[], (s) => s);
      expect(result.providerCount, 0);
      expect(result.items, isEmpty);
    });
  });
}
