// Sprint 42, F99-c -- rule create+delete lifecycle (in-VM, absorbs WinWright F56).
//
// This is the flow the WinWright F56 scripts could not run reliably: create a
// Top-Level-Domain block rule, confirm the dialog, verify it persisted, then
// delete it -- net-zero change. WinWright failed because the "Save" confirm
// button resolved 0 elements before the dialog settled, and the runner had no
// wait primitive. integration_test drives it in-VM with pumpAndSettle(), so the
// dialog is always settled before we tap, and the whole flow runs against an
// isolated temp DB (never the dev DB).
//
// We pump ManualRuleCreateScreen directly (it reads DatabaseHelper() -- the
// singleton the harness points at the temp DB -- and needs no app providers),
// which keeps the test focused on the create/confirm/persist path without
// depending on a saved account in the account-selection chain.
//
// Run: flutter test integration_test/rule_lifecycle_test.dart
//   (or .\scripts\run-integration-tests.ps1 -TestName lifecycle)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/utils/iana_tlds.dart';
import 'package:my_email_spam_filter/ui/screens/manual_rule_create_screen.dart';
import 'package:my_email_spam_filter/ui/testing/widget_keys.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F99-c rule create+delete lifecycle (in-VM)', () {
    late HarnessSession session;

    tearDown(() async {
      await session.dispose();
    });

    testWidgets('create a TLD block rule, verify it persists, then delete it',
        (tester) async {
      // Seed an isolated temp DB WITHOUT pumping the full app (bootDbOnly) --
      // we pump ManualRuleCreateScreen directly below, and booting SpamFilterApp
      // too would run RuleSetProvider.initialize() concurrently, racing with our
      // DB access (it closed the DB mid-seed when the suite ran back-to-back).
      session = await bootDbOnly(tester);

      // Pick a REAL IANA TLD (validateTld requires kIanaTlds membership) that is
      // NOT already in the freshly-seeded rules table -- robust against bundled
      // seed changes (BUG-S37-2 etc.) instead of hardcoding one TLD.
      final db = DatabaseHelper();
      final tld = await _pickUnseededIanaTld(db);
      final expectedPattern = '*.$tld';

      expect(await _tldRuleExists(db, expectedPattern), isFalse,
          reason: 'precondition: the chosen TLD rule must not already exist');

      // Pump the Add-Block-Rule screen standalone.
      await tester.pumpWidget(MaterialApp(
        home: const ManualRuleCreateScreen(mode: ManualRuleMode.blockRule),
      ));
      await tester.pumpAndSettle();

      // Select the Top-Level Domain rule type (radio by its label text).
      await tester.tap(find.text('Top-Level Domain'));
      await tester.pumpAndSettle();

      // Enter the TLD into the input field (the only text field on this screen
      // in TLD mode). find.byType(TextField) is unambiguous here.
      await tester.enterText(find.byType(TextField).first, tld);
      await tester.pumpAndSettle();

      // The form is a ListView, so the Save Rule button is lazily built and
      // below the fold in the default test viewport (the in-VM equivalent of
      // Sprint 41's "Save Rule off-screen" WinWright finding). Scroll it into
      // view first, then tap.
      await tester.scrollUntilVisible(
        find.byKey(WidgetKeys.saveRuleButton),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap "Save Rule" -> opens the "Confirm Block Rule" dialog.
      await tester.tap(find.byKey(WidgetKeys.saveRuleButton));
      await tester.pumpAndSettle();

      // The confirm dialog is now SETTLED (the WinWright failure point). Tap its
      // keyed "Save" action.
      expect(find.text('Confirm Block Rule'), findsOneWidget);
      await tester.tap(find.byKey(WidgetKeys.confirmDialogSaveButton));
      await tester.pumpAndSettle();

      // Verify the rule persisted to the (temp) DB.
      expect(await _tldRuleExists(db, expectedPattern), isTrue,
          reason: 'the TLD block rule should have been saved');

      // Teardown within the test: delete the rule so the flow is net-zero
      // (belt-and-suspenders -- the temp DB is discarded anyway, but this
      // exercises the delete path that F56 also covered).
      final deleted = await _deleteTldRule(db, expectedPattern);
      expect(deleted, greaterThan(0), reason: 'delete should remove the row');
      expect(await _tldRuleExists(db, expectedPattern), isFalse,
          reason: 'the rule should be gone after delete');
    });
  });
}

/// Picks a real IANA TLD whose `*.<tld>` block rule is NOT already seeded, so
/// the create flow exercises a genuine new insertion. Throws if none is free
/// (effectively impossible -- kIanaTlds has 1000+ entries).
Future<String> _pickUnseededIanaTld(DatabaseHelper db) async {
  final database = await db.database;
  final existing = <String>{
    for (final row in await database.query('rules',
        columns: ['source_domain'], where: "pattern_sub_type = 'top_level_domain'"))
      (row['source_domain'] as String?) ?? '',
  };
  // Prefer short, lowercase-letter-only TLDs (validateTld requires ^[a-z][a-z0-9-]*$).
  for (final tld in kIanaTlds) {
    if (tld.length >= 2 &&
        RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(tld) &&
        !existing.contains('*.$tld')) {
      return tld;
    }
  }
  throw StateError('No unseeded IANA TLD available for the lifecycle test');
}

/// Returns true if a rule whose source/pattern matches [sourcePattern] exists in
/// the rules table. Matches on the source_domain column used by TLD block rules.
Future<bool> _tldRuleExists(DatabaseHelper db, String sourcePattern) async {
  final database = await db.database;
  final rows = await database.query(
    'rules',
    where: 'source_domain = ?',
    whereArgs: [sourcePattern],
    limit: 1,
  );
  return rows.isNotEmpty;
}

/// Deletes rules whose source_domain matches [sourcePattern]; returns row count.
Future<int> _deleteTldRule(DatabaseHelper db, String sourcePattern) async {
  final database = await db.database;
  return database.delete(
    'rules',
    where: 'source_domain = ?',
    whereArgs: [sourcePattern],
  );
}
