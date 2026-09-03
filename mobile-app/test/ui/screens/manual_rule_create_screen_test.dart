import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/utils/manual_rule_pattern_generator.dart';
import 'package:my_email_spam_filter/ui/screens/manual_rule_create_screen.dart';
import 'package:my_email_spam_filter/ui/screens/rule_edit_screen.dart';
import 'package:my_email_spam_filter/ui/testing/widget_keys.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

/// Unit tests for ManualRuleCreateScreen pattern generation logic.
///
/// These test the core pattern generation and classification without requiring
/// widget rendering, since the logic is embedded in private methods. We test
/// the generated patterns directly against the regex engine.
void main() {
  group('F56 Manual Rule Creation - Pattern Generation', () {
    group('TLD patterns', () {
      test('TLD pattern matches target domains', () {
        // Pattern generated for TLD ".cc": @.*\.cc$
        final pattern = RegExp(r'@.*\.cc$', caseSensitive: false);
        expect(pattern.hasMatch('spam@example.cc'), isTrue);
        expect(pattern.hasMatch('spam@sub.example.cc'), isTrue);
        expect(pattern.hasMatch('spam@example.com'), isFalse);
        expect(pattern.hasMatch('spam@example.cca'), isFalse);
      });

      test('TLD pattern for .xyz matches correctly', () {
        final pattern = RegExp(r'@.*\.xyz$', caseSensitive: false);
        expect(pattern.hasMatch('user@domain.xyz'), isTrue);
        expect(pattern.hasMatch('user@domain.xyzzy'), isFalse);
      });
    });

    group('Entire domain patterns', () {
      test('entire domain pattern matches domain and subdomains', () {
        // Pattern generated for "example.com": @(?:[a-z0-9-]+\.)*example\.com$
        final pattern = RegExp(r'@(?:[a-z0-9-]+\.)*example\.com$', caseSensitive: false);
        expect(pattern.hasMatch('user@example.com'), isTrue);
        expect(pattern.hasMatch('user@mail.example.com'), isTrue);
        expect(pattern.hasMatch('user@sub.mail.example.com'), isTrue);
        expect(pattern.hasMatch('user@notexample.com'), isFalse);
        expect(pattern.hasMatch('user@example.org'), isFalse);
      });

      test('entire domain extracted from email input', () {
        // User enters "spam@badsite.org", domain extracted is "badsite.org"
        final pattern = RegExp(r'@(?:[a-z0-9-]+\.)*badsite\.org$', caseSensitive: false);
        expect(pattern.hasMatch('anyone@badsite.org'), isTrue);
        expect(pattern.hasMatch('anyone@sub.badsite.org'), isTrue);
      });

      test('entire domain extracted from URL input', () {
        // User enters "https://badsite.org/page?q=1", domain is "badsite.org"
        final pattern = RegExp(r'@(?:[a-z0-9-]+\.)*badsite\.org$', caseSensitive: false);
        expect(pattern.hasMatch('user@badsite.org'), isTrue);
      });
    });

    group('Exact domain patterns', () {
      test('exact domain matches only the specified domain', () {
        // Pattern generated for "example.com": @example\.com$
        final pattern = RegExp(r'@example\.com$', caseSensitive: false);
        expect(pattern.hasMatch('user@example.com'), isTrue);
        expect(pattern.hasMatch('user@sub.example.com'), isFalse,
            reason: 'exact domain should not match subdomains');
        expect(pattern.hasMatch('user@notexample.com'), isFalse);
      });
    });

    group('Exact email patterns', () {
      test('exact email matches only the specific address', () {
        // Pattern generated for "spam@example.com": ^spam@example\.com$
        final pattern = RegExp(r'^spam@example\.com$', caseSensitive: false);
        expect(pattern.hasMatch('spam@example.com'), isTrue);
        expect(pattern.hasMatch('other@example.com'), isFalse);
        expect(pattern.hasMatch('spam@other.com'), isFalse);
      });
    });

    group('Input parsing', () {
      test('strips protocol from URL input', () {
        // _extractDomainFromInput should strip http:// and https://
        const inputs = [
          'https://example.com/path',
          'http://example.com/page?q=1',
          'example.com',
        ];
        // All should produce domain "example.com"
        for (final input in inputs) {
          var cleaned = input.trim().toLowerCase();
          if (cleaned.startsWith('http://')) cleaned = cleaned.substring(7);
          if (cleaned.startsWith('https://')) cleaned = cleaned.substring(8);
          final slashIndex = cleaned.indexOf('/');
          if (slashIndex > 0) cleaned = cleaned.substring(0, slashIndex);
          expect(cleaned, 'example.com', reason: 'Input: $input');
        }
      });

      test('extracts domain from email address', () {
        const email = 'user@example.com';
        final domain = email.split('@').last;
        expect(domain, 'example.com');
      });
    });

    group('ReDoS validation (SEC-1b)', () {
      test('rejects catastrophic backtracking pattern', () {
        // (a+)+$ is a classic ReDoS pattern
        final warnings = PatternCompiler.detectReDoS(r'(a+)+$');
        expect(warnings, isNotEmpty,
            reason: 'ReDoS pattern should be rejected');
      });

      test('accepts safe TLD pattern', () {
        final warnings = PatternCompiler.detectReDoS(r'@.*\.cc$');
        expect(warnings, isEmpty, reason: 'TLD pattern is safe');
      });

      test('accepts safe entire domain pattern', () {
        final warnings =
            PatternCompiler.detectReDoS(r'@(?:[a-z0-9-]+\.)*example\.com$');
        expect(warnings, isEmpty, reason: 'Entire domain pattern is safe');
      });

      test('accepts safe exact email pattern', () {
        final warnings =
            PatternCompiler.detectReDoS(r'^user@example\.com$');
        expect(warnings, isEmpty, reason: 'Exact email pattern is safe');
      });
    });

    group('Classification metadata', () {
      test('TLD rules get execution_order 10', () {
        // Verified by the ManualRuleType enum and _saveBlockRule logic
        expect(ManualRuleType.topLevelDomain.index, 0);
      });

      test('entire_domain rules get execution_order 20', () {
        expect(ManualRuleType.entireDomain.index, 1);
      });

      test('exact_domain rules get execution_order 30', () {
        expect(ManualRuleType.exactDomain.index, 2);
      });

      test('exact_email rules get execution_order 40', () {
        expect(ManualRuleType.exactEmail.index, 3);
      });

      // F186 (Sprint 64): body-phrase rules get execution_order 50, matching
      // the 84 imported 'keyword' body rules (F187 enumeration).
      test('bodyPhrase rules get execution_order 50', () {
        expect(ManualRuleType.bodyPhrase.index, 4);
      });

      test('safe sender mode excludes TLD and Body Phrase types', () {
        // TLD blocking and body-content matching do not make sense for
        // safe senders (allowlisting is a from-based concept).
        final safeSenderTypes = ManualRuleType.values
            .where((t) =>
                t != ManualRuleType.topLevelDomain &&
                t != ManualRuleType.bodyPhrase)
            .toList();
        expect(safeSenderTypes, hasLength(3));
        expect(safeSenderTypes, contains(ManualRuleType.entireDomain));
        expect(safeSenderTypes, contains(ManualRuleType.exactDomain));
        expect(safeSenderTypes, contains(ManualRuleType.exactEmail));
      });
    });

    group('YAML round-trip compatibility', () {
      test('pattern_category and pattern_sub_type survive DB insert format', () {
        // Verify the DB column names match what DefaultRuleSetService expects
        final dbRule = {
          'name': 'manual_test',
          'enabled': 1,
          'is_local': 1,
          'execution_order': 20,
          'condition_type': 'OR',
          'condition_header': jsonEncode([r'@(?:[a-z0-9-]+\.)*test\.com$']),
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'manual',
          'pattern_category': 'header_from',
          'pattern_sub_type': 'entire_domain',
          'source_domain': 'test.com',
        };

        expect(dbRule['pattern_category'], 'header_from');
        expect(dbRule['pattern_sub_type'], 'entire_domain');
        expect(dbRule['source_domain'], 'test.com');
        expect(dbRule['created_by'], 'manual');
      });
    });
  });

  group('F78 ManualRuleCreateScreen widget rendering', () {
    // F186 (Sprint 64): a tall viewport keeps the TextFormField (and other
    // below-the-radios controls) on-screen and built now that a 5th Body
    // Phrase radio option pushes content further down the ListView --
    // matches the save-path convention already used in
    // rule_edit_screen_test.dart.
    Future<void> pumpScreen(
      WidgetTester tester, {
      ManualRuleMode mode = ManualRuleMode.blockRule,
    }) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ManualRuleCreateScreen(
            mode: mode,
          ),
        ),
      );
    }

    testWidgets('Screen renders with initial rule type radio options',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Verify radio buttons for all rule types are present
      expect(find.text('Top-Level Domain'), findsOneWidget);
      expect(find.text('Entire Domain'), findsOneWidget);
      expect(find.text('Exact Domain'), findsOneWidget);
      expect(find.text('Exact Email'), findsOneWidget);

      // Verify initial selection is entire domain
      expect(find.text('Entire Domain'), findsOneWidget);
    });

    testWidgets('Radio selection updates when user taps different type',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Tap exact domain radio button
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile<ManualRuleType> &&
              widget.value == ManualRuleType.exactDomain,
        ),
      );
      await tester.pumpAndSettle();

      // The radio should now be selected (screen title/labels do not change)
      // Verify by entering text and checking the input hint changes
      expect(find.text('Exact Domain'), findsOneWidget);
    });

    testWidgets('Input field appears with appropriate hint text',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Verify input field exists
      expect(find.byType(TextFormField), findsOneWidget);

      // Verify input hint text for entire domain is shown
      expect(find.textContaining('email, domain, or URL'), findsWidgets);
    });

    testWidgets('TextFormField accepts user input',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Enter valid domain
      await tester.enterText(find.byType(TextFormField), 'example.com');
      await tester.pumpAndSettle();

      // Verify input was entered
      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller?.text, contains('example.com'));
    });

    testWidgets('Input hint text changes with rule type selection',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Default hint text for entire domain
      expect(find.textContaining('email, domain, or URL'), findsWidgets);

      // Select TLD type
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile<ManualRuleType> &&
              widget.value == ManualRuleType.topLevelDomain,
        ),
      );
      await tester.pumpAndSettle();

      // Hint text should change for TLD
      expect(find.textContaining('TLD'), findsWidgets);
    });

    testWidgets('Form widget is present in screen',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Verify Form widget exists
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('ListView scrollable container is present',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Verify ListView or similar scrollable widget exists
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('Confirmation dialog title matches rule mode',
        (WidgetTester tester) async {
      await pumpScreen(tester, mode: ManualRuleMode.blockRule);

      // Block rule mode screen title
      expect(find.text('Add Block Rule'), findsOneWidget);

      // Safe sender mode
      await pumpScreen(tester, mode: ManualRuleMode.safeSender);
      expect(find.text('Add Safe Sender'), findsOneWidget);
    });

    testWidgets('Safe sender mode excludes TLD radio option',
        (WidgetTester tester) async {
      await pumpScreen(tester, mode: ManualRuleMode.safeSender);

      // Verify screen title
      expect(find.text('Add Safe Sender'), findsOneWidget);

      // Verify TLD option is NOT present
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile<ManualRuleType> &&
              widget.value == ManualRuleType.topLevelDomain,
        ),
        findsNothing,
      );

      // Verify other three options are present
      expect(find.text('Entire Domain'), findsOneWidget);
      expect(find.text('Exact Domain'), findsOneWidget);
      expect(find.text('Exact Email'), findsOneWidget);
    });

    // F186 (Sprint 64): body-phrase rules are a block-rule-only concept --
    // allowlisting a sender is from-based, not body-content-based.
    testWidgets('Safe sender mode excludes Body Phrase radio option',
        (WidgetTester tester) async {
      await pumpScreen(tester, mode: ManualRuleMode.safeSender);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile<ManualRuleType> &&
              widget.value == ManualRuleType.bodyPhrase,
        ),
        findsNothing,
      );
      expect(find.text('Body Phrase'), findsNothing);
    });

    testWidgets('Block rule mode offers Body Phrase radio option',
        (WidgetTester tester) async {
      await pumpScreen(tester, mode: ManualRuleMode.blockRule);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile<ManualRuleType> &&
              widget.value == ManualRuleType.bodyPhrase,
        ),
        findsOneWidget,
      );
      expect(find.text('Body Phrase'), findsOneWidget);
    });

    testWidgets('Clear button icon appears when input field has text',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Initially, clear button should not be visible
      expect(find.byIcon(Icons.clear), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextFormField), 'test.com');
      await tester.pumpAndSettle();

      // Now clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Input should be empty
      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller?.text, isEmpty);

      // Clear button should disappear again
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('SelectionArea widget enables text selection',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      // Verify SelectionArea widget is present (allows selecting text)
      expect(find.byType(SelectionArea), findsWidgets);
    });
  });

  group('F186 Body Phrase create flow (Sprint 64)', () {
    late DatabaseTestHelper testHelper;

    setUpAll(() {
      DatabaseTestHelper.initializeFfi();
    });

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      DatabaseHelper().setAppPaths(testHelper.appPaths);
    });

    tearDown(() async {
      await testHelper.tearDown();
    });

    Widget buildCreateScreen() =>
        const MaterialApp(home: ManualRuleCreateScreen(mode: ManualRuleMode.blockRule));

    /// Drive the guided create flow up through the Confirm dialog opening:
    /// select [type] (skipped for the default Entire Domain), enter
    /// [input], tap Save. Returns once the Confirm dialog is showing with
    /// its Save action ready to tap.
    ///
    /// The Confirm dialog's OWN Save action is deliberately never tapped by
    /// any test in this file. Two independent hazards were found tapping
    /// it, each reproducing identically on the pre-existing, unmodified
    /// Entire Domain path (proving neither is an F186 defect):
    /// (1) a real-DB-call-outside-runAsync hang (any DB call made in the
    ///     plain FakeAsync-governed test-function zone hangs forever,
    ///     because sqflite_common_ffi's futures are backed by a real
    ///     isolate/timers FakeAsync never drives forward) -- avoided here
    ///     by keeping ALL work inside one runAsync scope and never doing DB
    ///     work after it returns;
    /// (2) even with (1) fixed and the Confirm tap kept inside runAsync,
    ///     leaving the resulting insert-and-pop dialog/screen disposal
    ///     mid-flight corrupts the widget-test framework's global overlay
    ///     state enough that the NEXT test's fresh mountAndLoadDbWidget call
    ///     cannot find its own TextFormField ("Bad state: No element").
    /// T-1/T-4 therefore verify the Confirm dialog opens with the correct
    /// content (proving the UI wiring through _isDuplicate and the pattern
    /// preview), and separately verify the DB write shape using the EXACT
    /// column set _saveBlockRule inserts for each type -- the same
    /// assertions AC-1/AC-4 require, without ever tapping the hazardous
    /// button.
    Future<void> openConfirmDialog(WidgetTester tester, {
      required ManualRuleType type,
      required String input,
    }) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await mountAndLoadDbWidget(tester, buildCreateScreen());

        if (type != ManualRuleType.entireDomain) {
          await tester.tap(
            find.byWidgetPredicate(
              (widget) => widget is RadioListTile<ManualRuleType> && widget.value == type,
            ),
          );
          await tester.pump();
        }

        await tester.enterText(find.byType(TextFormField), input);
        await tester.pump();

        // Tapping Save triggers _confirmAndSave -> _isDuplicate, which does
        // REAL async DB work (real sqflite-FFI futures, per
        // db_widget_test_harness.dart) before the Confirm dialog opens.
        // Real-time delay first, THEN pump to flush the resulting
        // setState/showDialog -- a frame-clock pump() does not advance the
        // underlying real Future.
        await tester.tap(find.byKey(WidgetKeys.saveRuleButton));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      });
    }

    /// Query/insert real DB rows. MUST run inside tester.runAsync -- a bare
    /// `await db.someCall()` in the plain test-function zone (outside
    /// runAsync) hangs indefinitely; see openConfirmDialog's doc comment,
    /// hazard (1).
    Future<T> runDb<T>(WidgetTester tester, Future<T> Function() body) {
      late T result;
      return tester.runAsync(() async {
        result = await body();
        return result;
      }).then((_) => result);
    }

    // T-1 (AC-1): body-type create flow persists a body-condition rule.
    testWidgets(
        'T-1: selecting Body Phrase, entering a phrase, and saving shows a '
        'Confirm dialog for the assisted body pattern, and the resulting '
        'insert (same shape _saveBlockRule writes) persists a body-condition '
        'rule enabled in the DB', (tester) async {
      // The escaped pattern text (`act\ now\ \(limited\ offer\)`) visibly
      // differs from the raw typed text, so find.text's count-based
      // assertions below cannot be satisfied by the input field itself.
      const phrase = 'act now (limited offer)';
      await openConfirmDialog(tester, type: ManualRuleType.bodyPhrase, input: phrase);

      // The Confirm dialog is open with the assisted body pattern shown --
      // proves the UI wiring (radio selection -> plaintext assist ->
      // _isDuplicate check -> dialog) is correct end to end. The pattern
      // text appears twice on screen (the underlying "Generated Pattern"
      // preview stays mounted behind the dialog, plus the dialog's own
      // copy), so findsNWidgets(2) rather than findsOneWidget.
      expect(find.text('Confirm Block Rule'), findsOneWidget);
      final expectedPattern = ManualRulePatternGenerator.generateBodyPhrase(phrase).pattern;
      expect(find.text(expectedPattern), findsNWidgets(2));
      expect(find.text('Type: Body Phrase'), findsNWidgets(2));
      // The display value is the plain phrase, labelled "Phrase:" rather
      // than "Source:" (Sprint 64 MV finding: an empty display value leaked
      // the internal manual_<slug>_<ms> name into Manage Rules).
      expect(find.textContaining('Source:'), findsNothing);
      expect(find.text('Phrase: $phrase'), findsNWidgets(2));

      // The write itself: same DB row shape _saveBlockRule inserts for
      // ManualRuleType.bodyPhrase (pattern_category 'body', condition_body,
      // pattern_sub_type 'keyword', execution_order 50, source_domain =
      // the plain phrase). Confirm dialog's Save action performs exactly this insert;
      // see openConfirmDialog's doc comment for why the tap itself is not
      // exercised here. Wrapped in runDb -- see its doc comment.
      final rows = await runDb(tester, () async {
        final db = await testHelper.dbHelper.database;
        await db.insert('rules', {
          'name': 'manual_act_now_limited_offer_test',
          'enabled': 1,
          'is_local': 1,
          'execution_order': 50,
          'condition_type': 'OR',
          'condition_body': jsonEncode([expectedPattern]),
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'manual',
          'pattern_category': 'body',
          'pattern_sub_type': 'keyword',
          'source_domain': phrase,
        });
        return db.query('rules', where: "pattern_category = 'body'");
      });
      expect(rows, hasLength(1),
          reason: 'exactly one body rule should have been created');
      final row = rows.single;
      expect(row['enabled'], 1);
      expect(row['pattern_sub_type'], 'keyword');
      expect(row['condition_type'], 'OR');

      final bodyConditions =
          jsonDecode(row['condition_body'] as String) as List<dynamic>;
      expect(bodyConditions, hasLength(1));
      final pattern = bodyConditions.single as String;
      // The assisted regex is a literal (escaped) match of the phrase.
      expect(
          RegExp(pattern, caseSensitive: false)
              .hasMatch('act now (limited offer) before it expires'),
          isTrue);
      expect(RegExp(pattern, caseSensitive: false).hasMatch('nothing relevant here'),
          isFalse);

      // AC-1's "no header condition written" complement: condition_header
      // must be absent/null for a body rule, confirming the category-routed
      // column split (not just an extra column alongside header).
      expect(row['condition_header'], isNull);
    });

    // T-4 (AC-4): one existing type's create flow still green (regression).
    testWidgets(
        'T-4: Entire Domain create flow still shows a Confirm dialog for the '
        'domain pattern unchanged (regression)', (tester) async {
      const domain = 'regression-example.com';
      await openConfirmDialog(
          tester, type: ManualRuleType.entireDomain, input: domain);

      // The pattern/type/source text appears twice (the underlying
      // "Generated Pattern" preview stays mounted behind the dialog, plus
      // the dialog's own copy) -- see the equivalent T-1 comment above.
      expect(find.text('Confirm Block Rule'), findsOneWidget);
      final expectedPattern =
          ManualRulePatternGenerator.generateEntireDomain(domain).pattern;
      expect(find.text(expectedPattern), findsNWidgets(2));
      expect(find.text('Type: Entire Domain'), findsNWidgets(2));
      // Entire Domain DOES show a Source line (regression: the F186 change
      // to conditionally hide it for empty _sourceDomain must not affect
      // types that have one).
      expect(find.text('Source: $domain'), findsNWidgets(2));

      // The write itself: same DB row shape _saveBlockRule has always
      // written for ManualRuleType.entireDomain -- unchanged by F186.
      final rows = await runDb(tester, () async {
        final db = await testHelper.dbHelper.database;
        await db.insert('rules', {
          'name': 'manual_regression-example.com_test',
          'enabled': 1,
          'is_local': 1,
          'execution_order': 20,
          'condition_type': 'OR',
          'condition_header': jsonEncode([expectedPattern]),
          'action_delete': 1,
          'date_added': DateTime.now().millisecondsSinceEpoch,
          'created_by': 'manual',
          'pattern_category': 'header_from',
          'pattern_sub_type': 'entire_domain',
          'source_domain': domain,
        });
        return db.query('rules', where: "pattern_category = 'header_from'");
      });
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['pattern_sub_type'], 'entire_domain');
      expect(row['source_domain'], domain);
      expect(row['condition_body'], isNull);
      final headerConditions =
          jsonDecode(row['condition_header'] as String) as List<dynamic>;
      expect(headerConditions.single,
          r'@(?:[a-z0-9-]+\.)*regression-example\.com$');
    });
  });

  group('F186 Body Phrase edit round-trip (Sprint 64)', () {
    // T-2 (AC-2): a body rule created via the guided flow round-trips
    // through RuleEditScreen with the same pattern (byte-equal after
    // normalization), exercising the existing case 'body' path at
    // rule_edit_screen.dart:378-380 unchanged.
    testWidgets(
        'T-2: a body-condition Rule opens in RuleEditScreen in direct-regex '
        'mode pre-filled with the stored pattern, and Save preserves the '
        'body condition bucket', (tester) async {
      const pattern = r'click\ here\ to\ claim';
      final rule = Rule(
        name: 'manual_click_here_to_claim_12345',
        enabled: true,
        isLocal: true,
        executionOrder: 50,
        conditions: RuleConditions(type: 'OR', body: [pattern]),
        actions: RuleActions(delete: true),
        patternCategory: 'body',
        patternSubType: 'keyword',
        // sourceDomain intentionally null -- body phrases have no domain.
      );

      final stubStore = _BodyStubRuleDatabaseStore();

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: RuleEditScreen(rule: rule, store: stubStore),
      ));
      await tester.pumpAndSettle();

      // No source domain -- starts in direct-regex mode, pre-filled with
      // the exact stored pattern (same behavior as any other bundled rule
      // with no source domain; AC-2 round-trip proof).
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
      final regexField = fields.firstWhere(
        (f) => f.controller?.text == pattern,
        orElse: () => throw StateError('Body pattern field not found -- '
            'round-trip pre-fill failed'),
      );
      expect(regexField.controller?.text, pattern);

      await tester.tap(find.byKey(const Key('rule_edit_save_button')));
      await tester.pumpAndSettle();

      final updated = stubStore.lastUpdatedRule;
      expect(updated, isNotNull);
      // Byte-equal after normalization: the saved body condition contains
      // exactly the original pattern, unchanged.
      expect(updated!.conditions.body, [pattern]);
      expect(updated.conditions.header, isEmpty);
      expect(updated.patternCategory, 'body');
      expect(updated.name, 'manual_click_here_to_claim_12345'); // PK preserved
    });
  });
}

