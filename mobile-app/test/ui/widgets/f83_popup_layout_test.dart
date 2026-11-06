/// Sprint 83 MV Q1 (Harold, 2026-11-04): the email-detail pop-up cut off Block
/// Subject / Block Body at the DEFAULT Windows window and on the unfolded Fold,
/// because a wide pop-up was capped at 60% of the safe height. It now grows to
/// its content (placed by `EmailPopupPlacement`) and the header is compact:
/// no drag handle on a wide pop-up, Skip left of the check, the date and the
/// account on the subtitle line, no "No matching rule" badge for a No Rule item.
///
/// What these do NOT catch: real font metrics and scaling on a device (the test
/// font is fixed-width), and the item's real list position (the anchor is the
/// test's button at the top left).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/auth_results_parser.dart';
import 'package:my_email_spam_filter/core/services/rule_suggestion.dart';
import 'package:my_email_spam_filter/ui/widgets/email_detail_popup.dart';

const _from = 'news_026174@eachieved.com';

Future<void> _open(WidgetTester tester,
    {required Size physical, required double dpr, EdgeInsets? pad}) async {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (pad != null) {
    tester.view.padding = FakeViewPadding(
        top: pad.top * dpr, bottom: pad.bottom * dpr);
    tester.view.viewPadding = FakeViewPadding(
        top: pad.top * dpr, bottom: pad.bottom * dpr);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  }
  final suggestion = RuleSuggestion.suggest(
      fromEmail: _from,
      authClassification: 'green',
      authResult:
          AuthResultsParser.syntheticResultFor(AuthClassification.green));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Align(
          alignment: Alignment.topLeft,
          child: TextButton(
            onPressed: () => showEmailDetailPopup(
              context,
              result: EmailActionResult(
                email: EmailMessage(
                  id: '1',
                  from: _from,
                  subject: 'Tue,03 Nov-2026',
                  body: '',
                  headers: const {},
                  receivedDate: DateTime(2026, 11, 3, 17, 27),
                  folderName: 'Bulk',
                ),
                action: EmailActionType.none,
                success: true,
              ),
              effectiveEval: null,
              accountEmail: 'kimmeyharold@aol.com',
              showSkip: true,
              suggestion: suggestion,
              loadBody: () async => 'no links here',
              onQuickAction: (_, __, ___) {},
              onSkip: (_, __) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) {
  final scroll = find.byType(SingleChildScrollView).last;
  return tester
      .state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first)
      .position;
}

void main() {
  group('wide pop-up (Windows default 1280x720 logical; Fold inner screen)', () {
    for (final c in const [
      (Size(1600, 900), 1.25, 'Windows default window'),
      // Harold's Fold inner-screen screenshot is 2256x2504 px; the 2.625
      // density is ASSUMED (not read from the device).
      (Size(2256, 2504), 2.625, 'Fold inner screen (unfolded)'),
    ]) {
      testWidgets('${c.$3}: every row shows without scrolling, and the whole '
          'pop-up is inside the window', (tester) async {
        await _open(tester,
            physical: c.$1,
            dpr: c.$2,
            pad: c.$2 > 2 ? const EdgeInsets.only(top: 24, bottom: 48) : null);
        expect(_position(tester).maxScrollExtent, 0,
            reason: 'Block Subject / Block Body were cut off at this size');
        expect(find.text('Block Subject'), findsOneWidget);
        expect(find.text('Block Body'), findsOneWidget);

        final logical = c.$1 / c.$2;
        final card = tester.getRect(find.byType(SingleChildScrollView).last);
        expect(card.top, greaterThanOrEqualTo(0));
        expect(card.bottom, lessThanOrEqualTo(logical.height));
      });
    }

    testWidgets('compact header: no handle, Skip on the sender row, date and '
        'account on the subtitle line, no "No matching rule" badge',
        (tester) async {
      await _open(tester, physical: const Size(1600, 900), dpr: 1.25);
      final sender = tester.getRect(find.text(_from).first);
      final skip = tester.getRect(find.text('Skip').first);
      expect((skip.center.dy - sender.center.dy).abs(), lessThan(20),
          reason: 'Skip is on the sender row, left of the check');
      final subtitle = tester.getRect(find.textContaining('Bulk •'));
      final date = tester.getRect(find.byIcon(Icons.schedule));
      expect((date.center.dy - subtitle.center.dy).abs(), lessThan(20),
          reason: 'the date shares the subtitle line');
      expect(find.text('No matching rule'), findsNothing);
      expect(sender.right, lessThan(skip.left),
          reason: 'the sender is not covered by Skip');
    });
  });

  group('compact pop-up (phone, F178 bottom-anchored)', () {
    testWidgets('Skip stays off the sender row; the pop-up hugs the safe '
        'bottom; no badge', (tester) async {
      await _open(tester,
          physical: const Size(1440, 3120),
          dpr: 3.75,
          pad: const EdgeInsets.only(top: 24, bottom: 48));
      final sender = tester.getRect(find.text(_from).first);
      final skip = tester.getRect(find.text('Skip').first);
      expect(skip.top, greaterThan(sender.bottom),
          reason: 'F230: at phone width Skip on the sender row truncated it');
      expect(find.text('No matching rule'), findsNothing);
      final card = tester.getRect(find.byType(SingleChildScrollView).last);
      expect(card.bottom, closeTo(832 - 48, 1));
    });
  });

  group('EmailPopupPlacement', () {
    final size = const Size(1280, 720);
    Offset place(double h, {double? rowTop, double rowH = 40}) =>
        EmailPopupPlacement(
          isCompactWidth: false,
          safeTop: 0,
          safeBottom: 0,
          itemTop: rowTop,
          itemHeight: rowTop == null ? null : rowH,
        ).getPositionForChild(size, Size(800, h));

    test('room below: one row lower, so the next row stays visible', () {
      expect(place(300, rowTop: 100).dy, 100 + 40 + 40 + 8);
    });
    test('room only directly below', () {
      expect(place(560, rowTop: 100).dy, 100 + 40 + 8);
    });
    test('no room below: above the row', () {
      expect(place(300, rowTop: 600).dy, 600 - 8 - 300);
    });
    test('room nowhere: clamped so the bottom stays inside', () {
      expect(place(650, rowTop: 300).dy, 720 - 650 - 8);
    });
    test('taller than the window: pinned to the top', () {
      expect(place(900, rowTop: 300).dy, 8);
    });
  });
}
