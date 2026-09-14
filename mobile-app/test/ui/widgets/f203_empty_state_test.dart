import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/widgets/empty_state.dart';

/// F203 (Sprint 69): the scan-complete empty state used to assert something
/// false.
///
/// It always read "No emails were found in the selected folders for the
/// specified time period." True when the fetch came back empty; NOT true when
/// emails were fetched and skipped because they already sat in the safe-sender
/// folder. Harold's screen showed "Found N, evaluated 0" above an empty list
/// above "No emails were found" -- three statements that cannot all be right.
///
/// Shared by Windows and Android (ADR-0042): one widget, one conditional, no
/// platform branch.
void main() {
  Future<void> pump(WidgetTester tester, int skipped) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanCompleteNoEmailsEmptyState(skippedAlreadyFiled: skipped),
        ),
      ),
    );
  }

  group('F203 ScanCompleteNoEmailsEmptyState', () {
    testWidgets('with no skips it still says nothing was found', (t) async {
      await pump(t, 0);
      expect(find.text('Scan Complete'), findsOneWidget);
      expect(
        find.textContaining('No emails were found'),
        findsOneWidget,
        reason: 'an empty fetch really did find nothing -- unchanged',
      );
    });

    testWidgets('with skips it must NOT claim nothing was found', (t) async {
      await pump(t, 12);
      expect(
        find.textContaining('No emails were found'),
        findsNothing,
        reason: 'twelve emails WERE found; saying otherwise is the defect',
      );
    });

    testWidgets('with skips it reports how many and why', (t) async {
      await pump(t, 12);
      expect(find.textContaining('12'), findsOneWidget);
      expect(find.textContaining('no action was needed'), findsOneWidget);
      expect(find.text('Nothing Needed Action'), findsOneWidget);
    });

    testWidgets('one skipped email reads as singular', (t) async {
      await pump(t, 1);
      expect(find.textContaining('1 safe sender email was'), findsOneWidget);
    });

    testWidgets('several skipped emails read as plural', (t) async {
      await pump(t, 2);
      expect(find.textContaining('2 safe sender emails were'), findsOneWidget);
    });
  });
}
