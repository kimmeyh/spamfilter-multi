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

  const RuleQuickActionResult({
    required this.success,
    required this.displayMessage,
    this.conflictsRemoved = 0,
    this.error,
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
      String pattern;
      String displayMessage;

      switch (type) {
        case 'exact':
          final escaped = value.replaceAll('.', r'\.').replaceAll('@', r'@');
          pattern = '^$escaped\$';
          displayMessage = 'Added "$value" to Safe Senders';
          break;
        case 'exactDomain':
          final escaped = value.replaceAll('.', r'\.').replaceAll('@', r'@');
          pattern = '^[^@\\s]+$escaped\$';
          displayMessage = 'Added exact domain "$value" to Safe Senders';
          break;
        case 'entireDomain':
          final escaped = value.replaceAll('.', r'\.');
          pattern = r'^[^@\s]+@(?:[a-z0-9-]+\.)*' + escaped + r'$';
          displayMessage = 'Added entire domain "*.$value" to Safe Senders';
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
      String pattern;
      String ruleName;
      String displayMessage;

      switch (type) {
        case 'from':
          final escaped = value.replaceAll('.', r'\.').replaceAll('@', r'@');
          pattern = '^$escaped\$';
          ruleName = 'Block_${_sanitizeForRuleName(value)}';
          displayMessage = 'Created rule to block email "$value"';
          break;
        case 'exactDomain':
          final escaped = value.replaceAll('.', r'\.').replaceAll('@', r'@');
          pattern = '$escaped\$';
          ruleName = 'Block_ExactDomain_${_sanitizeForRuleName(value)}';
          displayMessage = 'Created rule to block exact domain "$value"';
          break;
        case 'entireDomain':
          final escaped = value.replaceAll('.', r'\.');
          pattern = r'@(?:[a-z0-9-]+\.)*' + escaped + r'$';
          ruleName = 'Block_EntireDomain_${_sanitizeForRuleName(value)}';
          displayMessage = 'Created rule to block entire domain "*.$value"';
          break;
        case 'subject':
          final escaped =
              value.replaceAll(RegExp(r'[.*+?^${}()|[\]\\]'), r'\$&');
          pattern = escaped;
          ruleName =
              'Block_Subject_${_sanitizeForRuleName(value.substring(0, value.length.clamp(0, 40)))}';
          displayMessage = 'Created rule to block subject containing "$value"';
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
          sourceDomain = value;
          executionOrder = 40;
          break;
        case 'exactDomain':
          patternCategory = 'header_from';
          patternSubType = 'exact_domain';
          sourceDomain = value.startsWith('@') ? value.substring(1) : value;
          executionOrder = 30;
          break;
        case 'entireDomain':
          patternCategory = 'header_from';
          patternSubType = 'entire_domain';
          sourceDomain = value;
          executionOrder = 20;
          break;
        case 'subject':
          patternCategory = 'subject';
          patternSubType = 'exact_domain';
          sourceDomain = value;
          executionOrder = 60;
          break;
        default:
          patternCategory = 'header_from';
          patternSubType = 'exact_domain';
          sourceDomain = value;
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
