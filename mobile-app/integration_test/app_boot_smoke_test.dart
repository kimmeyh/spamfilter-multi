// Sprint 42, F99 -- harness smoke test.
//
// Validates the integration_test bootstrap: an isolated temp DB is created and
// seeded with the bundled rule set (deterministic, ~4000+ rules), fully isolated
// from the dev DB. This is the foundation the F99 lifecycle / picker / visual
// tests build on.
//
// DESIGN (Harold steering 2026-06-20 -- no app shutdown between tests): tests
// share ONE process, so a test must NOT leave an uncontrollable async tail.
// bootApp() (full SpamFilterApp) fires RuleSetProvider.initialize() as a
// fire-and-forget microtask whose long async seed cannot be awaited from the
// test and collides with the next test's DB (database_closed). We therefore use
// bootDbOnly() everywhere: it seeds the temp DB deterministically (awaited) and
// the test pumps the specific screen(s) it needs. See app_harness.dart.
//
// Run: flutter test integration_test/app_boot_smoke_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:my_email_spam_filter/core/storage/database_helper.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F99 harness smoke', () {
    HarnessSession? session;

    tearDown(() async {
      // Null-safe: if bootDbOnly throws before assignment, do not mask the real
      // failure with a LateInitializationError (Copilot review PR #263).
      await session?.dispose();
    });

    testWidgets('seeds an isolated temp DB and pumps a widget', (tester) async {
      session = await bootDbOnly(tester);

      // The bundled rule set was seeded into the isolated temp DB.
      final db = await DatabaseHelper().database;
      final ruleCount = (await db.query('rules')).length;
      expect(ruleCount, greaterThan(0),
          reason: 'bundled rules should have seeded into the temp DB');

      // The widget layer pumps without error against the harness.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('harness ready'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('harness ready'), findsOneWidget);
    });
  });
}
