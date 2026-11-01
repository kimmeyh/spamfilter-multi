/// F306 (Sprint 82): the suggested rule in the shared email pop-up.
///
/// AC-1: a stored suggestion highlights exactly one button, with the visible
/// text "Suggested", and shows the exact regex and the reason sentence.
/// AC-2: tapping that button reports a QuickActionRequest whose builder pattern
/// equals the regex on screen (the tap goes through the existing path).
/// Without a suggestion none of that shows. The phone-width tests prove the
/// regex text does not overflow.
///
/// What these tests do NOT catch (one line each):
///   - how the border LOOKS on a real display (the test reads the decoration
///     width, not pixels);
///   - the two screens passing the suggestion in (the Review screen wiring is
///     proven by source text in f306_suggestion_wiring_test.dart);
///   - a real screen reader announcement (the test reads the semantics label).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/core/services/rule_suggestion.dart';
import 'package:my_email_spam_filter/ui/widgets/email_detail_popup.dart';

const _spamFrom = 'Deals <offers@mail.shop-example.com>';

EmailActionResult _result(String from) => EmailActionResult(
      email: EmailMessage(
        id: '1',
        from: from,
        subject: 'Big sale today',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 10, 30, 8, 37),
        folderName: 'INBOX',
      ),
      action: EmailActionType.none,
      success: true,
    );

