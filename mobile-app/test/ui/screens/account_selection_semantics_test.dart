import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// F129 R-6 (Sprint 51): the Select Account rows must expose an accessible
/// NAME. Before this, each row rendered correctly but surfaced as an unnamed
/// `Group` in the accessibility tree -- a screen reader announced nothing
/// actionable, and WinWright name-based selectors resolved 0 elements.
///
/// Why this test exists at the WIDGET level rather than relying on a live
/// WinWright inspection: the Windows UIA projection of Flutter semantics
/// proved unreliable as a verification instrument during Sprint 51 (the MCP
/// snapshot path and the CLI `inspect` path disagreed on the SAME process at
/// the SAME moment). Flutter's own semantics tree is the authoritative source
/// for whether a label exists, so that is what we assert.
///
/// This test pins the SHAPE that makes the label reach the tree -- a
/// Semantics container with excludeSemantics that merges child text into one
/// named, tappable node -- using the same widget structure the screen builds.
void main() {
  /// Mirrors the account-row structure in
  /// `account_selection_screen.dart` (Semantics -> Card -> ListTile).
  Widget buildAccountRow({
    required String email,
    required String platformName,
    required String authMethod,
    required String accountId,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Semantics(
          container: true,
          button: true,
          excludeSemantics: true,
          label: '$email - $platformName - $authMethod',
          hint: 'Select account to scan',
          // MUST mirror production: `excludeSemantics` drops the ListTile's own
          // gesture node, so without onTap HERE the merged node announces as a
          // Button that assistive technology cannot ACTIVATE. Omitting it made
          // this helper model the exact broken shape that shipped mid-Sprint-51
          // (named but unclickable), so the tests would have passed against a
          // regression. Caught by Copilot on PR #285.
          onTap: onTap ?? () {},
          child: Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.email)),
              title: Text('$email - $platformName - $authMethod'),
              subtitle: Text(accountId),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {},
                    tooltip: 'Start Scan',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {},
                    tooltip: 'Delete account',
                  ),
                ],
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('account row exposes an accessible name identifying the account',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(buildAccountRow(
      email: 'kimmeyharold@aol.com',
      platformName: 'AOL Mail',
      authMethod: 'App Password',
      accountId: 'kimmeyharold@aol.com',
    ));

    // The row announces WHICH account it is -- the defect was a nameless node.
    expect(
      find.bySemanticsLabel('kimmeyharold@aol.com - AOL Mail - App Password'),
      findsOneWidget,
      reason: 'an account row must carry an accessible name; without it a '
          'screen reader announces nothing actionable and name-based UI '
          'automation cannot address the row',
    );

    handle.dispose();
  });

  testWidgets('account row is marked as a button (actionable), not plain text',
      (tester) async {
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

    expect(node.hasFlag(SemanticsFlag.isButton), isTrue,
        reason: 'the row is tappable, so assistive technology must present '
            'it as actionable');

    handle.dispose();
  });

  testWidgets(
      'account row is ACTIVATABLE via the semantics node, not merely labelled',
      (tester) async {
    // The regression this pins (Copilot, PR #285): `excludeSemantics: true`
    // collapses the row into ONE named node, but it also drops the ListTile's
    // own gesture node. Without `onTap` on the Semantics widget itself, the row
    // announces as a Button that assistive technology CANNOT ACTIVATE -- which
    // is exactly what shipped in the account-picker dialog mid-Sprint-51 and
    // silently blocked the whole Settings path.
    //
    // Asserting the isButton FLAG is not enough: the broken shape sets that
    // flag too. This test performs the semantics ACTION, so it fails against
    // the broken shape and passes only when the merged node is genuinely
    // actionable. "A tree dump proves a name exists; only an interaction proves
    // the node still works."
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
      reason: 'the merged row node must expose a TAP action; a labelled node '
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

  testWidgets('error row names the failing account and the reason',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Semantics(
          container: true,
          excludeSemantics: true,
          label: 'broken@example.com - error: missing credentials',
          hint: 'Use the delete button to remove this account',
          child: Card(
            child: ListTile(
              title: const Text('broken@example.com'),
              subtitle: const Text('Error: Missing credentials'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {},
                tooltip: 'Delete account',
              ),
            ),
          ),
        ),
      ),
    ));

    expect(
      find.bySemanticsLabel('broken@example.com - error: missing credentials'),
      findsOneWidget,
      reason: 'an error row must say WHICH account failed and why, not '
          'surface as an unnamed group',
    );

    handle.dispose();
  });
}
