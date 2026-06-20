// Sprint 42, F99-d -- folder picker open/search/back (in-VM, absorbs F37).
//
// The WinWright F37 script failed because the picker's "Search folders..." Edit
// was not in the UIA tree yet when the next step fired (a dialog-settle race the
// WinWright run-runner could not wait out). In-VM with pumpAndSettle() the field
// is always present and settled before we type.
//
// The real FolderSelectionScreen fetches folders from a live account; this test
// injects synthetic folders via the F99-d debugFoldersOverride seam so the
// picker UI (search box, list, back) can be driven headless without an account.
//
// Run: flutter test integration_test/folder_picker_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/ui/screens/folder_selection_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const folders = <FolderInfo>[
    FolderInfo(id: '1', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
    FolderInfo(id: '2', displayName: 'Bulk Mail', canonicalName: CanonicalFolder.junk),
    FolderInfo(id: '3', displayName: 'Archive', canonicalName: CanonicalFolder.archive),
    FolderInfo(id: '4', displayName: 'Church', canonicalName: CanonicalFolder.custom),
  ];

  group('F99-d folder picker (in-VM, injected folders)', () {
    testWidgets('opens, renders folders, filters via the search box', (tester) async {
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

      // All injected folders render (loading bypassed by the override seam).
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Bulk Mail'), findsOneWidget);
      expect(find.text('Church'), findsOneWidget);

      // The search field exists and is settled -- the WinWright F37 failure point.
      final searchField = find.widgetWithText(TextField, 'Search folders...');
      expect(searchField, findsOneWidget,
          reason: 'the "Search folders..." field should be present and settled');

      // Typing filters the list (Church should disappear when searching "bulk").
      await tester.enterText(find.byType(TextField).first, 'bulk');
      await tester.pumpAndSettle();
      expect(find.text('Bulk Mail'), findsOneWidget);
      expect(find.text('Church'), findsNothing,
          reason: 'non-matching folders should be filtered out');

      // Clearing the search restores the full list.
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      expect(find.text('Church'), findsOneWidget);
    });
  });
}
