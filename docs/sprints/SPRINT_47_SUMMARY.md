# Sprint 47 Summary

**Branch**: `feature/20260711_Sprint_47`
**PR**: [#272](https://github.com/kimmeyh/spamfilter-multi/pull/272) -- "Sprint 47: Store 0.5.4 manual-testing feedback (F119, F112-F118)"
**Issues**: not recorded (PR body/commits show 0 GitHub issues open during this sprint's backlog-refinement entries)
**Dates**: 2026-07-11 -> 2026-07-18 (per `ALL_SPRINTS_MASTER_PLAN.md` Past Sprint Summary table)
**Retrospective**: `docs/sprints/SPRINT_47_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1,758 pass / 29 skip at Phase 7 retro commit; 1,761 pass / 29 skip after the post-merge Copilot-review fix commit |
| Analyzer | Clean |
| Windows build | Green (Phase 5 manual verification per PR test-plan checklist) |
| Manual Validation | Store-installed 0.5.4 build tested by Harold (source of the 8 feedback items); post-fix re-validation of F112-F118 occurred later, on the Sprint 49 (0.5.7-candidate) build, 2026-07-22 -- all items closed "Working as expected" per `ALL_SPRINTS_MASTER_PLAN.md` |
| Carry-forward | F33 prod-DB apply + `cleanup_body_rules.dart` decode-failure fix deferred to Sprint 48 (Harold pre-merge release-review decision, decoupled from the Store release) |

## Scope

8 items from Harold's manual testing of the Store-installed 0.5.4 build (backlog-refined 2026-07-15), approved as full scope:

| Task | Feature | Result |
|---|---|---|
| 1 | F119 (P8) | Store MSIX shipped running as `APP_ENV=dev`. Root cause: `pubspec.yaml` msix_config used the wrong key `build_windows_args`; the `msix` package (3.16.x) reads `windows_build_args`, so the wrong key was silently ignored and the inner `flutter build windows` ran with no dart-defines. Fixed the key, added `test/policy/msix_config_test.dart` as a build-failing gate, corrected `STORE_RELEASE_PROCESS.md` (3 places) and added a mandatory Step 4.0 verification step |
| 2 | F112 (P20) | "Review No Rule Items" entry point added to Scan History AppBar, centered above the "No Rule: N" chip, and the shared Settings AppBar (covers all 4 tabs) -- reused the Sprint 46 `account_selection_screen.dart` pattern |
| 3 | F113 (P22) | Provider-keyed new-account default profiles: AOL (Inbox/Bulk/Bulk Mail) and Gmail (INBOX/[Gmail]/Spam/Unwanted) folder defaults, Manual/Background scan setting defaults, Export CSV defaulted ON |
| 4 | F114 (P24) | `defaultScanHistoryRetentionDays` 7 -> 90, `defaultUnmatchedRetentionDays` 30 -> 90 (fresh-install only, no migration) |
| 5 | F115 (P26) | Review-No-Rule selection bar reordered: Apply Rule (left) -> N selected -> Clear |
| 6 | F116 (P28) | Demo Scan completion now navigates to `ResultsDisplayScreen` (chips/buttons) instead of an inline results `ListView`, matching Live Scan; dropped the intermediate "N/M processed" counter |
| 7 | F117 (P30) | Help footer replaced the hardcoded "Last updated: Sprint 40" literal with a runtime `package_info_plus` version read (Class-2 decision: package dependency chosen over a gate-enforced literal, per Harold's stated preference for always-accurate source-derived values) |
| 8 | F118 (P32) | Post-Store-release housekeeping: CHANGELOG dated, dev version bump 0.5.4 -> 0.5.5 across all version-consistency-gated literals, stray Android Gradle cache files un-tracked (`.gitignore` rule added), `secrets.prod.json` currency confirmed |

## What shipped

**F119 (Store build-integrity defect, first of a 3-sprint family)**. The Store-installed 0.5.4 MSIX ran as a dev build (`[DEV]` title, dev data directory, empty OAuth credentials) because `msix_config.build_windows_args` in `pubspec.yaml` was not a key the `msix` package recognized -- it silently ignored the block, so the packaged build never received `--dart-define=APP_ENV=prod`. The fix renamed the key to `windows_build_args` and added `test/policy/msix_config_test.dart` to fail the build if the typo'd key ever reappears. This was the first of three related root causes (F119, then F119-b in Sprint 48, F119-c in Sprint 49) that produced the same `[DEV]`-title symptom across three sprints before the family was fully closed.

**UX/onboarding feedback items (F112-F118)**. Six smaller items addressed specific Store-testing feedback: a consistent "Review No Rule Items" entry point across three surfaces, provider-keyed default scan folders and settings for new accounts, longer default data-retention windows, a reordered selection bar, Demo Scan matching the Live Scan completion flow, and a self-updating Help footer. A follow-up Copilot-review round on PR #272 (before merge) found and fixed two correctness gaps in F113: `providerDefaultFolders()` mis-parsed dashed local-parts in email addresses, and the new provider defaults were applied only at the settings-display layer, not at the actual scan call sites -- both fixed in the same PR.

**Retrospective improvements (5 proposed, all applied)**:
- IMP-1: augmented `SPRINT_N_PLAN.md` task template in `SPRINT_PLANNING.md` (Value/R-N/AC-N/T-N/Deps/NFRs/Task-Level DoD/Definition of Ready), from a research spike on sprint-card best practices.
- IMP-2: `docs/CODING_VELOCITY.md` actuals-logging codified as a Task-Level DoD item; backfilled all 8 Sprint 47 items plus the 5 IMP items into the Coverage Ledger.
- IMP-4: `test/policy/version_consistency_test.dart` and `check-version-consistency.ps1` extended to sweep `test/` too (closes the F118 hardcoded-versioned-filename class).
- IMP-5: new `test/policy/stale_footer_test.dart` flags hardcoded "Sprint N"/"Last updated" literals in `lib/ui/` (the F117 class) -- immediately caught and fixed a stale "coming in Sprint 12-13" placeholder on the Rules tab.
- IMP-3: `.claude/hooks/block-carry-forward-stash.ps1` PreToolUse hook blocking `git stash` during carry-forward, wired into `.claude/settings.json` -- initially blocked because `.claude/` writes require Harold approval in don't-ask mode; applied after Harold's one-time approval, verified live (hook fired on its own verification command).

## Deferred at pre-merge release review

Harold's pre-merge decisions (2026-07-18) kept two items out of the Sprint 47 -> `develop`/`main` release path and moved them to Sprint 48: F33 prod-DB `--env prod --apply` (local SQLite file, not bundled in the MSIX, zero Store-user impact) and the `cleanup_body_rules.dart` decode-failure report-not-delete fix (latent, dev-only script, must land before the F33 apply). Nothing else gated the `develop` -> `main` release.

## Follow-up captured for Sprint 48

Two candidates were logged from the Copilot review round on PR #272: F-PRECHECK (a pre-PR self-review checklist targeting recurring Copilot finding-classes -- mirror/parallel-site drift, helper-not-wired-into-real-path, doc-vs-code drift, fragile input parsing, API-scope mismatch, silent failure) and F-COPILOT-INSTR (audit past review rounds for more repeat classes plus a budget-fit trim of `.github/copilot-instructions.md`, then at ~4618 lines vs an ~4000 soft budget).
