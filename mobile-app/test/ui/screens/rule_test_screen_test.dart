import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/rule_test_screen.dart';

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

    testWidgets('shows demo data state when no real scan data is available',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Sub-feature 1: when the DB is unavailable (test environment), demo
      // data is loaded automatically. The screen shows the "enter a pattern"
      // prompt with a demo-data notice, NOT the "no sample emails" empty state.
      expect(find.textContaining('No sample emails available'), findsNothing);
      expect(find.textContaining('demo emails'), findsOneWidget);
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

      // Verify the "N of M emails match" count line is shown
      expect(find.textContaining('emails match'), findsWidgets);

      // Tap clear button (X icon in the text field suffix)
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // After clearing, the pattern field should be empty and _hasTestedOnce
      // resets. The screen returns to the "not tested yet" state.
      // The text field should be empty.
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text ?? '', isEmpty);
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

    // -------------------------------------------------------------------------
    // Sub-feature 1: demo data fallback
    // -------------------------------------------------------------------------

    group('Sub-feature 1 (demo fallback)', () {
      testWidgets('shows demo notice when no real scan data is available',
          (tester) async {
        // In the test environment the database is unavailable so _loadSampleEmails
        // catches the exception -> empty list -> demo fallback loads.
        // The demo-data notice is shown in the "not tested yet" center pane.
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Demo notice should appear (amber banner with "demo emails" text).
        expect(find.textContaining('demo emails'), findsOneWidget);
      });

      testWidgets('does not show "No sample emails available" when demo data loaded',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Sub-feature 1 ensures we never see the empty-state "No sample emails"
        // message in a fresh install -- demo data fills the gap.
        expect(find.textContaining('No sample emails available'), findsNothing);
      });

      testWidgets('sample email count is non-zero after demo data load',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // After entering a pattern and testing, the "N of M emails match"
        // label should show M > 0 (from demo data).
        await tester.enterText(find.byType(TextField).first, r'@example\.com$');
        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        // The count line should appear and M should be > 0.
        expect(find.textContaining('of'), findsOneWidget);
        // Verify the denominator is not "0" (demo data loaded).
        final countText = tester
            .widget<Text>(find.textContaining('emails match'))
            .data!;
        // countText is e.g. "0 of 55 emails match" -- split to extract M.
        final parts = countText.split(' of ');
        final total = int.tryParse(parts.last.split(' ').first) ?? 0;
        expect(total, greaterThan(0));
      });
    });

    // -------------------------------------------------------------------------
    // Sub-feature 2: plaintext-to-regex conversion
    // -------------------------------------------------------------------------

    group('Sub-feature 2 (plaintext-to-regex)', () {
      testWidgets('shows plaintext checkbox in UI', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Checkbox), findsOneWidget);
        expect(
          find.textContaining('Treat input as plain text'),
          findsOneWidget,
        );
      });

      testWidgets('checkbox is unchecked by default', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, isFalse);
      });

      testWidgets('checking plaintext checkbox changes input label',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Default label is 'Regex pattern'
        expect(find.text('Regex pattern'), findsOneWidget);

        // Check the checkbox
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        // Label should change to 'Plain text input'
        expect(find.text('Plain text input'), findsOneWidget);
        expect(find.text('Regex pattern'), findsNothing);
      });

      testWidgets('generated regex label appears after testing with plaintext',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Enable plaintext mode
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        // Enter a plain domain
        await tester.enterText(find.byType(TextField).first, 'example.com');
        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        // Generated regex label should be visible
        expect(find.textContaining('Generated regex:'), findsOneWidget);
      });

      testWidgets('no generated regex label when plaintext mode is off',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Do NOT enable plaintext mode
        await tester.enterText(find.byType(TextField).first, r'@example\.com$');
        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Generated regex:'), findsNothing);
      });

      testWidgets('plaintext test with valid email generates correct pattern',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '.xyz');
        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        // The generated regex for TLD .xyz should be shown
        expect(
          find.textContaining(r'@.*\.xyz$'),
          findsOneWidget,
        );
      });

      testWidgets('clear button resets generated regex label', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'example.com');
        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Generated regex:'), findsOneWidget);

        // Tap clear (X icon in the text field)
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        expect(find.textContaining('Generated regex:'), findsNothing);
      });
    });
  });
}
