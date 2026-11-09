import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/widgets/error_display.dart';

/// Sprint 84 self-review F7-3: ErrorDisplay scrolls in a short area instead of
/// overflowing (Sprint 60 EmptyState pattern: Center > SingleChildScrollView >
/// Padding > Column(min)).
///
/// The two phone sizes match the rule_test_screen test. The 360x240 case is a
/// landscape phone with the keyboard open: it is the one that is shorter than
/// the widget (about 300 logical pixels with an action button), so it is the
/// size that fails when the scroll view is removed.
///
/// What this does NOT catch: an overflow of a screen that WRAPS ErrorDisplay
/// in a taller parent column, or text scaling above 1.0.
void main() {
  for (final size in const [Size(390, 560), Size(320, 480), Size(360, 240)]) {
    testWidgets('ErrorDisplay with an action fits at ${size.width}x${size.height}',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorDisplay(
            message: 'The server did not answer. Check the connection and try '
                'again in a moment.',
            actionLabel: 'Try Again',
            onActionPressed: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'ErrorDisplay must scroll, not overflow, in a short area');
      expect(find.text('Try Again'), findsOneWidget);
    });
  }
}
