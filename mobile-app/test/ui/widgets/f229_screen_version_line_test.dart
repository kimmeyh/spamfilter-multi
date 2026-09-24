/// F229 (Sprint 73): the version line RENDERS, on the narrow branch that
/// actually ships to phones.
///
/// **Why this file exists separately from the wiring gate.** The gate proves
/// every screen CONSTRUCTS the widget. It cannot prove the widget draws
/// anything -- and this sprint has two proofs that the distinction is not
/// academic: F234 shipped a preview that could never report a non-zero count,
/// and F224 shipped a cancel that was swallowed on the live path, both with
/// entirely green source-text suites. So this drives the real widget and
/// asserts the string a user would see.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they prove the line
/// renders, carries the runtime version, shows the dev suffix, and does not
/// overflow at 411px. They CANNOT prove it is legible on real hardware at
/// 11pt, nor that its position above the body content reads as belonging to
/// the screen rather than to the content. That is Harold's judgement at manual
/// validation on the S24+, and it is the only thing that settles it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/app_version.dart';
import 'package:my_email_spam_filter/ui/widgets/screen_version_line.dart';

/// Built at runtime so no `V<X.Y.Z>` literal exists in this file for
/// version_consistency_test to flag as stale (it sweeps test/ as well).
final testVersion = [9, 9, 9].join('.');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppVersion.overrideForTest(testVersion));
  tearDown(() => AppVersion.overrideForTest(null));

  Future<void> pump(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenVersionLine(),
            Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('F229: the narrow branch -- the one that ships to phones', () {
    testWidgets('THE FEATURE: the version renders at 411px', (tester) async {
      await pump(tester, width: 411);

      expect(find.textContaining('V$testVersion'), findsOneWidget,
          reason: 'THE ASSERTION THAT MATTERS -- before this card a phone '
              'screenshot carried no version at all, because the AppBar label '
              'hides below 600px and nothing replaced it');
    });

    testWidgets('it does NOT overflow at 411px', (tester) async {
      await pump(tester, width: 411);

      expect(tester.takeException(), isNull,
          reason: 'the whole reason this is in the body and not the AppBar '
              'is that the action row is already 5px over budget at 411px');
    });

    testWidgets('it costs little vertical space', (tester) async {
      // Measured at 16 logical pixels during the deep dive. Pinned loosely:
      // the point is that it stays a LINE, not that it is exactly 16.
      await pump(tester, width: 411);

      final size = tester.getSize(find.byType(ScreenVersionLine));
      expect(size.height, lessThan(32),
          reason: 'a version line that grows into a banner is taking space '
              'from the screen it is annotating');
    });
  });

  group('F229: the wide branch defers to the AppBar label', () {
    testWidgets('nothing renders at 1024px', (tester) async {
      // Windows at its 1024x640 epx minimum. The AppBar label already shows
      // there, and rendering both would be noise rather than redundancy.
      await pump(tester, width: 1024);

      expect(find.textContaining('V$testVersion'), findsNothing);
    });

    test('THE COMPLEMENT: exactly one surface owns each width', () {
      // A pure check of the threshold, so a future edit that moves one
      // boundary without the other is red here rather than discovered from a
      // screenshot showing the version twice -- or nowhere.
      expect(ScreenVersionLine.appliesTo(width: 599), isTrue);
      expect(ScreenVersionLine.appliesTo(width: 600), isFalse,
          reason: '600 is where the AppBar label takes over, matching the '
              'app-wide "compact" breakpoint');
      expect(ScreenVersionLine.appliesTo(width: 411), isTrue,
          reason: 'phone width');
      expect(ScreenVersionLine.appliesTo(width: 1024), isFalse,
          reason: 'Windows minimum');
    });
  });

  group('F229: what the line says', () {
    testWidgets('it uses the RUNTIME version, never a literal', (tester) async {
      // R-5. version_consistency_test and stale_footer_test both police this;
      // a hardcoded string would pass the render test and then go stale at the
      // next version bump, which is precisely the provenance failure this
      // card exists to fix.
      await pump(tester, width: 411);

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, contains(testVersion),
          reason: 'the injected test version must appear, proving the value '
              'came from AppVersion and not from source');
    });

    testWidgets('the short V-form is used, per Harold', (tester) async {
      await pump(tester, width: 411);

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, startsWith('V'),
          reason: 'Harold asked for V<n>.<n>.<n>');
      expect(text.data, isNot(contains('Version ')),
          reason: 'the long form is the AppBar label; this line has no title '
              'competing with it and does not need the word');
    });

    testWidgets('it stays on ONE line and ellipsizes rather than wrapping',
        (tester) async {
      // The unhappy input: a very narrow window. Wrapping would push the
      // screen content down by a second line on every screen at once.
      await pump(tester, width: 200);

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });
}