Future<List<QuickActionRequest>> _open(
  WidgetTester tester, {
  required String from,
  RuleSuggestion? suggestion,
  Size size = const Size(1600, 1200),
  bool showSkip = true,
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
            result: _result(from),
            effectiveEval: null,
            accountEmail: 'me@aol.com',
            showSkip: showSkip,
            suggestion: suggestion,
            onQuickAction: (r, _, __) => requests.add(r),
            onSkip: (_, __) {},
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return requests;
}

RuleSuggestion _yellow(String from) =>
    RuleSuggestion.suggest(fromEmail: from, authClassification: 'yellow')!;

/// The border width of the button cell that holds [label].
double _borderWidth(WidgetTester tester, String label) {
  final container = find
      .ancestor(of: find.text(label), matching: find.byType(Container))
      .evaluate()
      .map((e) => e.widget as Container)
      .firstWhere((c) {
    final d = c.decoration;
    return d is BoxDecoration && d.border is Border;
  });
  return ((container.decoration as BoxDecoration).border as Border).top.width;
}

void main() {
  group('AC-1: a suggestion is shown', () {
    testWidgets('one button says Suggested, the regex and reason show',
        (tester) async {
      final s = _yellow(_spamFrom);
      await _open(tester, from: _spamFrom, suggestion: s);

      expect(find.text('Suggested'), findsOneWidget);
      // The word sits in the Block Entire Domain cell, not another one.
      expect(
          find.descendant(
              of: find.ancestor(
                  of: find.text('Block Entire Domain'),
                  matching: find.byType(InkWell)),
              matching: find.text('Suggested')),
          findsOneWidget);
      expect(find.text(s.pattern), findsOneWidget);
      expect(find.text(s.reasonText), findsOneWidget);

      // Not color alone: the suggested cell has the heavier border.
      expect(_borderWidth(tester, 'Block Entire Domain'), 2);
      expect(_borderWidth(tester, 'Block Exact Domain'), 1);
      expect(_borderWidth(tester, 'Block Email'), 1);
    });

    testWidgets('the semantics label names the suggestion', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, from: _spamFrom, suggestion: _yellow(_spamFrom));
      expect(find.bySemanticsLabel('Block Entire Domain, suggested rule'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Block Email'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a provider sender highlights Block Email', (tester) async {
      const from = 'Some One <some.one@gmail.com>';
      final s = _yellow(from);
      await _open(tester, from: from, suggestion: s);
      expect(find.text('Suggested'), findsOneWidget);
      expect(_borderWidth(tester, 'Block Email'), 2);
      expect(_borderWidth(tester, 'Block Entire Domain'), 1);
      expect(find.text(s.pattern), findsOneWidget);
    });

    testWidgets('without a suggestion nothing of it shows', (tester) async {
      await _open(tester, from: _spamFrom);
      expect(find.text('Suggested'), findsNothing);
      expect(find.byKey(const ValueKey('suggestion-note')), findsNothing);
      expect(_borderWidth(tester, 'Block Entire Domain'), 1);
    });

    testWidgets(
        'a suggestion that names a value no button passes shows nothing',
        (tester) async {
      // Defends the "regex on screen is one a tap saves" rule: a stale value
      // highlights no button and shows no regex.
      const stale = RuleSuggestion(
          kind: 'block',
          type: 'entireDomain',
          value: 'other-domain.com',
          pattern: r'@(?:[a-z0-9-]+\.)*other-domain\.com$',
          reasonCode: 'auth_yellow');
      await _open(tester, from: _spamFrom, suggestion: stale);
      expect(find.text('Suggested'), findsNothing);
      expect(find.byKey(const ValueKey('suggestion-note')), findsNothing);
    });
  });

  testWidgets(
      'a block Exact Domain suggestion does not light the safe Exact Domain '
      '(same value, different kind)', (tester) async {
    const value = '@mail.shop-example.com';
    final s = RuleSuggestion(
      kind: 'block',
      type: 'exactDomain',
      value: value,
      pattern: RuleQuickActionService.blockPatternFor('exactDomain', value)!,
      reasonCode: 'auth_yellow',
    );
    await _open(tester, from: _spamFrom, suggestion: s);
    expect(find.text('Suggested'), findsOneWidget);
    expect(_borderWidth(tester, 'Block Exact Domain'), 2);
    expect(_borderWidth(tester, 'Exact Domain'), 1);
  });

  group('AC-2: the tap saves exactly the shown rule', () {
    testWidgets('Block Entire Domain', (tester) async {
      final s = _yellow(_spamFrom);
      final requests = await _open(tester, from: _spamFrom, suggestion: s);
      final shown = tester
          .widget<Text>(find.byKey(const ValueKey('suggestion-pattern')))
          .data;
      await tester.tap(find.text('Block Entire Domain'));
      await tester.pumpAndSettle();
      // shop-example.com is not a provider, so no warning dialog opens.
      expect(requests, hasLength(1));
      expect(requests.single.kind, QuickActionKind.blockRule);
      expect(
          RuleQuickActionService.blockPatternFor(
              requests.single.type, requests.single.value),
          shown);
    });

    testWidgets('Block Email', (tester) async {
      const from = 'Some One <some.one@gmail.com>';
      final requests =
          await _open(tester, from: from, suggestion: _yellow(from));
      final shown = tester
          .widget<Text>(find.byKey(const ValueKey('suggestion-pattern')))
          .data;
      await tester.tap(find.text('Block Email'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(
          RuleQuickActionService.blockPatternFor(
              requests.single.type, requests.single.value),
          shown);
    });
  });

  // The Skip row of the pop-up overflows at 360 wide in the test font (Ahem is
  // wider than the real font) with or without a suggestion, so these tests
  // open the pop-up without Skip: they judge only what F306 adds.
  group('phone width (ADR-0042: Android and iOS use this widget)', () {
    const from = 'a@mail.long-company-name-for-testing.com';
    for (final size in const [Size(360, 800), Size(411, 900)]) {
      testWidgets('no overflow at ${size.width.toInt()} wide', (tester) async {
        await _open(tester,
            from: from, suggestion: _yellow(from), size: size, showSkip: false);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('suggestion-note')), findsOneWidget);
        final note =
            tester.getRect(find.byKey(const ValueKey('suggestion-note')));
        expect(note.left, greaterThanOrEqualTo(0));
        expect(note.right, lessThanOrEqualTo(size.width));
        // The regex is shown whole (wrapped, not cut off).
        expect(find.text(_yellow(from).pattern), findsOneWidget);
      });
    }
  });
}
