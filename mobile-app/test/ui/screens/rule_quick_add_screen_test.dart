import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/storage/rule_database_store.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spam_filter_mobile/ui/screens/rule_quick_add_screen.dart';

class FakeDatabaseProvider implements RuleDatabaseProvider {
  @override
  Future<Database> get database async => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> queryRules({bool? enabledOnly}) async => [];
  @override
  Future<List<Map<String, dynamic>>> querySafeSenders() async => [];
  @override
  Future<int> insertRule(Map<String, dynamic> rule) async => 0;
  @override
  Future<int> insertSafeSender(Map<String, dynamic> safeSender) async => 0;
  @override
  Future<Map<String, dynamic>?> getRule(String ruleName) async => null;
  @override
  Future<Map<String, dynamic>?> getSafeSender(String pattern) async => null;
  @override
  Future<int> updateRule(String ruleName, Map<String, dynamic> values) async => 0;
  @override
  Future<int> updateSafeSender(String pattern, Map<String, dynamic> values) async => 0;
  @override
  Future<int> deleteRule(String ruleName) async => 0;
  @override
  Future<int> deleteSafeSender(String pattern) async => 0;
  @override
  Future<void> deleteAllRules() async {}
  @override
  Future<void> deleteAllSafeSenders() async {}
}

class FakeRuleDatabaseStore implements RuleDatabaseStore {
  final List<Rule> _rules = [];
  bool shouldThrowOnAdd = false;
  Rule? lastAddedRule;

  @override
  Future<void> addRule(Rule rule) async {
    if (shouldThrowOnAdd) {
      throw Exception('Database error');
    }
    lastAddedRule = rule;
    _rules.add(rule);
  }

  @override
  Future<RuleSet> loadRules() async {
    return RuleSet(
      version: '1.0',
      settings: {},
      rules: _rules,
    );
  }

  @override
  Future<Rule?> getRule(String name) async {
    try {
      return _rules.firstWhere((r) => r.name == name);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateRule(Rule updatedRule) async {
    final index = _rules.indexWhere((r) => r.name == updatedRule.name);
    if (index >= 0) {
      _rules[index] = updatedRule;
    }
  }

  @override
  Future<void> deleteRule(String ruleName) async {
    _rules.removeWhere((r) => r.name == ruleName);
  }

  @override
  Future<void> deleteAllRules() async {
    _rules.clear();
  }

  @override
  Future<void> saveRules(RuleSet ruleSet) async {
    _rules.clear();
    _rules.addAll(ruleSet.rules);
  }

  @override
  Future<SafeSenderList> loadSafeSenders() async {
    return SafeSenderList(safeSenders: []);
  }

  @override
  Future<void> addSafeSender(String pattern) async {}

  @override
  Future<void> removeSafeSender(String pattern) async {}

  @override
  Future<void> saveSafeSenders(SafeSenderList safeSenders) async {}

  @override
  RuleDatabaseProvider get databaseProvider => FakeDatabaseProvider();
}

void main() {
  group('RuleQuickAddScreen', () {
    late EmailMessage testEmail;
    late FakeRuleDatabaseStore fakeStore;

    setUp(() {
      testEmail = EmailMessage(
        id: 'msg1',
        from: 'spammer@spam.com',
        subject: 'Buy cheap drugs',
        body: 'Click here http://spam.com or visit https://evil.org',
        headers: {'from': 'spammer@spam.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      fakeStore = FakeRuleDatabaseStore();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RuleQuickAddScreen(
            email: testEmail,
            ruleStore: fakeStore,
          ),
        ),
      );
    }

    testWidgets('Screen displays correct AppBar title', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Create Auto-Delete Rule'), findsOneWidget);
    });

    testWidgets('Email context card displays from address', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('spammer@spam.com'), findsWidgets);
    });

    testWidgets('Email context card displays folder name', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('INBOX'), findsOneWidget);
    });

    testWidgets('Rule name field is populated with auto-generated name', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('AutoDeleteSpamCom'), findsOneWidget);
    });

    testWidgets('From Header bucket is pre-selected', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('From Header'), findsOneWidget);
    });

    testWidgets('All 4 condition bucket labels are present', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('From Header'), findsOneWidget);
      expect(find.text('Subject'), findsWidgets);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Body URL'), findsOneWidget);
    });

    testWidgets('Execution order field is displayed', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Execution Order'), findsOneWidget);
    });

    testWidgets('Save and Cancel buttons are present', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('Cancel button closes screen without saving', (WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeStore.lastAddedRule, isNull);
    });

    testWidgets('Screen is scrollable', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('Form validation key is present', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('Email context section is present', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Email Context'), findsOneWidget);
    });

  });
}
