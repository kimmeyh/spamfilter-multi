# ADR-0006: Four Progressive Scan Modes

## Status

Accepted

## Date

~2025-10 (readonly and test modes at inception); 2026-01-04 (fullScan mode added, Phase 3.1)

## Context

A spam filter that can delete or move emails carries significant risk. A misconfigured rule can silently destroy important emails. Users need a way to gain confidence in their rules before enabling destructive operations.

The project experienced this risk firsthand: Issue #9 documented a bug where readonly mode was not properly enforced, resulting in 526 emails being permanently deleted during what the user believed was a safe, read-only scan. This incident demonstrated that scan mode enforcement is safety-critical and must be architecturally robust.

Users have different risk tolerances and use cases:
- **New users**: Want to test rules without any risk
- **Tuning users**: Want to see what rules and safe senders would do independently
- **Confident users**: Want full automated filtering with both rules and safe senders active

## Decision

Implement four scan modes with progressively increasing levels of action, defined as the `ScanMode` enum in `EmailScanProvider`:

| Mode | Display Name | Rules Executed | Safe Senders Executed | Risk Level |
|------|-------------|----------------|----------------------|------------|
| `readonly` | Read-Only | No (proposed only) | No (proposed only) | None |
| `testLimit` | Process Rules Only | Yes | No | Medium |
| `testAll` | Process Safe Senders Only | No | Yes | Low |
| `fullScan` | Process Safe Senders + Rules | Yes | Yes | High |

**Enforcement mechanism**: `EmailScanner` calculates two boolean flags before processing any email:
```
canExecuteRules = mode is not readonly AND mode is not testAll
canExecuteSafeSenders = mode is not readonly AND mode is not testLimit
```

All action methods are gated on these flags. In readonly mode, actions are logged with a `[READONLY]` prefix and results are recorded with `success: false` so the UI shows what would have happened without actually doing it.

**Default mode**: `readonly` (safest option). Users must explicitly select a more permissive mode.

## Alternatives Considered

### Two Modes Only (Readonly + Execute)
- **Description**: Simple binary toggle - either scan without acting or scan with full action
- **Pros**: Simpler UI; fewer options to confuse users; straightforward implementation
- **Cons**: No way to test rules independently from safe senders; no graduated confidence-building; users jump directly from zero risk to full risk with no intermediate step
- **Why Rejected**: The jump from "do nothing" to "do everything" is too large. Users need intermediate steps to build confidence, especially after the Issue #9 incident demonstrated the consequences of unintended actions

### Confirmation Per Email
- **Description**: Ask the user to confirm each action (delete/move) before executing it
- **Pros**: Maximum control; user sees and approves every action
- **Cons**: Impractical for large mailboxes (hundreds or thousands of emails); defeats the purpose of automated filtering; interrupts the scan workflow repeatedly
- **Why Rejected**: The spam filter processes potentially thousands of emails per scan. Per-email confirmation is not scalable and defeats the automation purpose

### Dry-Run with Undo
- **Description**: Execute all actions but maintain an undo log that can reverse them
- **Pros**: Users see real results; can undo mistakes; feels safe
- **Cons**: "Undo" is unreliable for email (permanently deleted emails cannot be restored from some providers); undo log adds storage and complexity; creates false confidence that actions are reversible when they may not be; maintaining undo state across sessions is complex
- **Why Rejected**: Email deletion may not be reversible depending on the provider and timing. An undo mechanism that sometimes fails is worse than a preview mechanism that always works

### Percentage-Based Execution
- **Description**: Execute actions on a configurable percentage of matching emails (e.g., process 10% first, then 50%, then 100%)
- **Pros**: Graduated risk; statistical sampling
- **Cons**: Which 10% gets processed is arbitrary; harder to reason about; users cannot predict which emails will be affected; percentage does not map well to user intent
- **Why Rejected**: Users think in terms of "test my rules" or "filter everything", not "filter 10% of my email". The semantic modes (readonly, rules-only, safe-senders-only, full) map better to user intent

## Consequences

### Positive
- **Safety by default**: New users start in readonly mode with zero risk of data loss
- **Graduated confidence**: Users can progress from readonly to rules-only to full scan as they gain confidence in their configuration
- **Independent testing**: Rules and safe senders can be tested independently, making it easier to debug which component is causing unexpected behavior
- **Incident prevention**: The four-mode system with boolean enforcement flags prevents the class of bug that caused Issue #9 (526 emails deleted in what was intended as a safe scan)
- **Proposed action visibility**: Readonly mode shows what would happen without doing it, giving users full visibility into filter behavior

### Negative
- **UI complexity**: Four modes require explanation and UI space for a mode selector, warning dialogs, and mode-specific result labels
- **Mode confusion**: Users may not immediately understand the difference between "Process Rules Only" and "Process Safe Senders Only", especially since the display names were refined over multiple sprints
- **Testing matrix**: Four modes multiply the test scenarios for email scanning, requiring tests for each mode's enforcement behavior

### Neutral
- **Mode names evolved**: The display names changed during Sprint 14 to be more descriptive (from technical names like "testLimit" to user-friendly names like "Process Rules Only"), indicating that the naming is a UX challenge separate from the architectural decision

## References

- `mobile-app/lib/core/providers/email_scan_provider.dart` - ScanMode enum (lines 22-28), display names (lines 184-196)
- `mobile-app/lib/core/services/email_scanner.dart` - Mode enforcement flags (lines 193-198), readonly prevention (lines 280-290)
- `mobile-app/test/integration/email_scanner_readonly_mode_test.dart` - Regression test for Issue #9 (lines 11-22)
- GitHub Issue #9 - Readonly mode bypass bug (526 emails deleted)
- GitHub Issue #32 - Full Scan mode added (Phase 3.1, Jan 4, 2026)
- `CHANGELOG.md` - Phase 3.1 entry documenting fullScan addition
