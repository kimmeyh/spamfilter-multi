import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';

import '../../helpers/database_test_helper.dart';

/// PR #292 round 3 (pr-test-analyzer): `_selectAccount` and
/// `_fetchAccountDisplayData` are both private, and had NO automated coverage
/// through three consecutive review rounds that each touched them --
/// round 2's contains()-vs-endsWith() divergence, and round 3's dropped
/// legacy-accountId fallback, were both caught by manual review only. The
/// suite never went red for either.
///
/// This pins the one invariant that broke twice: a row's DISPLAYED provider
/// and its SCAN TARGET must be the same value. `_fetchAccountDisplayData`
/// resolves an old-format accountId (no '@', accountId IS the platformId --
/// e.g. accountId='aol') to a real provider name for display.
/// `openManualScan`'s own three resolution tiers have no such fallback and
/// would call it `unknownPlatformId` on their own. Round 3 forwards the row's
/// resolution through `_selectAccount`'s `platformId` parameter specifically
/// so these two paths cannot disagree.
///
/// Harness: the `flutter_secure_storage` MethodChannel stub + FFI database
/// harness pattern from `manual_scan_unknown_platform_test.dart` (which
/// covers `openManualScan` directly but only with `@`-containing accountIds --
/// this is the no-'@' case that file does not reach).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> fakeSecureStorage = <String, String>{};

  late DatabaseTestHelper testHelper;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    fakeSecureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          final key = call.arguments['key'] as String;
          return fakeSecureStorage[key];
        case 'write':
          final key = call.arguments['key'] as String;
          final value = call.arguments['value'] as String;
          fakeSecureStorage[key] = value;
          return null;
        case 'readAll':
          return Map<String, String>.from(fakeSecureStorage);
      }
      return null;
    });

    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    DatabaseHelper().setAppPaths(testHelper.appPaths);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

  /// Seeds a LEGACY-format account: accountId IS the platformId, no '@'.
  /// `getCredentials('aol')` must succeed (non-null email) for
  /// `_fetchAccountDisplayData` to reach its old-format branch rather than
  /// treating the account as having no credentials at all.
  void registerLegacyAccount(String accountId) {
    fakeSecureStorage['saved_accounts'] = accountId;
    // Old-format accounts stored the platform id as the email too, or left it
    // blank -- either way `_fetchAccountDisplayData` only trusts email when it
    // CONTAINS '@'. An empty string exercises exactly that fallback branch.
    fakeSecureStorage['credentials_${accountId}_email'] = '';
    fakeSecureStorage['credentials_${accountId}_password'] = 'unused';
  }

  Widget buildScreen() {
    return MaterialApp(
      builder: (context, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedAccountProvider>(
            create: (_) => SelectedAccountProvider(),
          ),
          ChangeNotifierProvider<EmailScanProvider>(
            create: (_) => EmailScanProvider(),
          ),
          ChangeNotifierProvider<RuleSetProvider>(
            create: (_) => RuleSetProvider(),
          ),
        ],
        child: child!,
      ),
      home: const AccountSelectionScreen(),
    );
  }

  testWidgets(
      'a legacy account (accountId IS the platformId, no @) displays AND '
      'scans with the SAME resolved platform', (tester) async {
    registerLegacyAccount('aol');

    await tester.runAsync(() async {
      await tester.pumpWidget(buildScreen());
      // _loadSavedAccounts has a deliberate 500ms sync delay; the per-row
      // FutureBuilder resolves after that.
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Round 2's regression class: the row must not fall back to "Unknown
    // Provider" -- if it does, this whole test is meaningless (both paths
    // would trivially agree on "unknown").
    expect(find.textContaining('AOL', findRichText: true), findsWidgets,
        reason: 'precondition: the legacy accountId must resolve to a REAL '
            'provider for display, not "Unknown Provider" -- otherwise the '
            'row-vs-scan-target invariant below is not actually exercised');

    // Round 3's regression: tapping "Start Scan" must reach ScanProgressScreen
    // with the SAME platform the row displayed, not report "unknown".
    final startScan = find.byTooltip('Start Scan');
    expect(startScan, findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(startScan);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Could not determine the email provider'),
        findsNothing,
        reason: 'the row already resolved a real platform for display -- the '
            'scan path must reuse it, not re-derive "unknown" independently');
    expect(find.byType(ScanProgressScreen), findsOneWidget,
        reason: 'a legacy account whose row displays a resolved platform must '
            'reach the scan screen with that SAME platform');
  });
}
