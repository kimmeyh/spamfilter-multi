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
      // Sprint 38 F85: bodies now load asynchronously via FutureBuilder
      // against the asset bundle. pumpAndSettle so the futures resolve
      // before the body assertion runs.
      await tester.pumpAndSettle();

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
    'Help screen footer shows the issues link and no stale sprint marker (F117)',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump();

      // F117 (Sprint 47): the footer no longer hardcodes a sprint #; it shows
      // the app version (via package_info_plus, resolved async) plus the
      // issues link. Assert the stable part (the link) is present and the
      // old hardcoded "Sprint 40" string is gone.
      final footer = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '')
                .contains('github.com/kimmeyh/spamfilter-multi/issues'),
      );
      expect(footer, findsWidgets); // at least one (issues link is stable)

      // The key regression guard: the old hardcoded sprint marker is gone.
      final staleFooter = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('Sprint 40'),
      );
      expect(staleFooter, findsNothing);
    },
  );

  testWidgets(
    'Help section warns about unsubscribe risk for non-reputable senders',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump();

      // Sprint 37 Phase 7 round 2 (Harold feedback): unsubscribe advice was
      // initially too generous. Verify the section now warns to ONLY use
      // unsubscribe for well-known / Fortune 1000 senders.
      final body = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').contains('Fortune 1000') &&
            (w.data ?? '').contains('mark as Junk/Spam (above)'),
      );
      expect(
        body,
        findsOneWidget,
        reason:
            'Unsubscribe section must caution that unsubscribing can confirm a live address to non-reputable senders.',
      );
    },
  );

  testWidgets(
    'Help section advises AGAINST contacting individual mail-order catalogs',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump();

      // Sprint 37 Phase 7 round 2 (Harold feedback): contacting a catalog
      // directly is often interpreted as a confirmed-monitored address;
      // verify the section now recommends DMAchoice bulk opt-out instead.
      final body = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').contains('AVOID contacting individual mail-order catalogs') &&
            (w.data ?? '').contains('DMAchoice.org bulk opt-out'),
      );
      expect(
        body,
        findsOneWidget,
        reason:
            'Postal mail section must advise AGAINST direct catalog contact and steer users to DMAchoice bulk opt-out.',
      );
    },
  );
}
