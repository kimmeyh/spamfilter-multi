import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/main_navigation_screen.dart';
import 'package:my_email_spam_filter/ui/screens/no_rule_review_screen.dart';

/// F135 desktop default-screen decision (PR #292 review).
///
/// This branch decides what the whole desktop app shows on launch and had ZERO
/// coverage. It is also empirically the risky one: changing the desktop default
/// is what caused MV-1, where the Accounts icon stopped reaching anything
/// because Account Selection was no longer a route.
///
/// The failure modes worth pinning are the ones a user would meet head-on: a
/// permanent spinner (resolution never completes), or an inverted ternary that
/// boots straight past the account list.
///
/// Tested through `desktopDefaultScreenFor` rather than the private
/// `_DesktopDefaultScreen` widget, because the widget reads the real secure
/// credential store on init -- which has no test binding on Windows. Extracting
/// the DECISION keeps the risky part testable without adding a production
/// test-override seam to the store.
void main() {
  group('desktopDefaultScreenFor', () {
    testWidgets('null (still resolving) shows a neutral spinner',
        (tester) async {
      // Deliberately NOT Account Selection: flashing it and then replacing it
      // once accounts resolve is the jarring behaviour this avoids.
      await tester.pumpWidget(MaterialApp(
        home: desktopDefaultScreenFor(hasAccounts: null),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AccountSelectionScreen), findsNothing,
          reason: 'must not flash the account list before resolution finishes');
      expect(find.byType(NoRuleReviewScreen), findsNothing);
    });

    testWidgets('true (accounts exist) shows Review "No Rule" Items',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: desktopDefaultScreenFor(hasAccounts: true),
      ));
      await tester.pump();

      expect(find.byType(NoRuleReviewScreen), findsOneWidget,
          reason: 'F135: with at least one account the desktop default is the '
              'No-Rule review screen');
      expect(find.byType(AccountSelectionScreen), findsNothing);
    });

    testWidgets('false (no accounts) shows Account Selection', (tester) async {
      // Also the credential-store-failure path: getSavedAccounts() returns an
      // empty list on failure, so a broken store lands here -- the one screen
      // that can add an account or repair the situation. Landing on No-Rule
      // would show an empty list with no way to fix it.
      await tester.pumpWidget(MaterialApp(
        home: desktopDefaultScreenFor(hasAccounts: false),
      ));
      await tester.pump();

      expect(find.byType(AccountSelectionScreen), findsOneWidget,
          reason: 'with no accounts there is nothing to review, and this is '
              'the screen that can add one');
      expect(find.byType(NoRuleReviewScreen), findsNothing);

      // Drain the credential-store retry timer AccountSelectionScreen
      // schedules in initState, so the test does not fail on a pending timer.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('each state selects exactly one DESTINATION', (tester) async {
      // Guards an inverted ternary. Deliberately counts only the two
      // destination SCREENS, not spinners: both destinations render their own
      // CircularProgressIndicator while they load their data, so "a spinner is
      // on screen" does not mean "still resolving". A first version of this
      // test conflated the two and failed on hasAccounts=true -- the test was
      // wrong, not the app.
      const expected = <bool?, Type?>{
        null: null, // resolving -> neither destination yet
        true: NoRuleReviewScreen,
        false: AccountSelectionScreen,
      };

      for (final entry in expected.entries) {
        await tester.pumpWidget(MaterialApp(
          home: desktopDefaultScreenFor(hasAccounts: entry.key),
        ));
        await tester.pump();

        final onNoRule = find.byType(NoRuleReviewScreen).evaluate().isNotEmpty;
        final onAccounts =
            find.byType(AccountSelectionScreen).evaluate().isNotEmpty;

        expect(onNoRule && onAccounts, isFalse,
            reason: 'hasAccounts=${entry.key} must never render BOTH '
                'destinations');
        expect(onNoRule, entry.value == NoRuleReviewScreen,
            reason: 'hasAccounts=${entry.key}: No-Rule presence is wrong');
        expect(onAccounts, entry.value == AccountSelectionScreen,
            reason: 'hasAccounts=${entry.key}: Account Selection presence is '
                'wrong');

        // Drain AccountSelectionScreen's credential-store retry timer before
        // the next iteration replaces the tree.
        await tester.pump(const Duration(seconds: 1));
      }
    });
  });
}