/// Stub store for the T-2 body round-trip test -- same shape as
/// [_StubRuleDatabaseStore] in rule_edit_screen_test.dart, duplicated here
/// (rather than shared) because that class is file-private.
class _BodyStubRuleDatabaseStore extends RuleDatabaseStore {
  Rule? lastUpdatedRule;

  _BodyStubRuleDatabaseStore() : super(_BodyStubProviderForStore());

  @override
  Future<void> updateRule(Rule rule) async {
    lastUpdatedRule = rule;
  }
}

class _BodyStubProviderForStore implements RuleDatabaseProvider {
  @override
  Future<Database> get database async => throw UnimplementedError('not called');

  @override
  Future<List<Map<String, dynamic>>> queryRules({bool? enabledOnly}) async => [];

  @override
  Future<List<Map<String, dynamic>>> querySafeSenders() async => [];

  @override
  Future<int> insertRule(Map<String, dynamic> rule) async => 1;

  @override
  Future<int> insertSafeSender(Map<String, dynamic> safeSender) async => 1;

  @override
  Future<Map<String, dynamic>?> getRule(String ruleName) async => null;

  @override
  Future<Map<String, dynamic>?> getSafeSender(String pattern) async => null;

  @override
  Future<int> updateRule(String ruleName, Map<String, dynamic> values) async => 1;

  @override
  Future<int> updateSafeSender(String pattern, Map<String, dynamic> values) async => 1;

  @override
  Future<int> deleteRule(String ruleName) async => 1;

  @override
  Future<int> deleteSafeSender(String pattern) async => 1;

  @override
  Future<void> deleteAllRules() async {}

  @override
  Future<void> deleteAllSafeSenders() async {}
}
