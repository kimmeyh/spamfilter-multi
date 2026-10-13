/// Sprint 78 MV-3 (Harold): after picking a rule on Review No Rule Items, the
/// screen behind the pop-up went blank for about 5 seconds.
///
/// Mechanism: every quick action reloads the rules, the app root showed its
/// "Loading spam filter rules..." screen whenever [RuleSetProvider] was
/// loading, and that REPLACED the home screen -- Review No Rule Items -- which
/// was disposed and rebuilt from scratch. [RulesReadyGate] shows the loading
/// and error screens for the first load only.
///
/// SOURCE-TEXT VERIFIED: the last test reads `lib/main.dart` to prove the app
/// root uses the gate (the wiring); the gate's behavior is proven by the
/// widget tests.
///
/// What these tests do NOT catch: another ancestor of the home screen that
/// rebuilds it with a new key or type (none today: `_AppDefaultScreen`
/// returns the same const screen once accounts are resolved).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/widgets/rules_ready_gate.dart';

class _FakeRules extends RuleSetProvider {
  RuleLoadingState _state = RuleLoadingState.idle;

  @override
  RuleLoadingState get loadingState => _state;

  void set(RuleLoadingState s) {
    _state = s;
    notifyListeners();
  }

  int retries = 0;

  @override
  Future<void> initialize() async => retries++;
}

/// A home screen that counts how often it is created.
class _Home extends StatefulWidget {
  const _Home();
  static int created = 0;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  void initState() {
    super.initState();
    _Home.created++;
  }

  @override
  Widget build(BuildContext context) => const Text('home');
}

Future<_FakeRules> _mount(WidgetTester tester) async {
  _Home.created = 0;
  final rules = _FakeRules();
  await tester.pumpWidget(ChangeNotifierProvider<RuleSetProvider>.value(
    value: rules,
    child: const MaterialApp(home: RulesReadyGate(child: _Home())),
  ));
  return rules;
}

void main() {
  testWidgets('first load: loading screen, then the home screen',
      (tester) async {
    final rules = await _mount(tester);
    rules.set(RuleLoadingState.loading);
    await tester.pump();
    expect(find.text('Loading spam filter rules...'), findsOneWidget);
    expect(find.text('home'), findsNothing);

    rules.set(RuleLoadingState.success);
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a later reload keeps the SAME home screen mounted',
      (tester) async {
    final rules = await _mount(tester);
    rules.set(RuleLoadingState.success);
    await tester.pump();
    final createdAfterLoad = _Home.created;

    // A quick action reloads the rules.
    rules.set(RuleLoadingState.loading);
    await tester.pump();
    expect(find.text('Loading spam filter rules...'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    rules.set(RuleLoadingState.success);
    await tester.pump();

    expect(_Home.created, createdAfterLoad,
        reason: 'the home screen must not be disposed and rebuilt');
  });

  testWidgets(
      'a later reload ERROR keeps the SAME home screen and shows a banner '
      'with Retry (7.7.1 H-1)', (tester) async {
    final rules = await _mount(tester);
    rules.set(RuleLoadingState.success);
    await tester.pump();
    final createdAfterLoad = _Home.created;
    expect(find.byKey(const Key('rules_reload_error_banner')), findsNothing);

    rules.set(RuleLoadingState.error);
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('Loading spam filter rules...'), findsNothing);
    expect(find.byKey(const Key('rules_reload_error_banner')), findsOneWidget,
        reason: 'loadRules() swallows its error; without the banner a '
            'failed reload is invisible and the old rules stay in use');

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(rules.retries, 1);

    rules.set(RuleLoadingState.success);
    await tester.pump();
    expect(find.byKey(const Key('rules_reload_error_banner')), findsNothing);
    expect(_Home.created, createdAfterLoad,
        reason: 'showing and hiding the banner must not rebuild the home '
            'screen (the MV-3 defect)');
  });

  testWidgets('a FIRST-load error still shows Retry', (tester) async {
    final rules = await _mount(tester);
    rules.set(RuleLoadingState.loading);
    await tester.pump();
    rules.set(RuleLoadingState.error);
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  test('the app root uses the gate', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains('RulesReadyGate(child: MainNavigationScreen())'));
    expect(src, isNot(contains('if (ruleProvider.isLoading)')));
  });
}
