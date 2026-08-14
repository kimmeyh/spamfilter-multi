import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/main_navigation_screen.dart';
import 'package:my_email_spam_filter/ui/screens/no_rule_review_screen.dart';

/// F135 default-screen decision (PR #292 review), shared across every
/// platform since F142 (Sprint 57).
///
/// This branch decides what the WHOLE app shows on launch (previously
/// desktop-only; Android had a separate bottom-nav shell removed by F142)
/// and had ZERO coverage when first written. It is also empirically the
/// risky one: changing the default screen is what caused MV-1, where the
/// Accounts icon stopped reaching anything because Account Selection was no
/// longer a route.
///
/// The failure modes worth pinning are the ones a user would meet head-on: a
/// permanent spinner (resolution never completes), or an inverted ternary that
/// boots straight past the account list.
///
/// Most cases are tested through `appDefaultScreenFor` -- the extracted
/// decision, not the private `_AppDefaultScreenState` widget -- so the branch
/// logic is pinned without the async credential-store round-trip in every
/// case. That is a scoping choice, not a real harness limitation: the
/// `flutter_secure_storage` MethodChannel DOES have a test binding (stubbed
/// the same way `manual_scan_unknown_platform_test.dart` and
/// `settings_null_account_test.dart` do it), which the final WIRING test
/// below uses to drive the real widget end to end. A prior version of this
/// comment claimed no binding existed; that was wrong, and is corrected here
/// rather than left standing next to the test that disproves it.
///
/// F142 (Sprint 57): the WIRING test below now validates BOTH platforms
/// uniformly -- `MainNavigationScreen.build()` no longer has a
/// `Platform.isAndroid` branch, so this same test exercises Android's path
/// too (there is only one path now).
void main() {
  group('appDefaultScreenFor', () {
    testWidgets('null (still resolving) shows a neutral spinner',
        (tester) async {
      // Deliberately NOT Account Selection: flashing it and then replacing it
      // once accounts resolve is the jarring behaviour this avoids.
      await tester.pumpWidget(MaterialApp(
        home: appDefaultScreenFor(hasAccounts: null),
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
        home: appDefaultScreenFor(hasAccounts: true),
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
        home: appDefaultScreenFor(hasAccounts: false),
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
          home: appDefaultScreenFor(hasAccounts: entry.key),
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

    testWidgets(
        'WIRING: MainNavigationScreen itself lands on Account Selection with '
        'an empty credential store', (tester) async {
      // The function tests above cannot catch a wiring regression -- e.g.
      // build() hardcoding `appDefaultScreenFor(hasAccounts: true)` --
      // because they bypass the widget (PR #292 re-review). This pumps the
      // real screen with the secure-storage channel stubbed empty, driving
      // the actual initState -> _resolve -> build chain end to end. The
      // earlier claim that this needed "a production test-override seam" was
      // wrong: the channel stub is the seam, same as the sibling tests use.
      const channel =
          MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'read') return null; // no saved_accounts
        if (call.method == 'readAll') return <String, String>{};
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
      // First frame: still resolving (spinner). Then the async store read
      // completes and the decision renders.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountSelectionScreen), findsOneWidget,
          reason: 'an empty credential store must land on Account Selection '
              '-- the screen that can add an account. Landing on No-Rule '
              'here means the wiring inverted or hardcoded the decision.');
      expect(find.byType(NoRuleReviewScreen), findsNothing);

      // Drain AccountSelectionScreen's credential-store retry timers -- on the
      // EMPTY-store path it schedules repeated retries, so a single drain is
      // not enough here.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    });
  });
}
