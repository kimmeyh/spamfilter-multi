/// Sprint 37 Phase 7 Improvement #2 (Help screen "Other ways to reduce junk").
///
/// Verifies the new terminal section appears, references the FTC and
/// donotcall.gov sources, and the timestamp footer is updated.
///
/// F151i (Sprint 58, MV-7): section bodies now render as formatted Markdown
/// (RichText trees) instead of one large Text widget, so the body-content
/// assertions collect ALL rendered text (Text + RichText) and assert on the
/// combined string -- the CONTENT contract is unchanged, only the widget
/// shape it renders through.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';

/// Concatenates every piece of rendered text on screen (plain Text widgets
/// and RichText/TextSpan trees, which is what Markdown renders through).
String _allRenderedText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final widget in tester.allWidgets) {
    if (widget is Text && widget.data != null) {
      buffer.writeln(widget.data);
    } else if (widget is RichText) {
      buffer.writeln(widget.text.toPlainText());
    }
  }
  return buffer.toString();
}

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

      // Assert key tokens that future-me must not silently lose during a
      // content edit. Collected across the full rendered tree (F151i:
      // Markdown renders as RichText spans, not one Text widget).
      final rendered = _allRenderedText(tester);
      for (final token in const [
        '7726',
        'DoNotCall.gov',
        'OptOutPrescreen',
        'DMAchoice',
        'ReportFraud.ftc.gov',
      ]) {
        expect(
          rendered.contains(token),
          isTrue,
          reason:
              '"Other ways to reduce junk" body must reference "$token" -- '
              'the canonical reporting and opt-out destinations.',
        );
      }
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
      await tester.pumpAndSettle();

      // Sprint 37 Phase 7 round 2 (Harold feedback): unsubscribe advice was
      // initially too generous. Verify the section now warns to ONLY use
      // unsubscribe for well-known / Fortune 1000 senders. (F151i: collected
      // across the rendered tree -- Markdown renders as RichText spans.)
      final rendered = _allRenderedText(tester);
      expect(
        rendered.contains('Fortune 1000') &&
            rendered.contains('mark as Junk/Spam (above)'),
        isTrue,
        reason:
            'Unsubscribe section must caution that unsubscribing can confirm a live address to non-reputable senders.',
      );
    },
  );

  testWidgets(
    'Help section advises AGAINST contacting individual mail-order catalogs',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pumpAndSettle();

      // Sprint 37 Phase 7 round 2 (Harold feedback): contacting a catalog
      // directly is often interpreted as a confirmed-monitored address;
      // verify the section now recommends DMAchoice bulk opt-out instead.
      // (F151i: collected across the rendered tree.)
      final rendered = _allRenderedText(tester);
      expect(
        rendered.contains('AVOID contacting individual mail-order catalogs') &&
            rendered.contains('DMAchoice.org bulk opt-out'),
        isTrue,
        reason:
            'Postal mail section must advise AGAINST direct catalog contact and steer users to DMAchoice bulk opt-out.',
      );
    },
  );
}
