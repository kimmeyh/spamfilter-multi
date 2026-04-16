import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/help_screen.dart';

/// Widget tests for [HelpScreen] (F54, Sprint 33).
void main() {
  testWidgets('HelpScreen renders a title and the first section on open',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen()),
    );
    await tester.pumpAndSettle();

    // AppBar title present.
    expect(find.text('Help'), findsOneWidget);
    // The first section should be visible without scrolling.
    expect(find.text('Select Account'), findsOneWidget);
  });

  testWidgets('HelpScreen contains a heading for every HelpSection enum value',
      (tester) async {
    // Use a large viewport so all sections are rendered (ListView still
    // lazy-builds but a tall enough screen forces more children to build).
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen()),
    );
    await tester.pumpAndSettle();

    const expected = <String>[
      'Select Account',
      'Account Setup',
      'Manual Scan',
      'Results',
      'Scan History',
      'Settings',
      'Background Scanning',
      'Manage Rules',
      'Rule Quick Add',
      'Rule Test',
      'Manage Safe Senders',
      'Folder Selection',
      'YAML Import / Export',
    ];
    for (final title in expected) {
      expect(find.text(title), findsOneWidget,
          reason: 'missing Help section: $title');
    }
  });

  testWidgets('HelpScreen accepts an initialSection without throwing',
      (tester) async {
    // The ensureVisible scroll is best-effort and depends on ListView's
    // lazy-build state at post-frame; we verify the screen mounts without
    // error when initialSection is provided, rather than inspecting the
    // exact scroll offset (which is platform-sensitive).
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: HelpScreen(initialSection: HelpSection.yamlImportExport),
      ),
    );
    await tester.pumpAndSettle();

    // AppBar is present -- screen did not throw during init.
    expect(find.text('Help'), findsOneWidget);
  });

  test('HelpSection has a stable entry for each primary screen', () {
    // If anyone removes a HelpSection we want the test suite to shout:
    // the enum is a contract between every AppBar that passes into
    // openHelp() and the HelpScreen that renders the target.
    expect(HelpSection.values, hasLength(13));
  });
}
