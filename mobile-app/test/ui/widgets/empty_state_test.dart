/// F151a (Sprint 58): NoAccountsEmptyState gains purpose-explaining copy and
/// a secondary "Try Demo Mode instead" action distinct from "Add Account",
/// so a brand-new user (zero accounts) can discover what the app does and
/// find the no-account-needed exploration path without a prior tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/widgets/empty_state.dart';

void main() {
  group('NoAccountsEmptyState -- F151a welcome copy + Demo Mode surfacing', () {
    testWidgets('renders purpose-explaining copy alongside the existing message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoAccountsEmptyState(onAddAccount: () {}),
          ),
        ),
      );

      expect(find.textContaining('scans your inbox'), findsOneWidget);
      expect(find.textContaining('Add your first email account'), findsOneWidget);
    });

    testWidgets('shows the Add Account button unchanged', (tester) async {
      var addAccountTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoAccountsEmptyState(
              onAddAccount: () => addAccountTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Account'), findsOneWidget);
      await tester.tap(find.text('Add Account'));
      await tester.pump();
      expect(addAccountTapped, isTrue);
    });

    testWidgets('does not show a Demo Mode action when onTryDemoMode is not provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoAccountsEmptyState(onAddAccount: () {}),
          ),
        ),
      );

      expect(find.text('Try Demo Mode instead'), findsNothing);
    });

    testWidgets('shows a Demo Mode action distinct from Add Account when provided',
        (tester) async {
      var demoModeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoAccountsEmptyState(
              onAddAccount: () {},
              onTryDemoMode: () => demoModeTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Try Demo Mode instead'), findsOneWidget);
      expect(find.text('Add Account'), findsOneWidget);

      await tester.tap(find.text('Try Demo Mode instead'));
      await tester.pump();
      expect(demoModeTapped, isTrue);
    });
  });
}
