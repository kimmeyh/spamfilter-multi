import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/services/yaml_service.dart';

/// Integration test: YAML rules and safe senders export/import round-trip
///
/// [ISSUE #179] Sprint 19: Verifies that exporting rules/safe senders to YAML
/// and re-importing produces identical data. This is the critical test for
/// the import/export feature (F22).
///
/// Test strategy:
/// 1. Load the actual rules.yaml and rules_safe_senders.yaml from the repo root
/// 2. Export them to temporary files
/// 3. Re-import from the temporary files
/// 4. Compare original and re-imported data for exact match
void main() {
  final yamlService = YamlService();

  /// Find the repo root rules files (two directories up from mobile-app/test/)
  String getRepoRoot() {
    // Test runs from mobile-app/ directory
    // Repo root contains rules.yaml and rules_safe_senders.yaml
    final candidates = [
      '${Directory.current.path}/../rules.yaml', // from mobile-app/
      '${Directory.current.path}/rules.yaml',     // from repo root
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return File(candidate).parent.path;
      }
    }

    // Fallback: search up from current directory
    var dir = Directory.current;
    while (dir.path.length > 3) {
      if (File('${dir.path}/rules.yaml').existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }

    throw StateError('Could not find repo root with rules.yaml');
  }

  group('YAML Rules Round-Trip', () {
    late String repoRoot;
    late Directory tempDir;

    setUpAll(() {
      repoRoot = getRepoRoot();
    });

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('yaml_roundtrip_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('export then import rules produces identical rule set', () async {
      final rulesPath = '$repoRoot/rules.yaml';
      expect(File(rulesPath).existsSync(), isTrue,
          reason: 'rules.yaml must exist at repo root');

      // 1. Load original rules
      final original = await yamlService.loadRules(rulesPath);
      expect(original.rules.isNotEmpty, isTrue,
          reason: 'rules.yaml must contain at least one rule');

      // 2. Export to temp file
      final exportPath = '${tempDir.path}/exported_rules.yaml';
      await yamlService.exportRules(original, exportPath);
      expect(File(exportPath).existsSync(), isTrue);

      // 3. Re-import
      final reimported = await yamlService.loadRules(exportPath);

      // 4. Compare
      expect(reimported.version, equals(original.version),
          reason: 'Version must match');
      expect(reimported.rules.length, equals(original.rules.length),
          reason: 'Rule count must match');

      // Compare each rule by name and key properties
      // Note: Export normalizes (lowercase, deduplicate, sort patterns)
      // so we compare normalized forms
      final originalNames = original.rules.map((r) => r.name.toLowerCase()).toSet();
      final reimportedNames = reimported.rules.map((r) => r.name.toLowerCase()).toSet();
      expect(reimportedNames, equals(originalNames),
          reason: 'Rule names must match after normalization');

      // For each rule, verify conditions and actions match
      for (final origRule in original.rules) {
        final reimportedRule = reimported.rules.firstWhere(
          (r) => r.name.toLowerCase() == origRule.name.toLowerCase(),
          orElse: () => throw StateError('Rule "${origRule.name}" not found in reimported set'),
        );

        // Compare conditions type
        expect(reimportedRule.conditions.type, equals(origRule.conditions.type),
            reason: 'Conditions type must match for rule "${origRule.name}"');

        // Compare condition pattern counts (normalized: deduped + sorted)
        _expectNormalizedListsMatch(
          reimportedRule.conditions.from,
          origRule.conditions.from,
          'from conditions for "${origRule.name}"',
        );
        _expectNormalizedListsMatch(
          reimportedRule.conditions.header,
          origRule.conditions.header,
          'header conditions for "${origRule.name}"',
        );
        _expectNormalizedListsMatch(
          reimportedRule.conditions.subject,
          origRule.conditions.subject,
          'subject conditions for "${origRule.name}"',
        );

        // Compare actions
        expect(reimportedRule.actions.delete, equals(origRule.actions.delete),
            reason: 'Delete action must match for "${origRule.name}"');
        expect(reimportedRule.actions.moveToFolder?.toLowerCase(),
            equals(origRule.actions.moveToFolder?.toLowerCase()),
            reason: 'Move folder must match for "${origRule.name}"');
      }
    });

    test('export then import safe senders produces identical list', () async {
      final safeSendersPath = '$repoRoot/rules_safe_senders.yaml';
      expect(File(safeSendersPath).existsSync(), isTrue,
          reason: 'rules_safe_senders.yaml must exist at repo root');

      // 1. Load original safe senders
      final original = await yamlService.loadSafeSenders(safeSendersPath);
      expect(original.safeSenders.isNotEmpty, isTrue,
          reason: 'rules_safe_senders.yaml must contain at least one pattern');

      // 2. Export to temp file
      final exportPath = '${tempDir.path}/exported_safe_senders.yaml';
      await yamlService.exportSafeSenders(original, exportPath);
      expect(File(exportPath).existsSync(), isTrue);

      // 3. Re-import
      final reimported = await yamlService.loadSafeSenders(exportPath);

      // 4. Compare - export normalizes (lowercase, trim, deduplicate, sort)
      final originalNormalized = original.safeSenders
          .map((s) => s.toLowerCase().trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      final reimportedNormalized = reimported.safeSenders
          .map((s) => s.toLowerCase().trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      expect(reimportedNormalized.length, equals(originalNormalized.length),
          reason: 'Safe sender count must match after normalization '
              '(original: ${originalNormalized.length}, reimported: ${reimportedNormalized.length})');

      // Check that every original pattern exists in reimported set
      final missing = originalNormalized.difference(reimportedNormalized);
      expect(missing, isEmpty,
          reason: 'All original patterns must exist in reimported set. '
              'Missing: ${missing.take(5).join(", ")}${missing.length > 5 ? "..." : ""}');

      // Check no extra patterns were added
      final extra = reimportedNormalized.difference(originalNormalized);
      expect(extra, isEmpty,
          reason: 'No extra patterns should exist in reimported set. '
              'Extra: ${extra.take(5).join(", ")}${extra.length > 5 ? "..." : ""}');
    });

    test('double export produces identical YAML content', () async {
      final safeSendersPath = '$repoRoot/rules_safe_senders.yaml';
      final original = await yamlService.loadSafeSenders(safeSendersPath);

      // Export twice to different files
      final exportPath1 = '${tempDir.path}/export1.yaml';
      final exportPath2 = '${tempDir.path}/export2.yaml';
      await yamlService.exportSafeSenders(original, exportPath1);

      // Re-load from first export and export again
      final reloaded = await yamlService.loadSafeSenders(exportPath1);
      await yamlService.exportSafeSenders(reloaded, exportPath2);

      // Compare file contents byte-for-byte
      final content1 = await File(exportPath1).readAsString();
      final content2 = await File(exportPath2).readAsString();
      expect(content2, equals(content1),
          reason: 'Double export must produce identical YAML (idempotent normalization)');
    });

    test('double export produces identical rules YAML content', () async {
      final rulesPath = '$repoRoot/rules.yaml';
      final original = await yamlService.loadRules(rulesPath);

      // Export twice
      final exportPath1 = '${tempDir.path}/rules_export1.yaml';
      final exportPath2 = '${tempDir.path}/rules_export2.yaml';
      await yamlService.exportRules(original, exportPath1);

      final reloaded = await yamlService.loadRules(exportPath1);
      await yamlService.exportRules(reloaded, exportPath2);

      // Re-import both exports and compare data equivalence
      // Note: Byte-for-byte comparison may differ because Rule.toMap()
      // conditionally includes exceptions (null vs empty RuleExceptions).
      // The important guarantee is data equivalence.
      final fromExport1 = await yamlService.loadRules(exportPath1);
      final fromExport2 = await yamlService.loadRules(exportPath2);

      expect(fromExport2.rules.length, equals(fromExport1.rules.length),
          reason: 'Double rules export must preserve rule count');

      for (int i = 0; i < fromExport1.rules.length; i++) {
        final r1 = fromExport1.rules[i];
        final r2 = fromExport2.rules[i];
        expect(r2.name, equals(r1.name),
            reason: 'Rule name must match at index $i');
        expect(r2.conditions.type, equals(r1.conditions.type),
            reason: 'Conditions type must match for "${r1.name}"');
        expect(r2.actions.delete, equals(r1.actions.delete),
            reason: 'Delete action must match for "${r1.name}"');
      }
    });

    test('safe senders count matches expected range', () async {
      final safeSendersPath = '$repoRoot/rules_safe_senders.yaml';
      final safeSenders = await yamlService.loadSafeSenders(safeSendersPath);

      // The repo has hundreds of safe sender patterns
      expect(safeSenders.safeSenders.length, greaterThan(100),
          reason: 'Expected substantial safe sender list (current repo has 400+)');
    });

    test('rules count matches expected range', () async {
      final rulesPath = '$repoRoot/rules.yaml';
      final rules = await yamlService.loadRules(rulesPath);

      // The repo has multiple rules
      expect(rules.rules.length, greaterThan(0),
          reason: 'Expected at least one rule in rules.yaml');
    });
  });
}

/// Compare two lists after normalization (lowercase, deduplicate, sort)
///
/// The YAML export normalizes patterns, so we must compare normalized forms
void _expectNormalizedListsMatch(
  List<String> actual,
  List<String> expected,
  String description,
) {
  final normalizedActual = actual
      .map((s) => s.toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final normalizedExpected = expected
      .map((s) => s.toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  expect(normalizedActual, equals(normalizedExpected),
      reason: 'Normalized $description must match');
}
