import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/scan_history_screen.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

/// F135 R-10 regression (Sprint 52 review + re-review): Settings must OPEN and
/// WORK with no account.
///
/// The whole point of R-10 is that `accountId` became nullable so Settings can
/// be reached without a session selection and the cross-account General tab
/// still works, resolving an account lazily only when an account-scoped tab is
/// entered.
///
/// It could not. `build()` passed the THROWING getter (now named
/// `_requireAccountId` so misuse looks wrong on sight) to the AppBar builder
/// unconditionally, so the very first frame on the no-account path threw
/// `StateError` before anything rendered -- and the getter's own doc comment
/// asserted the opposite ("Every call site is inside an account-scoped TAB"),
/// which is what hid it. The re-review then found the null-account state the
/// crash fix UNLOCKED had its own holes: unguarded sibling tabs with lying
/// controls, a dead in-body View Scan History button, and a one-shot
/// resolution latch with no recovery. All are pinned here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> fakeSecureStorage = <String, String>{};

  setUp(() {
    fakeSecureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          final key = call.arguments['key'] as String;
          return fakeSecureStorage[key];
        case 'write':
          final key = call.arguments['key'] as String;
          final value = call.arguments['value'] as String;
          fakeSecureStorage[key] = value;
          return null;
        case 'readAll':
          return Map<String, String>.from(fakeSecureStorage);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('SettingsScreen builds with a null accountId (General tab)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    // One frame is enough: the defect threw during the FIRST build.
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'Settings must open without an account -- the General tab is '
            'cross-account by design. A StateError here is the R-10 defect: '
            'the throwing getter reached from build().');

    expect(find.text('General'), findsOneWidget,
        reason: 'the cross-account General tab must render with no account');
  });

  testWidgets(
      'General tab shows the version near the top, visible without '
      'scrolling (F140, Sprint 54)', (tester) async {
    // Default (small) test viewport -- if the version text only appeared in
    // the original bottom-of-tab About card, this would find nothing without
    // a scroll action. WinWright/UIA automation could not reach that card
    // (see docs/WINWRIGHT_SELECTORS.md), so the duplicate near the top must
    // render within the initial viewport with no scroll.
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    expect(find.textContaining('Version'), findsWidgets);
  });

  testWidgets(
      'ALL THREE account-scoped tabs render the guarded placeholder when '
      'unresolved', (tester) async {
    // TabBarView CONSTRUCTS all children eagerly -- `children:` is a plain
    // list literal, so every `_buildXTab()` call runs immediately, even while
    // General is the visible tab. (The underlying PageView separately mounts
    // only nearby pages into the render tree; that is a different layer and
    // not what this bug depended on.) The re-review found the first fix
    // guarded only the Account tab: the Manual Scan and Background tabs
    // CONSTRUCTED live controls whose onChanged callbacks flipped the UI, hit
    // the throwing getter, persisted nothing and reported nothing ("Enable
    // Background Scanning" showing ON with no task scheduled). All three must
    // show the placeholder instead. Visit each scoped tab and assert the
    // placeholder is what renders there.
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    for (final tab in const ['Account', 'Manual Scan', 'Background']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'entering the $tab tab unresolved must not throw');
      expect(find.text('Select an account to view its settings.'),
          findsOneWidget,
          reason: 'the $tab tab must be behind the unresolved-account '
              'placeholder -- a tab with live controls in this state silently '
              'persists nothing');
    }
  });

  testWidgets(
      'entering an account-scoped tab with NO accounts does not throw and '
      'keeps the recovery button', (tester) async {
    // Comment corrected in the re-review: an earlier version claimed the tab
    // listener "filters on indexIsChanging" -- the same commit had REMOVED
    // that filter. What this pins is behavior, not the listener's internals:
    // reaching a scoped tab account-less must not throw, and the placeholder
    // must carry its own Choose Account recovery button, because the
    // resolution latch (_accountResolutionAttempted) fires once -- without
    // the button, a cancelled picker or empty account list left the tab as a
    // permanent dead end with an instruction the user could not follow.
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'entering an account-scoped tab with no account must not '
            'throw');
    // By TEXT, not byType(ElevatedButton): ElevatedButton.icon constructs a
    // private subtype whose runtimeType does not match byType.
    expect(find.text('Choose Account'), findsOneWidget,
        reason: 'the placeholder must offer a way to retry resolution -- the '
            'latch makes the automatic path one-shot');
  });

  testWidgets(
      'with ONE saved account, entering a scoped tab auto-resolves and '
      'replaces the placeholder', (tester) async {
    // The other half of R-10, previously unpinned: the resolver has to
    // actually RUN and resolve. With the listener body deleted, this test
    // fails (placeholder never replaced) -- the no-account tests above stay
    // green in that mutation, which is exactly why this one exists.
    // getSavedAccounts() parses a comma-separated string under
    // 'saved_accounts'.
    fakeSecureStorage['saved_accounts'] = 'gmail-a@example.com';

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Select an account to view its settings.'), findsNothing,
        reason: 'a single configured account must auto-resolve on first entry '
            'to a scoped tab (session selection -> single account -> prompt), '
            'replacing the placeholder without ever showing a picker');
  });

  testWidgets(
      'the in-body View Scan History button works with NO account '
      '(cross-account fallback)', (tester) async {
    // Re-review finding: the General tab -- the tab an account-less user LANDS
    // on -- has its own View Scan History button, and it dereferenced the
    // throwing getter. Tapping it threw StateError inside an unawaited
    // future: no SnackBar, no navigation, a silent dead button (the MV-1
    // class). It must now open Scan History cross-account.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    // The button sits below the fold in the General tab's ListView.
    final button = find.text('Go to View Scan History');
    await tester.scrollUntilVisible(
      button,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull,
        reason: 'the button must not throw with no account resolved');
    expect(find.byType(ScanHistoryScreen), findsOneWidget,
        reason: 'it must NAVIGATE -- cross-account, unfiltered -- rather than '
            'being a silent dead button');
  });
}
