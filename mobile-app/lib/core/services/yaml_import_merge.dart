/// F269 (Sprint 80, #499): the MERGE mode of a YAML import.
///
/// Replace (the pre-Sprint-80 behavior) deletes every rule or safe sender and
/// writes the file's set. Merge keeps everything that exists and adds only what
/// is NEW, so a mined or shared rule file can be added without wiping a
/// user's own rules.
///
/// **What counts as a duplicate** (decided here, recorded in the Sprint 80
/// plan under Task 10):
///
/// - A rule is a duplicate when an existing rule (or an earlier rule in the
///   same file) has the same NAME (trimmed, case-insensitive), OR the same
///   condition identity: the same condition type and the same set of
///   `from`, `header`, `subject` and `body` patterns after the normalization
///   [ManualRuleDuplicateChecker] uses (trim, lowercase, `\ ` equals a plain
///   space). Actions and exceptions are NOT part of the identity, matching the
///   checker, which compares pattern + category + sub-type only.
/// - **A same-name rule with a DIFFERENT body is skipped as a duplicate and
///   counted. It never overwrites.** `rules.name` is UNIQUE in the database, so
///   adding it would fail anyway, and "Nothing existing is changed" is the
///   point of Merge. A user who wants the file's version picks Replace.
/// - A safe sender is a duplicate when an existing one (or an earlier one in
///   the file) matches after trim + lowercase, the same normalization as
///   [ManualRuleDuplicateChecker.safeSenderExists].
///
/// [ManualRuleDuplicateChecker] itself asks the database one pattern at a time
/// and needs a sqflite handle; a merge compares a whole file against the
/// stored set, so the same normalization is applied in memory here. Existing
/// abstraction checked: `ManualRuleDuplicateChecker` (normalization mirrored,
/// not reusable as-is), `RuleConflictDetector` (not used: it answers "would an
/// existing rule shadow this rule for a given EMAIL", which is not a
/// duplicate test), `YamlService.sanitizeRules` / `sanitizeSafeSenders` (the F266
/// validator, run by the screen before the merge; its counts arrive as
/// `alreadyInvalid`).
///
/// Writes go through `RuleDatabaseStore.addRule` / `addSafeSender`, which never
/// touch existing rows (unlike `saveRules`, which deletes the table first).
/// Those two methods also run the stricter ReDoS / unmatchable checks; a
/// pattern they reject is counted as invalid, and any OTHER failure (a database
/// error) is rethrown so it is never miscounted as "invalid".
library;

import '../models/rule_set.dart';
import '../models/safe_sender_list.dart';
import '../storage/rule_database_store.dart';

/// What a merge did, for the result message.
class ImportMergeResult {
  const ImportMergeResult({
    required this.added,
    required this.skippedDuplicate,
    required this.skippedInvalid,
  });

  final int added;
  final int skippedDuplicate;
  final int skippedInvalid;

  /// `Merged rules: 3 added, 1 skipped as duplicate, 0 skipped as invalid.`
  String describe(String itemType) =>
      'Merged $itemType: $added added, $skippedDuplicate skipped as '
      'duplicate, $skippedInvalid skipped as invalid.';
}

class YamlImportMerge {
  YamlImportMerge._();

  static String _norm(String p) => p.trim().toLowerCase().replaceAll(r'\ ', ' ');

  static String _list(List<String> patterns) =>
      (patterns.map(_norm).toList()..sort()).join('\u0001');

  /// Identity of a rule's conditions (see the library doc).
  static String ruleSignature(Rule rule) {
    final c = rule.conditions;
    return [
      c.type,
      _list(c.from),
      _list(c.header),
      _list(c.subject),
      _list(c.body),
    ].join('\u0002');
  }

  /// Name key: `rules.name` is UNIQUE, so a same-name rule can never be added.
  static String ruleNameKey(Rule rule) => rule.name.trim().toLowerCase();

  /// Safe sender key (same normalization as the duplicate checker).
  static String safeSenderKey(String pattern) => pattern.trim().toLowerCase();

  /// Add the rules of [imported] that are new. [alreadyInvalid] is the number
  /// the F266 sanitizer removed before this call, so the message reports it.
  static Future<ImportMergeResult> mergeRules({
    required RuleDatabaseStore dbStore,
    required RuleSet imported,
    int alreadyInvalid = 0,
  }) async {
    final existing = await dbStore.loadRules();
    final names = <String>{for (final r in existing.rules) ruleNameKey(r)};
    final signatures = <String>{for (final r in existing.rules) ruleSignature(r)};
    var added = 0;
    var duplicates = 0;
    var invalid = alreadyInvalid;
    for (final rule in imported.rules) {
      final nameKey = ruleNameKey(rule);
      final signature = ruleSignature(rule);
      if (names.contains(nameKey) || signatures.contains(signature)) {
        duplicates++;
        continue;
      }
      try {
        await dbStore.addRule(rule);
      } on RuleDatabaseStorageException catch (e) {
        if (e.originalError is RuleDatabaseStorageException) {
          invalid++; // rejected by the ReDoS / unmatchable check
          continue;
        }
        rethrow; // a real storage failure is not "invalid"
      }
      names.add(nameKey);
      signatures.add(signature);
      added++;
    }
    return ImportMergeResult(
        added: added, skippedDuplicate: duplicates, skippedInvalid: invalid);
  }

  /// Add the safe senders of [imported] that are new.
  static Future<ImportMergeResult> mergeSafeSenders({
    required RuleDatabaseStore dbStore,
    required SafeSenderList imported,
    int alreadyInvalid = 0,
  }) async {
    final existing = await dbStore.loadSafeSenders();
    final keys = <String>{for (final p in existing.safeSenders) safeSenderKey(p)};
    var added = 0;
    var duplicates = 0;
    var invalid = alreadyInvalid;
    for (final pattern in imported.safeSenders) {
      final key = safeSenderKey(pattern);
      if (keys.contains(key)) {
        duplicates++;
        continue;
      }
      try {
        await dbStore.addSafeSender(pattern);
      } on RuleDatabaseStorageException catch (e) {
        if (e.originalError is RuleDatabaseStorageException) {
          invalid++;
          continue;
        }
        rethrow;
      }
      keys.add(key);
      added++;
    }
    return ImportMergeResult(
        added: added, skippedDuplicate: duplicates, skippedInvalid: invalid);
  }
}
