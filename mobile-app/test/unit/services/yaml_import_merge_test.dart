/// F269 (Sprint 80, #499): YAML import MERGE mode.
///
/// What these tests do NOT catch: the import SCREEN's wiring. The screen builds
/// its own DatabaseHelper and AppPaths in initState and takes its file from a
/// platform picker, so it is not pumped here; the source gate at the bottom
/// only proves the merge branch calls the merge commit and Replace still calls
/// the old one. They also do not prove the dedupe agrees with
/// ManualRuleDuplicateChecker on every exotic pattern: the normalization is
/// mirrored in memory, and only case, whitespace and the `\ ` escape are tested.
/// A database failure in the middle of a merge leaves the rules added so far
/// (no transaction). PR #490 7.7.1 group "a failure part-way" proves the error
/// carries their count and the rules in use are reloaded; it does NOT prove the
/// screen shows that message (the screen is not pumped, see above), nor a
/// failure inside the provider's own reload at that point.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/yaml_import_merge.dart';
import 'package:my_email_spam_filter/core/services/yaml_service.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/yaml_import_export_screen.dart';

import '../../helpers/database_test_helper.dart';

Rule _rule(String domain, {String? name, List<String>? header}) => Rule(
      name: name ?? 'Block_EntireDomain_$domain',
      enabled: true,
      isLocal: true,
      executionOrder: 10,
      conditions: RuleConditions(
          type: 'OR',
          header: header ??
              ['@(?:[a-z0-9-]+\\.)*${domain.replaceAll('.', '\\.')}\$']),
      actions: RuleActions(delete: true),
    );

RuleSet _set(List<Rule> rules) =>
    RuleSet(version: '1.0', settings: {}, rules: rules);

/// Adds the first rule, then fails like a database error (not a validator
/// rejection).
class _AddFailsOnSecondStore extends RuleDatabaseStore {
  _AddFailsOnSecondStore(super.provider);
  int _adds = 0;

  @override
  Future<void> addRule(Rule rule) async {
    if (++_adds == 2) throw StateError('simulated disk I/O error');
    await super.addRule(rule);
  }
}

/// The merge's own read works; the second read (the full set for the YAML
/// copy) fails.
class _SecondLoadFailsStore extends RuleDatabaseStore {
  _SecondLoadFailsStore(super.provider);
  int _loads = 0;

  @override
  Future<RuleSet> loadRules() async {
    if (++_loads == 2) throw StateError('simulated read failure');
    return super.loadRules();
  }
}

