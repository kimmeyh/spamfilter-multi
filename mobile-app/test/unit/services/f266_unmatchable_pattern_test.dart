/// F266 (Sprint 77): patterns that can never match an email address.
///
/// 23 of 426 bundled safe-sender patterns carried a stray second literal `@`
/// after the domain wildcard, so those senders were not protected. Covers the
/// shared check ([PatternCompiler.detectUnmatchable]), the bundled assets, the
/// import sanitizers, the persistence boundaries, and the real v12 -> v13
/// database upgrade.
///
/// What these tests do NOT catch (one line each):
///   - detector: other impossible shapes (anchor in the wrong place, a class
///     excluding what the pattern requires, contradictory lookaheads) pass the
///     check by design;
///   - assets: a bundled pattern that is matchable but wrong (matches the
///     wrong domain) passes; the representative-address test covers only the
///     23 repaired entries;
///   - screens: the five UI call sites are not widget-tested here; they are
///     one-line calls to the shared check, covered by the store and unit tests
///     and by Manual Validation;
///   - migration: a production database with patterns of a shape other than
///     the shipped one is left alone by design (deterministic single shape).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/services/yaml_service.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/database_test_helper.dart';

const _broken = r'^[^@\s]+@(?:[a-z0-9-]+\.)*@banking\.jpmchase\.com$';
const _fixed = r'^[^@\s]+@(?:[a-z0-9-]+\.)*banking\.jpmchase\.com$';

List<String> _yamlListEntries(String path) => File(path)
    .readAsLinesSync()
    .where((l) => l.startsWith("- '") && l.endsWith("'"))
    .map((l) => l.substring(3, l.length - 1))
    .toList();

