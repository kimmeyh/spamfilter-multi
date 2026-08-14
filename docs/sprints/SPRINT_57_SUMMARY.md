# Sprint 57 Summary

**Branch**: `feature/20260813_Sprint_57`
**PR**: [#314](https://github.com/kimmeyh/spamfilter-multi/pull/314)
**Issues**: #313, #312
**Dates**: 2026-08-13 -> 2026-08-14
**Retrospective**: `docs/sprints/SPRINT_57_RETROSPECTIVE.md`

**Note**: created ahead of the normal cadence (SUMMARY is usually written during the NEXT sprint's planning, after merge) per Harold's 2026-08-14 standing instruction that every sprint have all three docs with no exceptions. PR #314 is ready for review but not yet merged as of this writing -- the Merge section below will need a final update once that happens.

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1,857 -> **1,864** passing / 0 failing / 29 skipped |
| Analyzer | Clean |
| Windows build | Green (built + launched twice: once pre-manual-validation, once with the Scan Again fix) |
| Manual Validation | Complete (Harold) -- Scan Again fix confirmed; a live-production investigation resolved to a non-issue |
| Carry-forward | None (F143/F144 explicitly deferred per plan, not carried mid-sprint) |

## Scope

Approved 2026-08-13 as F142 only; expanded 2026-08-14 to include F149. Plus 2 mid-sprint testing-feedback follow-ups.

| Task | Feature | Result |
|---|---|---|
| 1 | F142 | Android navigation model -- shared default-screen pattern, dead-end bottom-nav shell removed |
| 2 | F149 | Safe-sender Inbox/Bulk oscillation fix (AOL) -- pre-move target-folder duplicate check |
| -- | Follow-up | "Scan Again" now triggers Live Scan directly instead of returning to Manual Scan |
| -- | Follow-up | Version bump corrected to 0.7.0 (MINOR) instead of the requested 0.6.3, per the enforced semver policy |

## What shipped

**F142 -- Android navigation model.** `MainNavigationScreen`'s bottom-nav shell had 2 of 3 tabs as dead-end placeholders requiring an `accountId` the shell had no mechanism to supply. Removed the `Platform.isAndroid` branch entirely; both platforms now render the same default-screen decision (renamed `_DesktopDefaultScreen`/`desktopDefaultScreenFor` to `_AppDefaultScreen`/`appDefaultScreenFor` since both platforms share it). The "Review No Rule Items" AppBar icon stays Windows-gated this sprint -- an explicit decision (not a silent default), since `NoRuleReviewScreen`'s multi-item selection has no touch equivalent yet (F143, next sprint). New source-text policy gate confirms the removed scaffolding does not silently reappear.

**F142 manual validation blocked.** Attempting the Android-emulator on-device check failed the Android debug build outright at `:app:processDebugGoogleServices` -- a pre-existing, unrelated `google-services.json`/`applicationId` mismatch (F94), confirmed to block EVERY Android build, not just this change. Split out as **F150** for Sprint 58. Fallback verification used instead: since F142 introduced no Android-specific code path (both platforms now share one decision function), the Windows build/launch proof stands as strong indirect evidence.

**F149 -- safe-sender Inbox/Bulk oscillation fix.** Safe-sender messages on AOL were oscillating between Inbox and Bulk/Spam. AOL's own server-side rule independently demotes non-Outlook-safe-sender Inbox messages, and the app's safe-sender logic had no check for an existing duplicate in the target folder before re-promoting a candidate -- fighting AOL's rule every scan. Added `filterAlreadyInTargetFolder()`, a pre-move check reusing the existing `searchByMessageId` capability, alongside the existing F91 (Sprint 39) post-move source-folder dedup as a second, unchanged layer. Fails open on search errors. Root-caused via git history as an always-existing gap in F91's original design, not a regression (F91's own doc comments describe only source-folder reconciliation; no commit ever added, then removed, a target-folder check). 6 new mutation-verified tests extending the existing F91 fake-IMAP harness.

**Testing-feedback follow-ups (same sprint).** "Scan Again" on the Results screen used to replace itself with the Manual Scan screen, requiring a second tap to actually re-scan. Extracted the Live Scan start logic into a shared top-level `startRealScan()` function; "Scan Again" now calls it directly with `useReplacement: true`. Separately, a version-bump request (0.6.3) conflicted with the enforced semver policy since `[Unreleased]` contained F142's `feat` entry -- surfaced explicitly and resolved to 0.7.0 per policy.

**Live-production investigation (Manual Validation).** A "disappeared" no-rule email (present in one Live Scan, absent from the next, later found in Trash) was investigated with full code-path elimination -- the scan itself never acts on no-rule emails, and neither F91 nor F149's new code ran (both require a safe-sender match). A controlled reproduction (move the email back, re-run both scans while monitoring logs live) did NOT recur. Harold's own hypothesis -- that the PRODUCTION background-scan job, running its own independent 15-minute cycle against the same real mailbox, could have deleted it via an existing rule -- was confirmed exactly via the production background-scan log: a delete fired at the precise timestamp the email vanished, matched by an existing `firstliberty` rule. Not an app defect; a timing coincidence between the dev testing session and production's normal, correct background cycle.

## Retrospective

All 14 categories rated Very Good. 1 improvement, applied: the Tooling-Capability Pre-Flight rule (`docs/SPRINT_PLANNING.md`) extended to cover manual-validation steps that depend on an external build/environment succeeding at all, not just bolting a new capability onto a tool -- sourced from F142's Android-build assumption gap (F150).

## Merge

_(Pending as of this writing -- PR #314 marked Ready for Review 2026-08-14. Update this section once Harold merges: merge date, Post-Merge Cleanup confirmation for issues #313/#312, and Phase 6.6 carry-forward branch details.)_
