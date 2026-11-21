import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart'
    show Credentials;
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';

import '../../helpers/database_test_helper.dart';

/// F129 R-6 (Sprint 51): the Select Account rows must expose an accessible
/// NAME. Before this, each row rendered correctly but surfaced as an unnamed
/// `Group` in the accessibility tree -- a screen reader announced nothing
/// actionable, and WinWright name-based selectors resolved 0 elements.
///
/// Sprint 85 (F352 follow-up): the Sprint 51 fix wrapped the row in
/// `Semantics(excludeSemantics: true)`, which ALSO hid the row's own buttons
/// (the F352 default star, Start Scan, Delete) from assistive technology. A
/// mouse could press them; a screen reader could not reach them. The row now
/// keeps its one named, activatable node and exposes each button as a
/// separate, named, activatable child node.
///
/// Why this test exists at the WIDGET level rather than relying on a live
/// WinWright inspection: the Windows UIA projection of Flutter semantics
/// proved unreliable as a verification instrument during Sprint 51 (the MCP
/// snapshot path and the CLI `inspect` path disagreed on the SAME process at
/// the SAME moment). Flutter's own semantics tree is the authoritative source
/// for whether a label exists, so that is what we assert.
///
/// The first group mounts the REAL AccountSelectionScreen (same harness as
/// f352_default_account_screen_test.dart), so a change to the screen's row
/// shape fails it. The second group pins the same shape on a small mirror of
/// the row, which is faster to read when the real-screen group fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('real Select Account screen', () {
    const a = 'one@icloud.com';
    // email - provider name - auth method, as the screen builds it for iCloud.
    const rowLabel = '$a - iCloud Mail - App Password';

    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final fake = <String, String>{};
    late DatabaseTestHelper testHelper;

    setUpAll(DatabaseTestHelper.initializeFfi);

    setUp(() async {
      fake.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
        final key = (call.arguments as Map?)?['key'] as String?;
        switch (call.method) {
          case 'read':
            return fake[key];
          case 'write':
            fake[key!] = call.arguments['value'] as String;
            return null;
          case 'delete':
            fake.remove(key);
            return null;
          case 'readAll':
            return Map<String, String>.from(fake);
        }
        return null;
      });
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      DatabaseHelper().setAppPaths(testHelper.appPaths);
      await testHelper.createTestAccount(a, platformId: 'icloud');
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
      await testHelper.tearDown();
    });

    Future<void> mount(WidgetTester tester) async {
      await tester.runAsync(() => SecureCredentialsStore().saveCredentials(
            a,
            Credentials(email: a, password: 'app-password'),
            platformId: 'icloud',
          ));
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => SelectedAccountProvider()),
              ChangeNotifierProvider(create: (_) => EmailScanProvider()),
              ChangeNotifierProvider(create: (_) => RuleSetProvider()),
            ],
            child: child!,
          ),
          home: const AccountSelectionScreen(),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await tester.pump();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Unmount and let the screen's own reload timers and reads finish, so no
    // timer is pending when the test ends.
    Future<void> drain(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1500)));
      await tester.pump(const Duration(seconds: 3));
    }

    bool isDescendantOf(SemanticsNode node, SemanticsNode ancestor) {
      for (var p = node.parent; p != null; p = p.parent) {
        if (p.id == ancestor.id) return true;
      }
      return false;
    }

    // What this test would NOT catch: how the Windows UIA bridge projects
    // these nodes (names, nesting, InvokePattern) -- only a WinWright
    // ww_dump_tree of a live build shows that; the production "Missing
    // credentials" error row (it needs an account whose details fail to
    // load; only the mirror below covers its shape); the phone layout under
    // 600 dp, where the buttons move into the subtitle (mounted at 1400 dp
    // here); and whether the row, Start Scan and Delete handlers do the
    // right thing once activated (only their tap actions are asserted; only
    // the star is performed).
    testWidgets(
        'the row is one named, activatable node, and the star, Start Scan and '
        'Delete are separate, named, activatable nodes inside it',
        (tester) async {
      final handle = tester.ensureSemantics();
      await mount(tester);

      // The row keeps its Sprint 51 name and stays activatable.
      expect(find.bySemanticsLabel(rowLabel), findsOneWidget,
          reason: 'the row must still announce WHICH account it is');
      final row = tester.getSemantics(find.bySemanticsLabel(rowLabel));
      final rowData = row.getSemanticsData();
      expect(rowData.hasAction(SemanticsAction.tap), isTrue,
          reason: 'the named row node must carry the tap action; a tap on an '
              'unnamed child node is the Sprint 51 defect');
      expect(rowData.flagsCollection.isButton, isTrue);
      expect(rowData.hint, 'Select account to scan');

      final buttonLabels = [
        AccountSelectionScreen.setDefaultSemanticLabel(a),
        AccountSelectionScreen.startScanSemanticLabel(a),
        AccountSelectionScreen.deleteSemanticLabel(a),
      ];
      for (final label in buttonLabels) {
        expect(find.bySemanticsLabel(label), findsOneWidget,
            reason: '"$label" must be reachable by assistive technology');
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        final data = node.getSemanticsData();
        expect(node.id, isNot(row.id),
            reason: '"$label" must be its own node, not merged into the row');
        expect(isDescendantOf(node, row), isTrue,
            reason: '"$label" must sit inside its row, so the row reads as '
                'the group it belongs to');
        expect(data.hasAction(SemanticsAction.tap), isTrue,
            reason: '"$label" must be activatable, not only named');
        expect(data.flagsCollection.isButton, isTrue);
      }

      // Drive it, do not dump it (ACCESSIBILITY_STANDARDS.md section 1):
      // activate the star through the semantics tree and check the effect.
      final star = tester.getSemantics(
          find.bySemanticsLabel(buttonLabels.first));
      await tester.runAsync(() async {
        tester.binding.pipelineOwner.semanticsOwner!
            .performAction(star.id, SemanticsAction.tap);
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('default_mark_$a')), findsOneWidget,
          reason: 'activating the star through the accessibility tree must '
              'set the default, as a mouse click does');
      expect(await tester.runAsync(() => SettingsStore().getDefaultAccountId()),
          a);
      expect(
          find.bySemanticsLabel(
              AccountSelectionScreen.removeDefaultSemanticLabel(a)),
          findsOneWidget,
          reason: 'the star is renamed for its new action');
      expect(find.bySemanticsLabel('$rowLabel - default account'),
          findsOneWidget,
          reason: 'the row name says it is the default account');

      handle.dispose();
      await drain(tester);
    });
  });

  group('row shape mirror', () {
    /// Mirrors the account-row structure in `account_selection_screen.dart`
    /// (Card -> Semantics(label, hint) -> ListTile). The Card is the row's
    /// semantics container; the label and the ListTile's own tap merge into
    /// it, and the IconButtons stay separate child nodes.
    Widget buildAccountRow({
      required String email,
      required String platformName,
      required String authMethod,
      required String accountId,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Card(
            child: Semantics(
              label: '$email - $platformName - $authMethod',
              hint: 'Select account to scan',
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.email)),
                title: ExcludeSemantics(
                    child: Text('$email - $platformName - $authMethod')),
                subtitle: ExcludeSemantics(child: Text(accountId)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_arrow,
                          semanticLabel: AccountSelectionScreen
                              .startScanSemanticLabel(email)),
                      onPressed: () {},
                      tooltip: 'Start Scan',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          semanticLabel:
                              AccountSelectionScreen.deleteSemanticLabel(email)),
                      onPressed: () {},
                      tooltip: 'Delete account',
                    ),
                  ],
                ),
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
        'account row exposes an accessible name identifying the account',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildAccountRow(
        email: 'kimmeyharold@aol.com',
        platformName: 'AOL Mail',
        authMethod: 'App Password',
        accountId: 'kimmeyharold@aol.com',
      ));

      // The row announces WHICH account it is -- the defect was a nameless
      // node.
      expect(
        find.bySemanticsLabel('kimmeyharold@aol.com - AOL Mail - App Password'),
        findsOneWidget,
        reason: 'an account row must carry an accessible name; without it a '
            'screen reader announces nothing actionable and name-based UI '
            'automation cannot address the row',
      );

      handle.dispose();
    });

    testWidgets('account row is marked as a button (actionable), not plain '
        'text', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildAccountRow(
        email: 'kimmeyh@gmail.com',
        platformName: 'Gmail (IMAP)',
        authMethod: 'App Password',
        accountId: 'kimmeyh@gmail.com',
      ));

      final node = tester.getSemantics(
        find.bySemanticsLabel('kimmeyh@gmail.com - Gmail (IMAP) - App Password'),
      );

      expect(node.getSemanticsData().flagsCollection.isButton, isTrue,
          reason: 'the row is tappable, so assistive technology must present '
              'it as actionable');

      handle.dispose();
    });

    testWidgets(
        'account row is ACTIVATABLE via the semantics node, not merely labelled',
        (tester) async {
      // The regression this pins (Copilot, PR #285): a row can be NAMED by
      // one semantics node while its tap lives on another, unnamed node (or
      // on none). It then announces as a button that assistive technology
      // CANNOT ACTIVATE -- which is exactly what shipped in the
      // account-picker dialog mid-Sprint-51.
      //
      // Asserting the isButton FLAG is not enough: the broken shape sets that
      // flag too. This test performs the semantics ACTION, so it fails
      // against the broken shape and passes only when the named node is
      // genuinely actionable. "A tree dump proves a name exists; only an
      // interaction proves the node still works."
      final handle = tester.ensureSemantics();

      var tapped = 0;
      await tester.pumpWidget(buildAccountRow(
        email: 'kimmeyharold@aol.com',
        platformName: 'AOL Mail',
        authMethod: 'App Password',
        accountId: 'kimmeyharold@aol.com',
        onTap: () => tapped++,
      ));

      final node = tester.getSemantics(
        find.bySemanticsLabel('kimmeyharold@aol.com - AOL Mail - App Password'),
      );

      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'the named row node must expose a TAP action; a labelled node '
            'with no action is announced as a button that cannot be activated',
      );

      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(node.id, SemanticsAction.tap);
      await tester.pump();

      expect(tapped, 1,
          reason: 'activating the row through the accessibility tree must run '
              'the same handler a mouse tap would');

      handle.dispose();
    });

    testWidgets('error row names the failing account and the reason, and '
        'its delete button stays reachable', (tester) async {
      final handle = tester.ensureSemantics();

      const account = 'broken@example.com';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Card(
            child: Semantics(
              label: '$account - error: missing credentials',
              hint: 'Use the delete button to remove this account',
              child: ListTile(
                title: const ExcludeSemantics(child: Text(account)),
                subtitle: const ExcludeSemantics(
                    child: Text('Error: Missing credentials')),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      semanticLabel:
                          AccountSelectionScreen.deleteSemanticLabel(account)),
                  onPressed: () {},
                  tooltip: 'Delete account',
                ),
              ),
            ),
          ),
        ),
      ));

      expect(
        find.bySemanticsLabel('$account - error: missing credentials'),
        findsOneWidget,
        reason: 'an error row must say WHICH account failed and why, not '
            'surface as an unnamed group',
      );
      final delete = tester.getSemantics(find.bySemanticsLabel(
          AccountSelectionScreen.deleteSemanticLabel(account)));
      expect(delete.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
          reason: 'the hint names the delete button, so it must be reachable');

      handle.dispose();
    });
  });
}
