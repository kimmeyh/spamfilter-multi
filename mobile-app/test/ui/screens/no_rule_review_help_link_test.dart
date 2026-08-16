/// F154 (Sprint 59): the Review No Rule Items screen's Help icon must open
/// Help scrolled to its OWN dedicated section, not the `resultsDisplay`
/// nearest-match stand-in it used before F154.
///
/// This pins the SCREEN-side wiring (`helpSection:` argument). The
/// section-side mechanics (a `reviewNoRuleItems` deep-link lands with its
/// title at the viewport top) are covered per-value by
/// `integration_test/help_deep_link_test.dart`; without THIS test, pointing
/// the screen back at `resultsDisplay` would fail nothing.
///
/// Uses the real sqflite_ffi database (via DatabaseTestHelper) because
/// NoRuleReviewScreen loads from the store in initState; an empty database
/// (empty state) is sufficient -- the AppBar renders regardless of items.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/no_rule_review_screen.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  late DatabaseTestHelper testHelper;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  testWidgets(
      'Help icon opens Help scrolled to the "Review No Rule Items" section '
      '(F154, Sprint 59)', (tester) async {
    // Stub the secure-storage channel empty (same seam the sibling
    // desktop_default_screen_test uses) so the screen's account-email
    // lookups resolve instead of hanging pumpAndSettle.
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') return null;
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(const MaterialApp(home: NoRuleReviewScreen()));
    // Bounded pumps, not pumpAndSettle: the empty-state icon's ambient
    // animations can keep pumpAndSettle from ever settling here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    // Same assertion pattern as help_deep_link_test.dart: the target
    // section's title must land at the TOP of the Help viewport
    // (Scrollable.ensureVisible with alignment 0.0). The screen's own
    // AppBar title also reads "Review No Rule Items" but its route is
    // offstage under the pushed Help route, and finders skip offstage
    // widgets by default.
    final titleFinder = find.text('Review No Rule Items');
    expect(titleFinder, findsWidgets);

    final scrollableFinder = find.byType(Scrollable).first;
    final titleY = tester.getTopLeft(titleFinder.first).dy;
    final scrollableTopY = tester.getTopLeft(scrollableFinder).dy;

    expect(titleY, closeTo(scrollableTopY, 1.0),
        reason: 'The Review No Rule Items screen must deep-link Help to its '
            'own section. A title Y far from the Scrollable top means the '
            'screen is passing a different HelpSection (the pre-F154 '
            'resultsDisplay stand-in, or none at all).');
  });
}
