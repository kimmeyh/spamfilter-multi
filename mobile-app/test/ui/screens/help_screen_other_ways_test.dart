/// Sprint 37 Phase 7 Improvement #2 (Help screen "Other ways to reduce junk").
///
/// Verifies the new terminal section appears, references the FTC and
/// donotcall.gov sources, and the timestamp footer is updated.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';

void main() {
  testWidgets(
    'Help screen renders the "Other ways to reduce junk" terminal section',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump();

      // Scroll to the new section so it builds and lays out for the test.
      // (SingleChildScrollView builds all children up front, so finders work
      // regardless of viewport position, but we still need to allow layout.)
      expect(
        find.text(
          'Other ways to reduce junk email, mail, texts, and phone calls',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Help section names key reporting destinations (7726, DoNotCall.gov, OptOutPrescreen, DMAchoice, ReportFraud.ftc.gov)',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump();

      // The section body is one large Text widget; assert key tokens that
      // future-me must not silently lose during a content edit.
      final body = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').contains('7726') &&
            (w.data ?? '').contains('DoNotCall.gov') &&
            (w.data ?? '').contains('OptOutPrescreen') &&
            (w.data ?? '').contains('DMAchoice') &&
            (w.data ?? '').contains('ReportFraud.ftc.gov'),
      );
      expect(
        body,
        findsOneWidget,
        reason:
            '"Other ways to reduce junk" body must reference the canonical reporting and opt-out destinations.',
      );
    },
  );

  testWidgets(
    'Help screen footer timestamp is updated to Sprint 37 / May 2026',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump();

      final footer = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').contains('Sprint 37') &&
            (w.data ?? '').contains('May 2026'),
      );
      expect(footer, findsOneWidget);
    },
  );
}
