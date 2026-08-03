import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';

/// Unit tests for [SelectedAccountProvider] (PR #292 review).
///
/// This class had NO test coverage despite three screens depending on it for
/// correctness -- it is what decides whether the account picker appears, and a
/// stale value handed to a screen means a failed credential lookup.
///
/// The invariants worth pinning are the ones that are enforced in code but not
/// expressible in the type: an accountId is null or non-empty (never `''`),
/// listeners fire only on an actual change, and `clearIfSelected` is
/// account-specific rather than an unconditional clear.
void main() {
  group('SelectedAccountProvider', () {
    test('starts with no selection', () {
      final provider = SelectedAccountProvider();

      expect(provider.accountId, isNull);
      expect(provider.hasSelection, isFalse);
    });

    test('select() records the account and reports a selection', () {
      final provider = SelectedAccountProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.select('gmail-a@example.com');

      expect(provider.accountId, 'gmail-a@example.com');
      expect(provider.hasSelection, isTrue);
      expect(notifications, 1);
    });

    test('selecting the SAME account again does not notify', () {
      // Guards a rebuild storm: several screens read this in build(), so a
      // notify on every re-selection would rebuild them for no state change.
      final provider = SelectedAccountProvider();
      provider.select('gmail-a@example.com');

      var notifications = 0;
      provider.addListener(() => notifications++);
      provider.select('gmail-a@example.com');

      expect(notifications, 0);
      expect(provider.accountId, 'gmail-a@example.com');
    });

    test('select("") is rejected -- never stores an empty accountId', () {
      // `''` is the value the whole design exists to keep out: SettingsStore
      // accepts it and would persist settings under a bogus key, surfacing much
      // later as apparent data loss.
      final provider = SelectedAccountProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.select('');

      expect(provider.accountId, isNull);
      expect(provider.hasSelection, isFalse,
          reason: 'an empty id must never count as a selection');
      expect(notifications, 0);
    });

    test('select("") does not clobber an existing valid selection', () {
      final provider = SelectedAccountProvider();
      provider.select('gmail-a@example.com');

      provider.select('');

      expect(provider.accountId, 'gmail-a@example.com',
          reason: 'a rejected empty select must leave the prior value intact');
    });

    test('switching accounts notifies and replaces the value', () {
      final provider = SelectedAccountProvider();
      provider.select('gmail-a@example.com');

      var notifications = 0;
      provider.addListener(() => notifications++);
      provider.select('aol-b@example.com');

      expect(provider.accountId, 'aol-b@example.com');
      expect(notifications, 1);
    });

    test('clear() drops the selection and notifies', () {
      final provider = SelectedAccountProvider();
      provider.select('gmail-a@example.com');

      var notifications = 0;
      provider.addListener(() => notifications++);
      provider.clear();

      expect(provider.accountId, isNull);
      expect(provider.hasSelection, isFalse);
      expect(notifications, 1);
    });

    test('clear() on an empty provider does not notify', () {
      final provider = SelectedAccountProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.clear();

      expect(notifications, 0);
    });

    test('clearIfSelected() clears ONLY when the id matches', () {
      // The reason this method exists: clearing unconditionally on any account
      // deletion would discard a still-valid selection for a DIFFERENT account.
      final provider = SelectedAccountProvider();
      provider.select('gmail-a@example.com');

      provider.clearIfSelected('aol-b@example.com');
      expect(provider.accountId, 'gmail-a@example.com',
          reason: 'deleting a different account must not clear the selection');

      provider.clearIfSelected('gmail-a@example.com');
      expect(provider.accountId, isNull,
          reason: 'deleting the SELECTED account must clear it, so a stale id '
              'is never handed to a screen that would fail its credential '
              'lookup');
    });

    test('clearIfSelected() on an empty provider is a no-op', () {
      final provider = SelectedAccountProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.clearIfSelected('gmail-a@example.com');

      expect(provider.accountId, isNull);
      expect(notifications, 0);
    });

    test('hasSelection tracks accountId across a full cycle', () {
      final provider = SelectedAccountProvider();
      expect(provider.hasSelection, isFalse);

      provider.select('gmail-a@example.com');
      expect(provider.hasSelection, isTrue);

      provider.clear();
      expect(provider.hasSelection, isFalse);
    });
  });
}
