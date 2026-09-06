/// GP-18 App access reviewer-path gate (Sprint 65, Issue #381).
///
/// **What this protects.** R-2 of the GP-18 card decides how a Play Store
/// reviewer -- who has no email account and cannot create one -- exercises
/// the app's core value (spam filtering). The card's own text called this a
/// "decision point" and pointed at Demo Mode as the likely answer. This test
/// is that verification, not an assumption: it drives the SAME widget path a
/// reviewer would use, from a fresh install with no configured account, and
/// asserts the app reaches a screen that demonstrates spam filtering.
///
/// **Why the assertion is on `deletedCount`, not on-screen text.** Rendered
/// summary strings are a UI-wording concern and would make this test brittle
/// against future copy changes. `scanProvider.deletedCount` is the same
/// signal `email_scanner_readonly_mode_test.dart` uses to prove the rule
/// engine actually acted, and it is exactly what AC-2 asks for: not
/// navigation succeeding, but filtering happening.
///
/// **What the trace through the source proved, and why this is provider-
/// independent.** `EmailScanner.scanInbox` (lib/core/services/email_scanner.dart)
/// special-cases `platformId == 'demo'`: it uses `MockEmailData.getDemoRuleSet()`
/// / `getDemoSafeSenderList()` instead of `ruleSetProvider.rules` /
/// `.safeSenders`. Demo Mode therefore does not depend on the app's real rule
/// set being loaded, seeded, or even initialized -- this test intentionally
/// builds `RuleSetProvider()` and `EmailScanProvider()` with NO `.initialize()`
/// call, mirroring the state of a genuinely fresh install before any account
/// or rule-seeding work has happened, and Demo Mode still works.
///
/// **ADR-0042 parity.** Demo Mode is shared Dart code (`MockEmailProvider`,
/// `MockEmailData`, `EmailScanner`) with no `Platform.is*` branch anywhere in
/// the traced path, so this test exercises the one code path that runs
/// identically on Windows and Android -- it deliberately asserts nothing
/// platform-specific, which is itself the parity check.
///
/// **Harness.** `tester.runAsync` + `mountAndLoadDbWidget`-style manual
/// pumping (no `pumpAndSettle`, per the documented sqflite-FFI hang) --
/// `ScanProgressScreen.initState` reads `SettingsStore` (real sqflite-FFI
/// via `DatabaseTestHelper`), so this follows
/// `results_display_no_rule_reload_test.dart`'s established pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/ui/screens/platform_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('GP-18 R-2: Demo Mode reviewer path (no account required)', () {
    late DatabaseTestHelper testHelper;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      DatabaseHelper().setAppPaths(testHelper.appPaths);
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    /// Fresh-install state: providers exist but are deliberately NEVER
    /// initialized. A reviewer's first launch has no saved account and no
    /// prior rule-seeding run yet performed -- this is that moment.
    Widget buildFreshInstall() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<EmailScanProvider>(
            create: (_) => EmailScanProvider(),
          ),
          ChangeNotifierProvider<RuleSetProvider>(
            create: (_) => RuleSetProvider(),
          ),
        ],
        child: const MaterialApp(
          home: PlatformSelectionScreen(),
        ),
      );
    }

    testWidgets(
        'a reviewer with no account can reach Demo Mode and see spam '
        'filtering actually happen', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(buildFreshInstall());
        await tester.pump();

        // AC-2 step 1: the entry point named in the reviewer instructions
        // must be on-screen and tappable with no account configured.
        final demoCard = find.widgetWithText(ListTile, 'Try Demo Mode');
        expect(demoCard, findsOneWidget,
            reason: 'the exact on-screen text the reviewer instructions '
                'name must be reachable from the first screen a fresh '
                'install shows');

        await tester.tap(demoCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(ScanProgressScreen), findsOneWidget,
            reason: '_startDemoMode must land on the scan screen with no '
                'account picker or setup form in between');

        // Real-event-loop time for ScanProgressScreen.initState's
        // SettingsStore (sqflite-FFI) load to resolve, per the documented
        // pumpAndSettle-hangs-on-FFI hazard.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();

        // AC-2 step 2: the reviewer instructions must name a SECOND button
        // -- "Start Live Scan" would fail with no account. This is the one
        // that actually runs the demo data through the rule engine.
        //
        // By TEXT, not byType(ElevatedButton): ElevatedButton.icon
        // constructs a private subtype whose runtimeType does not match
        // byType (established pattern, settings_null_account_test.dart).
        final startDemoScan = find.text('Start Demo Scan (Testing)');
        expect(startDemoScan, findsOneWidget,
            reason: 'the reviewer instructions must point at this button '
                'specifically, not "Start Live Scan"');

        await tester.tap(startDemoScan);

        // The demo scan processes 50+ sample emails through MockEmailProvider
        // (simulated per-call network delay) and the real RuleEvaluator
        // against MockEmailData.getDemoRuleSet(). Give the real event loop
        // enough time for the whole batch to complete and the navigation to
        // ResultsDisplayScreen to occur.
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(ResultsDisplayScreen), findsOneWidget,
            reason: 'a completed demo scan must navigate to the results '
                'screen, matching the live-scan contract (F116)');

        // AC-2's actual bar: not navigation, but a demonstrated filtering
        // OUTCOME. The demo rule set is purpose-built to match the demo
        // sample data's spam-shaped senders/bodies, so a real reviewer
        // sees deletions -- this asserts the same fact the UI shows them.
        final scanProvider = Provider.of<EmailScanProvider>(
            tester.element(find.byType(ResultsDisplayScreen)),
            listen: false);
        expect(scanProvider.deletedCount, greaterThan(0),
            reason: 'AC-2: the reviewer must see spam filtering actually '
                'happen, not merely reach a screen -- zero deletions would '
                'mean the demo rule set stopped matching the demo sample '
                'data');
        expect(
            scanProvider.results
                .where((r) => (r.evaluationResult?.matchedRule ?? '').isNotEmpty)
                .isNotEmpty,
            isTrue,
            reason: 'at least one processed email must carry a real matched '
                'rule name, proving the rule ENGINE ran rather than the '
                'screen showing a hardcoded result');
      });
    });
  });
}
