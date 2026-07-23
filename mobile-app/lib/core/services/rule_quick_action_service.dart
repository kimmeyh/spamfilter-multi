import 'package:logger/logger.dart';

import '../models/rule_set.dart' show Rule, RuleConditions, RuleActions;
import '../providers/rule_set_provider.dart';
import 'rule_conflict_resolver.dart';

/// Result of a single quick-action rule/safe-sender creation, for callers
/// that need to summarize outcomes across a batch (F39) or show a single
/// SnackBar (the existing per-email quick-add flow).
class RuleQuickActionResult {
  final bool success;
  final String displayMessage;
  final int conflictsRemoved;
  final Object? error;

  /// F120 (Sprint 49): the rule this action CREATED (createBlockRule success
  /// only). Callers use it to re-evaluate their in-memory "No rule" set
  /// against ONLY this delta instead of the full rule set -- the full-set
  /// re-evaluation froze the UI for ~1-2 minutes per quick action on the
  /// 12.5k-rule Store prod DB (0.5.6, "(Not Responding)").
  final Rule? createdRule;

  /// F120: the safe-sender pattern this action ADDED (addSafeSender success
  /// only). Same delta-re-evaluation purpose as [createdRule].
  final String? createdSafeSenderPattern;

  const RuleQuickActionResult({
    required this.success,
    required this.displayMessage,
    this.conflictsRemoved = 0,
    this.error,
    this.createdRule,
    this.createdSafeSenderPattern,
  });
}

/// Screen-agnostic core of the "quick add safe sender" / "quick add block
/// rule" actions.
///
/// F39 (Sprint 46): extracted from `ResultsDisplayScreen._addSafeSender` /
/// `._createBlockRule` so the existing single-email detail-sheet flow and
/// the new cross-account "No rule" review screen's bulk actions call the
/// SAME rule-creation logic instead of two copies that could drift.
///
/// Deliberately excludes the re-evaluate/re-process/notify tail that the
/// original per-screen methods ran after every single call (re-evaluating
/// all in-memory "No rule" results, executing IMAP actions, showing a
/// SnackBar) -- that tail is specific to a live/historical scan session's
/// in-memory state (`EmailActionResult` list) and does not apply to the
/// cross-account screen, which operates on persisted `UnmatchedEmail` DB
/// rows and does not re-process over IMAP. Callers that DO need that tail
/// (the existing per-email screen) still run it themselves after calling
/// into this service, once per call as before. Callers doing a bulk
/// operation (F39) call this once per selected item, then run their own
/// batch-summary step once for the whole selection.
class RuleQuickActionService {
  final RuleSetProvider ruleProvider;
  final RuleConflictResolver _conflictResolver;
  final Logger _logger;

  RuleQuickActionService({
    required this.ruleProvider,
    RuleConflictResolver? conflictResolver,
    Logger? logger,
  })  : _conflictResolver = conflictResolver ?? RuleConflictResolver(),
        _logger = logger ?? Logger();

