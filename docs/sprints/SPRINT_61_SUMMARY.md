# Sprint 61 Summary

**Dates**: 2026-08-16 to 2026-08-21
**Branch**: `feature/20260816_Sprint_61` | **PR**: #347 -> develop
**Scope**: Task 0 (line-ending normalization, Issue #340), F170 (Release Cycle encoding, Issue
#341, ran first as assigned), F169 (account filter dropdown, Issue #338), F168 (background
folder-scope warning, Issue #339), F172 (AppBar version label, Issue #342), F171 (1024x640
minimum-window sweep, Issue #343), F162 (parity audit + ADR-0042, Issue #344), F167 (Help
capability wording, Issue #345), F161 (Android background-scan scheduler, Issue #346). Same-window
context: 0.10.0.0 / Submission 17 uploaded 2026-08-16 21:51, CERTIFIED 22:17 (~26 minutes) -- the first
real submit-to-live measurement (10-minute polling; the old ~51-minute figure was
observation-cadence bias; recorded in `docs/STORE_SUBMISSION_TIMING.md`).

## What Shipped

- **F161 (headline)**: Android background-scan scheduling as the canonical ADR-0042 platform
  factory. The per-account scan orchestration was extracted VERBATIM from the Windows worker into
  `BackgroundScanCore` (both platforms run the identical pipeline and persist identically);
  `BackgroundScanScheduler` defines the shared contract with `WindowsSchedulerAdapter` (Task
  Scheduler), `AndroidSchedulerAdapter` (per-account WorkManager unique work, 15-minute floor,
  network constraint, UPDATE policy), and the explicitly-named `UnsupportedPlatformScheduler`
  no-op; `AndroidBackgroundScanWorker` mirrors the Windows preamble and posts completion
  notifications, with POST_NOTIFICATIONS requested contextually. **Validated for CORRECTNESS
  on-device**: Harold's manual-vs-background count-parity experiment PASSED -- identical rule
  outcomes on every email both scans evaluated (20/20 in-window email_actions rows matched
  exactly; all arithmetic closed). The Google Play SHIPMENT PREREQUISITE is met.
- **F170**: the post-merge Release Cycle encoded as **Phase 8** -- merge to `develop`, Harold's
  parallel `develop` -> `main` merge (a build-time precondition for the MSIX, not a blocker),
  Backlog Refinement pass 1 (completeness sweep), Store release, refinement pass 2 (scope
  selection), then Phase 3. Landed in SPRINT_EXECUTION_WORKFLOW.md (authoritative),
  SPRINT_CHECKLIST.md 8.1-8.5, BACKLOG_REFINEMENT.md (two-pass model; the mandatory-vs-on-demand
  contradiction fixed), CLAUDE.md, and both hooks (verify-closeout `pr_number` precondition;
  auto-advance Gate 1c release-cycle markers made deliberate).
- **F162 / ADR-0042**: cross-platform parity ADR ACCEPTED with Harold's platform-factories
  addition ("used sparingly, but when it meets the long-term architecture needs"). The
  code-level audit found no systemic divergence; per Harold's descope steering, no findings were
  manufactured to justify the estimate.
- **F169**: the Review No Rule Items account filter is a single-select dropdown (F166 pattern),
  default All Accounts, every account reachable at any width. Its phone-width tests also exposed
  and fixed a pre-existing ~105px selection-bar overflow.
- **F172**: `Version <n>.<n>.<n>` renders right of the `?` icon on all 8 major screens from the
  single runtime version source, `[DEV]` suffix preserved; deliberately suppressed below 600px
  (the one intentional width-dependent difference this sprint, confirmed by Harold on Android).
- **F168**: Settings warns when a background scan's folder scope omits the Inbox, explaining the
  consequence; a deliberate Bulk-only scope is not blocked.
- **F171**: automated 1024x640 sweep (no clipping) + Harold's live judgment checks PASS.
- **F167**: Help describes the capability ("the operating system's scheduler"), never
  per-platform mechanisms, and carries no unshipped-platform caveats; pinned by
  `help_platform_claims_test.dart`.
- **Task 0**: `.gitattributes` line-ending normalization (LF, with CRLF pins for Windows script
  types).

## Verification

- Full suite at close: **1,893 passed / 26 skipped / 0 failed**; `flutter analyze` clean; hook
  suite 49/49; every new gate mutation-verified (including the IMP-2 call-site gate, red on a
  re-added guard, and the auto-advance IMP-1 case that no pre-existing pattern would catch).
- Manual Validation complete 2026-08-20: Android F161 end-to-end (permission prompt, Test scan,
  notification, Scan History, DB rows, count-parity PASS), F169/F172 parity checks, Windows
  1024x640 and selection-bar checks PASS; the Windows background-scan-unchanged check (F161
  AC-4) carried to Sprint 62 validation at Harold's direction.

## Notable Process Events

- **The scan-cascade forensics day (2026-08-19)**: AOL scans sat `in_progress` at 0 emails for
  20+ minutes over a ~140-email mailbox. Root causes proven, not guessed: `daysBack=0`
  full-mailbox fetches balloon the app to 817MB-1.4GB PSS (~7-10MB retained per message) and
  Android LOW_MEMORY-kills it; WorkManager re-fires the killed task at every launch until it
  succeeds, stacking concurrent scans behind AOL's session cap. Contained with force-stops and a
  surgical WorkManager-state clear; registered as F177 (chunked fetch, m=20 universal) and F175
  (concurrency + orphan reconciliation + retry bounding) rather than hot-patched mid-validation.
- **MV round 1 caught the sprint's one escape**: both settings call sites of the F161 factory
  reroute kept their `if (Platform.isWindows)` guards -- Android persisted the setting but never
  scheduled work. Exactly the ADR-0042 silent-claim failure shape, one file from the 9
  mutation-verified adapter tests. Fixed same-day; now pinned by the IMP-2 policy gate.
- **Three turn-ending failures** during execution (announcing the next task, then ending the
  turn); Harold flagged each. Now mechanically blocked by the IMP-1 hook extension.
- Retro: Testing Approach "Needs improvement" (the escape above), Process Issues "Good" with the
  dev-team list, all else Good/Very Good. **All 4 proposed improvements approved ("all") and
  applied same-session.**

## Backlog Movement

- NEW: F173 (recurring test-coverage deep dive, HOLD template), F174 (silent empty-folder
  fetch), F175 (scan concurrency control + wait estimate), F176 (account email on scan screens),
  F177 (memory-bounded chunked IMAP fetch), F178 (Android review popup clips Block Subject);
  plus a Sprint 62 validation carry-over (Windows F161 AC-4 regression glance).
- DONE and pruned: F161, F162, F167, F168, F169, F170, F171, F172.
- F163 explicitly excluded from the sprint after verification (22 skip sites remain; unchanged
  in the backlog).