const _safeA =r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$';
const _safeB = r'^[^@\s]+@(?:[a-z0-9-]+\.)*friends\.org$';
// F266: two "@" after the local part can never match an address.
const _badSafe = r'^[^@\s]+@[^@\s]+@bad\.com$';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper db;
  late RuleDatabaseStore store;
  late RuleSetProvider provider;

  setUp(() async {
    db = DatabaseTestHelper();
    await db.setUp();
    store = RuleDatabaseStore(db.dbHelper);
    provider = RuleSetProvider()
      ..initializeForTesting(
        databaseStore: store,
        safeSenderStore: SafeSenderDatabaseStore(db.dbHelper),
      );
    await provider.loadRules();
    await provider.loadSafeSenders();
  });

  tearDown(() async => db.tearDown());

  group('Merge rules', () {
    test('AC-1: DB has A, file has A and B -> A once plus B; 1 added, 1 duplicate',
        () async {
      // C is in the DB but not in the file: it must survive, and the YAML copy
      // must hold A, B and C (the full set), not just the file's A and B.
      await store.saveRules(_set([_rule('a.com'), _rule('c.com')]));
      RuleSet? yamlWritten;

      final out = await commitRulesMerge(
        imported: _set([_rule('a.com'), _rule('b.com')]),
        alreadyInvalid: 0,
        dbStore: store,
        writeYaml: (r) async => yamlWritten = r,
        provider: provider,
      );

      expect(out.result.added, 1);
      expect(out.result.skippedDuplicate, 1);
      expect(out.result.skippedInvalid, 0);
      expect(out.result.describe('rules'),
          'Merged rules: 1 added, 1 skipped as duplicate, 0 skipped as invalid.');
      final stored = (await store.loadRules()).rules.map((r) => r.name).toList()
        ..sort();
      expect(stored, [
        'Block_EntireDomain_a.com',
        'Block_EntireDomain_b.com',
        'Block_EntireDomain_c.com',
      ]);
      expect(out.reloaded, isTrue);
      expect(provider.rules.rules.length, 3, reason: 'F297 reload after merge');
      expect(yamlWritten!.rules.length, 3,
          reason: 'the YAML copy holds the FULL set, not only the added rule');
    });

    test('a same-NAME rule with a different body is skipped, never overwritten',
        () async {
      await store.saveRules(_set([_rule('a.com', name: 'Mine')]));

      final r = await YamlImportMerge.mergeRules(
        dbStore: store,
        imported: _set([_rule('other.com', name: 'mine')]),
      );

      expect(r.added, 0);
      expect(r.skippedDuplicate, 1);
      final rules = (await store.loadRules()).rules;
      expect(rules.length, 1);
      expect(rules.single.name, 'Mine');
      expect(rules.single.conditions.header.single, contains('a'));
      expect(rules.single.conditions.header.single, isNot(contains('other')));
    });

    test('the same patterns under another name are a duplicate (case, spaces)',
        () async {
      await store.saveRules(_set([
        _rule('a.com', name: 'Old', header: [r'Act\ Now']),
      ]));

      final r = await YamlImportMerge.mergeRules(
        dbStore: store,
        imported: _set([
          _rule('a.com', name: 'New', header: ['  act now ']),
        ]),
      );

      expect(r.added, 0);
      expect(r.skippedDuplicate, 1);
    });

    test('a rule repeated inside the file is added once', () async {
      final r = await YamlImportMerge.mergeRules(
        dbStore: store,
        imported: _set([_rule('x.com'), _rule('x.com')]),
      );
      expect(r.added, 1);
      expect(r.skippedDuplicate, 1);
      expect((await store.loadRules()).rules.length, 1);
    });

    test('existing rules are untouched by a merge (order, enabled, action)',
        () async {
      final mine = Rule(
        name: 'Mine',
        enabled: false,
        isLocal: true,
        executionOrder: 7,
        conditions: RuleConditions(type: 'OR', header: ['@zzz\\.com\$']),
        actions: RuleActions(delete: false, moveToFolder: 'Junk'),
      );
      await store.saveRules(_set([mine]));

      await YamlImportMerge.mergeRules(
          dbStore: store, imported: _set([_rule('new.com')]));

      final kept = (await store.loadRules()).rules.firstWhere((r) => r.name == 'Mine');
      expect(kept.enabled, isFalse);
      expect(kept.executionOrder, 7);
      expect(kept.actions.moveToFolder, 'Junk');
    });

    test('AC-3: patterns the F266 validator rejects are skipped and counted',
        () async {
      // A real file: one good rule and one whose From pattern needs two "@".
      final bad = Rule(
        name: 'Bad',
        enabled: true,
        isLocal: true,
        executionOrder: 10,
        conditions: RuleConditions(type: 'OR', from: [r'^a@b@c\.com$']),
        actions: RuleActions(delete: true),
      );
      final sanitized =
          YamlService.sanitizeRules(_set([_rule('good.com'), bad]));
      expect(sanitized.droppedRules, 1, reason: 'precondition: F266 drops it');

      final out = await commitRulesMerge(
        imported: sanitized.ruleSet,
        alreadyInvalid: sanitized.droppedRules, // as the screen passes it
        dbStore: store,
        writeYaml: (_) async {},
        provider: provider,
      );

      expect(out.result.added, 1);
      expect(out.result.skippedInvalid, 1);
      expect((await store.loadRules()).rules.map((r) => r.name),
          ['Block_EntireDomain_good.com']);
    });

    test('a rule the store rejects as unsafe is counted invalid, not added',
        () async {
      // Not run through the sanitizer: the store is the backstop.
      final bad = Rule(
        name: 'BadFrom',
        enabled: true,
        isLocal: true,
        executionOrder: 10,
        conditions: RuleConditions(type: 'OR', from: [r'^a@b@c\.com$']),
        actions: RuleActions(delete: true),
      );
      final r = await YamlImportMerge.mergeRules(
          dbStore: store, imported: _set([bad, _rule('ok.com')]));
      expect(r.added, 1);
      expect(r.skippedInvalid, 1);
    });
  });

  group('Merge safe senders', () {
    test('adds new, skips duplicate (case/space), counts invalid', () async {
      await store.saveSafeSenders(SafeSenderList(safeSenders: [_safeA]));
      SafeSenderList? yamlWritten;

      final out = await commitSafeSendersMerge(
        imported: SafeSenderList(
            safeSenders: ['  ${_safeA.toUpperCase()} ', _safeB, _badSafe]),
        alreadyInvalid: 0,
        dbStore: store,
        writeYaml: (s) async => yamlWritten = s,
        provider: provider,
      );

      expect(out.result.added, 1);
      expect(out.result.skippedDuplicate, 1);
      expect(out.result.skippedInvalid, 1);
      expect(out.result.describe('safe senders'),
          'Merged safe senders: 1 added, 1 skipped as duplicate, '
          '1 skipped as invalid.');
      final stored = (await store.loadSafeSenders()).safeSenders;
      expect(stored.toSet(), {_safeA, _safeB});
      expect(provider.safeSenders.safeSenders.toSet(), {_safeA, _safeB});
      expect(yamlWritten!.safeSenders.length, 2);
    });

    test('invalid patterns removed earlier by the sanitizer are included', () async {
      final r = await YamlImportMerge.mergeSafeSenders(
        dbStore: store,
        imported: SafeSenderList(safeSenders: [_safeB]),
        alreadyInvalid: 2,
      );
      expect(r.skippedInvalid, 2);
      expect(r.added, 1);
    });
  });

  group('PR #490 7.7.1: a failure part-way', () {
    test('a storage error after one rule was added reports that rule and '
        'reloads it into the rules in use', () async {
      final failing = _AddFailsOnSecondStore(db.dbHelper);

      final error = await commitRulesMerge(
        imported: _set([_rule('one.com'), _rule('two.com')]),
        alreadyInvalid: 0,
        dbStore: failing,
        writeYaml: (_) async => fail('no YAML copy after a failed merge'),
        provider: provider,
      ).then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<ImportMergeInterruptedException>());
      final e = error as ImportMergeInterruptedException;
      expect(e.partial.added, 1);
      expect(e.reloaded, isTrue);
      expect(e.toString(), contains('after 1 rules were added'));
      expect(e.toString(), contains('are in use'));
      expect(provider.rules.rules.map((r) => r.name),
          ['Block_EntireDomain_one.com'],
          reason: 'the rule stored before the failure must be in use');
    });

    test('a failed YAML copy still reports the merge counts', () async {
      final error = await commitRulesMerge(
        imported: _set([_rule('one.com')]),
        alreadyInvalid: 0,
        dbStore: store,
        writeYaml: (_) async => throw const FileSystemException('disk full'),
        provider: provider,
      ).then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<YamlCopyNotWrittenException>());
      expect(error.toString(),
          startsWith('Merged rules: 1 added, 0 skipped as duplicate'));
    });

    test('a failed read of the full set for the YAML copy is a copy problem, '
        'not "Import failed"', () async {
      final failing = _SecondLoadFailsStore(db.dbHelper);

      final error = await commitRulesMerge(
        imported: _set([_rule('one.com')]),
        alreadyInvalid: 0,
        dbStore: failing,
        writeYaml: (_) async {},
        provider: provider,
      ).then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<YamlCopyNotWrittenException>());
      expect(error.toString(), contains('Merged rules: 1 added'));
    });

    test('patterns stripped from kept rules are named apart from skipped '
        'rules', () {
      expect(mergeStrippedPatternsNote(0), '');
      expect(mergeStrippedPatternsNote(2),
          ' 2 patterns that can never match removed from the imported rules.');
    });
  });

  group('Replace is unchanged (AC-2)', () {
    test('commitRulesImport still deletes what is not in the file', () async {
      await store.saveRules(_set([_rule('a.com')]));

      final ok = await commitRulesImport(
        rules: _set([_rule('b.com')]),
        dbStore: store,
        writeYaml: (_) async {},
        provider: provider,
      );

      expect(ok, isTrue);
      expect((await store.loadRules()).rules.map((r) => r.name),
          ['Block_EntireDomain_b.com']);
    });

    test('commitSafeSendersImport still deletes what is not in the file',
        () async {
      await store.saveSafeSenders(SafeSenderList(safeSenders: [_safeA]));

      await commitSafeSendersImport(
        safeSenders: SafeSenderList(safeSenders: [_safeB]),
        dbStore: store,
        writeYaml: (_) async {},
        provider: provider,
      );

      expect((await store.loadSafeSenders()).safeSenders, [_safeB]);
    });
  });

  test('source gate: the screen routes Merge to the merge commit and Replace to '
      'the old one', () {
    final src = File('lib/ui/screens/yaml_import_export_screen.dart')
        .readAsStringSync();
    for (final call in ['commitRulesMerge(', 'commitSafeSendersMerge(']) {
      final guarded = RegExp(
          r'mode == YamlImportMode\.merge\)\s*\{[^}]*?' + RegExp.escape(call),
          dotAll: true);
      expect(guarded.hasMatch(src), isTrue, reason: call);
    }
    expect(src.contains('await commitRulesImport('), isTrue);
    expect(src.contains('await commitSafeSendersImport('), isTrue);
  });
}
