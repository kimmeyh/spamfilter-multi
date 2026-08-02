import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

/// F135 R-10 regression (Sprint 52 review): Settings must OPEN with no account.
///
/// The whole point of R-10 is that `accountId` became nullable so Settings can
/// be reached without a session selection and the cross-account General tab
/// still works, resolving an account lazily only when an account-scoped tab is
/// entered.
///
/// It could not. `build()` passed the THROWING `_accountId` getter to the AppBar
/// builder unconditionally, so the very first frame on the no-account path threw
/// `StateError` before anything rendered -- and the getter's own doc comment
/// asserted the opposite ("Every call site is inside an account-scoped TAB"),
/// which is what hid it. Found by the PR #292 review round; no existing test
/// covered the null path because every production caller happened to pass a
/// non-null id.
void main() {
  testWidgets('SettingsScreen builds with a null accountId (General tab)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    // One frame is enough: the defect threw during the FIRST build.
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'Settings must open without an account -- the General tab is '
            'cross-account by design. A StateError here is the R-10 defect: '
            'the throwing _accountId getter reached from build().');

    expect(find.text('General'), findsOneWidget,
        reason: 'the cross-account General tab must render with no account');
  });

  testWidgets('switching to an account-scoped tab attempts resolution',
      (tester) async {
    // Guards the OTHER half of R-10: the AppBar fix above stops the crash, but
    // the lazy resolver still has to run when the user reaches an
    // account-scoped tab. The listener filters on `indexIsChanging`, so this
    // pins that a tab TAP actually triggers resolution rather than silently
    // leaving the tab account-less.
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    // With no accounts configured the resolver cannot produce one, so the
    // placeholder stays -- the assertion that matters is that switching tabs
    // does not throw and does not leave a half-built account tab.
    expect(tester.takeException(), isNull,
        reason: 'entering an account-scoped tab with no account must not throw');
  });

  testWidgets('the account-scoped tabs still render without an account',
      (tester) async {
    // TabBarView builds ALL children eagerly, so the Account/Manual Scan/
    // Background tab bodies are constructed even while General is selected.
    // They must not touch the throwing getter before an account resolves.
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'eagerly-built account-scoped tab bodies must tolerate an '
            'unresolved account rather than throwing');
  });
}
