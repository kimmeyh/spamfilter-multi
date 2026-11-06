// Sprint 84, F345 -- DIAGNOSTIC PROBE, not a regression test. It asserts nothing;
// it prints the facts that tell why two shared integration tests fail only on
// the iOS Simulator (folder_picker_test.dart at its last assertion,
// safe_sender_lifecycle_test.dart at scrollUntilVisible). The ios.yml job
// `ios-simulator` runs it outside the verdict and uploads the log. Delete it
// when both failures are explained.
//
// It skips itself unless the job passes --dart-define=IOS_PROBE=true, so on Windows
// it is one skipped file. Output lines start with "PROBE ".
//
// WHAT THIS DOES NOT CATCH: nothing, it asserts nothing. It only reports.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/screens/folder_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/manual_rule_create_screen.dart';
import 'package:my_email_spam_filter/ui/testing/widget_keys.dart';

import 'helpers/app_harness.dart';

const bool _on = bool.fromEnvironment('IOS_PROBE');

void _facts(WidgetTester tester, String stage) {
  final v = tester.view;
  // ignore: avoid_print
  print('PROBE [$stage] physicalSize=${v.physicalSize} dpr=${v.devicePixelRatio} '
      'viewInsets=${v.viewInsets} padding=${v.padding} '
      'textFields=${find.byType(TextField).evaluate().length} '
      'scrollables=${find.byType(Scrollable).evaluate().length} '
      'radioTiles=${find.byType(RadioListTile<String>).evaluate().length} '
      'saveButton=${find.byKey(WidgetKeys.saveRuleButton).evaluate().length}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F345 iOS diagnostic probe', () {
    HarnessSession? session;
    tearDown(() async {
      await session?.dispose();
    });

    testWidgets('folder picker: state after each step', (tester) async {
      const folders = <FolderInfo>[
        FolderInfo(id: '1', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
        FolderInfo(id: '2', displayName: 'Bulk Mail', canonicalName: CanonicalFolder.junk),
        FolderInfo(id: '3', displayName: 'Archive', canonicalName: CanonicalFolder.archive),
        FolderInfo(id: '4', displayName: 'Church', canonicalName: CanonicalFolder.custom),
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
      _facts(tester, 'picker initial');
      await tester.enterText(find.byType(TextField).first, 'bulk');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      // ignore: avoid_print
      print('PROBE picker after "bulk": controller="${field.controller?.text}" '
          'Church=${find.text('Church').evaluate().length} '
          'Bulk=${find.text('Bulk Mail').evaluate().length}');
      _facts(tester, 'picker after bulk');
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      final field2 = tester.widget<TextField>(find.byType(TextField).first);
      // ignore: avoid_print
      print('PROBE picker after clear: controller="${field2.controller?.text}" '
          'Church=${find.text('Church').evaluate().length} '
          'Inbox=${find.text('Inbox').evaluate().length} '
          'Bulk=${find.text('Bulk Mail').evaluate().length}');
      _facts(tester, 'picker after clear');
    }, skip: !_on);

    testWidgets('safe sender form: state after entering the domain', (tester) async {
      session = await bootDbOnly(tester);
      await tester.pumpWidget(ChangeNotifierProvider<RuleSetProvider>(
        create: (_) => RuleSetProvider(),
        child: MaterialApp(
          home: const ManualRuleCreateScreen(mode: ManualRuleMode.safeSender),
        ),
      ));
      await tester.pumpAndSettle();
      _facts(tester, 'safe sender initial');
      await tester.enterText(find.byType(TextField).first, 'winwright-e2e-test.com');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      // ignore: avoid_print
      print('PROBE safe sender after enterText: controller="${field.controller?.text}"');
      _facts(tester, 'safe sender after enterText');
      for (var i = 0; i < 5; i++) {
        final s = find.byType(Scrollable);
        if (s.evaluate().isEmpty) break;
        await tester.drag(s.first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
        _facts(tester, 'safe sender after drag ${i + 1}');
      }
    }, skip: !_on);
  });
}
