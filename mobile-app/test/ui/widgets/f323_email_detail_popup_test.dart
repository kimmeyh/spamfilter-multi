/// F323 (Sprint 83): the pop-up changes. Block Body sharing the row with Block
/// Subject, the "could not check" note, and the `news_` shape button.
///
/// What these tests do NOT catch (one line each):
///   - how the two half-width cells LOOK on the real Fold cover screen (the
///     test uses a 344 logical pixel window and reads layout, not pixels);
///   - a real body fetch (the loader is a closure here; the fetcher has its own
///     test, and the two screens' wiring is read from source in
///     f323_wiring_test.dart);
///   - a screen reader announcement (labels are not read).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/auth_results_parser.dart';
import 'package:my_email_spam_filter/core/services/rule_suggestion.dart';
import 'package:my_email_spam_filter/ui/widgets/email_detail_popup.dart';

const _from = 'Deals <offers@shop.example>';

EmailActionResult _result(String from, {String subject = 'Big sale today'}) =>
    EmailActionResult(
      email: EmailMessage(
        id: '1',
        from: from,
        subject: subject,
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 11, 1, 8, 37),
        folderName: 'INBOX',
      ),
      action: EmailActionType.none,
      success: true,
    );

Future<List<QuickActionRequest>> _open(
  WidgetTester tester, {
  String from = _from,
  String subject = 'Big sale today',
  RuleSuggestion? suggestion,
  Future<String> Function()? loadBody,
  bool Function(String)? isSafeLinkDomain,
  Size size = const Size(1600, 1200),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final requests = <QuickActionRequest>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showEmailDetailPopup(
            context,
            result: _result(from, subject: subject),
            effectiveEval: null,
            accountEmail: 'me@aol.com',
            showSkip: true,
            suggestion: suggestion,
            loadBody: loadBody,
            isSafeLinkDomain: isSafeLinkDomain,
            onQuickAction: (r, _, __) => requests.add(r),
            onSkip: (_, __) {},
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return requests;
}

Rect _cell(WidgetTester tester, String label) => tester.getRect(find
    .ancestor(of: find.text(label), matching: find.byType(InkWell))
    .first);

final _yellowOk =
    AuthResultsParser.syntheticResultFor(AuthClassification.yellow);

void main() {
  // 7.7.1 code-reviewer M-2. What this does NOT catch: a read that already
  // started when the pop-up closes (it still runs to the end).
  group('the body read waits, and a closed pop-up never reads', () {
    setUp(() => emailPopupBodyReadDelay = const Duration(milliseconds: 400));
    tearDown(() => emailPopupBodyReadDelay = Duration.zero);

    testWidgets('closed before the wait ends: the body is never read',
        (tester) async {
      var reads = 0;
      await _open(tester, settle: false, loadBody: () async {
        reads++;
        return 'https://other.example/x';
      });
      await tester.pump(const Duration(milliseconds: 100));
      Navigator.of(tester.element(find.text('Block Subject'))).pop();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(reads, 0);
    });

    testWidgets('left open: the body is read once, after the wait',
        (tester) async {
      var reads = 0;
      await _open(tester, settle: false, loadBody: () async {
        reads++;
        return 'https://other.example/x';
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(reads, 0);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(find.text('other.example'), findsOneWidget);
    });
  });

  group('R-1: Block Subject and Block Body share one row', () {
    testWidgets('same row, two cells, each at most half the width',
        (tester) async {
      await _open(tester,
          loadBody: () async => 'go to https://other.example/x');
      final subject = _cell(tester, 'Block Subject');
      final body = _cell(tester, 'Block Body');
      expect(subject.top, body.top);
      expect(subject.height, body.height);
      expect(body.left, greaterThan(subject.right - 0.1));
      expect((subject.width - body.width).abs(), lessThan(0.5));
      // The three-cell grid above keeps its cells.
      expect(find.text('Block Entire Domain'), findsOneWidget);
    });

    testWidgets('narrow window (Fold cover screen, 344 px): no overflow, '
        'both cells readable', (tester) async {
      // Sprint 83: the date/account row used to overflow by 93 px at this
      // width; it now wraps. So NO layout error is allowed anywhere in the
      // pop-up, not only in the button rows.
      // What this does NOT catch: overflow with a larger OS font scale, or
      // with the Skip button shown (this pop-up is opened without a sequence).
      final errors = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError =
          (d) => errors.add(d.toString(minLevel: DiagnosticLevel.fine));
      addTearDown(() => FlutterError.onError = prev);
      await _open(tester,
          size: const Size(344, 740),
          subject: 'A fairly long subject line for the cell',
          loadBody: () async => 'https://a-rather-long-domain-name.example/x');
      // Restore the handler BEFORE asserting: a failing expect while the
      // override is active is swallowed into `errors` and the binding then
      // reports "A test overrode FlutterError.onError" instead of the cause.
      FlutterError.onError = prev;
      expect(tester.takeException(), isNull);
      expect(errors, isEmpty, reason: errors.join('\n'));
      final subject = _cell(tester, 'Block Subject');
      final body = _cell(tester, 'Block Body');
      expect(subject.top, body.top);
      expect(subject.width, greaterThan(100));
      expect(body.width, greaterThan(100));
      expect(body.right, lessThanOrEqualTo(344));
      expect(find.text('Block Body'), findsOneWidget);
      expect(find.text('Block Subject'), findsOneWidget);
    });

    testWidgets('no subject: the Subject cell is a disabled placeholder, '
        'Body stays in place', (tester) async {
      await _open(tester,
          subject: '',
          loadBody: () async => 'https://other.example/x');
      expect(find.text('Block Subject'), findsOneWidget);
      expect(find.text('Not available'), findsWidgets);
      expect(_cell(tester, 'Block Subject').top,
          _cell(tester, 'Block Body').top);
    });
  });

  group('R-1 / AC-3: the Block Body value and its states', () {
    testWidgets('the first outside link domain is shown and saved as a body '
        'rule', (tester) async {
      final requests = await _open(tester,
          loadBody: () async =>
              'a https://shop.example/home b https://evil-links.example/x');
      expect(find.text('evil-links.example'), findsOneWidget);
      await tester.tap(find.text('Block Body'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.type, 'body');
      expect(requests.single.value, 'evil-links.example');
      expect(requests.single.kind, QuickActionKind.blockRule);
    });

    testWidgets('a safe-sender link domain is skipped', (tester) async {
      await _open(tester,
          loadBody: () async => 'https://friend.example https://real.example',
          isSafeLinkDomain: (d) => d == 'friend.example');
      expect(find.text('real.example'), findsOneWidget);
      expect(find.text('friend.example'), findsNothing);
    });

    testWidgets('no qualifying link: "No outside link", not tappable',
        (tester) async {
      final requests = await _open(tester,
          loadBody: () async => 'only https://shop.example/home');
      expect(find.text('No outside link'), findsOneWidget);
      await tester.tap(find.text('Block Body'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
    });

    testWidgets('a failed read: "Could not read message", not tappable, no '
        'exception', (tester) async {
      final requests = await _open(tester,
          loadBody: () async => throw StateError('offline'));
      expect(find.text('Could not read message'), findsOneWidget);
      await tester.tap(find.text('Block Body'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while the body loads the cell says Loading and is not '
        'tappable; the pop-up is usable', (tester) async {
      final done = Completer<String>();
      final requests =
          await _open(tester, loadBody: () => done.future, settle: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Loading...'), findsOneWidget);
      await tester.tap(find.text('Block Body'));
      await tester.pump();
      expect(requests, isEmpty);
      // Other buttons still work.
      await tester.tap(find.text('Block Subject'));
      await tester.pumpAndSettle();
      expect(requests.single.type, 'subject');
      done.complete('https://late.example');
      await tester.pump();
    });

    testWidgets('the loader runs once per pop-up, not once per rebuild',
        (tester) async {
      var calls = 0;
      await _open(tester, loadBody: () async {
        calls++;
        return 'https://other.example';
      });
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('no loader (the screen cannot read a body): "Not available"',
        (tester) async {
      await _open(tester);
      final cell = find
          .ancestor(of: find.text('Block Body'), matching: find.byType(InkWell))
          .first;
      expect(
          find.descendant(of: cell, matching: find.text('Not available')),
          findsOneWidget);
    });
  });

  group('R-2 / AC-1: could not check', () {
    testWidgets('the note replaces "Suggested"; no rule is highlighted',
        (tester) async {
      await _open(tester, suggestion: RuleSuggestion.couldNotCheckNote);
      expect(
          find.text(
              "Could not check this sender (the mail server's check did not finish)"),
          findsOneWidget);
      expect(find.text('Suggested'), findsNothing);
      expect(find.byKey(const ValueKey('suggestion-note')), findsNothing);
      expect(find.byKey(const ValueKey('suggestion-pattern')), findsNothing);
    });

    testWidgets('without the note marker nothing about checking shows',
        (tester) async {
      await _open(tester);
      expect(find.byKey(const ValueKey('could-not-check-note')), findsNothing);
    });
  });

  group('R-3 / AC-4: the sender-shape button', () {
    RuleSuggestion shape() => RuleSuggestion.suggest(
        fromEmail: 'news_123456@any-shop.com',
        authClassification: 'green',
        authResult: _yellowOk)!;

    // Sprint 83 MV Q9 = 2: the button is OFFERED; Block Entire Domain is the
    // Suggested one. What this does NOT catch: a news_ row stored by an older
    // build (its stored suggestion still names the shape rule).
    testWidgets('a news_ sender: the shape button is offered, Block Entire '
        'Domain is Suggested; the tap saves the shape rule', (tester) async {
      final requests = await _open(tester,
          from: 'news_123456@any-shop.com', suggestion: shape());
      expect(find.text('Block sender pattern'), findsOneWidget);
      Finder suggestedIn(String label) => find.descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first,
          matching: find.text('Suggested'));
      expect(suggestedIn('Block sender pattern'), findsNothing);
      expect(suggestedIn('Block Entire Domain'), findsOneWidget);
      await tester.tap(find.text('Block sender pattern'));
      await tester.pumpAndSettle();
      expect(requests.single.type, 'senderShape');
      expect(requests.single.value, 'news_digits');
    });

    testWidgets('a news_ sender with no suggestion still gets the button',
        (tester) async {
      await _open(tester, from: 'news_1234@any-shop.com');
      expect(find.text('Block sender pattern'), findsOneWidget);
    });

    testWidgets('absent for an ordinary sender', (tester) async {
      await _open(tester);
      expect(find.text('Block sender pattern'), findsNothing);
    });

    // Sprint 83 7.7.1 pass-2 F6: the name above promised this case.
    testWidgets('absent for news_ followed by letters', (tester) async {
      await _open(tester, from: 'news_abcd@any-shop.com');
      expect(find.text('Block sender pattern'), findsNothing);
    });
  });
}
