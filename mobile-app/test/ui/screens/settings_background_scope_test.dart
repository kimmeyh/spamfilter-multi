/// F168 (Sprint 61): a background folder scope that omits the Inbox is warned
/// about, because an unattended scan with a wrong scope is indistinguishable
/// from a healthy one.
///
/// The production incident (Harold, 2026-08-16): the 19:45 background scan ran
/// over "Bulk, Bulk Mail" and reported Found 0 / Processed 0, while a manual
/// scan 21 minutes later over "Bulk, Bulk Mail, Inbox" found 152 emails and
/// deleted 6 -- all of them Inbox rows matching existing Block rules. The rules
/// were right and the scanner was right; the background scope simply never
/// looked at the Inbox.
///
/// Root cause confirmed by Harold: the Inbox genuinely was not selected
/// ("but thought I had", and later: "it is possible that I removed inbox to do
/// some test, but don't remember it"). Both readings lead to the same defect --
/// whether the removal was deliberate or accidental, NOTHING afterwards told
/// the user their background scans had stopped covering the Inbox. The AOL
/// provider default is `['Inbox', 'Bulk', 'Bulk Mail']`, so that scope was a
/// silent deviation from the intended default.
///
/// These tests pin the PREDICATE (`scopeCoversInbox`) rather than only the
/// rendered banner: the predicate is where the real logic lives, and it must
/// handle provider-prefixed folder names and the empty-means-defaults case.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

void main() {
  group('F168: scopeCoversInbox -- does a folder scope cover the Inbox?', () {
    test('AC-3: a scope containing the Inbox produces NO warning', () {
      // The AOL provider default, verbatim from SettingsStore.
      expect(
          SettingsScreen.scopeCoversInbox(['Inbox', 'Bulk', 'Bulk Mail']), isTrue,
          reason: 'the AOL default scope covers the Inbox -- warning here '
              'would fire on the intended default and train the user to '
              'ignore the warning');
    });

    test(
        'AC-2: the exact production scope that failed -- Bulk/Bulk Mail with no '
        'Inbox -- IS flagged', () {
      expect(SettingsScreen.scopeCoversInbox(['Bulk', 'Bulk Mail']), isFalse,
          reason: 'this is the literal scope from Harold 2026-08-16 that '
              'reported Found 0 while spam sat in the Inbox');
    });

    test('an EMPTY scope counts as covered (empty means provider defaults)',
        () {
      expect(SettingsScreen.scopeCoversInbox([]), isTrue,
          reason: 'an empty selection resolves to the provider defaults, which '
              'include the Inbox. Warning on empty would fire on the default '
              'state of every new account.');
    });

    test('case and provider prefixes do not defeat the check', () {
      // Providers spell it differently; the check must not be fooled into
      // warning on a scope that DOES cover the Inbox.
      expect(SettingsScreen.scopeCoversInbox(['INBOX']), isTrue,
          reason: 'IMAP spells it INBOX');
      expect(SettingsScreen.scopeCoversInbox(['inbox']), isTrue,
          reason: 'case-insensitive');
      expect(SettingsScreen.scopeCoversInbox(['[Gmail]/Inbox']), isTrue,
          reason: 'Gmail prefixes with [Gmail]/ -- matching must use the last '
              'path segment, not the whole string');
      expect(SettingsScreen.scopeCoversInbox([' Inbox ']), isTrue,
          reason: 'stray whitespace must not cause a false warning');
    });

    test('a folder merely CONTAINING "inbox" does not count as the Inbox', () {
      expect(SettingsScreen.scopeCoversInbox(['Inbox Archive']), isFalse,
          reason: 'a substring match would silently suppress the warning for '
              'a scope that does NOT include the real Inbox -- the failure '
              'mode this whole feature exists to prevent');
      expect(SettingsScreen.scopeCoversInbox(['Old Inbox 2019']), isFalse);
    });
  });
}
