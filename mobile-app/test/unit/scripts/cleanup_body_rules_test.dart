import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../scripts/cleanup_body_rules.dart';

/// F33 (Sprint 46): unit tests for the body-rules cleanup classification and
/// regex-conversion logic. These cover the pure functions used by the DB
/// cleanup script (scripts/cleanup_body_rules.dart) -- no DB required. The
/// DB apply/backup path is exercised manually against the dev DB (see the
/// SPRINT_46_F33_BODY_RULES_REPORT.md dry-run output).
void main() {
  group('extractDomainRoot', () {
    test('leading-slash full domain', () {
      expect(extractDomainRoot(r'/adianeos\.com'), 'adianeos.com');
    });

    test('leading-dot "anywhere" full domain', () {
      expect(extractDomainRoot(r'\.adianeos\.com'), 'adianeos.com');
    });

    test('bare full domain', () {
      expect(extractDomainRoot(r'adianeos\.com'), 'adianeos.com');
    });

    test('multi-label tld (co.uk)', () {
      expect(extractDomainRoot(r'/new\-word\.co\.uk'), 'new-word.co.uk');
    });

    test('escaped hyphen in label is unescaped', () {
      expect(extractDomainRoot(r'/pic\-time\.net'), 'pic-time.net');
      expect(extractDomainRoot(r'/offers\-usa\.com'), 'offers-usa.com');
    });

    test('trailing-dot without tld returns null (truncated)', () {
      expect(extractDomainRoot(r'/acslogeg\.'), isNull);
    });

    test('bare label without any dot returns null', () {
      expect(extractDomainRoot(r'/auenwind'), isNull);
    });
  });

  group('buildUrlAnchoredRegex', () {
    test('produces a regex matching the domain as a URL host', () {
      final rx = RegExp(buildUrlAnchoredRegex('adianeos.com'));
      expect(rx.hasMatch('http://adianeos.com'), isTrue); // apex after //
      expect(rx.hasMatch('https://adianeos.com'), isTrue); // https apex
      expect(rx.hasMatch('http://a.a.a.adianeos.com'), isTrue); // subdomains
      expect(rx.hasMatch('http://adianeos.com/win'), isTrue); // apex + path
    });

    test('rejects bare mentions, emails, and substrings', () {
      final rx = RegExp(buildUrlAnchoredRegex('adianeos.com'));
      expect(rx.hasMatch('bob@adianeos.com'), isFalse); // email
      expect(rx.hasMatch('adianeos.com is a scam'), isFalse); // bare text
      expect(rx.hasMatch('myadianeos.com'), isFalse); // substring
    });

    test('hyphenated domain regex behaves correctly', () {
      final rx = RegExp(buildUrlAnchoredRegex('pic-time.net'));
      expect(rx.hasMatch('http://pic-time.net/x'), isTrue);
      expect(rx.hasMatch('http://a.pic-time.net'), isTrue);
      expect(rx.hasMatch('bob@pic-time.net'), isFalse);
      expect(rx.hasMatch('mypic-time.net'), isFalse);
    });
  });

  group('analyzeBodyRules classification', () {
    Map<String, Object?> row(int id, String name, String body,
            {String? subType = 'entire_domain', String? src}) =>
        {
          'id': id,
          'name': name,
          'condition_body': jsonEncode([body]),
          'pattern_category': 'body',
          'pattern_sub_type': subType,
          'source_domain': src,
        };

    test('G1: full-domain rules are converted, not removed', () {
      final a = analyzeBodyRules([
        row(1, 'r1', r'/adianeos\.com', src: 'adianeos.com'),
        row(2, 'r2', r'\.pic\-time\.net', src: 'pic-time.net'),
      ]);
      expect(a.g1, hasLength(2));
      expect(a.g1Conversions[1], r'(?:://|[/.])adianeos\.com');
      expect(a.g1Conversions[2], r'(?:://|[/.])pic-time\.net');
      expect(a.toRemove, isEmpty);
    });

    test('G2: spaced-phrase keyword rules are reclassified, not converted', () {
      final a = analyzeBodyRules([
        row(1, 'k1', r'camp\ lejeune', src: r'camp\ lejeunecom'),
      ]);
      expect(a.keyword, hasLength(1));
      expect(a.g1Conversions, isEmpty);
      expect(a.toRemove, isEmpty);
    });

    test('G4: adamshetzner-without-tld is removed', () {
      final a = analyzeBodyRules([
        row(1, 'ad1', r'/adamshetzner\.', src: 'adamshetzner.com'),
        row(2, 'ad2', r'\.adamshetzner\.', src: 'adamshetzner.com'),
      ]);
      expect(a.adamshetznerRemovals, hasLength(2));
      expect(a.toRemove.map((r) => r.id), containsAll([1, 2]));
    });

    test('G6: truncated/bare no-tld rules are removed (all anchor forms)', () {
      final a = analyzeBodyRules([
        row(1, 't1', r'/acslogeg\.', src: 'acslogeg.com'), // slash trailing-dot
        row(2, 't2', r'/auenwind', src: 'auenwindcom'), // slash bare label
        row(3, 't3', r'\.aalbody\.', src: '.aalbody.com'), // dot trailing-dot
        row(4, 't4', r'@jacksodoy\.', src: '@jacksodoy.com'), // @ trailing-dot
        row(5, 't5', r'18birdies\.', src: '18birdies.com'), // bare trailing-dot
      ]);
      expect(a.truncated, hasLength(5));
      expect(a.toRemove.map((r) => r.id), containsAll([1, 2, 3, 4, 5]));
      expect(a.g1Conversions, isEmpty);
    });

    test('G5: empty condition_body is an orphan removal', () {
      final a = analyzeBodyRules([
        {
          'id': 1,
          'name': 'orphan',
          'condition_body': '[]',
          'pattern_category': 'body',
          'pattern_sub_type': 'entire_domain',
          'source_domain': 'x.com',
        },
      ]);
      expect(a.orphans, hasLength(1));
      expect(a.toRemove.map((r) => r.id), contains(1));
    });

    test('DUP: same-domain-root duplicates keep the first, remove the rest', () {
      final a = analyzeBodyRules([
        row(10, 'd_a', r'/adamsdomain\.com', src: 'adamsdomain.com'),
        row(11, 'd_b', r'\.adamsdomain\.com', src: 'adamsdomain.com'),
      ]);
      expect(a.duplicateRemovals, hasLength(1));
      expect(a.duplicateRemovals.first.id, 11); // higher id removed
      expect(a.g1Conversions.containsKey(10), isTrue); // survivor still converts
      expect(a.g1Conversions.containsKey(11), isFalse); // removed, not converted
      expect(a.g1.map((r) => r.id), isNot(contains(11)));
    });

    test('SPECIAL: phone number is rewritten to a format-tolerant regex', () {
      final a = analyzeBodyRules([
        row(1, 'phone', r'800\-571\-7438', src: '800-571-7438com'),
      ]);
      expect(a.specialConversions, hasLength(1));
      expect(a.ambiguous, isEmpty);
      final rx = RegExp(a.specialConversions[1]!);
      expect(rx.hasMatch('800-571-7438'), isTrue);
      expect(rx.hasMatch('(800) 571-7438'), isTrue);
      expect(rx.hasMatch('800.571.7438'), isTrue);
      expect(rx.hasMatch('(800)571-7438'), isTrue);
      expect(rx.hasMatch('800-571-7439'), isFalse);
    });

    test('SPECIAL: hand-decided ambiguous rows are removed', () {
      final a = analyzeBodyRules([
        row(1, 'nl', r'\.nl/', src: '.nl'),
        row(2, 'syspath', r'sys\-confg\.co\.uk/cl/', src: 'sys-confg.co.ukcl'),
      ]);
      expect(a.specialRemovals, hasLength(2));
      expect(a.ambiguous, isEmpty);
      expect(a.toRemove.map((r) => r.id), containsAll([1, 2]));
    });
  });
}
