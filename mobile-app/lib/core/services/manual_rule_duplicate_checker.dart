import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Pre-insert duplicate checks for manually created block rules and safe senders.
///
/// Sprint 36 BUG-S35-1: The `rules` table has no UNIQUE constraint on the
/// semantic identity of a rule (pattern + sub_type + category). Only
/// `rules.name` is UNIQUE, and manual rule names include a timestamp so they
/// can never collide. This meant a user could create a rule for `.xyz` that
/// had the same pattern as the bundled `._.xyz` rule, and the insert would
/// succeed silently. The two rows were visually indistinguishable in the
/// Manage Rules UI and could only be told apart at the DB level.
///
/// Safe senders have a UNIQUE constraint on `pattern` at the schema level, so
/// a duplicate insert there already throws a UNIQUE constraint error. The
/// manual-create screen catches that via `isUniqueConstraintError()` and
/// shows a friendly message. We still add a pre-insert check for safe senders
/// so the two code paths behave identically (and so the test suite can cover
/// both in the same shape).
///
/// The check is normalized: pattern comparison is case-insensitive and
/// whitespace-trimmed so `.XYZ` and `.xyz` are treated as the same.
class ManualRuleDuplicateChecker {
  final Database _db;

  ManualRuleDuplicateChecker(this._db);

  /// Returns `true` if a block rule with the same semantic identity already
  /// exists. Matches on normalized pattern + `pattern_category` + `pattern_sub_type`.
  ///
  /// Parameters:
  /// - [pattern]: the generated regex pattern string. Compared case-insensitively
  ///   after trimming.
  /// - [patternCategory]: e.g. 'header_from'.
  /// - [patternSubType]: e.g. 'top_level_domain', 'entire_domain', 'exact_domain',
  ///   'exact_email'.
  Future<bool> blockRuleExists({
    required String pattern,
    required String patternCategory,
    required String patternSubType,
  }) async {
    final normalized = _normalize(pattern);
    if (normalized.isEmpty) return false;

    // The stored `condition_header` is a JSON-encoded list of patterns.
    // The manual-create path always writes a single-element list, so we
    // match against both the exact stored form and a LIKE to catch
    // legacy rows where whitespace differs.
    final storedExact = jsonEncode([normalized]);

    final results = await _db.query(
      'rules',
      where: '''
        pattern_category = ?
        AND pattern_sub_type = ?
        AND (
          LOWER(TRIM(condition_header)) = LOWER(?)
          OR LOWER(TRIM(condition_header)) LIKE ?
        )
      ''',
      whereArgs: [
        patternCategory,
        patternSubType,
        storedExact,
        '%"${normalized.replaceAll('"', '\\"')}"%',
      ],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  /// Returns `true` if a safe sender with the same normalized pattern already
  /// exists. Matches on normalized pattern + `pattern_type`.
  Future<bool> safeSenderExists({
    required String pattern,
    required String patternType,
  }) async {
    final normalized = _normalize(pattern);
    if (normalized.isEmpty) return false;

    final results = await _db.query(
      'safe_senders',
      where: 'LOWER(TRIM(pattern)) = ? AND pattern_type = ?',
      whereArgs: [normalized, patternType],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  /// Normalize a pattern for equality comparison: trim whitespace and
  /// lowercase. Regex patterns are case-insensitive at runtime
  /// (see `gmail_windows_oauth_handler.dart` and rule_evaluator), so
  /// `.XYZ` and `.xyz` generate semantically identical rules.
  String _normalize(String pattern) => pattern.trim().toLowerCase();
}
