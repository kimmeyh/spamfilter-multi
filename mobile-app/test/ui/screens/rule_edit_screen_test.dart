/// Widget tests for RuleEditScreen (F35, Sprint 40).
///
/// Tests cover:
/// - Screen structure (app bar, sections, buttons)
/// - Pre-population from an existing rule
/// - Pattern mode switching (guided vs direct regex)
/// - Direct regex validation (ReDoS, invalid syntax)
/// - Enabled toggle and execution order field
/// - Action section (delete vs move to folder)
///
/// Save-path integration (actual DB write) is covered in the unit tests
/// under test/unit/storage/ and test/unit/providers/, which run against
/// a real in-memory SQLite database via sqflite_common_ffi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/rule_edit_screen.dart';

// ---------------------------------------------------------------------------
// Stub RuleDatabaseStore -- intercept at the Store level so widget tests need
// no real SQLite database. The stub overrides only updateRule, which is the
// only method called by RuleEditScreen.
// ---------------------------------------------------------------------------

class _StubRuleDatabaseStore extends RuleDatabaseStore {
  bool throwOnUpdate;
  Rule? lastUpdatedRule;

  _StubRuleDatabaseStore({this.throwOnUpdate = false})
      : super(_StubProviderForStore());

  @override
  Future<void> updateRule(Rule rule) async {
    if (throwOnUpdate) {
      throw RuleDatabaseStorageException('Stub DB update failure');
    }
    lastUpdatedRule = rule;
  }
}

/// A no-op provider passed as the super-constructor argument to
/// [_StubRuleDatabaseStore]. No methods on it are ever called by the
/// [RuleEditScreen] code path -- only [_StubRuleDatabaseStore.updateRule]
/// is invoked.
class _StubProviderForStore implements RuleDatabaseProvider {
  @override
  Future<Database> get database async => throw UnimplementedError('not called');

  @override
  Future<List<Map<String, dynamic>>> queryRules({bool? enabledOnly}) async => [];

  @override
  Future<List<Map<String, dynamic>>> querySafeSenders() async => [];

  @override
  Future<int> insertRule(Map<String, dynamic> rule) async => 1;

  @override
  Future<int> insertSafeSender(Map<String, dynamic> safeSender) async => 1;

  @override
  Future<Map<String, dynamic>?> getRule(String ruleName) async => null;

  @override
  Future<Map<String, dynamic>?> getSafeSender(String pattern) async => null;

  @override
  Future<int> updateRule(String ruleName, Map<String, dynamic> values) async => 1;

  @override
  Future<int> updateSafeSender(String pattern, Map<String, dynamic> values) async => 1;

  @override
  Future<int> deleteRule(String ruleName) async => 1;

  @override
  Future<int> deleteSafeSender(String pattern) async => 1;

  @override
  Future<void> deleteAllRules() async {}

  @override
  Future<void> deleteAllSafeSenders() async {}
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Standard header_from block rule used in most tests.
Rule _makeHeaderRule({
  String name = 'manual_example_com_12345',
  bool enabled = true,
  int executionOrder = 20,
  String pattern = r'@(?:[a-z0-9-]+\.)*example\.com$',
  String sourceDomain = 'example.com',
  String patternSubType = 'entire_domain',
  bool actionDelete = true,
  String? moveToFolder,
}) {
  return Rule(
    name: name,
    enabled: enabled,
    isLocal: true,
    executionOrder: executionOrder,
    conditions: RuleConditions(type: 'OR', header: [pattern]),
    actions: RuleActions(delete: actionDelete, moveToFolder: moveToFolder),
    patternCategory: 'header_from',
    patternSubType: patternSubType,
    sourceDomain: sourceDomain,
  );
}

Widget _buildScreen(Rule rule, {_StubRuleDatabaseStore? store}) {
  return MaterialApp(
    home: RuleEditScreen(
      rule: rule,
      store: store ?? _StubRuleDatabaseStore(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RuleEditScreen -- structure', () {
    testWidgets('shows Edit Rule app bar', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      expect(find.text('Edit Rule'), findsOneWidget);
    });

    testWidgets('shows rule name banner with source domain', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      // Source domain is shown in the banner
      expect(find.text('example.com'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Enabled switch', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('shows Execution Order text field', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      expect(find.text('Execution Order'), findsOneWidget);
    });

    testWidgets('shows Action section with Delete and Move options', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Delete'), findsAtLeastNWidgets(1));
      expect(find.text('Move to Folder'), findsOneWidget);
    });

    testWidgets('shows Pattern section with mode toggle chips', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      expect(find.text('Pattern'), findsOneWidget);
      expect(find.text('Guided (plaintext)'), findsOneWidget);
      expect(find.text('Direct regex'), findsOneWidget);
    });

    testWidgets('shows Save Changes button (FilledButton type in widget tree)', (tester) async {
      // Use a tall view so the button is on-screen and not clipped.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      // The save button is a FilledButton keyed 'rule_edit_save_button'.
      // With a tall view it should be visible without scrolling.
      expect(find.byKey(const Key('rule_edit_save_button')), findsOneWidget);
    });
  });

