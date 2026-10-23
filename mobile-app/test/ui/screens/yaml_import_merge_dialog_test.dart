/// F269 (Sprint 80, #499): the import confirmation dialog offers Merge
/// (pre-selected) and Replace.
///
/// What these tests do NOT catch: that the SCREEN passes the chosen mode on to
/// the right commit function (the screen is not pumped; the source gate in
/// test/unit/services/yaml_import_merge_test.dart covers the wiring), and how
/// the dialog looks on a phone-width layout in dark mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/yaml_import_export_screen.dart';

Future<void> _open(WidgetTester tester,
    {List<String> skipped = const []}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showDialog<YamlImportMode>(
            context: context,
            builder: (_) => YamlImportConfirmDialog(
              title: 'Import Rules',
              itemCount: 3,
              itemType: 'rules',
              displayPath: '.../Harold/rules.yaml',
              skipped: skipped,
              droppedText: '1 pattern',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AC-4: Merge is pre-selected when the dialog opens',
      (tester) async {
    await _open(tester);

    final seg = tester.widget<SegmentedButton<YamlImportMode>>(
        find.byType(SegmentedButton<YamlImportMode>));
    expect(seg.selected, {YamlImportMode.merge});
    expect(find.text('Merge 3 rules'), findsOneWidget);
    expect(find.textContaining('Nothing you have now is changed'), findsOneWidget);
    expect(find.textContaining('replace ALL'), findsNothing);
  });

  testWidgets('pressing the confirm button right away returns Merge',
      (tester) async {
    YamlImportMode? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => got = await showDialog<YamlImportMode>(
            context: context,
            builder: (_) => const YamlImportConfirmDialog(
              title: 'Import Rules',
              itemCount: 3,
              itemType: 'rules',
              displayPath: 'rules.yaml',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge 3 rules'));
    await tester.pumpAndSettle();
    expect(got, YamlImportMode.merge);
  });

  testWidgets('choosing Replace shows the old warning and returns Replace',
      (tester) async {
    YamlImportMode? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => got = await showDialog<YamlImportMode>(
            context: context,
            builder: (_) => const YamlImportConfirmDialog(
              title: 'Import Rules',
              itemCount: 3,
              itemType: 'rules',
              displayPath: 'rules.yaml',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(
        find.text('This will replace ALL existing rules with 3 rules from the '
            'selected file.'),
        findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.text('Replace with 3 rules'));
    await tester.pumpAndSettle();
    expect(got, YamlImportMode.replace);
  });

  testWidgets('Cancel returns null', (tester) async {
    YamlImportMode? got = YamlImportMode.merge;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => got = await showDialog<YamlImportMode>(
            context: context,
            builder: (_) => const YamlImportConfirmDialog(
              title: 'Import Rules',
              itemCount: 3,
              itemType: 'rules',
              displayPath: 'rules.yaml',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('the F266 skipped list still shows in the dialog', (tester) async {
    await _open(tester, skipped: ['Rule "x": pattern "a@b@c" can never match']);
    expect(find.textContaining('Skipped 1 pattern'), findsOneWidget);
    expect(find.textContaining('can never match'), findsWidgets);
  });
}
