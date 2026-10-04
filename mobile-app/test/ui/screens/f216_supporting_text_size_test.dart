/// Widget tests for F216 (Sprint 75): supporting text next to, or directly
/// below, a Material subtitle-level line must RENDER at the same font size
/// as that peer line, not one step smaller.
///
/// T-1 (AC-1): ResultsDisplayScreen's email action pop-up -- the date/domain
/// row must resolve to the same font size as the folder/subject/rule line
/// above it.
/// T-2 (AC-2): ManualRuleCreateScreen and RuleEditScreen -- the Examples
/// hint and the generated Type:/Phrase:/Source: lines must resolve to the
/// same font size as the RadioListTile subtitle beside them.
///
/// What these tests do NOT catch (per the card -- Manual Validation covers
/// the rest):
/// - Phone-width layout and dark-theme rendering: font SIZE is independent
///   of brightness, so neither theme nor window width is exercised here.
/// - Color/contrast: F210 already gates color pairing separately; these
///   tests read only `fontSize`.
/// - The confirm dialog's Type:/Phrase: pair in ManualRuleCreateScreen: it
///   received the identical literal style change as the generated-pattern
///   panel asserted below, but opening the dialog (which calls the
///   duplicate-check DB path) is not exercised here.
/// - The input field's FLOATING label: this card deliberately leaves it at
///   the Material default (see the comment on its InputDecoration) because
///   Flutter always paints the floated label through a fixed 0.75x scale
///   transform on top of whatever style resolves, so promoting it to
///   bodyMedium would render it SMALLER (14 x 0.75 = 10.5sp) than today's
///   default (16 x 0.75 = 12sp) -- the opposite of the intended fix.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/manual_rule_create_screen.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';
import 'package:my_email_spam_filter/ui/screens/rule_edit_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

