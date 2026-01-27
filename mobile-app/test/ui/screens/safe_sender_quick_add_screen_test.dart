import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/storage/safe_sender_database_store.dart';
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spam_filter_mobile/ui/screens/safe_sender_quick_add_screen.dart';

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

class FakeSafeSenderDatabaseStore implements SafeSenderDatabaseStore {
  final List<SafeSenderPattern> _patterns = [];
  bool shouldThrowOnAdd = false;
  SafeSenderPattern? lastAddedPattern;

  @override
  Future<void> addSafeSender(SafeSenderPattern safeSender) async {
    if (shouldThrowOnAdd) {
      throw Exception('Database error');
    }
    lastAddedPattern = safeSender;
    _patterns.add(safeSender);
  }

  @override
  Future<List<SafeSenderPattern>> loadSafeSenders() async => _patterns;

  @override
  Future<SafeSenderPattern?> getSafeSender(String pattern) async {
    try {
      return _patterns.firstWhere((p) => p.pattern == pattern);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateSafeSender(String pattern, SafeSenderPattern updatedSender) async {
    final index = _patterns.indexWhere((p) => p.pattern == pattern);
    if (index >= 0) {
      _patterns[index] = updatedSender;
    }
  }

  @override
  Future<void> removeSafeSender(String pattern) async {
    _patterns.removeWhere((p) => p.pattern == pattern);
  }

  @override
  Future<void> addException(String safeSenderPattern, String exceptionPattern) async {}

  @override
  Future<void> removeException(String safeSenderPattern, String exceptionPattern) async {}

  @override
  Future<void> deleteAllSafeSenders() async {
    _patterns.clear();
  }

  @override
  RuleDatabaseProvider get databaseProvider => FakeDatabaseProvider();
}

void main() {
  group('SafeSenderQuickAddScreen', () {
    late EmailMessage testEmail;
    late FakeSafeSenderDatabaseStore fakeStore;

    setUp(() {
      testEmail = EmailMessage(
        id: 'msg1',
        from: 'john.doe@example.com',
        subject: 'Test Email Subject',
        body: 'This is a test email body',
        headers: {'from': 'john.doe@example.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      fakeStore = FakeSafeSenderDatabaseStore();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SafeSenderQuickAddScreen(
            email: testEmail,
            safeSenderStore: fakeStore,
          ),
        ),
      );
    }

    testWidgets('Screen displays email from address', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('john.doe@example.com'), findsWidgets);
    });

    testWidgets('Screen displays email subject', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Test Email Subject'), findsOneWidget);
    });

    testWidgets('Screen displays folder name', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('INBOX'), findsOneWidget);
    });

    testWidgets('Shows all 4 pattern type options', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Type 1: Exact Email'), findsOneWidget);
      expect(find.text('Type 2: Domain'), findsOneWidget);
      expect(find.text('Type 3: Domain + Subdomains'), findsOneWidget);
      expect(find.text('Type 4: Custom Pattern'), findsOneWidget);
    });

    testWidgets('Pattern Preview is expandable', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Pattern Preview'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsOneWidget);
    });

    testWidgets('Exception toggle is visible', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Enable Exception Denylist'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('Selecting Type 4 shows custom pattern field', (WidgetTester tester) async {
      await pumpScreen(tester);

      // Initially custom field should not be visible
      expect(find.text('Custom Regex Pattern'), findsNothing);

      // Tap Type 4
      await tester.tap(find.text('Type 4: Custom Pattern'));
      await tester.pumpAndSettle();

      // Now custom field should be visible
      expect(find.text('Custom Regex Pattern'), findsOneWidget);
    });

    testWidgets('Save and Cancel buttons are present', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Save Safe Sender'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Cancel button closes screen without saving', (WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeStore.lastAddedPattern, isNull);
    });

    testWidgets('AppBar displays email address', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Add Safe Sender - john.doe@example.com'), findsOneWidget);
    });

    testWidgets('Screen layout is scrollable', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('Form validation key is present', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('Email context card is present', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Email Context'), findsOneWidget);
    });

    testWidgets('Pattern type selection is present', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Pattern Type'), findsOneWidget);
    });

    testWidgets('Exception list is hidden initially', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Exception Patterns'), findsNothing);
    });

    testWidgets('Custom pattern field validates input', (WidgetTester tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Type 4: Custom Pattern'));
      await tester.pumpAndSettle();

      final customField = find.byType(TextFormField);
      await tester.enterText(customField, '^valid@pattern\\.com\$');
      await tester.pump();

      expect(find.text('^valid@pattern\\.com\$'), findsOneWidget);
    });

  });
}
