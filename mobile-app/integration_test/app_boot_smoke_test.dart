// Sprint 42, F99 -- harness smoke test.
//
// Validates the integration_test bootstrap end-to-end: the real SpamFilterApp
// boots against an isolated temp DB, the RuleSetProvider initializes, and the
// home screen renders. This is the foundation that the F99 lifecycle, folder-
// picker, and visual-regression tests build on; if this is green the harness
// itself works.
//
// Run: flutter test integration_test/app_boot_smoke_test.dart
//   (or via the F99 runner script run-integration-tests.ps1)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F99 harness smoke', () {
    late HarnessSession session;

    tearDown(() async {
      await session.dispose();
    });

    testWidgets('app boots to the home screen against an isolated temp DB',
        (tester) async {
      session = await bootApp(tester);

      // The home (Account Selection) screen exposes the top-bar Settings and
      // "View Scan History" controls once initialization completes. Assert the
      // loading spinner is gone and the home surface is present.
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'RuleSetProvider should have finished initializing');
      expect(find.byType(MaterialApp), findsOneWidget);

      // At least one Scaffold renders (the app shell). This proves the widget
      // tree pumped without an init exception.
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
