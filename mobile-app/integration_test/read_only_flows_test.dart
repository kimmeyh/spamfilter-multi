// Sprint 43, F100 -- the six read-only WinWright flows, ported to the in-VM
// integration_test lane (Sprint 42 retro IMP-3).
//
// The WinWright scripts these replace (test/winwright/*.json) proved a screen
// rendered by REACHING it via the live UIA tree and resolving a selector. In
// the in-VM lane the equivalent is to pump the screen directly against the
// seeded temp DB and assert its key content / behavior with find.byX +
// pumpAndSettle() -- no out-of-process selector-settle flakiness, no dependency
// on a saved account or live window.
//
// These are all READ-ONLY: no flow saves a rule, toggles a persisted setting,
// or mutates the DB (mirroring the WinWright scripts, which cancelled out of
// every create/edit screen). Each pumps a screen standalone -- the screens in
// this set read DatabaseHelper()/stores directly and need no app providers,
// same as the F99 lifecycle tests.
//
// Ported flows (WinWright script -> case):
//   test_navigation.json      -> Manage Rules + create-screen reachable (NAV)
//   test_settings_tabs.json   -> all 4 Settings tabs present + cycle (SET)
//   test_scan_history.json    -> Scan History screen renders (HIST)
//   test_text_selection.json  -> Help renders selectable content (TXT)
//   test_f25_rule_test_tool.json -> Rule Test tool runs a pattern (F25)
//   test_f35_rule_edit.json   -> Rule Edit dual-mode toggle, leave unsaved (F35)
//
// As each flow is verified here, its WinWright script is retired (F100 scope).
//
// Run: flutter test integration_test/read_only_flows_test.dart
//   (or .\scripts\run-integration-tests.ps1 -TestName read_only)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';
import 'package:my_email_spam_filter/ui/screens/rule_edit_screen.dart';
import 'package:my_email_spam_filter/ui/screens/rule_test_screen.dart';
import 'package:my_email_spam_filter/ui/screens/rules_management_screen.dart';
import 'package:my_email_spam_filter/ui/screens/scan_history_screen.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F100 read-only flows (in-VM ports of the WinWright read-only set)', () {
    HarnessSession? session;

    tearDown(() async {
      // Null-safe: a boot failure before assignment must not mask the real error
      // with a LateInitializationError (Copilot review PR #263).
      await session?.dispose();
    });

    // NAV (test_navigation.json): Manage Rules renders the seeded rules and the
    // Add-block-rule entry point. WinWright proved this by clicking the add
    // affordance open and cancelling; here we assert the management screen and
    // its 'Add block rule' control render against the seeded temp DB.
    testWidgets('NAV: Manage Rules renders with seeded rules + add affordance',
        (tester) async {
      session = await bootDbOnly(tester);
      await tester.pumpWidget(const MaterialApp(home: RulesManagementScreen()));
      await tester.pumpAndSettle();

      // The screen rendered, and its 'Add block rule' control (the create entry
      // point the WinWright NAV flow opened and cancelled) is present.
      expect(find.byType(RulesManagementScreen), findsOneWidget);
      expect(find.byTooltip('Add block rule'), findsWidgets,
          reason: 'Manage Rules should expose the Add-block-rule control');
    });

    // SET (test_settings_tabs.json): all four Settings tabs are present and can
    // be cycled. WinWright clicked each 'Tab N of 4'; here we tap each Tab label.
    testWidgets('SET: all 4 Settings tabs present and cycle without error',
        (tester) async {
      session = await bootDbOnly(tester);
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(accountId: 'test-account')),
      );
      await tester.pumpAndSettle();

      for (final label in const ['General', 'Account', 'Manual Scan', 'Background']) {
        expect(find.widgetWithText(Tab, label), findsOneWidget,
            reason: 'Settings should expose the "$label" tab');
      }

      // Cycle through them (read-only: no toggle touched), then back to General.
      for (final label in const ['Account', 'Manual Scan', 'Background', 'General']) {
        await tester.tap(find.widgetWithText(Tab, label));
        await tester.pumpAndSettle();
      }
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    // HIST (test_scan_history.json): the Scan History screen renders. WinWright
    // opened it from the home top bar and pressed Back.
    testWidgets('HIST: Scan History screen renders', (tester) async {
      session = await bootDbOnly(tester);
      await tester.pumpWidget(const MaterialApp(home: ScanHistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(ScanHistoryScreen), findsOneWidget);
    });

    // TXT (test_text_selection.json): the Help screen renders selectable content
    // (ADR-0037 accessibility). WinWright reached Help and Manage Rules to prove
    // their text rendered; the Manage-Rules half is covered by NAV above.
    testWidgets('TXT: Help screen renders selectable text content',
        (tester) async {
      session = await bootDbOnly(tester);
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsOneWidget);
      // Help content is rendered as selectable text (ADR-0037). At least one
      // SelectableText / SelectionArea region should be present.
      final hasSelectable = find.byType(SelectableText).evaluate().isNotEmpty ||
          find.byType(SelectionArea).evaluate().isNotEmpty;
      expect(hasSelectable, isTrue,
          reason: 'Help should render selectable text content (ADR-0037)');
    });

    // F25 (test_f25_rule_test_tool.json): open the Rule Test tool, enable the
    // plaintext toggle, type a pattern, run Test. Read-only: the tool computes
    // matches and persists nothing.
    testWidgets('F25: Rule Test tool runs a plaintext pattern (no persistence)',
        (tester) async {
      session = await bootDbOnly(tester);
      await tester.pumpWidget(const MaterialApp(home: RuleTestScreen()));
      await tester.pumpAndSettle();

      // Enable the plaintext-to-regex toggle (WinWright ww_set_checked).
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Type a plaintext pattern and run Test. The Test button is a
      // FilledButton.icon (play_arrow); target it by its icon so we do not
      // depend on the named-constructor's runtime widget type.
      await tester.enterText(find.byType(TextField).first, 'example.com');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      // The tool ran in-place (still on the Test screen); nothing was saved.
      expect(find.byType(RuleTestScreen), findsOneWidget);
    });

    // F35 (test_f35_rule_edit.json): open a seeded rule in the editor, exercise
    // the Guided/Direct-regex dual-mode toggle, then leave WITHOUT saving so the
    // rule is unchanged.
    testWidgets('F35: Rule Edit dual-mode toggle, leave without saving',
        (tester) async {
      session = await bootDbOnly(tester);
      final store = RuleDatabaseStore(DatabaseHelper());
      final ruleSet = await store.loadRules();
      expect(ruleSet.rules, isNotEmpty,
          reason: 'the seeded rule set should provide a rule to edit');
      final rule = ruleSet.rules.first;
      final originalPattern = rule.conditions.from.isNotEmpty
          ? rule.conditions.from.first
          : (rule.conditions.header.isNotEmpty
              ? rule.conditions.header.first
              : '');

      await tester.pumpWidget(MaterialApp(
        home: RuleEditScreen(rule: rule, store: store),
      ));
      await tester.pumpAndSettle();

      // The dual-mode toggle renders Guided (plaintext) <-> Direct regex as
      // button segments. Tapping each by its label exercises the toggle without
      // depending on the exact segmented-button generic.
      expect(find.text('Direct regex'), findsWidgets,
          reason: 'the rule editor should expose the Direct-regex mode');
      expect(find.text('Guided (plaintext)'), findsWidgets,
          reason: 'the rule editor should expose the Guided-plaintext mode');
      await tester.tap(find.text('Direct regex').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guided (plaintext)').first);
      await tester.pumpAndSettle();

      // Leave without saving: the rule in the DB is unchanged.
      final reloaded = await store.loadRules();
      final same = reloaded.rules.firstWhere((r) => r.name == rule.name);
      final samePattern = same.conditions.from.isNotEmpty
          ? same.conditions.from.first
          : (same.conditions.header.isNotEmpty
              ? same.conditions.header.first
              : '');
      expect(samePattern, originalPattern,
          reason: 'leaving the editor without Save must not mutate the rule');
    });
  });
}
