/// F323 R-1 (Sprint 83, Q4): which body link domain Block Body offers.
///
/// What these tests do NOT catch (one line each):
///   - HTML-only mail: the function reads the text/plain body the evaluator
///     matches, so an HTML-only message is out of scope by design;
///   - the safe-sender lookup the screens pass in (the callback is a stub
///     here; the screens build it from SafeSenderList.findMatch);
///   - the body fetch itself (see f323_popup_body_fetcher_test.dart).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/body_link_domain.dart';

String? _first(String body,
        {String? sender = 'shop.example',
        bool Function(String)? safe}) =>
    firstOutsideLinkDomain(
        body: body, senderDomain: sender, isSafeDomain: safe ?? (_) => false);

void main() {
  test('the FIRST outside link wins, in document order (not alphabetical)', () {
    expect(
        _first('see https://zzz.example/a and https://aaa.example/b'),
        'zzz.example');
  });

  test('a link on exactly the sender domain is skipped', () {
    expect(
        _first('https://shop.example/a then https://other.example/b'),
        'other.example');
  });

  test('a subdomain of the sender domain is NOT an exact match (qualifies)',
      () {
    expect(_first('https://track.shop.example/a'), 'track.shop.example');
  });

  test('www is ignored and the case is folded', () {
    expect(_first('HTTPS://WWW.Shop.Example/a https://X.example'), 'x.example');
  });

  test('safe-sender link domains are skipped, exact or entire domain', () {
    bool safe(String d) => d == 'friend.example' || d.endsWith('.bank.example');
    expect(
        _first('https://friend.example https://login.bank.example '
            'https://real.example',
            safe: safe),
        'real.example');
  });

  test('no qualifying link, empty body, or no links gives null', () {
    expect(_first('https://shop.example/a'), isNull);
    expect(_first(''), isNull);
    expect(_first('no links at all'), isNull);
    expect(_first('https://friend.example', safe: (_) => true), isNull);
  });

  test('trailing sentence punctuation does not change the domain', () {
    expect(_first('Visit https://other.example.'), 'other.example');
  });

  test('a sender with no domain skips nothing', () {
    expect(_first('https://shop.example/a', sender: null), 'shop.example');
  });
}
