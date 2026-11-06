// Sprint 42, F99-c -- safe-sender create+delete lifecycle (in-VM, absorbs F56).
//
// Sibling of rule_lifecycle_test.dart for the safe-sender side. Creates an
// Entire-Domain safe sender, confirms the (settled) dialog, verifies it
// persisted to safe_senders, then deletes it. Runs against an isolated temp DB.
//
// Run: flutter test integration_test/safe_sender_lifecycle_test.dart
//   (or .\scripts\run-integration-tests.ps1 -TestName safe_sender)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/ui/screens/manual_rule_create_screen.dart';
import 'package:my_email_spam_filter/ui/testing/widget_keys.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F99-c safe-sender create+delete lifecycle (in-VM)', () {
    HarnessSession? session;

    tearDown(() async {
      // Null-safe: if bootDbOnly throws before assignment, do not mask the real
      // failure with a LateInitializationError (Copilot review PR #263).
      await session?.dispose();
    });

    testWidgets('create an Entire-Domain safe sender, verify, then delete',
        (tester) async {
      session = await bootDbOnly(tester);

      // A distinctive domain unlikely to collide with the seeded safe senders.
      const domain = 'winwright-e2e-test.com';
      // Mirror the app's generateEntireDomain pattern so we can query for it.
      final expectedPattern = '@(?:[a-z0-9-]+\\.)*${RegExp.escape(domain)}\$';

      final db = DatabaseHelper();
      expect(await _safeSenderExists(db, expectedPattern), isFalse,
          reason: 'precondition: the test safe sender must not already exist');

      // F345 (Sprint 84): the save path takes RuleSetProvider (F298, Sprint 83
      // PR #490, commit 32059a86: `Provider.of<RuleSetProvider>` in
      // ManualRuleCreateScreen._saveRule). The screen was pumped bare, so Save
      // threw ProviderNotFoundException on EVERY platform. A fresh, uninitialized
      // provider is enough: reloadRulesAfterWrite never throws.
      await tester.pumpWidget(ChangeNotifierProvider<RuleSetProvider>(
        create: (_) => RuleSetProvider(),
        child: MaterialApp(
          home: const ManualRuleCreateScreen(mode: ManualRuleMode.safeSender),
        ),
      ));
      await tester.pumpAndSettle();

      // Entire Domain is the default safe-sender type. Enter the domain.
      await tester.enterText(find.byType(TextField).first, domain);
      await tester.pumpAndSettle();
      // F345: close the soft keyboard (iOS) before scrolling; a drag that starts
      // on the focused text field is taken by the field, not the form.
      await dismissKeyboard(tester);

      // Scroll the lazily-built Save Rule button into view (ListView), then tap.
      await tester.scrollUntilVisible(
        find.byKey(WidgetKeys.saveRuleButton),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.saveRuleButton));
      await tester.pumpAndSettle();

      // Confirm dialog is settled -> tap its keyed Save.
      expect(find.text('Confirm Safe Sender'), findsOneWidget);
      await tester.tap(find.byKey(WidgetKeys.confirmDialogSaveButton));
      await tester.pumpAndSettle();

      // Verify persisted, then delete (net-zero).
      expect(await _safeSenderExists(db, expectedPattern), isTrue,
          reason: 'the safe sender should have been saved');
      final deleted = await _deleteSafeSender(db, expectedPattern);
      expect(deleted, greaterThan(0));
      expect(await _safeSenderExists(db, expectedPattern), isFalse,
          reason: 'the safe sender should be gone after delete');
    });
  });
}

Future<bool> _safeSenderExists(DatabaseHelper db, String pattern) async {
  final database = await db.database;
  final rows = await database.query('safe_senders',
      where: 'pattern = ?', whereArgs: [pattern], limit: 1);
  return rows.isNotEmpty;
}

Future<int> _deleteSafeSender(DatabaseHelper db, String pattern) async {
  final database = await db.database;
  return database.delete('safe_senders', where: 'pattern = ?', whereArgs: [pattern]);
}
