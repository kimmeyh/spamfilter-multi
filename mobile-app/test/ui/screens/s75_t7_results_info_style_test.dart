/// Sprint 75 Task 7 (R-2), PR #440 test-review MINOR-5: the Results screen's
/// scan-status row (`_buildScanStatusIndicator` in
/// `results_display_screen.dart`) renders a scan REFUSED because another
/// scan holds the account (`EmailScanProvider.markScanRefused`,
/// `hasError && wasRefused`) with the INFO style -- `Icons.info_outline` and
/// the theme's neutral `colorScheme.secondary` / `colorScheme.onSurface` --
/// never the ERROR style (`Icons.error_outline`, `Colors.red[700]`) a genuine
/// scan failure (`EmailScanProvider.errorScan`) uses.
///
/// **Reachability note.** These tests record one `EmailActionResult` first so
/// the row renders through `hasLiveResults`. That gap -- a REAL refusal leaves
/// `results` empty, so the row never rendered -- was found while writing this
/// file and fixed in Sprint 75 (`showLiveRefusal`); the empty-results path is
/// pinned by `s75_refusal_display_test.dart`.
///
/// **What these tests do NOT catch**: the empty-results refusal path (that is
/// the sibling file's job) -- these pin the STYLE only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

import '../../helpers/database_test_helper.dart';

const _accountId = 'aol-user@aol.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  /// Starts a scan, records one result (so `hasLiveResults` stays true once
  /// the status flips away from `scanning`), mounts the real
  /// `ResultsDisplayScreen`, then returns the provider for the test to flip
  /// into the error state under test.
  Future<EmailScanProvider> mount(WidgetTester tester) async {
    final scanProvider = EmailScanProvider();
    scanProvider.startScan(totalEmails: 1, persist: false);
    scanProvider.recordResult(EmailActionResult(
      email: EmailMessage(
        id: '1',
        from: 'someone@example.com',
        subject: 'hello',
        body: '',
        headers: const {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      ),
      action: EmailActionType.none,
      success: true,
    ));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RuleSetProvider>(
              create: (_) => RuleSetProvider()),
          ChangeNotifierProvider<EmailScanProvider>.value(value: scanProvider),
        ],
        child: const MaterialApp(
          home: ResultsDisplayScreen(
            platformId: 'aol',
            platformDisplayName: 'AOL',
            accountId: _accountId,
            accountEmail: _accountId,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return scanProvider;
  }

  testWidgets(
      'a scan REFUSED because another scan holds the account uses the INFO '
      'style, not the error style', (tester) async {
    final scanProvider = await mount(tester);

    scanProvider
        .markScanRefused('A background scan of $_accountId is running.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final message =
        find.textContaining('A background scan of $_accountId is running.');
    expect(message, findsOneWidget);

    expect(find.byIcon(Icons.info_outline), findsOneWidget,
        reason: 'a refusal is information, not a failure');
    expect(find.byIcon(Icons.error_outline), findsNothing,
        reason: 'the error icon must not appear for a refusal');

    final context = tester.element(message);
    final scheme = Theme.of(context).colorScheme;
    expect(tester.widget<Icon>(find.byIcon(Icons.info_outline)).color,
        scheme.secondary,
        reason: 'the info icon must use the neutral theme color');
    expect(tester.widget<Text>(message).style?.color, scheme.onSurface,
        reason: 'the refusal text must use the neutral theme color, not red');
  });

  testWidgets('a genuine scan FAILURE uses the error style, not the info '
      'style', (tester) async {
    final scanProvider = await mount(tester);

    await scanProvider.errorScan('the mail server closed the connection');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final message = find.textContaining('the mail server closed the connection');
    expect(message, findsOneWidget);

    expect(find.byIcon(Icons.error_outline), findsOneWidget,
        reason: 'a genuine failure must show the error icon');
    expect(find.byIcon(Icons.info_outline), findsNothing,
        reason: 'the info icon must not appear for a genuine failure');

    expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
        Colors.red[700]);
    expect(tester.widget<Text>(message).style?.color, Colors.red[700]);
  });
}
