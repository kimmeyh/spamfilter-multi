/// SEC-15 (merged into F192, Sprint 77): the Custom IMAP host policy.
///
/// `ImapHostPolicy.classify` is the ONE place the policy lives, so this table
/// is the whole specification: every range boundary, IPv6 form, `localhost`
/// variant and malformed shape.
///
/// What this does NOT catch: a host NAME that resolves to a private address
/// (classified public by design; the policy performs no DNS), and the form
/// failing to call the function (the widget test
/// `custom_imap_setup_flow_test.dart` covers the wiring).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/security/imap_host_policy.dart';

void main() {
  const local = ImapHostClass.localOrPrivate;
  const pub = ImapHostClass.publicHost;
  const bad = ImapHostClass.malformed;

  void table(String name, Map<String, ImapHostClass> cases) {
    group(name, () {
      cases.forEach((host, expected) {
        test('"$host" -> ${expected.name}', () {
          expect(ImapHostPolicy.classify(host), expected);
        });
      });
    });
  }

  table('IPv4 private and loopback ranges, with their boundaries', {
    '10.0.0.0': local,
    '10.255.255.255': local,
    '9.255.255.255': pub,
    '11.0.0.0': pub,
    '127.0.0.1': local,
    '127.255.255.254': local,
    '126.255.255.255': pub,
    '128.0.0.1': pub,
    '172.15.255.255': pub,
    '172.16.0.0': local,
    '172.31.255.255': local,
    '172.32.0.0': pub,
    '192.167.255.255': pub,
    '192.168.0.1': local,
    '192.168.255.255': local,
    '192.169.0.0': pub,
    '169.253.255.255': pub,
    '169.254.0.1': local,
    '169.255.0.0': pub,
    '0.0.0.0': local,
    '8.8.8.8': pub,
    '203.0.113.7': pub,
  });

  table('IPv6', {
    '::1': local,
    '[::1]': local,
    '::': local,
    'fc00::1': local,
    'fd12:3456:789a::1': local,
    'fdff:ffff::1': local,
    'fe00::1': pub,
    'fe80::1': local,
    'febf::1': local,
    'fec0::1': pub,
    '2001:db8::1': pub,
    '2606:4700:4700::1111': pub,
    '::ffff:192.168.1.5': local,
    '::ffff:8.8.8.8': pub,
    '::ffff:127.0.0.1': local,
  });

  table('localhost spellings', {
    'localhost': local,
    'LOCALHOST': local,
    'localhost.': local,
    'mail.localhost': local,
    ' localhost ': local,
  });

  table('public host names', {
    'imap.mail.yahoo.com': pub,
    'IMAP.Example.COM': pub,
    'mail-1.example.co.uk': pub,
    'imap.mail.yahoo.com.': pub,
    'my_mail.example.com': pub,
    // Contains "localhost" but is a different name.
    'notlocalhost.example.com': pub,
    'localhost.example.com': pub,
  });

  table('empty and malformed (the form refuses these)', {
    '': ImapHostClass.empty,
    '   ': ImapHostClass.empty,
    'imap.example.com:993': bad,
    'imap.example.com/inbox': bad,
    'imap example.com': bad,
    'user@imap.example.com': bad,
    'https://imap.example.com': bad,
    '.example.com': bad,
    'example..com': bad,
    '-bad.example.com': bad,
    'bad-.example.com': bad,
    // All-numeric last label: an IPv4 shorthand some resolvers expand to a
    // loopback or private address. Refused rather than guessed.
    '127.1': bad,
    '2130706433': bad,
    '0x7f.1': bad,
    '1.2.3': bad,
    '300.1.1.1': bad,
    'münchen.example.com': bad,
    '[not-an-address]': bad,
  });

  group('the warning text (Harold, Sprint 77 Q2)', () {
    test('is exactly the approved sentence and never mentions business use',
        () {
      expect(
        ImapHostPolicy.localNetworkWarning,
        'This server is on your own computer or local network. '
        'Continue only if you run this mail server yourself.',
      );
      final lower = ImapHostPolicy.localNetworkWarning.toLowerCase();
      // Whole words only: "network" legitimately contains "work".
      for (final word in ['business', 'work', 'office', 'company', 'enterprise']) {
        expect(RegExp('\\b$word\\b').hasMatch(lower), isFalse,
            reason: 'must not suggest "$word"');
      }
    });
  });
}
