import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/widgets/system_inset_wrapper.dart';

/// F209 (Sprint 69): content was hidden behind the Android navigation bar on
/// almost every screen. The audit found only 2 of 23 screens used `SafeArea`,
/// so this was the app-wide default rather than a few misses.
///
/// Proven non-cosmetic: the Import/Export failure message is cut off
/// mid-sentence by the navigation buttons, so a user cannot read the
/// diagnostic that explains what went wrong.
///
/// **ADR-0042 both-branches rule.** This is a DECLARED platform exception --
/// Windows has no system navigation bar. These tests cover BOTH sides: the
/// Android branch insets, and the desktop branch is a genuine no-op, asserted
/// rather than assumed.
void main() {
  group('F209 system navigation inset', () {
    group('the platform decision', () {
      test('applies on Android', () {
        expect(SystemInsetWrapper.appliesTo(isAndroid: true), isTrue);
      });

      test('does NOT apply off Android -- Windows has no system nav bar', () {
        expect(SystemInsetWrapper.appliesTo(isAndroid: false), isFalse);
      });
    });

    group('the computed inset', () {
      test('Android with 3-button navigation gets the reported inset', () {
        expect(
          SystemInsetWrapper.bottomInset(
            isAndroid: true,
            viewPaddingBottom: 48,
          ),
          48,
        );
      });

      test('Android with gesture navigation gets its smaller inset', () {
        // A gesture-navigation device reports a much thinner bar. The inset
        // follows the platform rather than assuming a fixed 3-button height.
        expect(
          SystemInsetWrapper.bottomInset(
            isAndroid: true,
            viewPaddingBottom: 16,
          ),
          16,
        );
      });

      test('Android reporting no inset adds none', () {
        expect(
          SystemInsetWrapper.bottomInset(
            isAndroid: true,
            viewPaddingBottom: 0,
          ),
          0,
        );
      });

      test('DESKTOP NO-REGRESSION: never insets, whatever is reported', () {
        // ADR-0042: the Windows layout must not change. Even if the platform
        // reported an inset, this branch must ignore it.
        expect(
          SystemInsetWrapper.bottomInset(
            isAndroid: false,
            viewPaddingBottom: 48,
          ),
          0,
          reason: 'a desktop layout change would be a regression, not a fix',
        );
      });
    });

    group('rendering -- both ADR-0042 branches, for real', () {
      // Widget tests run on the HOST, so the widget's own Platform.isAndroid
      // is false here. debugIsAndroid drives the branch explicitly, so the
      // ANDROID path -- the one that actually ships -- is rendered by a test
      // rather than inferred from the pure functions above.
      Future<Rect> render(
        WidgetTester tester, {
        required bool isAndroid,
        required double viewPaddingBottom,
      }) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: viewPaddingBottom),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SystemInsetWrapper(
                debugIsAndroid: isAndroid,
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    key: Key('bottom_content'),
                    height: 20,
                    width: 100,
                  ),
                ),
              ),
            ),
          ),
        );
        return tester.getRect(find.byKey(const Key('bottom_content')));
      }

      double screenHeight(WidgetTester tester) =>
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      testWidgets('ANDROID: bottom content clears the navigation bar',
          (tester) async {
        final rect = await render(
          tester,
          isAndroid: true,
          viewPaddingBottom: 48,
        );
        expect(
          rect.bottom,
          screenHeight(tester) - 48,
          reason: 'this is the defect: without the inset the bottom 48 logical '
              'pixels sit UNDER the system buttons, which is what cut the '
              'Import failure message off mid-sentence',
        );
      });

      testWidgets('ANDROID: a gesture-navigation inset is honoured too',
          (tester) async {
        final rect = await render(
          tester,
          isAndroid: true,
          viewPaddingBottom: 16,
        );
        expect(rect.bottom, screenHeight(tester) - 16);
      });

      testWidgets('DESKTOP NO-REGRESSION: layout is byte-identical',
          (tester) async {
        // ADR-0042 requires proving the branch that must NOT change. Rendered
        // with the same reported inset as the Android case above: the desktop
        // branch must ignore it entirely.
        final rect = await render(
          tester,
          isAndroid: false,
          viewPaddingBottom: 48,
        );
        expect(
          rect.bottom,
          screenHeight(tester),
          reason: 'Windows has no system navigation bar; inserting padding '
              'there would be a regression, not a fix',
        );
      });

      testWidgets('ANDROID with no reported inset is also unchanged',
          (tester) async {
        final rect = await render(
          tester,
          isAndroid: true,
          viewPaddingBottom: 0,
        );
        expect(rect.bottom, screenHeight(tester));
      });

      testWidgets('the child always renders', (tester) async {
        await render(tester, isAndroid: true, viewPaddingBottom: 48);
        expect(find.byKey(const Key('bottom_content')), findsOneWidget);
        await render(tester, isAndroid: false, viewPaddingBottom: 48);
        expect(find.byKey(const Key('bottom_content')), findsOneWidget);
      });
    });
  });
}
