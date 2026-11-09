# ADR-0052: A Persisted Default Account; the Session Selection Stays Unpersisted

## Status

Accepted (Harold, 2026-11-07, Sprint 84 Manual Validation, q6 = a). It changes the F135 decision of 2026-07-30
("does not need to be persisted between sessions") for the default account only. Implementation is backlog card F352
(next sprint). Until F352 ships, the code still matches F135.

## Date

2026-11-07

## Context

`SelectedAccountProvider` (`mobile-app/lib/core/providers/selected_account_provider.dart`) holds the account chosen
during a session. F135 (Sprint 51, Harold 2026-07-30, option A) made it session-only on purpose: the selection resets
when the app closes, and the app must not start straight on the last account's screen. The class comment says: "If
that changes, persist via `SettingsStore`; do not add a second source of truth here."

Harold, 2026-11-07: let the user set one email account as the default, or have no default. When the app starts, the
default account is the selected account. The app still works normally when the user selects another account during
the session.

Screens that read the selection today: Settings (`settings_screen.dart:335,351`), Scan History
(`scan_history_screen.dart:99`), Review No Rule Items (`no_rule_review_screen.dart:245`), Help (`help_screen.dart:138`).
The start screen is Review No Rule Items when accounts exist (`main_navigation_screen.dart:84-94`).

## Decision

1. **One stored value.** `SettingsStore` keeps an app-wide `default_account_id` in `app_settings`. No value means "no
   default". There is no second store.
2. **Where it is set (q4 = b).** Only on Select Account: each account row has a control to make it the default or to
   remove the default. Settings > Account shows a read-only label when the shown account is the default.
3. **Startup (q5 = a).** The start screen does not change. At startup, the default seeds `SelectedAccountProvider`
   once, so Settings > Account, Manual Scan and Background open on that account without the picker.
4. **The session selection stays unpersisted.** Picking another account changes only the session; it is forgotten when
   the app closes. The next start uses the default again.
5. **Deleting the default account clears the default**, in the same operation, so no stale id remains.
6. **No automatic default.** A single account does not become the default unless the user sets it.
7. **Background scans do not change.** They are per account (ADR-0039) and do not read the selection or the default.
8. **All platforms** use the same shared code (ADR-0042); there is no platform exception.

## Alternatives Considered

### Keep F135 unchanged (q6 = b)
- Pro: no persistence change.
- Con: the request cannot be met; the user picks the same account in every session.

### Persist the last session selection
- Pro: no new control.
- Con: the app follows whatever was picked last, which is the behavior F135 rejected, and the user cannot choose
  "no default".

### Set the default on both screens (q4 = a) or on Settings > Account only (q4 = c)
- Not chosen by Harold. Select Account is the one place where the default is set.

## Consequences

### Positive
- The user picks the account once, not once per session.
- One stored value with one writer path (Select Account) and one clear path (account delete).

### Negative
- A new `app_settings` key, and account deletion must clear it.
- The startup path reads one more setting before the first account-scoped screen.

### Neutral
- `SelectedAccountProvider` keeps its public interface; only its initial value changes.

## References
- Card F352 in `docs/ALL_SPRINTS_MASTER_PLAN.md`
- `docs/sprints/SPRINT_84_PLAN.md`, "Manual Validation decisions, round 2 (Harold, 2026-11-07)"
- F135, Sprint 51 retrospective IMP-3 (`docs/sprints/SPRINT_51_RETROSPECTIVE.md`)
- ADR-0039 (per-account background scans), ADR-0042 (platform parity)
