import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

import 'database_test_helper.dart';

/// F298 (Sprint 80, #496): shared setup for the screen tests that prove a rule
/// or safe sender write reaches [RuleSetProvider].
///
/// The screens under test use REAL stores on a temp sqflite-FFI database, so
/// the provider sees a change only if the screen reloads it: the provider is
/// loaded BEFORE the action and its in-memory set is compared AFTER.
/// Database work runs inside `tester.runAsync` (see db_widget_test_harness).

/// A rule store whose load always fails, so a provider built on it reports a
/// failed reload while the screen's own store still writes normally.
class FailingLoadRuleStore extends RuleDatabaseStore {
  FailingLoadRuleStore(RuleDatabaseProvider provider) : super(provider);

  @override
  Future<RuleSet> loadRules() async =>
      throw StateError('F298 test: simulated reload failure');
}

class F298Harness {
  late DatabaseTestHelper testHelper;

  Future<void> setUp() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    DatabaseHelper().setAppPaths(testHelper.appPaths);
  }

  Future<void> tearDown() => testHelper.tearDown();

  /// A provider on the same database as the screens, loaded now.
  Future<RuleSetProvider> loadedProvider({bool failReload = false}) async {
    final provider = RuleSetProvider();
    provider.initializeForTesting(
      databaseStore: failReload
          ? FailingLoadRuleStore(testHelper.dbHelper)
          : RuleDatabaseStore(testHelper.dbHelper),
      safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
    );
    await provider.loadRules();
    await provider.loadSafeSenders();
    return provider;
  }

  Future<void> insertRule(
    String name, {
    String fromPattern = r'@(?:[a-z0-9-]+\.)*example\.com$',
    String column = 'condition_header',
    bool enabled = true,
  }) async {
    final db = await testHelper.dbHelper.database;
    await db.insert('rules', {
      'name': name,
      'enabled': enabled ? 1 : 0,
      'is_local': 1,
      'execution_order': 30,
      'condition_type': 'OR',
      column: '["${fromPattern.replaceAll(r'\', r'\\')}"]',
      'action_delete': 1,
      'date_added': DateTime.now().millisecondsSinceEpoch,
      'created_by': 'test',
      'pattern_category': 'header_from',
      'pattern_sub_type': 'entire_domain',
      'source_domain': name,
    });
  }

  Future<void> insertSafeSender(String pattern) async {
    final store = SafeSenderDatabaseStore(testHelper.dbHelper);
    await store.addSafeSender(SafeSenderPattern(
      pattern: pattern,
      patternType: 'email',
      dateAdded: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Widget wrap(RuleSetProvider provider, Widget screen) =>
      ChangeNotifierProvider<RuleSetProvider>.value(
        value: provider,
        child: MaterialApp(home: screen),
      );

  /// Like [wrap], but [screen] is PUSHED from a home page, so a screen that
  /// pops itself on save has a route to pop back to.
  Widget wrapPushed(RuleSetProvider provider, Widget Function() screen) =>
      ChangeNotifierProvider<RuleSetProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<bool>(builder: (_) => screen())),
                  child: const Text('open f298 screen'),
                ),
              ),
            ),
          ),
        ),
      );

  /// Opens a screen mounted with [wrapPushed]; call inside `runAsync`.
  Future<void> openPushed(WidgetTester tester) async {
    await tester.tap(find.text('open f298 screen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Taps [finder] and gives the real event loop time to finish the handler's
/// database work (never pumpAndSettle: see db_widget_test_harness.dart).
/// Call from INSIDE `tester.runAsync` (it must not nest another runAsync).
///
///
/// [until] is true once the handler's database work is visible (a snackbar or
/// dialog on screen, or the provider changed). The loop polls for it up to
/// 20 s so a loaded machine does not turn a fixed delay into a failure; on a
/// timeout it falls through and the test's own expectations report what is
/// missing (a removed reload therefore costs 20 s, then fails).
Future<void> tapAndLetDbRun(WidgetTester tester, Finder finder,
    {required bool Function() until}) async {
  await tester.tap(finder);
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
    if (until()) break;
  }
  await tester.pump(const Duration(milliseconds: 100));
}

/// True when some widget's text contains [text] (a snackbar, a dialog title).
bool shown(String text) => find.textContaining(text).evaluate().isNotEmpty;

/// Taps [finder] for UI-only effects (dialogs opening or closing).
Future<void> tapAndPump(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The BUTTON labelled [label] inside the open dialog (the list behind it, and
/// the dialog's own detail rows, can hold the same text).
Finder inDialog(String label) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));

void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
