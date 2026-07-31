import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';
import 'package:my_email_spam_filter/ui/widgets/standard_app_bar_actions.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';

/// MV-1 regression (Sprint 52, Harold 2026-07-31): the Accounts icon must
/// actually REACH the account selection screen.
///
/// **The defect this pins.** `StandardAppBarActions` defaulted the Accounts icon
/// to `Navigator.popUntil(context, (route) => route.isFirst)`. That was correct
/// before F135, when Account Selection was effectively what the first route
/// rendered. F135 made Review "No Rule" Items the desktop default, and the first
/// route is `MainNavigationScreen`, which renders the No-Rule screen inline
/// whenever an account exists -- so Account Selection stopped being a route on
/// desktop and `popUntil` could never reach it. On the No-Rule screen the icon
/// was completely inert; from deeper screens it unwound to No-Rule instead.
///
/// Harold found it in manual validation: *"have not found a screen where the
/// icon is working."*
///
/// **Why the existing gate did not catch it.** `test/policy/appbar_action_order_test.dart`
/// is a SOURCE-TEXT gate: it proves every screen delegates to the shared builder
/// and that the icons are in the canonical ORDER. It cannot see what a handler
/// DOES. The two changes (F134 order, F135 default screen) were each correct in
/// isolation and broke only at their intersection, which no source-text check
/// can observe. This test presses the button and asserts where you land.
///
/// That is the same lesson as the Sprint 51 semantics defect, one layer up: a
/// declaration existing is not proof that activating it works.
void main() {
  group('Accounts icon navigation (MV-1 regression)', () {
    testWidgets('pressing Accounts pushes the account selection screen',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Some Screen'),
              actions: StandardAppBarActions.build(
                context: context,
                helpSection: HelpSection.resultsDisplay,
                // Mirror the No-Rule screen, which is where Harold first saw the
                // dead icon: it is the desktop DEFAULT, so it is the first route
                // and has nothing to pop back to.
                includeNoRuleReview: false,
              ),
            ),
            body: const Text('body'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AccountSelectionScreen), findsNothing,
          reason: 'precondition: we do not start on account selection');

      final accountsIcon = find.byTooltip('Select Account');
      expect(accountsIcon, findsOneWidget,
          reason: 'the Accounts action must be present on a screen that did '
              'not opt out via includeAccounts: false');

      await tester.tap(accountsIcon);
      // Fixed frames, NOT pumpAndSettle: the pushed AccountSelectionScreen
      // reads the secure credential store in initState and schedules a 500ms
      // retry timer, so pumpAndSettle never reaches a steady state here.
      // Pumping past the route transition is enough -- this test asserts WHERE
      // the icon lands, not what that screen renders once loaded.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The assertion that fails against the old popUntil default: from a
      // first-route screen popUntil is a no-op, so we would still be on 'Some
      // Screen' and AccountSelectionScreen would never appear.
      expect(find.byType(AccountSelectionScreen), findsOneWidget,
          reason: 'the Accounts icon must NAVIGATE to account selection. '
              'Harold: the account screen is still needed for adding '
              'additional accounts and for updating an existing one, even '
              'though it is no longer the default screen.');

      // Drain the credential-store retry timer that AccountSelectionScreen
      // schedules in initState, so the test does not fail on a pending timer.
      await tester.pump(const Duration(seconds: 1));
    },
        // The builder's action set is Windows-desktop scoped in places, and this
        // defect is a desktop-navigation one.
        skip: !Platform.isWindows);

    testWidgets('an explicit onAccounts override still wins', (tester) async {
      // The fix must not take the override away from screens that need their
      // own behavior (account_selection_screen passes includeAccounts: false;
      // others may supply a custom handler).
      var customCalled = 0;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              actions: StandardAppBarActions.build(
                context: context,
                helpSection: HelpSection.resultsDisplay,
                includeNoRuleReview: false,
                onAccounts: () => customCalled++,
              ),
            ),
            body: const Text('body'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Select Account'));
      await tester.pumpAndSettle();

      expect(customCalled, 1,
          reason: 'an explicit onAccounts handler must take precedence over '
              'the default push');
      expect(find.byType(AccountSelectionScreen), findsNothing,
          reason: 'the override replaces the default navigation entirely');
    }, skip: !Platform.isWindows);
  });
}
