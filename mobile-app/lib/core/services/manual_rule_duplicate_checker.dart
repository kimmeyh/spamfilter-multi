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

  /// Sprint 37 BUG-S36-1: Find an existing block rule that already covers
  /// the given source domain/email by virtue of being a broader sub-type.
  ///
  /// Coverage matrix (returns the existing covering rule when found):
  /// - new `exact_email` covered by existing `exact_domain` (matching domain)
  /// - new `exact_email` covered by existing `entire_domain` (matching base)
  /// - new `exact_domain` covered by existing `entire_domain` (matching base)
  /// - new `entire_domain` is broader than `exact_domain` and `exact_email` --
  ///   never covered by them
  /// - `top_level_domain` has no overlap with domain/email types
  ///
  /// Returns a `SubsumingRuleInfo` describing the existing rule (sub-type +
  /// source domain + rule name) so the caller can name it in the error
  /// message, or `null` if no covering rule exists.
  Future<SubsumingRuleInfo?> findSubsumingBlockRule({
    required String sourceDomain,
    required String patternSubType,
    required String patternCategory,
  }) async {
    final newBase = _baseDomainFor(sourceDomain, patternSubType);
    if (newBase == null) return null;

    final broaderTypes = _broaderBlockSubTypes(patternSubType);
    if (broaderTypes.isEmpty) return null;

    final placeholders = List.filled(broaderTypes.length, '?').join(',');
    final results = await _db.query(
      'rules',
      columns: ['name', 'pattern_sub_type', 'source_domain'],
      where: '''
        pattern_category = ?
        AND pattern_sub_type IN ($placeholders)
        AND LOWER(TRIM(source_domain)) = ?
      ''',
      whereArgs: [patternCategory, ...broaderTypes, newBase],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final row = results.first;
    return SubsumingRuleInfo(
      ruleName: row['name'] as String,
      subType: row['pattern_sub_type'] as String,
      sourceDomain: row['source_domain'] as String,
    );
  }

  /// Sprint 37 BUG-S36-1: Find an existing safe sender that already covers
  /// the given source domain/email. Same coverage matrix as block rules
  /// but operates on the `safe_senders` table, which does not have a
  /// `source_domain` column -- the base domain is extracted from `pattern`.
  Future<SubsumingRuleInfo?> findSubsumingSafeSender({
    required String sourceDomain,
    required String patternType,
  }) async {
    final newBase = _baseDomainFor(sourceDomain, patternType);
    if (newBase == null) return null;

    final broaderTypes = _broaderSafeSenderTypes(patternType);
    if (broaderTypes.isEmpty) return null;

    final placeholders = List.filled(broaderTypes.length, '?').join(',');
    final results = await _db.query(
      'safe_senders',
      columns: ['pattern', 'pattern_type'],
      where: 'pattern_type IN ($placeholders)',
      whereArgs: broaderTypes,
    );

    for (final row in results) {
      final existingPattern = row['pattern'] as String;
      final existingType = row['pattern_type'] as String;
      final existingBase = _extractBaseFromPattern(existingPattern, existingType);
      if (existingBase == null) continue;
      if (existingBase == newBase) {
        return SubsumingRuleInfo(
          ruleName: existingPattern,
          subType: existingType,
          sourceDomain: existingBase,
        );
      }
    }
    return null;
  }

  /// Returns the comparable base for the given input. For domain types this
  /// is the lowercased domain. For `exact_email` it returns the domain part
  /// (everything after `@`) because an `exact_email` `bob@cwru.edu` is
  /// covered by `exact_domain cwru.edu` or `entire_domain cwru.edu`.
  ///
  /// Returns `null` for `top_level_domain` (no comparable base in the
  /// domain space) and for empty/malformed input.
  String? _baseDomainFor(String input, String subType) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    switch (subType) {
      case 'exact_email':
        if (!trimmed.contains('@')) return null;
        final domain = trimmed.split('@').last;
        return domain.isEmpty ? null : domain;
      case 'exact_domain':
      case 'entire_domain':
        return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
      case 'top_level_domain':
        return null;
      default:
        return null;
    }
  }

  /// Returns the sub-types that, if matched on base domain, would already
  /// cover a new rule of the given sub-type. `entire_domain` is the
  /// broadest, so an `exact_domain` is covered by `entire_domain`. An
  /// `exact_email` is covered by either `exact_domain` (same domain) or
  /// `entire_domain`.
  List<String> _broaderBlockSubTypes(String newSubType) {
    switch (newSubType) {
      case 'exact_email':
        return const ['exact_domain', 'entire_domain'];
      case 'exact_domain':
        return const ['entire_domain'];
      case 'entire_domain':
      case 'top_level_domain':
        return const [];
      default:
        return const [];
    }
  }

  /// Same coverage matrix for safe senders. `safe_senders.pattern_type`
  /// uses the same vocabulary as `rules.pattern_sub_type`.
  List<String> _broaderSafeSenderTypes(String newPatternType) =>
      _broaderBlockSubTypes(newPatternType);

  /// Extract the base domain or email from a stored regex pattern.
  /// Inverse of `_generatePattern` in `manual_rule_create_screen.dart`.
  ///
  /// Pattern shapes:
  /// - `entire_domain`: `@(?:[a-z0-9-]+\.)*{escaped_domain}$`
  /// - `exact_domain`: `@{escaped_domain}$`
  /// - `exact_email`: `^{escaped_email}$`
  /// - `top_level_domain`: `@.*\.{tld}$` (block only -- no base for matching)
  ///
  /// Returns `null` if the pattern shape does not match the expected form
  /// for the given sub-type.
  static String? _extractBaseFromPattern(String pattern, String subType) {
    final trimmed = pattern.trim();
    switch (subType) {
      case 'entire_domain':
        final match = RegExp(r'^@\(\?:\[a-z0-9-\]\+\\\.\)\*(.+)\$$')
            .firstMatch(trimmed);
        if (match == null) return null;
        return _unescapeRegexLiteral(match.group(1)!);
      case 'exact_domain':
        if (!trimmed.startsWith('@') || !trimmed.endsWith(r'$')) return null;
        final body = trimmed.substring(1, trimmed.length - 1);
        return _unescapeRegexLiteral(body);
      case 'exact_email':
        if (!trimmed.startsWith('^') || !trimmed.endsWith(r'$')) return null;
        final body = trimmed.substring(1, trimmed.length - 1);
        final unescaped = _unescapeRegexLiteral(body);
        return unescaped.contains('@') ? unescaped : null;
      default:
        return null;
    }
  }

  /// Reverse `RegExp.escape`: turn `\.` into `.`, `\-` into `-`, etc.
  /// Only handles the characters that `RegExp.escape` actually escapes for
  /// domains and emails; not a general regex unescape.
  static String _unescapeRegexLiteral(String escaped) {
    final buf = StringBuffer();
    var i = 0;
    while (i < escaped.length) {
      final c = escaped[i];
      if (c == r'\' && i + 1 < escaped.length) {
        buf.write(escaped[i + 1]);
        i += 2;
      } else {
        buf.write(c);
        i++;
      }
    }
    return buf.toString().toLowerCase();
  }
}

/// Description of an existing rule that subsumes a candidate new rule.
/// Returned by `findSubsumingBlockRule` and `findSubsumingSafeSender` so
/// the caller can render a validation error that names the existing rule.
class SubsumingRuleInfo {
  final String ruleName;
  final String subType;
  final String sourceDomain;

  const SubsumingRuleInfo({
    required this.ruleName,
    required this.subType,
    required this.sourceDomain,
  });

  /// Human-readable phrase like `entire_domain cwru.edu` for use in
  /// validation error messages.
  String get displayLabel => '$subType $sourceDomain';
}
