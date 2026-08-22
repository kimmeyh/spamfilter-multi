/// F176 (Sprint 62): the shared account-email label for the Manual Scan and
/// Live Scan screens. Small type, single line, ellipsized -- the AppBar
/// titles carry the email too, but truncate it away at phone width, which
/// left multi-account validation unable to tell WHICH account a scan ran
/// against (Harold, Sprint 61 MV).
///
/// Mutation-verified at authoring: removing the AccountEmailLabel from
/// ScanProgressScreen's header turns the screen-presence test red.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';
import 'package:my_email_spam_filter/ui/widgets/account_email_label.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });
  group('AccountEmailLabel widget', () {
    testWidgets('renders the email in small single-line type',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AccountEmailLabel(email: 'kimmeyharold@aol.com'),
        ),
      ));

      final text = tester.widget<Text>(find.text('kimmeyharold@aol.com'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis,
          reason: 'a long address must ellipsize, never wrap or overflow '
              'the header layout at phone width (the F169 rule)');
    });

    testWidgets('a very long address at a narrow width does not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(411, 731);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AccountEmailLabel(
            email: '${'very-long-local-part' * 8}@example.com',
          ),
        ),
      ));

      expect(tester.takeException(), isNull,
          reason: 'no RenderFlex overflow at 411px with an absurd address');
    });

    testWidgets('renders nothing for an empty email (demo-safe)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AccountEmailLabel(email: '')),
      ));
      expect(find.byType(Text), findsNothing);
    });
  });

  group('screen presence', () {
    late DatabaseTestHelper testHelper;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    testWidgets(
        'ScanProgressScreen body shows the account email (not only the '
        'truncating AppBar title)', (tester) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => EmailScanProvider()),
          ChangeNotifierProvider(create: (_) => RuleSetProvider()),
        ],
        child: const MaterialApp(
          home: ScanProgressScreen(
            platformId: 'demo',
            platformDisplayName: 'Demo',
            accountId: 'demo-account',
            accountEmail: 'user@example.com',
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(AccountEmailLabel), findsOneWidget,
          reason: 'F176: the body label is the fix -- the AppBar title '
              'truncates the email away at phone width');
      expect(
        find.descendant(
            of: find.byType(AccountEmailLabel),
            matching: find.text('user@example.com')),
        findsOneWidget,
      );
    });
  });
}
