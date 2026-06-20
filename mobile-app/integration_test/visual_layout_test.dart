// Sprint 42, F99-e -- layout-regression checks (in-VM, delivers the F76 goal).
//
// F76 wanted "layout-bounds, not pixel-diff" visual regression -- WinWright's
// CLI could not read element bounds at all, so it was abandoned and folded here.
// integration_test gives direct access to widget geometry via tester.getRect()
// / getSize(), so we assert layout INVARIANTS that a real regression (element
// moved, resized, mis-stacked) would break, without the anti-aliasing / DPI
// noise that makes pixel-diff goldens flaky for Flutter-on-DirectX.
//
// These are intentionally RELATIONAL assertions (ordering, alignment, non-zero
// size) rather than absolute pixel coordinates, so they are stable across the
// test viewport size while still catching genuine layout breakage.
//
// Run: flutter test integration_test/visual_layout_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/ui/screens/folder_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/manual_rule_create_screen.dart';
import 'package:my_email_spam_filter/ui/testing/widget_keys.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F99-e layout regression (in-VM bounds)', () {
    late HarnessSession session;
    tearDown(() async => session.dispose());

    testWidgets('Add-Block-Rule: Save Rule button has real, on-screen bounds',
        (tester) async {
      session = await bootDbOnly(tester);

      await tester.pumpWidget(const MaterialApp(
        home: ManualRuleCreateScreen(mode: ManualRuleMode.blockRule),
      ));
      await tester.pumpAndSettle();

      // Bring the Save Rule button into view (ListView-lazy) and assert it has
      // a sane, non-degenerate rectangle (a real regression that collapses or
      // hides the button would make width/height 0 or move it off-screen).
      await tester.scrollUntilVisible(
        find.byKey(WidgetKeys.saveRuleButton),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final saveRect = tester.getRect(find.byKey(WidgetKeys.saveRuleButton));
      expect(saveRect.width, greaterThan(40),
          reason: 'Save Rule button should have a real width');
      expect(saveRect.height, greaterThan(20),
          reason: 'Save Rule button should have a real height');

      final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(saveRect.left, greaterThanOrEqualTo(0));
      expect(saveRect.top, greaterThanOrEqualTo(0));
      expect(saveRect.bottom, lessThanOrEqualTo(screenSize.height + 1),
          reason: 'Save Rule button should be within the viewport after scroll');
    });

    testWidgets('Folder picker: search field sits above the folder list',
        (tester) async {
      session = await bootDbOnly(tester);

      const folders = <FolderInfo>[
        FolderInfo(id: '1', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
        FolderInfo(id: '2', displayName: 'Bulk Mail', canonicalName: CanonicalFolder.junk),
      ];

      await tester.pumpWidget(MaterialApp(
        home: FolderSelectionScreen(
          platformId: 'imap',
          accountId: 'test-account',
          singleSelect: true,
          onFoldersSelected: (_) {},
          debugFoldersOverride: folders,
        ),
      ));
      await tester.pumpAndSettle();

      // Layout invariant: the search field is above the first folder row.
      final searchRect =
          tester.getRect(find.widgetWithText(TextField, 'Search folders...'));
      final inboxRect = tester.getRect(find.text('Inbox').first);
      expect(searchRect.bottom, lessThanOrEqualTo(inboxRect.top + 1),
          reason: 'the search field should sit above the folder list');
      expect(searchRect.width, greaterThan(100),
          reason: 'the search field should span a real width');
    });
  });
}
