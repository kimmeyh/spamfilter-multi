# Sprint 43 Summary

**Branch**: `feature/20260623_Sprint_43`
**PR**: [#265](https://github.com/kimmeyh/spamfilter-multi/pull/265)
**Issues**: none tracked as individual GitHub issues (work tracked via `docs/ALL_SPRINTS_MASTER_PLAN.md` backlog item IDs: F102, F103, F96, F100, F101, F104, F105, F110)
**Dates**: 2026-06-23 -> 2026-06-26
**Retrospective**: `docs/sprints/SPRINT_43_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | +1686 ~28 (per PR body; ~1658 at F102, ~1684 after F110, +1686 after Copilot-review fixes) |
| Analyzer | Clean |
| Windows build | Green |
| Manual Validation | Complete (Harold) |
| Copilot review | Complete, all comment threads resolved (0 unresolved) |
| Carry-forward | SEC-11b removed/deferred to Post-MVP (cipher switched to SQLite3MultipleCiphers); F106 cleanup gated on it moves with it |

## Scope

Approved 2026-06-23 (Phase 3.7): 7 items in execution order (SEC-11b removed from
the original 8-item plan before execution began, per Harold's 2026-06-24 direction).

| Task | Feature | Result |
|---|---|---|
| 1 | F102 | Logging-redaction policy (ADR-0030 Section 5) + enforcement gate (PowerShell CLI + Dart mirror); caught and fixed 13 pre-existing PII-in-log leaks |
| 2 | F103 | Architecture deep dive (F71 template instance); surfaced F107 (ADR-0037 status review) |
| - | SEC-11b | Removed from sprint, deferred to Post-MVP -- `sqflite_sqlcipher` driver is mobile-only (no Windows desktop support); cipher decision changed to SQLite3MultipleCiphers |
| 3 | F96 | F89 auth-state coverage for off-scan quick-add paths (Scan History reload + email-detail); DB v8 (`auth_classification` column); RED anti-phishing warning now fires off-scan |
| 4 | F100 | Ported the 6 read-only WinWright flows to the in-VM `integration_test` lane; retired the corresponding WinWright scripts |
| 5 | F101 | Background-scan DB-lock retry cap lowered 20 -> 15 (~15 min worst case, was ~20 min) |
| 6 | F104 | Security deep dive (F70 template instance); verified the F102 redaction gate GREEN; surfaced F108 (dependency major-bump review) |
| 7 | F105 | Dev version bump 0.5.3 -> 0.5.4 (5-file checklist) |
| - | F110 | Added mid-sprint (manual-testing driven): "Phishing SPF/DKIM/DMARC" CSV column + per-account-log failure lines; narrowed the F102 redaction rule to the user's own address only (third-party sender addresses now logged in the clear as the security signal); new `Redact.senderForLog` |

## What shipped

**Logging redaction policy (F102).** ADR-0030 gained a "Logging & Redaction"
section documenting the invariant: never log raw account ids, email addresses,
tokens, or email content. A two-lane enforcement gate
(`scripts/check-log-redaction.ps1` + `test/policy/log_redaction_test.dart`) fails
the build on any `Logger`/`_bgLog` call that interpolates raw PII without
`Redact.*`. Running the gate for the first time caught 13 pre-existing leaks
across `safe_sender_evaluator`, `account_maintenance_screen`,
`background_scan_worker`, `pattern_normalization`, `process_results_screen`, and
`folder_selection_screen`.

**Auth-state coverage for off-scan paths (F96).** Before this sprint, emails
reconstructed from the DB on the Scan History reload or email-detail quick-add
paths carried only From/Subject and always classified GREY, so the RED
anti-phishing warning could never fire off-scan. DB v8 adds a nullable
`auth_classification` column (persisting the `AuthClassification` enum, per
Harold's Class-1 decision at approval -- not raw headers) captured at scan time
and re-hydrated on both quick-add paths, including gating the inline
Scan-History "add safe sender" action behind the RED warning dialog for the
first time.

**Periodic deep dives (F103/F104).** F103 (architecture) found the codebase
healthy post-Sprint-42 doc refresh, with one real drift item: ADR-0037
(UI/Accessibility Standards) still marked "Proposed" despite the standards
being implemented -- filed as F107. F104 (security) confirmed the F102
redaction gate is mechanically enforced (zero violations) and surfaced F108
(several security-relevant dependencies due for a major-version review).

**Test-infra consolidation (F100).** The 6 read-only WinWright flows
(navigation, settings tabs, scan history, text selection, F25 rule-test, F35
rule-edit) were ported to the in-VM `integration_test` lane as
`read_only_flows_test.dart`, each pumping the screen directly against the F99
seeded temp DB. The corresponding WinWright scripts were retired.

**Phishing auth-failure visibility (F110, added mid-sprint).** Manual testing
with Harold surfaced a want for auth-failure visibility beyond the RED-dialog
gate: a new "Phishing SPF/DKIM/DMARC" column in the debug CSV/XLSX exports and
a failures-only line per email in the per-account scan log. Implementing this
required narrowing the F102 redaction rule (Class-1, approved): "do not log raw
email" now applies only to the user's own configured-account addresses, not
third-party senders, since the sender address is itself the security signal.
New `Redact.senderForLog(addr, userAccountEmails)` masks only the user's own
identity, matching by equality-or-suffix on the bare address to be
account-id-format-agnostic (a hyphenated-id parsing bug in the first cut of
this logic was caught and fixed during the PR #265 Copilot review).

**Build stability detour.** The Windows release build failed mid-sprint on a
native-asset build hook for `sqlite3`/`sqflite_common_ffi`. A `sqlite3` 2.x
downgrade was tried, briefly believed to fix it, then reverted after it broke
reading the real dev DB with a false "malformed schema code 11" error. Root
cause was a polluted build cache from previously killed build runs; a clean
rebuild resolved it with `sqlite3` 3.x retained. Documented as
`feedback_no_sqlite_downgrade` to prevent recurrence.

**SEC-11b removed from scope.** The originally planned `sqflite_sqlcipher`
driver for DB-at-rest encryption turned out to be mobile-only, with no Windows
desktop support -- blocking it on the app's primary platform. Harold directed a
switch to SQLite3MultipleCiphers (cross-platform) and deferred the full item to
the Post-MVP backlog rather than attempting a half-working driver mid-sprint.

## Retrospective improvements (both applied)

| ID | Improvement |
|---|---|
| IMP-1 | Cheapest-first model-assignment process (Haiku -> Sonnet -> Opus escalation ladder, with a mandatory "why not cheaper" note for any non-Haiku pick); Sprint 43 itself ran entirely on Opus with no per-task justification |
| IMP-2 | Sprint PR stays DRAFT through Phases 3-7, converted to Ready-for-Review at exactly one point (end of Phase 7.7); Sprint 43's PR was marked ready early, triggering an unwanted Copilot review on every subsequent commit |

## Lessons worth carrying

1. **A failing native-asset build hook is not necessarily a dependency
   problem.** The sqlite3 2.x downgrade was an unnecessary and harmful fix for
   what was actually a polluted build cache from killed runs.
2. **Piping long-running `flutter test` output through `grep`/`tail` hides
   liveness.** The pipe buffers to zero bytes until the process exits, making a
   healthy run look hung; run to a file and poll instead.
3. **A redaction/PII policy is only real once it is mechanically enforced.**
   The F102 gate found 13 pre-existing leaks that manual review across prior
   sprints had missed.
4. **A security-relevant rule can need narrowing, not just tightening.** F110
   showed that "never log raw email" was over-broad -- third-party sender
   addresses are themselves the security signal for phishing detection, so the
   rule was refined to protect only the user's own identity.
