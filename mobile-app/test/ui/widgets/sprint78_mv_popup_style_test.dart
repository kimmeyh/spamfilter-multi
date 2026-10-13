/// Sprint 78 Manual Validation changes to the shared email pop-up and the
/// search field (Harold, 2026-10-12/13).
///
/// - MV-1: the subject line, the date/account row (icons included) and the
///   whole Skip button take the sender line's color, the theme's onSurface.
/// - MV-2: for a shared email-provider sender, the four DOMAIN actions are
///   dimmed to about half strength but stay tappable (the F47 "Proceed
///   Anyway" warning still opens); Exact Email and Block Email stay full.
/// - MV-4: the search field takes the theme's text colors instead of fixed
///   black, on both the Results and the Review screens.
///
/// The pop-up is shared by both screens, so one harness covers both
/// (ADR-0042: no platform branch exists in it).
///
/// SOURCE-TEXT VERIFIED: the last test reads the two screen files to prove
/// both use the shared [ResultSearchField]; the behavior itself is proven by
/// the widget tests above it.
///
/// What these tests do NOT catch: how the colors LOOK on a real display
/// (contrast is checked against the theme's own pairings, not measured), or
/// a third screen that builds its own search field.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/ui/widgets/email_detail_popup.dart';
import 'package:my_email_spam_filter/ui/widgets/result_list_pieces.dart';

EmailActionResult _result(String from) => EmailActionResult(
      email: EmailMessage(
        id: '1',
        from: from,
        subject: 'You have placed Order 38010630',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 7, 13, 8, 37),
        folderName: 'Bulk',
      ),
      action: EmailActionType.none,
      success: true,
    );

Future<void> _open(WidgetTester tester, String from) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, brightness: Brightness.dark),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showEmailDetailPopup(
            context,
            result: _result(from),
            effectiveEval: null,
            accountEmail: 'kimmeyharold@aol.com',
            showSkip: true,
            onQuickAction: (_, __, ___) {},
            onSkip: (_, __) {},
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Color? _textColor(WidgetTester tester, Finder f) =>
    tester.widget<Text>(f).style?.color;

Color? _iconColor(WidgetTester tester, IconData icon) => tester
    .widget<Icon>(find.byIcon(icon).last)
    .color;

void main() {
  group('MV-1: pop-up detail lines take the sender line color', () {
    testWidgets('subject line, date, account, their icons and Skip',
        (tester) async {
      await _open(tester, 'aishatulhumairataraba@gmail.com');
      final context = tester.element(find.text('Skip'));
      final onSurface = Theme.of(context).colorScheme.onSurface;

      // The sender line has no explicit color: it inherits onSurface.
      final senderStyle = DefaultTextStyle.of(
              tester.element(
                  find.text('aishatulhumairataraba@gmail.com').first))
          .style;
      expect(senderStyle.color, onSurface,
          reason: 'the reference color is what the sender line renders in');

      expect(
          _textColor(tester,
              find.text('Bulk • You have placed Order 38010630 • No rule')),
          onSurface);
      expect(_textColor(tester, find.text('2026-07-13 08:37')), onSurface);
      expect(_textColor(tester, find.text('kimmeyharold@aol.com')), onSurface);
      expect(_iconColor(tester, Icons.schedule), onSurface);
      expect(_iconColor(tester, Icons.account_circle_outlined), onSurface);
      expect(_textColor(tester, find.text('Skip')), onSurface);
      expect(_iconColor(tester, Icons.skip_next), onSurface);
      // Weights unchanged: Skip keeps w600, the subject line is not bold.
      expect(tester.widget<Text>(find.text('Skip')).style?.fontWeight,
          FontWeight.w600);
      expect(
          tester
              .widget<Text>(find
                  .text('Bulk • You have placed Order 38010630 • No rule'))
              .style
              ?.fontWeight,
          isNot(FontWeight.bold));
    });
  });

  group('MV-2: provider sender dims the four domain actions', () {
    const domainLabels = [
      'Exact Domain',
      'Entire Domain',
      'Block Exact Domain',
      'Block Entire Domain',
    ];

    testWidgets('gmail.com: domain actions at half strength, email actions full',
        (tester) async {
      await _open(tester, 'aishatulhumairataraba@gmail.com');
      for (final label in domainLabels) {
        expect(_textColor(tester, find.text(label))!.a, closeTo(0.5, 0.01),
            reason: '"$label" is dimmed for a provider sender');
      }
      expect(_textColor(tester, find.text('Exact Email')), Colors.green);
      expect(_textColor(tester, find.text('Block Email')), Colors.red);
    });

    testWidgets('a dimmed domain action still opens the provider warning',
        (tester) async {
      await _open(tester, 'aishatulhumairataraba@gmail.com');
      await tester.tap(find.text('Exact Domain'));
      await tester.pumpAndSettle();
      expect(find.text('Proceed Anyway'), findsOneWidget,
          reason: 'dimmed is a hint, not disabled (Harold: option 1)');
    });

    testWidgets('a non-provider sender keeps every action at full color',
        (tester) async {
      await _open(tester, 'offers@spam-example.com');
      expect(_textColor(tester, find.text('Exact Domain')), Colors.green);
      expect(_textColor(tester, find.text('Entire Domain')), Colors.green);
      expect(_textColor(tester, find.text('Block Exact Domain')), Colors.red);
      expect(_textColor(tester, find.text('Block Entire Domain')), Colors.red);
    });
  });

  group('MV-4: search field uses the theme text colors', () {
    testWidgets('dark theme: text onSurface, hint onSurfaceVariant',
        (tester) async {
      final scheme = ColorScheme.fromSeed(
          seedColor: Colors.blue, brightness: Brightness.dark);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, colorScheme: scheme),
        home: Scaffold(
          appBar: AppBar(
            title: ResultSearchField(
              controller: TextEditingController(),
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.color, scheme.onSurface);
      expect(field.decoration?.hintStyle?.color, scheme.onSurfaceVariant);
      expect(field.style?.color, isNot(Colors.black));
    });

    test('both screens use the shared search field (no fixed black text)', () {
      for (final path in [
        'lib/ui/screens/results_display_screen.dart',
        'lib/ui/screens/no_rule_review_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, contains('ResultSearchField('), reason: path);
        expect(src, isNot(contains("hintText: 'Search emails...'")),
            reason: '$path must not build its own search field');
      }
    });
  });
}
