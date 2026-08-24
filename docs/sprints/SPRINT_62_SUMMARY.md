# Sprint 62 Summary

**Dates**: 2026-08-21 to 2026-08-23
**Branch**: `feature/20260821_Sprint_62` | **PR**: #355 -> develop
**Scope**: F177 (memory-bounded chunked fetch, Issue #349), F175 (scan concurrency control +
wait estimate, Issue #351), F174 (silent empty-folder fetch, Issue #350), F178 (Android popup
clips Block Subject, Issue #352), F176 (account email on scan screens, Issue #353), F163
(skipped-tests remediation, Issue #354), plus the Sprint 61 F161 AC-4 Windows validation
carry-over. Same-window context: 0.11.0.0 / Submission 18 uploaded ~10:10 2026-08-22,
CERTIFIED AND LIVE ~10:41 (~25-30 minutes at 5-minute polling, confirming the ~26-minute
Sprint 61 measurement).

## What Shipped

- **F177 (headline)**: scans fetch mail in bounded batches of 20 (`fetchBatchSize`, universal
  -- no folder-size threshold on purpose), evaluate each batch, and retain only
  body-truncated records (`copyWithTruncatedBody`, 100-char preview cap), with progress
  reported per batch. **Survival PASS on the previously-fatal case**: the daysBack=0 AOL scan
  (181 emails, all folders) that repeatedly died LOW_MEMORY in Sprint 61 completed in 6m17s
  with no kill -- peak ~1.0GB PSS vs 817MB-1.4GB WITH death, in-flight ~1.6MB/message vs
  ~6MB. Outcome equivalence pinned by test (batching changes how messages are held, never
  verdicts). Residual peak (full bodies through fetch+evaluation) registered as **F180**.
- **F175**: `ScanCoordinator` -- FIFO in-process lease serializing manual/background/test/demo
  scans at ONE chokepoint (`EmailScanner.scanInbox`), with a declared ADR-0042 exception
  (Windows background scans run in a separate process; F109 owns cross-process exclusion).
  Cross-process DETECTION is database-backed and platform-uniform: starting a manual scan
  during a background scan shows a wait notice naming the scan with a rolling-average
  completion estimate. Background scans hung past 30 minutes fail loudly AND (post-review
  fix) release their lease; startup reconciliation marks orphaned `in_progress` rows
  `interrupted` (29 cleared on-device, including the Sprint 61 forever-running class);
  disabling background scanning also cancels the stuck `_test` retry. **Harold's Class-1
  decision on the R-7 evaluation: fully-independent Manual/Background settings tabs are the
  deliberate design -- DECLINED, do not re-raise.**
- **F174**: an unlistable/empty search sequence is an explicit logged non-event instead of a
  swallowed exception; genuine per-folder fetch failures now surface in the scan's errorCount
  while remaining folders complete.
- **F178**: two rounds. Round 1 (safe-area clamps) was INERT on-device -- Scaffold/SafeArea
  consume inherited MediaQuery padding, and the flat test harness kept padding the production
  tree strips, so its test lied green; caught by Harold's screenshot. Round 2, per Harold's
  direction: compact widths BOTTOM-ANCHOR the popup (the Windows small-window pattern) using
  unconsumable root-view insets (`MediaQueryData.fromView`, `useSafeArea: false`). PASS from
  both test rows.
- **F176**: `AccountEmailLabel` (shared widget) shows the account email in the scan screens'
  bodies and the results summary -- phone titles truncate behind action icons, leaving no
  in-body account identification. Same on both platforms.
- **F163**: 11 approved remediations live -- read-only enforcement rebuilt as REAL
  full-pipeline coverage, the delete-recoverability trio live on both adapters via new test
  seams, the Gmail no-auth trio un-skipped, the yaml backup test fixed. Skips 26 -> 15, all
  deliberate keeps.
- **CI**: draft-PR pushes no longer run CI (jobs fire at Ready-for-Review); the Linux-only
  scheduler test failure root-caused -- `Workmanager()`'s constructor REPLACES injected fakes
  on hosts with a platform branch (silently vacuous on CI) -- and fixed with
  `setUpAll(Workmanager.new)`.

## Verification

- Full suite at close: **1,931+ passed / 15 skipped / 0 failed**; `flutter analyze` clean;
  hook suite 51/51; mutation verification throughout (including the C-2 owner-match gate and
  the long-body retention test that replaced a mutation-surviving vacuous loop).
- Manual Validation complete 2026-08-22, every item disposed (F177 survival PASS, F175 live
  wait-notice + reconciliation PASS, F178 round 2 PASS, F176 PASS both platforms, F161 AC-4
  PASS).
- Phase 5 evidence pass 2026-08-23: automated code review (2 critical / 3 high / 4 medium --
  all verified before acting; C-2 real and fixed, C-1 honestly downgraded to
  unreachable-but-guarded after a fakeAsync reproduction attempt), F-PRECHECK six classes
  clean (recorded on PR #355), WinWright sweep green with `sweep-head` recorded.

## Notable Process Events

- **The D: drive vanished mid-close-out** (2026-08-23): the entire volume dropped between a
  confirmed file write and the next test run. Recovery was trivial because everything was
  pushed; the one interrupted write was recovered byte-exact from its temp file.
- **Phase 5 evidence steps ran late**: MV started while development was hot and
  5.1.1/5.1.2/5.1.5 were silently unrun -- caught by the line-by-line checklist walk before
  Phase 7. The late review then found C-2 AFTER Harold had validated. Now mechanically gated
  (retro IMP-1/IMP-2: close-out hook checks 3d/3e, Sprint 63+).
- **The WinWright sweep found Sprint 61's rot**: F169 (chips -> dropdown) shipped without a
  sweep, so all three scripts' chip selectors rotted silently -- the Sprint 52-58 class
  recurring one sprint after the artifact rule was added. Repaired live (dropdown face needs
  physical mouse clicks; runner still replays no ww_wait -- settle buffers documented);
  f129 retired as a strict subset of mt2c (retro IMP-5).
- Retro: Harold -- Testing "Needs improvement as noted by dev team during sprint", Process
  "Good - see issues noted by dev team", all else Good/Very Good; Cats 13/14 "none". **All 7
  improvement proposals decided "all as recommended": 5 applied same-session, 2 to backlog
  (F182, F183).**

## Backlog Movement

- NEW: F179 (subject-phrase picker, HOLD -- GenAI-gated), F180 (fetch/eval body caps, P10),
  F181 (remove testLimit option, P18), F182 (mt2c seeding preamble, P30), F183 (upstream
  ww_wait request, HOLD -- external).
- DONE and pruned: F163, F174, F175, F176, F177, F178 (+ the F161 AC-4 carry-over closed).
- Sprint 63 carry-ins (Cat 13, Claude): E2E coverage for the new UI surfaces (F178 popup /
  F175 dialog / F176 label); watch CI's first live run on PR #355; (f129-into-mt2c merge
  executed in-retro, no longer a carry-in).