  /// Adds a safe-sender pattern. [type] is one of 'exact', 'exactDomain',
  /// 'entireDomain'. [senderEmailForConflictCheck] should be the full
  /// sender email address (used to remove conflicting block rules), and
  /// may differ from [value] (e.g. [value] can be a bare domain for the
  /// domain pattern types).
  Future<RuleQuickActionResult> addSafeSender({
    required String value,
    required String type,
    required String senderEmailForConflictCheck,
  }) async {
    try {
      // Copilot review (Sprint 46): an empty value must never reach pattern
      // generation -- the entireDomain shape with '' would produce a pattern
      // matching EVERY email address.
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        _logger.w('Rejected safe-sender add with empty value (type: $type)');
        return RuleQuickActionResult(
          success: false,
          displayMessage: 'Cannot add a safe sender from an empty value',
        );
      }

      String pattern;
      String displayMessage;

      // Copilot review (Sprint 46): RegExp.escape (consistent with
      // PatternGeneration / ManualRulePatternGenerator) instead of escaping
      // only '.'/'@' -- valid addresses can contain regex metacharacters
      // (e.g. plus-addressing: bob+tag@x.com).
      switch (type) {
        case 'exact':
          pattern = '^${RegExp.escape(trimmed)}\$';
          displayMessage = 'Added "$trimmed" to Safe Senders';
          break;
        case 'exactDomain':
          // Copilot round 5: normalize the leading '@' so a bare-domain
          // caller cannot silently create an ineffective pattern.
          final domainValue = trimmed.startsWith('@') ? trimmed : '@$trimmed';
          pattern = '^[^@\\s]+${RegExp.escape(domainValue)}\$';
          displayMessage = 'Added exact domain "$domainValue" to Safe Senders';
          break;
        case 'entireDomain':
          pattern =
              r'^[^@\s]+@(?:[a-z0-9-]+\.)*' + RegExp.escape(trimmed) + r'$';
          displayMessage = 'Added entire domain "*.$trimmed" to Safe Senders';
          break;
        default:
          _logger.w('Unknown safe sender type: $type');
          return RuleQuickActionResult(
            success: false,
            displayMessage: 'Unknown safe sender type: $type',
          );
      }

      final conflicts = await _conflictResolver.removeConflictingRules(
        emailAddress: senderEmailForConflictCheck,
        ruleProvider: ruleProvider,
      );

      await ruleProvider.addSafeSender(pattern);
      await ruleProvider.loadSafeSenders();
      await ruleProvider.loadRules();

      if (conflicts.conflictsRemoved > 0) {
        displayMessage +=
            ' (removed ${conflicts.conflictsRemoved} conflicting rule${conflicts.conflictsRemoved > 1 ? "s" : ""})';
      }

      // Copilot review (Sprint 46): do not log the raw pattern -- it embeds
      // email addresses/domains. The type + length are enough for debugging.
      _logger.i('[OK] Added safe sender (type: $type, '
          'patternLength: ${pattern.length})');
      return RuleQuickActionResult(
        success: true,
        displayMessage: displayMessage,
        conflictsRemoved: conflicts.conflictsRemoved,
        createdSafeSenderPattern: pattern,
      );
    } catch (e) {
      _logger.e('[FAIL] Failed to add safe sender: $e');
      return RuleQuickActionResult(
        success: false,
        displayMessage: 'Failed to add safe sender: $e',
        error: e,
      );
    }
  }

  /// Creates a block rule. [type] is one of 'from', 'exactDomain',
  /// 'entireDomain', 'subject'. [senderEmailForConflictCheck] is required
  /// for non-subject types to remove conflicting safe senders; pass null
  /// for 'subject' rules (subject-based rules do not conflict with
  /// safe senders, which match on the from address).
  ///
  /// [sourceDescription] names the calling surface in the persisted rule
  /// metadata comment (Copilot review, Sprint 46 -- this service is shared
  /// by the Results screen and the No Rule Review screen, so the provenance
  /// must not hard-code one of them).
  Future<RuleQuickActionResult> createBlockRule({
    required String type,
    required String value,
    String? senderEmailForConflictCheck,
    String sourceDescription = 'Results screen',
  }) async {
    try {
      // Copilot review (Sprint 46): reject empty values before pattern
      // generation -- the entireDomain shape with '' would produce a
      // match-everything pattern, and '@'/'@null' inputs create junk rules.
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '@' || trimmed == '@null') {
        _logger.w('Rejected block-rule create with empty/degenerate value '
            '(type: $type)');
        return RuleQuickActionResult(
          success: false,
          displayMessage: 'Cannot create a block rule from an empty value',
        );
      }

      String pattern;
      String ruleName;
      String displayMessage;

      // Copilot review (Sprint 46): RegExp.escape (consistent with
      // PatternGeneration / ManualRulePatternGenerator) instead of escaping
      // only '.'/'@' -- valid addresses can contain regex metacharacters.
      switch (type) {
        case 'from':
          pattern = '^${RegExp.escape(trimmed)}\$';
          ruleName = 'Block_${_sanitizeForRuleName(trimmed)}';
          displayMessage = 'Created rule to block email "$trimmed"';
          break;
        case 'exactDomain':
          // Copilot round 5: normalize the leading '@' -- a bare-domain
          // value would produce a suffix-matching pattern (example\.com$
          // also matches user@notexample.com).
          final domainValue = trimmed.startsWith('@') ? trimmed : '@$trimmed';
          pattern = '${RegExp.escape(domainValue)}\$';
          ruleName = 'Block_ExactDomain_${_sanitizeForRuleName(domainValue)}';
          displayMessage = 'Created rule to block exact domain "$domainValue"';
          break;
        case 'entireDomain':
          pattern = r'@(?:[a-z0-9-]+\.)*' + RegExp.escape(trimmed) + r'$';
          ruleName = 'Block_EntireDomain_${_sanitizeForRuleName(trimmed)}';
          displayMessage = 'Created rule to block entire domain "*.$trimmed"';
          break;
        case 'subject':
          pattern = RegExp.escape(trimmed);
          ruleName =
              'Block_Subject_${_sanitizeForRuleName(trimmed.substring(0, trimmed.length.clamp(0, 40)))}';
          displayMessage = 'Created rule to block subject containing "$trimmed"';
          break;
        default:
          _logger.w('Unknown block rule type: $type');
          return RuleQuickActionResult(
            success: false,
            displayMessage: 'Unknown block rule type: $type',
          );
      }

      ConflictResolutionResult conflicts = ConflictResolutionResult.empty;
      if (type != 'subject' && senderEmailForConflictCheck != null) {
        conflicts = await _conflictResolver.removeConflictingSafeSenders(
          emailAddress: senderEmailForConflictCheck,
          ruleProvider: ruleProvider,
        );
      }

      String patternCategory;
      String patternSubType;
      String sourceDomain;
      int executionOrder;

      switch (type) {
        case 'from':
          patternCategory = 'header_from';
          patternSubType = 'exact_email';
          sourceDomain = trimmed;
          executionOrder = 40;
          break;
        case 'exactDomain':
          patternCategory = 'header_from';
          patternSubType = 'exact_domain';
          sourceDomain = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
          executionOrder = 30;
          break;
        case 'entireDomain':
          patternCategory = 'header_from';
          patternSubType = 'entire_domain';
          sourceDomain = trimmed;
          executionOrder = 20;
          break;
        case 'subject':
          patternCategory = 'subject';
          patternSubType = 'exact_domain';
          sourceDomain = trimmed;
          executionOrder = 60;
          break;
        default:
          patternCategory = 'header_from';
          patternSubType = 'exact_domain';
          sourceDomain = trimmed;
          executionOrder = 30;
      }

      final conditions = type == 'subject'
          ? RuleConditions(type: 'OR', subject: [pattern])
          : RuleConditions(type: 'OR', header: [pattern]);

      final rule = Rule(
        name: ruleName,
        enabled: true,
        isLocal: true,
        executionOrder: executionOrder,
        conditions: conditions,
        actions: RuleActions(delete: true),
        metadata: {
          'comment':
              'Created from $sourceDescription on ${DateTime.now().toIso8601String().substring(0, 10)}',
        },
        patternCategory: patternCategory,
        patternSubType: patternSubType,
        sourceDomain: sourceDomain,
      );

      await ruleProvider.addRule(rule);
      await ruleProvider.loadRules();
      await ruleProvider.loadSafeSenders();

      if (conflicts.conflictsRemoved > 0) {
        displayMessage +=
            ' (removed ${conflicts.conflictsRemoved} conflicting safe sender${conflicts.conflictsRemoved > 1 ? "s" : ""})';
      }

      // Copilot review (Sprint 46): do not log the rule name or raw pattern
      // -- both embed user-entered email addresses/domains.
      _logger.i('[OK] Created block rule (type: $type, '
          'patternLength: ${pattern.length})');
      return RuleQuickActionResult(
        success: true,
        displayMessage: displayMessage,
        conflictsRemoved: conflicts.conflictsRemoved,
        createdRule: rule,
      );
    } catch (e) {
      _logger.e('[FAIL] Failed to create block rule: $e');
      return RuleQuickActionResult(
        success: false,
        displayMessage: 'Failed to create rule: $e',
        error: e,
      );
    }
  }

  /// BUG-S39-1 (Sprint 39): preserves `_`, `-`, `@`, `.` so distinct inputs
  /// (e.g. `account_update@amazon.com` vs `account-update@amazon.com`)
  /// produce distinct rule names, avoiding a UNIQUE-constraint collision on
  /// the `rules.name` column.
  String _sanitizeForRuleName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9._@-]'), '_');
  }
}