void main() {
  setUpAll(() => DatabaseTestHelper.initializeFfi());

  group('detectUnmatchable', () {
    test('flags the shipped shape: stray @ after the domain wildcard', () {
      expect(PatternCompiler.detectUnmatchable(_broken), isNotEmpty);
    });

    test('flags two plain literal @ and an escaped \\@', () {
      expect(PatternCompiler.detectUnmatchable(r'^a@b@c\.com$'), isNotEmpty);
      expect(PatternCompiler.detectUnmatchable(r'^a\@b@c\.com$'), isNotEmpty);
    });

    test('does NOT count the @ inside a character class', () {
      expect(PatternCompiler.detectUnmatchable(_fixed), isEmpty);
      expect(PatternCompiler.detectUnmatchable(r'^[^@\s]+@spam\.com$'),
          isEmpty);
      expect(PatternCompiler.detectUnmatchable(r'^[a@]+@spam\.com$'), isEmpty);
    });

    test('legal multi-@ shapes pass: alternation, optional parts, lookaround',
        () {
      expect(
          PatternCompiler.detectUnmatchable(r'^(a@b\.com|c@d\.com)$'),
          isEmpty,
          reason: 'each branch has one @');
      expect(PatternCompiler.detectUnmatchable(r'^a@b\.com|c@d@e\.com$'),
          isEmpty,
          reason: 'the cheapest top-level branch has one @');
      expect(PatternCompiler.detectUnmatchable(r'^a@(?:b@)?c\.com$'), isEmpty,
          reason: 'an optional group counts 0');
      expect(PatternCompiler.detectUnmatchable(r'^a@b@?c\.com$'), isEmpty);
      expect(PatternCompiler.detectUnmatchable(r'^a@(?=.*@)c\.com$'), isEmpty,
          reason: 'a lookahead consumes nothing');
    });

    test('repeats are counted: (@){2} and (@)+(@) need two', () {
      expect(PatternCompiler.detectUnmatchable(r'^a(?:@){2}c$'), isNotEmpty);
      expect(PatternCompiler.detectUnmatchable(r'^a(?:@)+@c$'), isNotEmpty);
    });

    test('never throws on malformed input and does not flag it', () {
      for (final p in ['(((', '[', r'\', 'a{', '(?<n', ')@@', '']) {
        expect(() => PatternCompiler.detectUnmatchable(p), returnsNormally,
            reason: p);
      }
      expect(PatternCompiler.detectUnmatchable('['), isEmpty);
    });

    test('validatePattern adds the warning only for address fields', () {
      final compiler = PatternCompiler();
      expect(compiler.validatePattern(_broken, addressField: true),
          isNotEmpty);
      expect(compiler.validatePattern(_broken), isEmpty,
          reason: 'subject and body patterns may contain two @');
    });
  });

  group('repairStrayAtAfterDomainWildcard', () {
    test('removes only the second @ and the result is matchable', () {
      expect(PatternCompiler.repairStrayAtAfterDomainWildcard(_broken), _fixed);
      final re = RegExp(_fixed, caseSensitive: false);
      expect(re.hasMatch('alerts@banking.jpmchase.com'), isTrue);
      expect(re.hasMatch('alerts@mail.banking.jpmchase.com'), isTrue);
    });

    test('leaves matchable and differently shaped patterns alone', () {
      expect(PatternCompiler.repairStrayAtAfterDomainWildcard(_fixed), isNull);
      expect(PatternCompiler.repairStrayAtAfterDomainWildcard(r'^a@b@c$'),
          isNull,
          reason: 'unmatchable but not the shipped shape: not rewritten');
    });
  });

  group('bundled assets', () {
    final safeSenders =
        _yamlListEntries('assets/rules/rules_safe_senders.yaml');

    test('every bundled safe-sender pattern passes the check', () {
      expect(safeSenders.length, greaterThan(400));
      final bad = safeSenders
          .where((p) => PatternCompiler.detectUnmatchable(p).isNotEmpty)
          .toList();
      expect(bad, isEmpty);
    });

    test('the 23 repaired entries match a representative address', () {
      // The 23 entries are exactly the ones whose domain part is one of
      // these (the pre-fix file carried them with a stray @).
      const domains = [
        'accountprotection.microsoft.com', 'acm.discoursemail.com',
        'amer.ph.mc.philips.com', 'banking.jpmchase.com', 'cc.aol.com',
        'challenge.itu.int', 'connect.vizio.com', 'directv.ebilling.com',
        'email.apple.com', 'email.microsoft.com', 'id.apple.com',
        'infoemails.microsoft.com', 'infomails.microsoft.com',
        'information.microsoft.com', 'khanacademy.zendesk.com',
        'mail.support.microsoft.com', 'ncbi.nlm.nih.gov',
        'notificationemails.microsoft.com', 'oaks.state.oh.us',
        'promomail.microsoft.com', 'quantum-computing.ibm.com',
        'relay.walmart.com', 'store.email.wdc.com',
      ];
      expect(domains, hasLength(23));
      final compiler = PatternCompiler();
      for (final domain in domains) {
        final escaped = domain.replaceAll('.', r'\.').replaceAll('-', r'\-');
        final pattern = r'^[^@\s]+@(?:[a-z0-9-]+\.)*' + escaped + r'$';
        expect(safeSenders, contains(pattern),
            reason: 'bundled file carries $domain');
        final re = compiler.compile(pattern);
        expect(re.hasMatch('alerts@$domain'), isTrue, reason: domain);
        expect(re.hasMatch('alerts@sub.$domain'), isTrue, reason: domain);
      }
    });

    test('the file keeps its export invariants: sorted, unique, trimmed', () {
      expect(safeSenders, orderedEquals([...safeSenders]..sort()));
      expect(safeSenders.toSet().length, safeSenders.length);
      expect(safeSenders.every((p) => p == p.trim() && p == p.toLowerCase()),
          isTrue);
    });

    test('rules.yaml has no unmatchable from pattern (block rules)', () {
      final ruleSet = YamlService().parseRulesFromString(
          File('assets/rules/rules.yaml').readAsStringSync());
      final bad = <String>[];
      for (final rule in ruleSet.rules) {
        for (final p in [...rule.conditions.from, ...?rule.exceptions?.from]) {
          if (PatternCompiler.detectUnmatchable(p).isNotEmpty) bad.add(p);
        }
      }
      expect(bad, isEmpty);
    });
  });

  group('import sanitizers (YamlService)', () {
    test('safe senders: unmatchable entries are skipped and reported', () {
      final result = YamlService.sanitizeSafeSenders(
          SafeSenderList(safeSenders: [_fixed, _broken, '@example.com']));
      expect(result.list.safeSenders, [_fixed, '@example.com']);
      expect(result.skipped, hasLength(1));
      expect(result.skipped.single, contains('jpmchase'));
    });

    Rule rule(String name, String type, List<String> from,
            {List<String> subject = const [], List<String> exceptionFrom = const []}) =>
        Rule(
          name: name,
          enabled: true,
          isLocal: false,
          executionOrder: 10,
          conditions: RuleConditions(type: type, from: from, subject: subject),
          actions: RuleActions(delete: true),
          exceptions:
              exceptionFrom.isEmpty ? null : RuleExceptions(from: exceptionFrom),
        );

    test('rules: OR drops only the bad pattern; AND and emptied rules are '
        'skipped whole; bad exceptions are dropped; subject is not checked',
        () {
      final result = YamlService.sanitizeRules(RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          rule('or-mixed', 'OR', [_broken, '@ok\\.com\$']),
          rule('or-only-bad', 'OR', [_broken]),
          rule('and-bad', 'AND', [_broken, '@ok\\.com\$']),
          rule('bad-exception', 'OR', ['@ok\\.com\$'],
              exceptionFrom: [_broken, 'x@y\\.com']),
          rule('subject-two-at', 'OR', [], subject: ['a@b and c@d']),
        ],
      ));
      final byName = {for (final r in result.ruleSet.rules) r.name: r};
      expect(byName['or-mixed']!.conditions.from, ['@ok\\.com\$']);
      expect(byName.containsKey('or-only-bad'), isFalse);
      expect(byName.containsKey('and-bad'), isFalse,
          reason: 'dropping one AND condition would widen the rule');
      expect(byName['bad-exception']!.exceptions!.from, ['x@y\\.com']);
      expect(byName['subject-two-at']!.conditions.subject, ['a@b and c@d']);
      expect(result.skipped, isNotEmpty);
    });

    test('final review 9: dropped rules and dropped patterns are counted '
        'separately, not as skipped lines', () {
      // AND rule with ONE bad from: two detail lines, but one dropped rule.
      var result = YamlService.sanitizeRules(RuleSet(
        version: '1.0',
        settings: {},
        rules: [rule('and-bad', 'AND', [_broken, '@ok\\.com\$'])],
      ));
      expect(result.skipped, hasLength(2), reason: 'pattern line + rule line');
      expect(result.droppedRules, 1);
      expect(result.droppedPatterns, 0,
          reason: 'its pattern is part of the dropped rule, not counted twice');
      expect(
          YamlService.describeDropped(
              droppedRules: result.droppedRules,
              droppedPatterns: result.droppedPatterns),
          '1 rule');

      // Kept OR rule that loses one pattern: one pattern, no rule.
      result = YamlService.sanitizeRules(RuleSet(
        version: '1.0',
        settings: {},
        rules: [rule('or-mixed', 'OR', [_broken, '@ok\\.com\$'])],
      ));
      expect(result.droppedRules, 0);
      expect(result.droppedPatterns, 1);
      expect(
          YamlService.describeDropped(
              droppedRules: result.droppedRules,
              droppedPatterns: result.droppedPatterns),
          '1 pattern');

      // Both in one file: 3 detail lines, but 1 rule and 1 pattern.
      result = YamlService.sanitizeRules(RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          rule('and-bad', 'AND', [_broken, '@ok\\.com\$']),
          rule('or-mixed', 'OR', [_broken, '@ok\\.com\$']),
        ],
      ));
      expect(result.skipped, hasLength(3));
      expect(result.droppedRules, 1);
      expect(result.droppedPatterns, 1);
      expect(
          YamlService.describeDropped(
              droppedRules: result.droppedRules,
              droppedPatterns: result.droppedPatterns),
          '1 rule and 1 pattern');

      expect(
          YamlService.describeDropped(droppedRules: 2, droppedPatterns: 3),
          '2 rules and 3 patterns');
      expect(YamlService.describeDropped(droppedRules: 0, droppedPatterns: 0),
          '');

      final ss = YamlService.sanitizeSafeSenders(
          SafeSenderList(safeSenders: [_broken, _fixed]));
      expect(ss.droppedPatterns, 1);
    });

    test('final review 7c: header patterns with the shipped defect are '
        'dropped; key:value header text is not touched', () {
      final result = YamlService.sanitizeRules(RuleSet(
        version: '1.0',
        settings: {},
        rules: [
          Rule(
            name: 'hdr',
            enabled: true,
            isLocal: false,
            executionOrder: 10,
            conditions: RuleConditions(
                type: 'OR', header: [_broken, 'x-spam:a@b and c@d']),
            actions: RuleActions(delete: true),
          ),
        ],
      ));
      expect(result.ruleSet.rules.single.conditions.header,
          ['x-spam:a@b and c@d']);
      expect(result.droppedPatterns, 1);
      expect(result.droppedRules, 0);
    });
  });

  group('persistence boundaries reject unmatchable patterns', () {
    late DatabaseTestHelper helper;

    setUp(() async {
      helper = DatabaseTestHelper();
      await helper.setUp();
    });
    tearDown(() async => helper.tearDown());

    test('SafeSenderDatabaseStore.addSafeSender and updateSafeSender', () async {
      final store = SafeSenderDatabaseStore(helper.dbHelper);
      SafeSenderPattern sender(String pattern, {List<String>? exceptions}) =>
          SafeSenderPattern(
            pattern: pattern,
            patternType: 'entire_domain',
            exceptionPatterns: exceptions,
            dateAdded: 1,
            createdBy: 'test',
          );
      await expectLater(store.addSafeSender(sender(_broken)),
          throwsA(isA<SafeSenderDatabaseException>()));
      await expectLater(
          store.addSafeSender(sender(_fixed, exceptions: [r'^a@b@c$'])),
          throwsA(isA<SafeSenderDatabaseException>()));
      await store.addSafeSender(sender(_fixed));
      await expectLater(store.updateSafeSender(_fixed, sender(_broken)),
          throwsA(isA<SafeSenderDatabaseException>()));
      expect((await store.loadSafeSenders()).map((s) => s.pattern), [_fixed]);
    });

    test('RuleDatabaseStore: addSafeSender, saveSafeSenders (before the '
        'delete), addRule', () async {
      final store = RuleDatabaseStore(helper.dbHelper);
      await expectLater(store.addSafeSender(_broken),
          throwsA(isA<RuleDatabaseStorageException>()));
      await store.addSafeSender(_fixed);
      await expectLater(
          store.saveSafeSenders(SafeSenderList(safeSenders: [_broken])),
          throwsA(isA<RuleDatabaseStorageException>()));
      expect((await store.loadSafeSenders()).safeSenders, [_fixed],
          reason: 'a rejected import must not empty the table');
      await expectLater(
          store.addRule(_simpleRule("bad", [_broken])),
          throwsA(isA<RuleDatabaseStorageException>()));
      await store.addRule(_simpleRule('good', [r'@ok\.com$']));
    });

    test('final review 7c: the rule store also rejects the defect in a '
        'header pattern (the column the app stores From rules in)', () async {
      final store = RuleDatabaseStore(helper.dbHelper);
      final headerRule = Rule(
        name: 'hdr-bad',
        enabled: true,
        isLocal: false,
        executionOrder: 10,
        conditions: RuleConditions(type: 'OR', header: [_broken]),
        actions: RuleActions(delete: true),
      );
      await expectLater(
          store.addRule(headerRule), throwsA(isA<RuleDatabaseStorageException>()));
      // Non-From header text with two @ is not the shipped shape: accepted.
      await store.addRule(Rule(
        name: 'hdr-ok',
        enabled: true,
        isLocal: false,
        executionOrder: 11,
        conditions: RuleConditions(type: 'OR', header: ['x-spam:a@b and c@d']),
        actions: RuleActions(delete: true),
      ));
    });
  });

  group('DB v13: the REAL upgrade repairs a v12 database', () {
    late DatabaseTestHelper helper;

    setUp(() async {
      helper = DatabaseTestHelper();
      await helper.setUp();
    });
    tearDown(() async => helper.tearDown());

    Future<void> buildV12Fixture(
        [Future<void> Function(Database db)? extra]) async {
      await helper.dbHelper.close();
      final dbFile = File(helper.testDbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final v12 = await databaseFactoryFfi.openDatabase(
        helper.testDbPath,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE safe_senders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pattern TEXT NOT NULL UNIQUE,
                pattern_type TEXT NOT NULL,
                exception_patterns TEXT,
                date_added INTEGER NOT NULL,
                date_modified INTEGER,
                created_by TEXT DEFAULT 'manual',
                created_with_auth_state TEXT
              );''');
            await db.execute('''
              CREATE TABLE rules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                enabled INTEGER NOT NULL DEFAULT 1,
                is_local INTEGER NOT NULL DEFAULT 0,
                execution_order INTEGER NOT NULL,
                condition_type TEXT NOT NULL,
                condition_from TEXT, condition_header TEXT,
                condition_subject TEXT, condition_body TEXT,
                action_delete INTEGER NOT NULL DEFAULT 0,
                action_move_to_folder TEXT, action_assign_category TEXT,
                exception_from TEXT, exception_header TEXT,
                exception_subject TEXT, exception_body TEXT,
                metadata TEXT, date_added INTEGER NOT NULL,
                date_modified INTEGER, created_by TEXT DEFAULT 'manual',
                pattern_category TEXT, pattern_sub_type TEXT,
                source_domain TEXT, created_with_auth_state TEXT
              );''');
            Future<void> ss(String pattern) => db.insert('safe_senders', {
                  'pattern': pattern,
                  'pattern_type': 'entire_domain',
                  'date_added': 1,
                });
            // Broken, no clash: must be rewritten in place.
            await ss(_broken);
            // Broken AND its fixed form already exists: the broken row goes.
            await ss(r'^[^@\s]+@(?:[a-z0-9-]+\.)*@id\.apple\.com$');
            await ss(r'^[^@\s]+@(?:[a-z0-9-]+\.)*id\.apple\.com$');
            // Healthy rows, one legal multi-@ alternation: untouched.
            await ss(r'^[^@\s]+@(?:[a-z0-9-]+\.)*aa\.com$');
            await ss(r'^(a@b\.com|c@d\.com)$');
            // Block rule with a broken from pattern, one with a healthy one.
            Future<void> rule(String name, List<String> from, List<String>? ex) =>
                db.insert('rules', {
                  'name': name,
                  'execution_order': 10,
                  'condition_type': 'OR',
                  'condition_from': jsonEncode(from),
                  'exception_from': ex == null ? null : jsonEncode(ex),
                  'date_added': 1,
                });
            await rule('broken-rule', [_broken, r'@ok\.com$'], [_broken]);
            await rule('healthy-rule', [r'@ok\.com$'], null);
            await extra?.call(db);
          },
        ),
      );
      await v12.close();
    }

    test('rewrites in place, deletes a would-be duplicate, leaves healthy '
        'rows alone, and repairs rule from patterns', () async {
      await buildV12Fixture();

      final db = await helper.dbHelper.database;
      expect(await db.getVersion(), databaseVersion);
      expect(databaseVersion, 13);

      final patterns = (await db.query('safe_senders', orderBy: 'pattern'))
          .map((r) => r['pattern'] as String)
          .toList();
      expect(
          patterns,
          unorderedEquals([
            _fixed,
            r'^[^@\s]+@(?:[a-z0-9-]+\.)*id\.apple\.com$',
            r'^[^@\s]+@(?:[a-z0-9-]+\.)*aa\.com$',
            r'^(a@b\.com|c@d\.com)$',
          ]),
          reason: '5 fixture rows -> 4 (one broken row deleted as a duplicate)');
      expect(patterns.where((p) => PatternCompiler.detectUnmatchable(p).isNotEmpty),
          isEmpty);

      final rewritten = await db.query('safe_senders',
          where: 'pattern = ?', whereArgs: [_fixed]);
      expect(rewritten.single['date_modified'], isNotNull);

      final broken = await db.query('rules',
          where: 'name = ?', whereArgs: ['broken-rule']);
      expect(jsonDecode(broken.single['condition_from'] as String),
          [_fixed, r'@ok\.com$']);
      expect(jsonDecode(broken.single['exception_from'] as String), [_fixed]);
      final healthy = await db.query('rules',
          where: 'name = ?', whereArgs: ['healthy-rule']);
      expect(jsonDecode(healthy.single['condition_from'] as String),
          [r'@ok\.com$']);
    });

    test('final review 7: header columns and exception_patterns are repaired; '
        'unreadable rows and unrepairable patterns are logged and counted, '
        'never silent', () async {
      final logged = <String>[];
      void listener(LogEvent e) => logged.add(e.message.toString());
      Logger.addLogListener(listener);
      addTearDown(() => Logger.removeLogListener(listener));

      await buildV12Fixture((db) async {
        Future<void> rule(String name, Map<String, Object?> cols) =>
            db.insert('rules', {
              'name': name,
              'execution_order': 10,
              'condition_type': 'OR',
              'date_added': 1,
              ...cols,
            });
        // Rules the app creates for a From address live in condition_header.
        await rule('header-rule', {
          'condition_header': jsonEncode([_broken, 'x-spam:.*']),
          'exception_header': jsonEncode([_broken]),
        });
        // Three unreadable shapes: not JSON, not a list, a list of non-strings
        // (the lazy-cast case).
        await rule('bad-json', {'condition_from': '{not json'});
        await rule('not-a-list', {'condition_from': '{"a":1}'});
        await rule('not-strings', {'condition_from': '[1,2]'});
        // Unmatchable, but not the shipped shape.
        await rule('other-shape', {'condition_from': jsonEncode([r'^a@b@c\.com$'])});
        await db.insert('safe_senders', {
          'pattern': r'^[^@\s]+@(?:[a-z0-9-]+\.)*withexc\.com$',
          'pattern_type': 'entire_domain',
          'exception_patterns': jsonEncode([_broken, r'^ok@withexc\.com$']),
          'date_added': 1,
        });
        await db.insert('safe_senders', {
          'pattern': r'^other-shape@b@c\.com$',
          'pattern_type': 'exact_email',
          'date_added': 1,
        });
        await db.insert('safe_senders', {
          'pattern': r'^[^@\s]+@(?:[a-z0-9-]+\.)*badexc\.com$',
          'pattern_type': 'entire_domain',
          'exception_patterns': '[1,2]',
          'date_added': 1,
        });
      });

      final db = await helper.dbHelper.database;
      Future<Map<String, Object?>> ruleRow(String name) async => (await db
              .query('rules', where: 'name = ?', whereArgs: [name]))
          .single;

      final hdr = await ruleRow('header-rule');
      expect(jsonDecode(hdr['condition_header'] as String),
          [_fixed, 'x-spam:.*'],
          reason: 'header column repaired, key:value text untouched');
      expect(jsonDecode(hdr['exception_header'] as String), [_fixed]);

      final exc = (await db.query('safe_senders',
              where: 'pattern LIKE ?', whereArgs: ['%withexc%']))
          .single;
      expect(jsonDecode(exc['exception_patterns'] as String),
          [_fixed, r'^ok@withexc\.com$']);

      // Unreadable rows stay as they were and are NOT reported as repaired.
      expect((await ruleRow('bad-json'))['condition_from'], '{not json');
      expect((await ruleRow('not-strings'))['condition_from'], '[1,2]');

      final text = logged.join('\n');
      for (final name in ['bad-json', 'not-a-list', 'not-strings']) {
        final id = (await ruleRow(name))['id'];
        expect(text, contains('v13: rules id=$id condition_from skipped'),
            reason: '$name must be logged by row id');
      }
      expect(text, contains('FormatException'));
      expect(text, contains('TypeError'));
      expect(text, contains('exception_patterns skipped, unreadable'));
      final summary =
          logged.lastWhere((l) => l.startsWith('v13 migration complete'));
      expect(summary, contains('4 row(s) skipped as unreadable'),
          reason: 'three rule columns plus one exception_patterns row');
      expect(summary, contains('2 unmatchable pattern(s) left as is'),
          reason: 'one rule from pattern plus one safe sender pattern');
      expect(summary, contains('1 safe sender exception list(s) repaired'));
      // No pattern text or address in any v13 log line.
      for (final line in logged.where((l) => l.startsWith('v13'))) {
        expect(line, isNot(contains('@')), reason: line);
      }
    });

    test('the repaired senders match mail after the upgrade (the point of '
        'the fix)', () async {
      await buildV12Fixture();
      final store = RuleDatabaseStore(helper.dbHelper);
      final list = await store.loadSafeSenders();
      expect(list.isSafe('alerts@banking.jpmchase.com'), isTrue);
    });
  });
}

Rule _simpleRule(String name, List<String> from) => Rule(
      name: name,
      enabled: true,
      isLocal: false,
      executionOrder: 10,
      conditions: RuleConditions(type: 'OR', from: from),
      actions: RuleActions(delete: true),
    );
