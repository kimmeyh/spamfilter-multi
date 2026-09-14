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
/// **These tests exist in the shape they do because the FIRST implementation
/// was wrong in three ways**, all found by code review before hardware
/// validation. It applied raw `Padding` at `MaterialApp.builder`, which
/// shrank the subtree without telling anything inside that the inset had been
/// handled. Each group below pins one of those regressions:
///
/// 1. a `SafeArea`-wrapped bottom sheet inset twice and left a dead strip;
/// 2. the F178 action popup -- which reads the ROOT VIEW precisely because
///    inherited MediaQuery gets consumed -- was positioned inside a Stack that
///    had been shrunk, re-breaking a Sprint 62 fix Harold found by screenshot;
/// 3. `viewPadding` ignored the keyboard, pushing every text-entry screen 48
///    logical pixels too high while typing.
///
/// **ADR-0042 both-branches rule.** This is a DECLARED platform exception --
/// Windows has no system navigation bar. Both sides are covered: the Android
/// branch insets, and the desktop branch is a genuine no-op, asserted rather
/// than assumed.
void main() {
  const navBar = 48.0;

  void configureView(WidgetTester tester,
      {double padBottom = navBar,
      double viewPadBottom = navBar,
      double keyboard = 0}) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(bottom: padBottom);
    tester.view.viewPadding = FakeViewPadding(bottom: viewPadBottom);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
  }

  double screenHeight(WidgetTester tester) =>
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  Widget screen({required bool isAndroid, required Widget body, Widget? bar}) =>
      MaterialApp(
        home: SystemInsetWrapper(
          debugIsAndroid: isAndroid,
          child: Scaffold(appBar: bar as PreferredSizeWidget?, body: body),
        ),
      );

  const bottomContent = Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(key: Key('bottom_content'), height: 20, width: 100),
  );

  group('F209 system navigation inset', () {
    group('the platform decision', () {
      test('applies on Android', () {
        expect(SystemInsetWrapper.appliesTo(isAndroid: true), isTrue);
      });

      test('does NOT apply off Android -- Windows has no system nav bar', () {
        expect(SystemInsetWrapper.appliesTo(isAndroid: false), isFalse);
      });
    });

    group('the inset itself', () {
      testWidgets('ANDROID: bottom content clears the navigation bar',
          (tester) async {
        configureView(tester);
        await tester.pumpWidget(
          screen(isAndroid: true, body: bottomContent),
        );
        expect(
          tester.getRect(find.byKey(const Key('bottom_content'))).bottom,
          screenHeight(tester) - navBar,
          reason: 'without this the bottom 48 logical pixels sit UNDER the '
              'system buttons, which is what cut the Import failure message '
              'off mid-sentence',
        );
      });

      testWidgets('DESKTOP NO-REGRESSION: layout is unchanged',
          (tester) async {
        // ADR-0042 requires proving the branch that must NOT change. Rendered
        // with the same reported inset as the Android case above.
        configureView(tester);
        await tester.pumpWidget(
          screen(isAndroid: false, body: bottomContent),
        );
        expect(
          tester.getRect(find.byKey(const Key('bottom_content'))).bottom,
          screenHeight(tester),
          reason: 'Windows has no system navigation bar; inserting padding '
              'there would be a regression, not a fix',
        );
      });

      testWidgets('ANDROID with no reported inset is also unchanged',
          (tester) async {
        configureView(tester, padBottom: 0, viewPadBottom: 0);
        await tester.pumpWidget(
          screen(isAndroid: true, body: bottomContent),
        );
        expect(
          tester.getRect(find.byKey(const Key('bottom_content'))).bottom,
          screenHeight(tester),
        );
      });
    });

    group('REGRESSION 3: the keyboard case', () {
      testWidgets('content is NOT pushed an extra 48px above the keyboard',
          (tester) async {
        // When the keyboard covers the navigation bar, Flutter zeroes
        // `padding` while `viewPadding` stays at 48. The first implementation
        // read viewPadding and so inset an area that was no longer there.
        configureView(tester,
            padBottom: 0, viewPadBottom: navBar, keyboard: 300);
        await tester.pumpWidget(
          screen(isAndroid: true, body: bottomContent),
        );
        expect(
          tester.getRect(find.byKey(const Key('bottom_content'))).bottom,
          screenHeight(tester) - 300,
          reason: 'content must sit ON the keyboard, not 48 pixels above it. '
              'This is why the wrapper reads `padding` (what is not already '
              'consumed) rather than `viewPadding` (the physical inset).',
        );
      });
    });

    group('REGRESSION 1: nested SafeArea must not inset twice', () {
      testWidgets('a SafeArea-wrapped sheet sits flush to the nav bar',
          (tester) async {
        configureView(tester);
        await tester.pumpWidget(
          screen(
            isAndroid: true,
            body: const SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(key: Key('nested'), height: 20, width: 100),
              ),
            ),
          ),
        );
        expect(
          tester.getRect(find.byKey(const Key('nested'))).bottom,
          screenHeight(tester) - navBar,
          reason: 'SafeArea CONSUMES what it applies, so a nested SafeArea is '
              'a no-op. Raw Padding does not, which left a second 48px dead '
              'strip under sheets that already handled their own inset.',
        );
      });
    });

    group('REGRESSION 2: dialog routes must be untouched', () {
      testWidgets('an F178-style popup still spans the full screen',
          (tester) async {
        // results_display_screen.dart reads MediaQueryData.fromView on
        // purpose: inherited MediaQuery gets CONSUMED, which silently
        // degenerated its safe-area math on a real phone (Sprint 62, found
        // from Harold's screenshot of a clipped "Block Subject"). fromView
        // cannot be consumed -- so if the wrapper shrinks the Stack the popup
        // is positioned in, the popup lands 48px high and clips again.
        //
        // Wrapping AROUND the Scaffold rather than above the Navigator is what
        // prevents that: the dialog route is pushed above this wrapper.
        configureView(tester);
        await tester.pumpWidget(
          screen(
            isAndroid: true,
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    useSafeArea: false,
                    builder: (_) {
                      final mq = MediaQueryData.fromView(View.of(context));
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            bottom: mq.padding.bottom,
                            child: const SizedBox(
                              key: Key('popup'),
                              height: 100,
                              width: 200,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byKey(const Key('popup'))).bottom,
          screenHeight(tester) - navBar,
          reason: 'the popup positions from GLOBAL coordinates in a full-screen '
              'Stack. If the wrapper shrank that Stack, this lands at '
              '${screenHeight(tester) - navBar * 2} and F178 regresses.',
        );
      });
    });

    testWidgets('the child always renders, on both branches', (tester) async {
      configureView(tester);
      await tester.pumpWidget(screen(isAndroid: true, body: bottomContent));
      expect(find.byKey(const Key('bottom_content')), findsOneWidget);
      await tester.pumpWidget(screen(isAndroid: false, body: bottomContent));
      expect(find.byKey(const Key('bottom_content')), findsOneWidget);
    });
  });
}
