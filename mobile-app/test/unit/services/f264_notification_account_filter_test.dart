/// F264 (Sprint 77) T-8 (AC-10): which accounts a notification-started run
/// scans -- provider x per-account switch x background switch.
///
/// What this does NOT catch: Android delivering the notification, the real
/// package names the mail apps post under (the AOL and Yahoo names are
/// unverified until the Fold, MV76-1), or the worker actually calling this
/// function (the worker's wiring is pinned by a source gate in
/// `f253_new_mail_switch_test.dart` and by the mutation run).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/notification_account_filter.dart';

void main() {
  bool selected(
    String? providers,
    String platformId, {
    bool newMail = true,
    bool background = true,
  }) =>
      accountSelectedByNotification(
        providers: providers,
        platformId: platformId,
        newMailSwitch: newMail,
        backgroundEnabled: background,
      );

  group('provider family', () {
    test('both Gmail paths are Gmail; everything else is its own family', () {
      expect(providerFamilyOf('gmail'), 'gmail');
      expect(providerFamilyOf('gmail-imap'), 'gmail');
      expect(providerFamilyOf('aol'), 'aol');
      expect(providerFamilyOf('yahoo'), 'yahoo');
      expect(providerFamilyOf('icloud'), 'icloud');
    });
  });

  group('AC-10: the Gmail app scans only Gmail accounts', () {
    test('a Gmail account with both switches on is scanned', () {
      expect(selected('gmail', 'gmail'), isTrue);
      expect(selected('gmail', 'gmail-imap'), isTrue);
    });

    test('an AOL, Yahoo or iCloud account is not', () {
      for (final p in ['aol', 'yahoo', 'icloud', 'imap']) {
        expect(selected('gmail', p), isFalse, reason: p);
      }
    });
  });

  group('the AOL and Yahoo apps', () {
    test('AOL app -> AOL accounts only', () {
      expect(selected('aol', 'aol'), isTrue);
      expect(selected('aol', 'gmail'), isFalse);
      expect(selected('aol', 'yahoo'), isFalse);
    });

    test('Yahoo Mail -> Yahoo accounts only', () {
      expect(selected('yahoo', 'yahoo'), isTrue);
      expect(selected('yahoo', 'aol'), isFalse);
    });
  });

  group('Samsung Email and Outlook (every provider)', () {
    test('every account with both switches on is scanned', () {
      for (final p in ['gmail', 'gmail-imap', 'aol', 'yahoo', 'icloud']) {
        expect(selected(kAnyProvider, p), isTrue, reason: p);
      }
    });
  });

  group('the switches', () {
    test('an account whose OWN new-mail switch is off is never scanned', () {
      expect(selected('gmail', 'gmail', newMail: false), isFalse);
      expect(selected(kAnyProvider, 'aol', newMail: false), isFalse);
    });

    test('an account whose background scanning is off is never scanned', () {
      expect(selected('gmail', 'gmail', background: false), isFalse);
      expect(selected(kAnyProvider, 'aol', background: false), isFalse);
    });
  });

  group('the payload value', () {
    test('a missing set reads as every provider; an empty one as none', () {
      expect(selected(null, 'aol'), isTrue,
          reason: 'a build that sent no set degrades to the old behavior');
      expect(selected('', 'aol'), isFalse);
    });

    test('a comma list matches any member', () {
      expect(selected('gmail,aol', 'aol'), isTrue);
      expect(selected('gmail,aol', 'yahoo'), isFalse);
    });
  });
}
