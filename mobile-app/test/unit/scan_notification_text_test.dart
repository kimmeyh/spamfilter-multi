// F286 (Sprint 79): the shared background-scan notification text and ID.
//
// What these tests do NOT catch: whether Android actually RENDERS `<s>` as
// strikethrough (that is Android's Html converter, checked by the emulator
// rehearsal and on the Fold after release, Q9 = 2), and whether a platform
// worker posts through this builder at all (the source gate at the bottom
// covers the Android worker; the Windows toast is F287's test).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_notification_text.dart';

ScanNotificationText build(ScanMode mode, {int errors = 0}) =>
    ScanNotificationText.build(
      accountId: 'kimmeyharold@aol.com',
      mode: mode,
      noRule: 9,
      deleted: 1,
      safe: 0,
      errors: errors,
    );

void main() {
  group('live mode (safeSendersAndRules) -- Harold\'s exact text', () {
    test('title and body, errors 0', () {
      final t = build(ScanMode.safeSendersAndRules);
      expect(t.title, 'Back. scan k*@aol completed');
      expect(t.plainBody, 'No rule 9 Deleted 1 Safe 0');
      expect(t.htmlBody, 'No rule 9 Deleted 1 Safe 0');
      expect(t.hasStruckCounts, isFalse);
    });

    test('errors appended only when > 0, no colons or commas', () {
      final t = build(ScanMode.safeSendersAndRules, errors: 2);
      expect(t.plainBody, 'No rule 9 Deleted 1 Safe 0 Errors 2');
      expect(t.title + t.plainBody, isNot(contains(':')));
      expect(t.title + t.plainBody, isNot(contains(',')));
    });
  });

  group('modes other than live (Q1 = 1: strikethrough plus title word)', () {
    test('read-only strikes Deleted and Safe and names the mode', () {
      final t = build(ScanMode.readOnly);
      expect(t.title, 'Back. scan k*@aol read-only completed');
      expect(t.htmlBody, 'No rule 9 <s>Deleted 1</s> <s>Safe 0</s>');
      expect(t.plainBody, 'No rule 9 Deleted 1 Safe 0');
    });

    test('rules-only strikes Safe only', () {
      final t = build(ScanMode.rulesOnly);
      expect(t.title, 'Back. scan k*@aol rules-only completed');
      expect(t.htmlBody, 'No rule 9 Deleted 1 <s>Safe 0</s>');
    });

    test('safe-senders-only strikes Deleted only', () {
      final t = build(ScanMode.safeSendersOnly);
      expect(t.title, 'Back. scan k*@aol safe-senders-only completed');
      expect(t.htmlBody, 'No rule 9 <s>Deleted 1</s> Safe 0');
    });

    test('Errors is never struck, in any mode', () {
      for (final mode in ScanMode.values) {
        expect(build(mode, errors: 3).htmlBody, endsWith(' Errors 3'),
            reason: '$mode');
      }
    });
  });

  group('maskAccount', () {
    test('first letter, star, at, domain without its last label', () {
      expect(ScanNotificationText.maskAccount('kimmeyharold@aol.com'), 'k*@aol');
      expect(ScanNotificationText.maskAccount('kimmeyh@gmail.com'), 'k*@gmail');
      expect(ScanNotificationText.maskAccount('x@mail.example.co.uk'),
          'x*@mail.example.co');
    });

    test('unhappy inputs never show a raw identifier', () {
      expect(ScanNotificationText.maskAccount('opaque-id'), 'account');
      expect(ScanNotificationText.maskAccount('@aol.com'), '*@aol');
      expect(ScanNotificationText.maskAccount('k@localhost'), 'k*@localhost');
    });
  });

  group('notificationId (FNV-1a, 31 bits)', () {
    // Values from an independent Python FNV-1a implementation; "a" and ""
    // also match the published FNV-1a 32-bit vectors (0xe40c292c, offset
    // basis 0x811c9dc5) masked to 31 bits.
    test('pinned values', () {
      expect(ScanNotificationText.notificationId(''), 18652613);
      expect(ScanNotificationText.notificationId('a'), 1678518572);
      expect(ScanNotificationText.notificationId('kimmeyharold@aol.com'),
          772562602);
      expect(ScanNotificationText.notificationId('kimmeyh@gmail.com'),
          1988489478);
      expect(ScanNotificationText.notificationId('kimmeyh@yahoo.com'),
          663563768);
    });

    test('non-negative and distinct for the four real accounts', () {
      final ids = [
        'kimmeyharold@aol.com',
        'kimmeyh@gmail.com',
        'kimmeyh@yahoo.com',
        'kimmeyharold@icloud.com',
      ].map(ScanNotificationText.notificationId).toList();
      expect(ids.every((i) => i >= 0 && i <= 0x7fffffff), isTrue);
      expect(ids.toSet().length, 4);
    });
  });

  test('source gate: the Android worker posts through the shared builder', () {
    final src = File('lib/core/services/android_background_scan_worker.dart')
        .readAsStringSync();
    expect(src, contains('ScanNotificationText.build('));
    expect(src, contains('ScanNotificationText.notificationId(accountId)'));
    expect(src, contains('DefaultStyleInformation(true, false)'));
    expect(src, isNot(contains('accountId.hashCode')));
    expect(src, isNot(contains("'Background scan complete'")));
  });
}
