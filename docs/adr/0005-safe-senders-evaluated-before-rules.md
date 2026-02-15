# ADR-0005: Safe Senders Evaluated Before Rules

## Status

Accepted

## Date

~2025-10 (project inception, formalized in RuleEvaluator design)

## Context

The spam filter evaluates each incoming email against two data sets:

1. **Safe sender list**: Trusted sender patterns that should never be filtered (whitelist)
2. **Spam filtering rules**: Conditions, actions, and exceptions that determine what to do with spam

The evaluation order matters: if rules are checked first, a poorly written rule could flag a trusted sender's email as spam. If safe senders are checked first, trusted contacts are always protected regardless of how aggressive the rules are.

Additionally, within each rule, there is a question of ordering: should conditions be checked before exceptions, or should exceptions pre-filter before conditions are evaluated?

Users expect two properties from a spam filter:
- **Whitelist reliability**: If they mark a sender as safe, that sender's emails must never be filtered
- **Predictable behavior**: The evaluation logic should be easy to reason about

## Decision

Implement a three-tier evaluation priority in `RuleEvaluator`:

1. **Safe senders checked FIRST** (global whitelist): If the sender matches any safe sender pattern, return immediately with a "safe" result. No rules are evaluated. The whitelist has absolute priority.

2. **Rules evaluated in ascending `executionOrder`**: For each enabled rule:
   - **Exceptions checked BEFORE conditions** (local pre-filter): If the email matches any exception pattern for this rule, skip the entire rule and move to the next one
   - **Conditions checked SECOND**: If the email matches the rule's conditions, apply the rule's action and return

3. **No match**: If no safe sender matched and no rule matched, return a "no action" result.

This creates two levels of exemption:
- **Global exemption** (safe senders): Email bypasses ALL rules entirely
- **Local exemption** (rule exceptions): Email bypasses ONE specific rule but continues to be evaluated against remaining rules

First matching rule wins - once a rule's conditions match (and its exceptions do not), that rule's action is returned without evaluating subsequent rules.

## Alternatives Considered

### Rules First, Then Safe Sender Override
- **Description**: Evaluate rules first to determine what action would be taken, then check safe senders to override/cancel the action
- **Pros**: Could provide information about what rules would have matched (useful for analytics)
- **Cons**: Wasted computation - evaluates all rules even when the sender is trusted; more complex logic to "undo" a matched rule; potential for bugs where override fails to cancel an action
- **Why Rejected**: Evaluating rules against known-safe emails is unnecessary work and introduces a failure mode where the override could malfunction, leading to trusted emails being filtered

### Parallel Evaluation (Check Both, Then Decide)
- **Description**: Evaluate safe senders and rules simultaneously, then resolve conflicts (safe sender wins ties)
- **Pros**: Could report both safe sender match and rule match for analytics
- **Cons**: More complex conflict resolution logic; no performance benefit over sequential evaluation; harder to reason about behavior; safe sender result is always the final answer anyway
- **Why Rejected**: Added complexity for no practical benefit. The safe sender result always takes priority, so evaluating rules in parallel just wastes computation

### Conditions Before Exceptions (Within Rules)
- **Description**: Check if an email matches a rule's conditions first, then check exceptions to cancel the match
- **Pros**: Slightly more intuitive for some users ("this rule matches, except for these senders")
- **Cons**: Evaluates potentially expensive condition patterns only to throw away the result if an exception matches; exceptions are typically simpler patterns (single sender) while conditions can be complex (multiple header patterns)
- **Why Rejected**: Checking exceptions first is a performance optimization (exceptions are typically simpler and faster to evaluate) and produces the same logical result. If the exception matches, the rule is skipped regardless of whether conditions would have matched

## Consequences

### Positive
- **Whitelist reliability**: Users can be confident that marking a sender as safe guarantees their emails will never be filtered, regardless of how aggressive the spam rules are
- **Predictable behavior**: The three-tier priority (safe senders > exceptions > conditions) is easy to explain and reason about
- **Performance**: Safe sender patterns are typically simple (email address or domain match) and checked first, providing an early exit for trusted emails. Within rules, exceptions pre-filter before expensive condition evaluation
- **Two-level exemption**: Users have both global (safe sender) and per-rule (exception) tools for managing false positives

### Negative
- **No analytics for safe emails**: Because safe sender emails skip all rule evaluation, users cannot see which rules would have matched a safe sender's email. This information could be useful for rule tuning
- **Order sensitivity**: The `executionOrder` field determines which rule matches first for non-safe emails. If users do not understand execution order, they may get unexpected results when multiple rules could match

### Neutral
- **First-match semantics**: Only the first matching rule's action is applied. This is simpler than accumulating actions from multiple matching rules but means rule ordering matters

## References

- `mobile-app/lib/core/services/rule_evaluator.dart` - Evaluation logic (lines 20-81: priority order, lines 30-38: safe sender check, lines 52-56: exception check, lines 58-72: condition check)
- `mobile-app/lib/core/models/rule_set.dart` - Rule model with executionOrder field
- `mobile-app/lib/core/models/safe_sender_list.dart` - Safe sender patterns
- `mobile-app/lib/core/models/evaluation_result.dart` - Result types including safeSender
- GitHub Issue #18 - Comprehensive RuleEvaluator test suite (32 tests, 97.96% coverage)
