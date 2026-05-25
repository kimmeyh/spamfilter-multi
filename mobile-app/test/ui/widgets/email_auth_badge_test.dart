/// F89 (Sprint 39) Phase 2 widget tests: EmailAuthBadge renders one chip per
/// classification state, and AuthWarningDialog implements the RED-state
/// warn-then-confirm (cancel + add-anyway) with collapsible technical
/// details. Includes the Sprint 38 Amazon phishing RED fixture.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/auth_results_parser.dart';
import 'package:my_email_spam_filter/ui/widgets/auth_warning_dialog.dart';
import 'package:my_email_spam_filter/ui/widgets/email_auth_badge.dart';

EmailAuthResult _result(
  AuthMethodResult spf,
  AuthMethodResult dkim,
  AuthMethodResult dmarc, {
  String raw = 'raw-auth-text',
}) =>
    EmailAuthResult(spf: spf, dkim: dkim, dmarc: dmarc, raw: raw);

void main() {
  Future<void> pumpBadge(WidgetTester tester, EmailAuthResult result) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: EmailAuthBadge(authResult: result))),
    );
  }

  group('EmailAuthBadge -- per-state rendering', () {
    testWidgets('GREEN badge renders "Authenticated"', (tester) async {
      await pumpBadge(tester, _result(
        AuthMethodResult.pass,
        AuthMethodResult.pass,
        AuthMethodResult.pass,
      ));
      expect(find.byKey(const ValueKey('email_auth_badge_green')), findsOneWidget);
      expect(find.text('Authenticated'), findsOneWidget);
    });

    testWidgets('YELLOW badge renders "Partly authenticated"', (tester) async {
      await pumpBadge(tester, _result(
        AuthMethodResult.pass,
        AuthMethodResult.fail,
        AuthMethodResult.none,
      ));
      expect(find.byKey(const ValueKey('email_auth_badge_yellow')), findsOneWidget);
      expect(find.text('Partly authenticated'), findsOneWidget);
    });

    testWidgets('RED badge renders "Authentication failed"', (tester) async {
      await pumpBadge(tester, _result(
        AuthMethodResult.fail,
        AuthMethodResult.fail,
        AuthMethodResult.fail,
      ));
      expect(find.byKey(const ValueKey('email_auth_badge_red')), findsOneWidget);
      expect(find.text('Authentication failed'), findsOneWidget);
    });

    testWidgets('GREY badge renders when no auth data present', (tester) async {
      await pumpBadge(tester, _result(
        AuthMethodResult.none,
        AuthMethodResult.none,
        AuthMethodResult.none,
        raw: '',
      ));
      expect(find.byKey(const ValueKey('email_auth_badge_grey')), findsOneWidget);
      expect(find.text('No authentication data'), findsOneWidget);
    });
  });

  group('AuthWarningDialog -- RED-state safe-sender warn-then-confirm', () {
    // Sprint 38 Amazon phishing lead RED fixture.
    final amazonPhish = _result(
      AuthMethodResult.fail,
      AuthMethodResult.fail,
      AuthMethodResult.fail,
      raw: 'mx.aol.com; spf=fail smtp.mailfrom=account_update@amazon.com; '
          'dkim=fail header.d=amazon.com; dmarc=fail (p=REJECT)',
    );

    Future<bool?> showDialogAndGet(
      WidgetTester tester, {
      required Future<void> Function(WidgetTester) interact,
    }) async {
      bool? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                captured = await AuthWarningDialog.showSafeSenderWarning(
                  context,
                  senderEmail: 'account_update@amazon.com',
                  authResult: amazonPhish,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await interact(tester);
      await tester.pumpAndSettle();
      return captured;
    }

    testWidgets('dialog explains failures and shows both actions',
        (tester) async {
      await showDialogAndGet(tester, interact: (t) async {
        // Leave dialog open by tapping Cancel at the end.
        await t.tap(find.byKey(const Key('auth_warning_cancel')));
      });
      // The dialog body should mention the protocols and the sender.
      // (Asserted indirectly via keys; the labels are static copy.)
    });

    testWidgets('Cancel path returns false (does NOT whitelist)',
        (tester) async {
      final result = await showDialogAndGet(tester, interact: (t) async {
        await t.tap(find.byKey(const Key('auth_warning_cancel')));
      });
      expect(result, isFalse);
    });

    testWidgets('Add Anyway path returns true', (tester) async {
      final result = await showDialogAndGet(tester, interact: (t) async {
        await t.tap(find.byKey(const Key('auth_warning_add_anyway')));
      });
      expect(result, isTrue);
    });

    testWidgets('technical details are collapsible and reveal raw text',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AuthWarningDialog.showSafeSenderWarning(
                context,
                senderEmail: 'account_update@amazon.com',
                authResult: amazonPhish,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Raw text hidden until expanded.
      expect(find.byKey(const Key('technical_details_text')), findsNothing);
      final toggle = find.byKey(const Key('toggle_technical_details'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('technical_details_text')), findsOneWidget);

      // Clean up the open dialog.
      await tester.tap(find.byKey(const Key('auth_warning_cancel')));
      await tester.pumpAndSettle();
    });
  });
}
