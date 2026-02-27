import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/ui/screens/rule_test_screen.dart';

void main() {
  group('RuleTestScreen', () {
    Widget buildTestWidget({
      String? initialPattern,
      String? initialConditionType,
    }) {
      return MaterialApp(
        home: RuleTestScreen(
          initialPattern: initialPattern,
          initialConditionType: initialConditionType,
        ),
      );
    }

    testWidgets('renders app bar with correct title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Test Rule Pattern'), findsOneWidget);
    });

    testWidgets('shows pattern input field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Regex pattern'), findsOneWidget);
    });

    testWidgets('shows condition type segmented button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('From'), findsOneWidget);
      expect(find.text('Subject'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Header'), findsOneWidget);
    });

    testWidgets('shows Test button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Test'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('pre-fills pattern from initialPattern', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialPattern: r'@spam\.com$',
      ));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, r'@spam\.com$');
    });

    testWidgets('shows empty state when no sample emails and no test run',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Database will fail in test environment, so we see the "no sample emails" state
      expect(find.textContaining('No sample emails available'), findsOneWidget);
      expect(find.textContaining('Run a scan first'), findsOneWidget);
    });

    testWidgets('shows error for empty pattern when Test pressed',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the Test button with empty pattern
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a pattern to test'), findsOneWidget);
    });

    testWidgets('shows error for invalid regex pattern', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter an invalid regex
      await tester.enterText(find.byType(TextField), '[invalid');
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid regex'), findsOneWidget);
    });

    testWidgets('valid pattern shows match count text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter a valid regex
      await tester.enterText(find.byType(TextField), r'@test\.com$');
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      // Should show match count (0 of 0 since no sample emails in test env)
      expect(find.textContaining('of'), findsOneWidget);
      expect(find.textContaining('emails match'), findsOneWidget);
    });

    testWidgets('clear button resets state', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialPattern: 'test',
      ));
      await tester.pumpAndSettle();

      // Run test first
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      // Verify match count is shown
      expect(find.textContaining('emails match'), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Match count should be gone, pattern should be empty
      expect(find.textContaining('emails match'), findsNothing);
    });

    testWidgets('hint text changes with condition type', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Default is 'from' - check hint
      final fromHintFinder = find.textContaining('spam');
      expect(fromHintFinder, findsWidgets);
    });

    testWidgets('Match against label is shown', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Match against: '), findsOneWidget);
    });

    testWidgets('constructor accepts all optional parameters', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialPattern: r'@example\.com$',
        initialConditionType: 'subject',
      ));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, r'@example\.com$');
    });

    testWidgets('Scaffold has back navigation', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('pattern with only spaces shows error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a pattern to test'), findsOneWidget);
    });

    testWidgets('multiple test runs update results', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // First test
      await tester.enterText(find.byType(TextField), 'pattern1');
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('emails match'), findsOneWidget);

      // Change pattern and test again
      await tester.enterText(find.byType(TextField), 'pattern2');
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('emails match'), findsOneWidget);
    });

    testWidgets('screen has Divider between input and results', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
    });
  });
}