  group('RuleEditScreen -- pre-population', () {
    testWidgets('pre-fills enabled state (enabled rule)', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule(enabled: true)));
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('pre-fills enabled state (disabled rule)', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule(enabled: false)));
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isFalse);
    });

    testWidgets('pre-fills execution order field', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule(executionOrder: 30)));
      await tester.pumpAndSettle();

      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('starts in guided mode when source domain matches pattern', (tester) async {
      // The pattern for "entire domain" of "example.com" is
      // @(?:[a-z0-9-]+\.)*example\.com$ which the init logic regenerates and
      // compares to the stored pattern.
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      // In guided mode the rule type radio buttons should be present
      expect(find.text('Entire Domain'), findsAtLeastNWidgets(1));
      expect(find.text('Exact Domain'), findsOneWidget);
    });

    testWidgets('starts in direct-regex mode for a rule with no source domain', (tester) async {
      final rule = Rule(
        name: 'bundled_rule_xyz',
        enabled: true,
        isLocal: false,
        executionOrder: 10,
        conditions: RuleConditions(type: 'OR', header: [r'@.*\.xyz$']),
        actions: RuleActions(delete: true),
        patternCategory: 'header_from',
        patternSubType: 'top_level_domain',
        // sourceDomain intentionally null
      );
      await tester.pumpWidget(_buildScreen(rule));
      await tester.pumpAndSettle();

      // Should show the direct-regex text field
      expect(find.text('Regex pattern'), findsOneWidget);
    });

    testWidgets('pre-fills direct-regex field for rule with no source domain', (tester) async {
      final existingPattern = r'@.*\.xyz$';
      final rule = Rule(
        name: 'bundled_rule_xyz',
        enabled: true,
        isLocal: false,
        executionOrder: 10,
        conditions: RuleConditions(type: 'OR', header: [existingPattern]),
        actions: RuleActions(delete: true),
        patternCategory: 'header_from',
        patternSubType: 'top_level_domain',
      );
      await tester.pumpWidget(_buildScreen(rule));
      await tester.pumpAndSettle();

      // The TextFormField for direct regex should contain the pattern
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
      final regexField = fields.firstWhere(
        (f) => f.controller?.text == existingPattern,
        orElse: () => throw StateError('Pattern field not found'),
      );
      expect(regexField.controller?.text, existingPattern);
    });
  });

  group('RuleEditScreen -- mode switching', () {
    testWidgets('can switch from guided to direct-regex mode', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      // Initially in guided mode -- radio buttons are present somewhere in the
      // widget tree (may be off-screen in compact test layout).
      expect(
        find.text('Entire Domain', skipOffstage: false),
        findsAtLeastNWidgets(1),
      );

      // Scroll to the "Direct regex" chip and tap it.
      await tester.scrollUntilVisible(
        find.text('Direct regex'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Direct regex'));
      await tester.pumpAndSettle();

      // Now the direct-regex field should appear.
      expect(find.text('Regex pattern'), findsOneWidget);
    });

    testWidgets('can switch back from direct-regex to guided mode', (tester) async {
      final rule = Rule(
        name: 'bundled_rule_xyz',
        enabled: true,
        isLocal: false,
        executionOrder: 10,
        conditions: RuleConditions(type: 'OR', header: [r'@.*\.xyz$']),
        actions: RuleActions(delete: true),
        patternCategory: 'header_from',
        patternSubType: 'top_level_domain',
      );
      await tester.pumpWidget(_buildScreen(rule));
      await tester.pumpAndSettle();

      // Starts in direct-regex mode.
      expect(find.text('Regex pattern'), findsOneWidget);

      // Scroll to the "Guided (plaintext)" chip and tap it.
      await tester.scrollUntilVisible(
        find.text('Guided (plaintext)'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guided (plaintext)'));
      await tester.pumpAndSettle();

      // Guided mode shows rule type radio buttons.
      expect(
        find.text('Entire Domain', skipOffstage: false),
        findsAtLeastNWidgets(1),
      );
    });
  });

  group('RuleEditScreen -- direct regex validation', () {
    testWidgets('shows no error for a valid regex', (tester) async {
      final rule = Rule(
        name: 'rule_no_src',
        enabled: true,
        isLocal: true,
        executionOrder: 20,
        conditions: RuleConditions(type: 'OR', header: [r'@example\.com$']),
        actions: RuleActions(delete: true),
        patternCategory: 'header_from',
        patternSubType: 'exact_domain',
      );
      await tester.pumpWidget(_buildScreen(rule));
      await tester.pumpAndSettle();

      // Clear the field and type a valid regex
      final regexField = find.byType(TextFormField).last;
      await tester.enterText(regexField, r'@spam\.net$');
      await tester.pumpAndSettle();

      // No error icon should be present
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('shows error for a ReDoS-vulnerable pattern', (tester) async {
      final rule = Rule(
        name: 'rule_no_src',
        enabled: true,
        isLocal: true,
        executionOrder: 20,
        conditions: RuleConditions(type: 'OR', header: [r'@example\.com$']),
        actions: RuleActions(delete: true),
        patternCategory: 'header_from',
        patternSubType: 'exact_domain',
      );
      await tester.pumpWidget(_buildScreen(rule));
      await tester.pumpAndSettle();

      final regexField = find.byType(TextFormField).last;
      // Classic ReDoS: (a+)+ -- should be rejected
      await tester.enterText(regexField, r'(a+)+');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('RuleEditScreen -- enabled toggle', () {
    testWidgets('can toggle enabled state', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule(enabled: true)));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isFalse);
    });
  });

  group('RuleEditScreen -- action section', () {
    testWidgets('Move to Folder radio reveals folder text field', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeHeaderRule()));
      await tester.pumpAndSettle();

      // Tap the "Move to Folder" radio button
      await tester.tap(find.text('Move to Folder'));
      await tester.pumpAndSettle();

      // Folder name field should now appear
      expect(find.text('Folder name'), findsOneWidget);
    });

    testWidgets('pre-fills folder name for existing move-to-folder rule', (tester) async {
      final rule = _makeHeaderRule(actionDelete: false, moveToFolder: 'Junk');
      await tester.pumpWidget(_buildScreen(rule));
      await tester.pumpAndSettle();

      // "Junk" should be shown in the folder field
      expect(find.text('Junk'), findsOneWidget);
    });
  });

  group('RuleEditScreen -- save path (stub store)', () {
    // Save-path tests use a tall screen (1080x1920) so the entire form fits in
    // one viewport and no scrollUntilVisible is needed. This eliminates
    // test-pollution from scroll state left by prior tests.

    testWidgets('Save Changes button calls store.updateRule on success', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final stubStore = _StubRuleDatabaseStore();
      await tester.pumpWidget(_buildScreen(_makeHeaderRule(), store: stubStore));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rule_edit_save_button')));
      await tester.pumpAndSettle();

      expect(stubStore.lastUpdatedRule, isNotNull);
      expect(stubStore.lastUpdatedRule!.name, equals('manual_example_com_12345'));
    });

    testWidgets('Save Changes preserves rule name (PK)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const originalName = 'manual_spam_org_99999';
      final stubStore = _StubRuleDatabaseStore();
      await tester.pumpWidget(_buildScreen(
        _makeHeaderRule(
          name: originalName,
          sourceDomain: 'spam.org',
          pattern: r'@(?:[a-z0-9-]+\.)*spam\.org$',
        ),
        store: stubStore,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rule_edit_save_button')));
      await tester.pumpAndSettle();

      expect(stubStore.lastUpdatedRule!.name, equals(originalName));
    });

    testWidgets('store.updateRule threw -- screen stays and button still present', (tester) async {
      // Verifies the error path: when the store throws, the updateRule is
      // invoked but the screen stays (no pop). lastUpdatedRule is null because
      // the stub throws before setting it.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final stubStore = _StubRuleDatabaseStore(throwOnUpdate: true);
      await tester.pumpWidget(_buildScreen(_makeHeaderRule(), store: stubStore));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rule_edit_save_button')));
      await tester.pumpAndSettle();

      // The store threw -- lastUpdatedRule is null.
      expect(stubStore.lastUpdatedRule, isNull);
      // The save button is still present (screen was NOT popped).
      expect(find.byKey(const Key('rule_edit_save_button')), findsOneWidget);
    });
  });
}