/// Returns the font size [textFinder] actually PAINTS at.
///
/// `Text.style` alone is not enough: a RadioListTile subtitle Text carries
/// no explicit `style` at all -- it inherits Material's ListTile subtitle
/// default -- so the only way to compare it against a Text with an explicit
/// theme style is to read what both actually render through their
/// underlying RichText/RenderParagraph.
double? _renderedFontSize(WidgetTester tester, Finder textFinder) {
  final richText =
      find.descendant(of: textFinder, matching: find.byType(RichText)).first;
  final RenderParagraph paragraph =
      tester.renderObject<RenderParagraph>(richText);
  return paragraph.text.style?.fontSize;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('T-1 (AC-1): ResultsDisplayScreen popup date/domain row', () {
    late DatabaseTestHelper testHelper;
    const accountId = 'aol-user@aol.com';
    late int scanId;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      await testHelper.createTestAccount(accountId, platformId: 'aol');

      scanId = await testHelper.createTestScanResult(
        accountId,
        scanType: 'manual',
        scanMode: 'readonly',
        totalEmails: 1,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await testHelper.dbHelper.insertEmailActionBatch([
        {
          'scan_result_id': scanId,
          'email_id': '3001',
          'email_from': 'bad@spam.com',
          'email_subject': 'Win a prize',
          'email_received_date': now,
          'email_folder': 'INBOX',
          'action_type': 'none',
          'matched_rule_name': null,
          'matched_pattern': null,
          'is_safe_sender': 0,
          'success': 1,
        },
      ]);
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    Future<RuleSetProvider> buildRuleProvider() async {
      final provider = RuleSetProvider();
      provider.initializeForTesting(
        databaseStore: RuleDatabaseStore(testHelper.dbHelper),
        safeSenderStore: SafeSenderDatabaseStore(testHelper.dbHelper),
      );
      await provider.loadRules();
      await provider.loadSafeSenders();
      return provider;
    }

    Widget wrapScreen(
      RuleSetProvider ruleProvider,
      EmailScanProvider scanProvider,
    ) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<RuleSetProvider>.value(value: ruleProvider),
          ChangeNotifierProvider<EmailScanProvider>.value(value: scanProvider),
        ],
        child: MaterialApp(
          home: ResultsDisplayScreen(
            platformId: 'aol',
            platformDisplayName: 'AOL',
            accountId: accountId,
            accountEmail: accountId,
            historicalScanId: scanId,
          ),
        ),
      );
    }

    testWidgets(
        'the date and domain row resolves to the same font size as the '
        'folder/subject/rule line above it (F216 R-2/AC-1)', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late RuleSetProvider ruleProvider;
      await tester.runAsync(() async {
        ruleProvider = await buildRuleProvider();
        final scanProvider = EmailScanProvider();
        await mountAndLoadDbWidget(
            tester, wrapScreen(ruleProvider, scanProvider));
      });

      // Open the popup by tapping the seeded result row.
      await tester.tap(find.text('bad@spam.com'));
      await tester.pumpAndSettle();

      final popupFinder =
          find.byWidgetPredicate((w) => w is Material && w.elevation == 8);
      expect(popupFinder, findsOneWidget,
          reason: 'expected exactly one popup Material (elevation: 8)');

      // The subtitle line is the only Text in the popup containing the
      // ' • ' separator -- unique within the popup subtree.
      final subtitleFinder = find.descendant(
        of: popupFinder,
        matching: find.textContaining(' • '),
      );
      expect(subtitleFinder, findsOneWidget,
          reason: 'expected one folder/subject/rule subtitle line');
      final subtitleFontSize = _renderedFontSize(tester, subtitleFinder);
      expect(subtitleFontSize, isNotNull);

      // The date/domain Row carries the schedule icon; both the date Text
      // and (when a domain is present) the domain Text are its descendant
      // Texts, in that order.
      final dateRowFinder = find
          .ancestor(
            of: find.descendant(
                of: popupFinder, matching: find.byIcon(Icons.schedule)),
            matching: find.byType(Row),
          )
          .first;
      final rowTextFinders =
          find.descendant(of: dateRowFinder, matching: find.byType(Text));
      final dateTextFinder = rowTextFinders.at(0);
      final dateFontSize = _renderedFontSize(tester, dateTextFinder);

      expect(dateFontSize, equals(subtitleFontSize),
          reason: 'Harold, 2026-09-12 ("2. a"): the date must match the '
              'folder/subject/rule line, not stay a step smaller');

      // Domain Text is present because the seeded sender has a domain.
      final domainTextFinder = rowTextFinders.at(1);
      final domainFontSize = _renderedFontSize(tester, domainTextFinder);
      expect(domainFontSize, equals(subtitleFontSize),
          reason: 'the domain must match the folder/subject/rule line, '
              'the same decision as the date');
    });
  });

  group('T-2 (AC-2): ManualRuleCreateScreen Examples/Type/Source lines', () {
    testWidgets(
        'the Examples hint and the generated Type:/Source: lines resolve '
        'to the same font size as the Rule Type subtitle beside them',
        (tester) async {
      // Tall view: the input field sits below five RadioListTiles in a
      // ListView, which only builds visible children -- too-short a view
      // leaves it unbuilt and `enterText` cannot find an EditableTextState.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: ManualRuleCreateScreen(mode: ManualRuleMode.blockRule),
      ));
      await tester.pumpAndSettle();

      // Default selected type for a block rule is entireDomain -- its
      // RadioListTile subtitle is the peer these lines must match.
      final subtitleFinder =
          find.text(ManualRuleType.entireDomain.description);
      expect(subtitleFinder, findsOneWidget);
      final subtitleFontSize = _renderedFontSize(tester, subtitleFinder);
      expect(subtitleFontSize, isNotNull);

      final hintFinder =
          find.textContaining('Examples: spam@example.com, example.com,');
      expect(hintFinder, findsOneWidget);
      expect(_renderedFontSize(tester, hintFinder), equals(subtitleFontSize),
          reason: 'the Examples hint supports the field directly below it '
              'and must match the RadioListTile subtitles (F216 R-3/AC-2)');

      // Generate a pattern so the Type:/Source: lines appear.
      await tester.enterText(find.byType(TextFormField), 'spam.com');
      await tester.pumpAndSettle();

      final typeLineFinder = find.textContaining('Type: Entire Domain');
      expect(typeLineFinder, findsOneWidget);
      expect(_renderedFontSize(tester, typeLineFinder),
          equals(subtitleFontSize),
          reason: 'the generated Type: line must match the RadioListTile '
              'subtitles (F216 R-3/AC-2)');

      final sourceLineFinder = find.textContaining('Source: spam.com');
      expect(sourceLineFinder, findsOneWidget);
      expect(_renderedFontSize(tester, sourceLineFinder),
          equals(subtitleFontSize),
          reason: 'the generated Source: line must match the RadioListTile '
              'subtitles (F216 R-3/AC-2)');
    });
  });

  group('T-2 (AC-2): RuleEditScreen Examples/Type/Phrase lines', () {
    late DatabaseTestHelper testHelper;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    testWidgets(
        'the Examples hint and the Type:/Phrase: lines resolve to the '
        'same font size as the Rule Type subtitle beside them',
        (tester) async {
      final rule = Rule(
        name: 'manual_a_local_girl_12345',
        enabled: true,
        isLocal: true,
        executionOrder: 50,
        conditions: RuleConditions(type: 'OR', body: [r'a\ local\ girl']),
        actions: RuleActions(delete: true),
        patternCategory: 'body',
        patternSubType: 'keyword',
        sourceDomain: 'a local girl',
      );

      await tester.pumpWidget(MaterialApp(
        home: RuleEditScreen(
          rule: rule,
          store: RuleDatabaseStore(testHelper.dbHelper),
        ),
      ));
      await tester.pumpAndSettle();

      // A body rule reopens selected as Body Phrase (Sprint 64 regression
      // guard in rule_edit_screen_test.dart) -- its subtitle is the peer.
      final subtitleFinder =
          find.text(ManualRuleType.bodyPhrase.description);
      expect(subtitleFinder, findsOneWidget);
      final subtitleFontSize = _renderedFontSize(tester, subtitleFinder);
      expect(subtitleFontSize, isNotNull);

      final hintFinder = find.textContaining('Examples: click here to claim');
      expect(hintFinder, findsOneWidget);
      expect(_renderedFontSize(tester, hintFinder), equals(subtitleFontSize),
          reason: 'the Examples hint must match the RadioListTile '
              'subtitles, consistent with ManualRuleCreateScreen '
              '(F216 AC-2)');

      final typeLineFinder = find.textContaining('Type: Body Phrase');
      expect(typeLineFinder, findsOneWidget);
      expect(_renderedFontSize(tester, typeLineFinder),
          equals(subtitleFontSize),
          reason: 'the Type: line must match the RadioListTile subtitles '
              '(F216 R-3/AC-2)');

      final phraseLineFinder = find.textContaining('Phrase: a local girl');
      expect(phraseLineFinder, findsOneWidget);
      expect(_renderedFontSize(tester, phraseLineFinder),
          equals(subtitleFontSize),
          reason: 'the Phrase: line must match the RadioListTile subtitles '
              '(F216 R-3/AC-2)');
    });
  });
}
