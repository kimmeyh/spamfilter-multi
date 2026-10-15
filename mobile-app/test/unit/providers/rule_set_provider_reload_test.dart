/// F297 (Sprint 79, #488): rules and safe senders are reloaded after a YAML
/// import, through ONE shared reload.
///
/// Found by Harold on Windows 0.20.0 [DEV], 2026-10-14: after importing the
/// Fold's rules and safe senders, Review No Rule Items still showed 386. The
/// database held the imported set; the in-memory [RuleSetProvider] did not,
/// because the import wrote to the stores and never reloaded it.
///
/// What these tests do NOT catch: a screen that bypasses
/// [commitRulesImport] / [commitSafeSendersImport] and writes the stores
/// itself (the Rules and Safe Senders management screens and the quick-add
/// screens still do; card #488 lists them as a follow-up). They also do not
/// pump the import screen: no file picker fake exists, so the screen's call
/// into the commit functions is covered by review, not by a test.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/storage/rule_database_store.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';
import 'package:my_email_spam_filter/ui/screens/yaml_import_export_screen.dart';

import '../../helpers/database_test_helper.dart';

class _ThrowingRuleStore extends RuleDatabaseStore {
  _ThrowingRuleStore(super.databaseProvider);
  bool fail = true;
  @override
  Future<RuleSet> loadRules() async {
    if (fail) throw StateError('rules table unreadable');
    return super.loadRules();
  }
}

class _ThrowingSafeSenderStore extends SafeSenderDatabaseStore {
  _ThrowingSafeSenderStore(super.databaseProvider);
  @override
  Future<List<SafeSenderPattern>> loadSafeSenders() async =>
      throw StateError('safe_senders table unreadable');
}

Rule _blockRule(String domain) => Rule(
      name: 'Block_EntireDomain_$domain',
      enabled: true,
      isLocal: true,
      executionOrder: 10,
      conditions: RuleConditions(
          type: 'OR',
          header: ['@(?:[a-z0-9-]+\\.)*${domain.replaceAll('.', '\\.')}\$']),
      actions: RuleActions(delete: true),
    );

const _safePattern = r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper db;
  late RuleDatabaseStore ruleStore;
  late RuleSetProvider provider;

  setUp(() async {
    db = DatabaseTestHelper();
    await db.setUp();
    ruleStore = RuleDatabaseStore(db.dbHelper);
    provider = RuleSetProvider()
      ..initializeForTesting(
        databaseStore: ruleStore,
        safeSenderStore: SafeSenderDatabaseStore(db.dbHelper),
      );
    // The state Harold's app was in: rules already loaded, so every
    // "load if not loaded" guard is satisfied and nothing reloads.
    await provider.loadRules();
    await provider.loadSafeSenders();
  });

  tearDown(() async => db.tearDown());

  group('RuleSetProvider.reloadFromDatabase', () {
    test('AC-1: picks up rules and safe senders written behind its back',
        () async {
      await ruleStore.saveRules(
          RuleSet(version: '1.0', settings: {}, rules: [_blockRule('brarpy.net')]));
      await ruleStore
          .saveSafeSenders(SafeSenderList(safeSenders: [_safePattern]));
      // The defect: the provider still holds the old (empty) set.
      expect(provider.rules.rules, isEmpty);

      final ok = await provider.reloadFromDatabase();

      expect(ok, isTrue);
      expect(provider.rules.rules.map((r) => r.name),
          ['Block_EntireDomain_brarpy.net']);
      expect(provider.safeSenders.safeSenders, [_safePattern]);
    });

    test('AC-2: returns false when the rules load fails', () async {
      final p = RuleSetProvider()
        ..initializeForTesting(
          databaseStore: _ThrowingRuleStore(db.dbHelper),
          safeSenderStore: SafeSenderDatabaseStore(db.dbHelper),
        );
      expect(await p.reloadFromDatabase(), isFalse);
    });

    test('AC-2: returns false when the safe senders load fails', () async {
      final p = RuleSetProvider()
        ..initializeForTesting(
          databaseStore: ruleStore,
          safeSenderStore: _ThrowingSafeSenderStore(db.dbHelper),
        );
      expect(await p.reloadFromDatabase(), isFalse);
    });

    test('an earlier failure does not make a later good reload read as failed',
        () async {
      final store = _ThrowingRuleStore(db.dbHelper);
      final p = RuleSetProvider()
        ..initializeForTesting(
          databaseStore: store,
          safeSenderStore: SafeSenderDatabaseStore(db.dbHelper),
        );
      expect(await p.reloadFromDatabase(), isFalse);
      store.fail = false;
      expect(await p.reloadFromDatabase(), isTrue);
    });
  });

  group('YAML import commit (AC-3)', () {
    test('a rules import is visible in the provider with no restart',
        () async {
      RuleSet? yamlWritten;
      final ok = await commitRulesImport(
        rules: RuleSet(
            version: '1.0', settings: {}, rules: [_blockRule('aglimertoe.com')]),
        dbStore: ruleStore,
        writeYaml: (r) async => yamlWritten = r,
        provider: provider,
      );

      expect(ok, isTrue);
      expect(yamlWritten, isNotNull);
      expect(provider.rules.rules.map((r) => r.name),
          ['Block_EntireDomain_aglimertoe.com']);
    });

    test('a safe senders import is visible in the provider with no restart',
        () async {
      SafeSenderList? yamlWritten;
      final ok = await commitSafeSendersImport(
        safeSenders: SafeSenderList(safeSenders: [_safePattern]),
        dbStore: ruleStore,
        writeYaml: (s) async => yamlWritten = s,
        provider: provider,
      );

      expect(ok, isTrue);
      expect(yamlWritten, isNotNull);
      expect(provider.safeSenders.safeSenders, [_safePattern]);
    });
  });
}
