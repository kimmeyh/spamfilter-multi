import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';
import 'package:my_email_spam_filter/ui/widgets/standard_app_bar_actions.dart';

import '../../helpers/database_test_helper.dart';

/// PR #292 review: Manual Scan must not navigate with an unresolved platform.
///
/// `openManualScan` resolves platformId in three tiers -- the caller's value,
/// then the credential store, then a domain guess. The guess
/// (`inferPlatformFromEmail` in `core/utils/platform_inference.dart` -- the
/// ONE implementation) returns `unknownPlatformId` for any address outside its
/// six known domains (five providers), which includes every custom or
/// corporate IMAP host the generic adapter otherwise supports.
///
/// It used to push anyway, feeding "unknown" into the scan pipeline: the real
/// failure (`EmailScanner`: 'Platform unknown not supported') surfaced two
/// screens later, in a Results screen titled with a provider the user never
/// chose, after they tapped Start Live Scan.
///
/// The sentinel is also ambiguous at the navigation boundary: it cannot
/// distinguish an unsupported provider from a keystore read failure from a
/// missing platformId key. So the honest thing is to report and stay put,
/// which is what `settings_screen.dart` already does in three comparable
/// places.
///
/// Harness notes (both patterns copied from `no_rule_review_screen_test.dart`):
/// - `SecureCredentialsStore` is not injectable, so its MethodChannel is
///   stubbed. `getPlatformId` reads `credentials_<accountId>_platformId`; an
///   empty fake store returns null, which IS the unresolvable case.
/// - The destination `ScanProgressScreen` reads `SettingsStore` (a real DB
///   read) in initState, so the FFI database harness backs the navigation
///   cases; without it the pushed screen throws asynchronously.
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

  Widget hostWith({required String accountId, String? platformId}) {
    return MaterialApp(
      // Provider sits INSIDE MaterialApp via `builder` so routes pushed onto
      // the Navigator (ScanProgressScreen) can still see it -- a provider
      // ABOVE MaterialApp is out of scope for pushed routes.
      builder: (context, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<EmailScanProvider>(
            create: (_) => EmailScanProvider(),
          ),
          // Watched by ScanProgressScreen.build; a bare instance is enough for
          // the screen to RENDER, which is all the navigation cases assert.
          ChangeNotifierProvider<RuleSetProvider>(
            create: (_) => RuleSetProvider(),
          ),
        ],
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            // Built under a Builder INSIDE the Scaffold so the guard's
            // `ScaffoldMessenger.of(context)` resolves to this Scaffold.
            Builder(
              builder: (context) => Row(
                children: StandardAppBarActions.build(
                  context: context,
                  helpSection: HelpSection.resultsDisplay,
                  accountId: accountId,
                  accountEmail: accountId,
                  platformId: platformId,
                  includeNoRuleReview: false,
                ),
              ),
            ),
          ],
        ),
        body: const Text('host'),
      ),
    );
  }

  /// Pumps [widget], taps Manual Scan, and drives the async resolution.
  /// Runs inside `tester.runAsync` because the credential-store read and the
  /// pushed screen's SettingsStore load are real async work that never
  /// resolves in the default fake-async zone.
  Future<void> tapManualScan(WidgetTester tester, Widget widget) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.tap(find.byTooltip('Manual Scan'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('an UNRESOLVABLE provider reports and does NOT navigate',
      (tester) async {
    // A corporate IMAP host: not one of the six guessable domains, and the
    // fake store holds no platformId for it -- nothing to fall back on.
    await tapManualScan(
        tester, hostWith(accountId: 'harold@corp-mail.example'));

    expect(find.byType(ScanProgressScreen), findsNothing,
        reason: 'must not push a scan screen we already know cannot scan -- '
            'that defers a guaranteed failure two screens downstream');

    expect(find.textContaining('Could not determine the email provider'),
        findsOneWidget,
        reason: 'the user must be told WHY, at the moment they asked, with an '
            'action they can take');
  });

  testWidgets('a KNOWN provider still navigates normally', (tester) async {
    // Guards over-correction: the guard must reject only the unresolved case.
    await tapManualScan(
        tester,
        hostWith(accountId: 'harold@example.com', platformId: 'gmail'));

    expect(find.byType(ScanProgressScreen), findsOneWidget,
        reason: 'an explicitly supplied platformId must navigate as before');
  });

  testWidgets('a STORED platformId resolves without a caller-supplied one',
      (tester) async {
    // The middle tier: nothing passed in, but the credential store knows.
    fakeSecureStorage['credentials_harold@corp-mail.example_platformId'] =
        'aol';

    await tapManualScan(
        tester, hostWith(accountId: 'harold@corp-mail.example'));

    expect(find.byType(ScanProgressScreen), findsOneWidget,
        reason: 'a platformId recorded at account setup must be honoured even '
            'for a domain the inference cannot guess');
  });

  testWidgets('a guessable domain resolves without a stored platformId',
      (tester) async {
    await tapManualScan(tester, hostWith(accountId: 'harold@gmail.com'));

    expect(find.byType(ScanProgressScreen), findsOneWidget,
        reason: 'the domain fallback still works for the five known providers');
  });

  testWidgets('a lookalike domain does NOT resolve to the real provider',
      (tester) async {
    // The inference matched on `contains('@gmail.com')`, so
    // `user@gmail.com.attacker.example` resolved to gmail. Now matched on the
    // address ENDING.
    await tapManualScan(
        tester, hostWith(accountId: 'harold@gmail.com.attacker.example'));

    expect(find.byType(ScanProgressScreen), findsNothing,
        reason: 'a domain that merely CONTAINS @gmail.com is a different host '
            'and must not be treated as Gmail');
    expect(find.textContaining('Could not determine the email provider'),
        findsOneWidget);
  });
}
