# Sprint 62 Plan

**Status**: DRAFTED 2026-08-22 -- awaiting Harold's Phase 3.7 approval. Scope selected by Harold at
Phase 8.4 refinement pass 2 (2026-08-22).
**Branch**: `feature/20260821_Sprint_62` | **PR**: draft, created at Phase 3.3.1
**Theme**: Scan robustness (the Sprint 61 MV root causes) + MV follow-up UX + test-suite hygiene.

**Standing constraint (Harold, restated at scope selection)**: everything accounts for BOTH the
Windows app and the Android app under ADR-0042 -- functionally and UI the same unless it cannot
be, and where it cannot be, implemented as a declared platform exception for exactly what is
needed. This applies to backend code, frontend code, data, architecture, development, security,
testing, and deployment. Every card below carries a Platform NFR stating its parity posture.

**Category 13 carry-ins from Sprint 61 (applied here)**:
1. Manual Validation includes the Windows background-scan regression check (F161 AC-4) -- see MV
   section.
2. `sprint_status.json` `github_issues` was emptied at this sprint's branch rollover (done
   2026-08-21), not at card closure.

**Task order**: Task 1 (F177) -> Task 2 (F174, same adapter file -- serialized) -> Task 3 (F175)
-> Task 4 (F178) -> Task 5 (F176) -> Task 6 (F163). Rationale: F177 and F174 touch
`generic_imap_adapter.dart` and must not interleave; F175's wait-estimate math benefits from
F177's faster, bounded scans; the UX and test tasks are independent.

---

### Task 1 -- F177: Memory-bounded, chunked IMAP fetch with incremental progress (Priority 8)

**Value**: This prevents the proven LOW_MEMORY kill cascade (817MB-1.4GB PSS from unbounded
full-mailbox fetches) and ends the "0 emails for 20+ minutes" progress blindness.

**Requirements** (numbered, detailed):
- R-1: Within-folder message fetching proceeds in batches of **m = 20 UIDs, applied universally**
  (no folder-size threshold -- parameters set with Harold 2026-08-19). A 3-message folder is one
  batch of 3; a 137-message folder is 7 batches.
- R-2: Each batch is fetched, evaluated, and persisted before the next batch is fetched; message
  references from a completed batch are released (not accumulated in a whole-folder list).
- R-3: Scan progress is reported to the provider at every batch boundary (fetched-so-far /
  total-UIDs for the folder), so the UI and logs show movement during long fetches.
- R-4: Behavior is identical for daysBack-bounded scans, daysBack=0 "scan all" scans, and the
  no-rule backlog re-scan path -- batching changes HOW messages are fetched, never WHICH.
- R-5: The Gmail API adapter path is checked for the same unbounded-accumulation shape; if it
  pages already, record that as confirmed; if not, apply the same batch bound.

**Affected components / files**:
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` -- `fetchMessages` /
  `fetchMessagesIncremental` gain the batched fetch (UID list already known up front; chunk it).
- `mobile-app/lib/core/services/email_scanner.dart` -- consume per batch
  (fetch-evaluate-persist-release loop) instead of whole-folder lists.
- `mobile-app/lib/core/providers/email_scan_provider.dart` -- per-batch progress updates (extend
  the existing progress-throttling mechanism, do not bypass it).
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` -- R-5 check.

**Dependencies / blockers**: None. Task 2 (F174) touches the same adapter file -- serialized
after this task.

**Non-functional requirements**:
- Platform: SHARED code, identical on Windows and Android (ADR-0042 -- no exception needed; the
  memory ceiling that motivates it is Android's, the correctness is universal).
- Persistence: per-batch persistence must keep the existing scan_results single-row-per-scan
  model -- counts accumulate into the same row; no schema change.
- Performance: batching must not add a per-batch IMAP reconnect; one session per folder as today.

**Acceptance criteria** (measurable, traceable):
- AC-1: A folder with more than 20 matched UIDs is fetched in ceil(n/20) batches; no code path
  requests message content for more than 20 UIDs in a single IMAP FETCH.
- AC-2: Progress callbacks fire at least once per batch with monotonically increasing counts.
- AC-3: Scan outcomes (found/processed/deleted/safe/no-rule counts and persisted rows) for a
  multi-batch folder are IDENTICAL to the pre-change single-fetch outcomes for the same message
  set.
- AC-4: The daysBack=0 path and the backlog re-scan path both batch (no full-list bypass
  remains).
- AC-5: R-5 recorded: Gmail path either confirmed already-bounded (with evidence) or bounded.

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (AC-1) -- TEST-UNIT in `test/adapters/generic_imap_adapter_chunked_fetch_test.dart`:
  against the established fake IMAP client seam, a 47-UID folder produces FETCH requests of
  20/20/7, in order.
- T-2 (AC-2) -- TEST-UNIT same file: progress callback sequence is per-batch and monotonic.
- T-3 (AC-3) -- TEST-UNIT in `test/unit/services/email_scanner_*`: outcome-equivalence for a
  multi-batch folder vs the same messages in one batch (counts and persisted rows equal).
- T-4 (AC-4) -- TEST-UNIT: daysBack=0 and backlog-cursor paths assert batched fetching.
  (Mutation-verify T-1 and T-3: raise m to 10_000 -> T-1 red; drop the release step -> memory
  assertion not directly testable, so T-3 pins outcome-equivalence instead -- state this limit.)

**Definition of Done**: default task-level DoD PLUS:
- On-emulator sanity run against the AOL account (daysBack=0, the previously-fatal case) with
  `dumpsys meminfo` sampled during the scan -- PSS stays under ~600MB (vs 817MB-1.4GB before).
  This is evidence for the fix's purpose, not a CI gate.

**Model**: Sonnet -- *why not the cheaper tier*: multi-file fetch-loop restructuring across
adapter/scanner/provider with a memory-lifecycle invariant; beyond Haiku heuristics (4+ files,
core scan path). Not top-tier: the design (m=20, per-batch loop) is already fixed and recorded.

**Executed-by** (filled at completion): Fable 5 -- single-session sprint execution (continuity
with the in-context design decisions outweighed tier hand-off; same reasoning as Sprint 61).

**COMPLETION NOTES (2026-08-22)**: DONE, ~75m of 60-100m est. All ACs met:
- AC-1: every UID FETCH bounded to `GenericIMAPAdapter.fetchBatchSize = 20` (adapter test pins
  20/20/7 for a 47-UID folder; mutation m=10000 -> red).
- AC-2: per-batch monotonic progress via the adapter `onBatch` handoff -> scanner `batchSink`
  (incrementFoundEmails + updateProgress per batch).
- AC-3: outcome equivalence pinned by a full `scanInbox` demo test against an INDEPENDENT
  unbatched evaluation of the same messages -- identical safe/delete/move/no-rule counts.
- AC-4: both the full-fetch (daysBack=0) and backlog-cursor incremental paths batch (adapter
  test covers fetchMessagesIncremental streaming with correct cursor).
- AC-5 / R-5: Gmail's network granularity is already per-message (messages.get per id); its
  RETURNED list is bounded by the scanner's m=20 slicing, which feeds ALL list-returning paths
  (Gmail/demo/mock) through the same evaluateBatch sink as the streamed IMAP path.
- **Documented deviation from R-2's literal wording** (implementation choice, recorded): each
  batch is fetched, evaluated, and reduced to a `copyWithTruncatedBody(kBodyPreviewMaxLength)`
  record before the next fetch -- but PERSISTENCE stays at the established post-6b points,
  preserving the Issue #144 two-phase batch-action design and the plan's own single-row
  scan_results NFR. The memory intent (bounded retention, per-batch release) is met by
  truncation: full bodies are evaluated, never retained. Verified no consumer reads more than
  the 100-char preview (UI reads no `.body` at all).
- **Test-vacuity catch worth keeping**: demo mock bodies are ALL under the 100-char cap, so the
  first retention assertion passed even with truncation removed (mutation survived). Fixed with
  a long-body (50KB x 25) provider injected via the new
  `PlatformRegistry.overrideFactoryForTest` seam -- non-vacuous by construction, and the
  truncation mutation now goes red. Four mutations verified red total.
- New test seams: `GenericIMAPAdapter.debugSetImapClient` (fake ImapClient, scripted
  SEARCH/FETCH), `PlatformRegistry.overrideFactoryForTest` (restore-in-tearDown contract).
- On-emulator memory DoD check deferred to MV (with Harold's daysBack=0 AOL run -- the
  previously-fatal case), as planned.

**Step-types**: SVC-EDIT+TEST-UNIT

**Est-Effort**: 60-100m (SVC-EDIT multi-file actuals: F147 ~50m single-file; this is 3 files +
outcome-equivalence tests)

_**Risk & rollback**_: Scan-correctness risk on the core path -- mitigated by T-3
outcome-equivalence and the full-suite gate; rollback is reverting to the single-fetch path
(no schema/data change involved).

---

### Task 2 -- F174: Per-folder IMAP fetch failure is silent (Priority 20)

**Value**: This prevents a scan from looking healthy while silently skipping a whole folder
(the F168 silent-scope class in miniature).

**Requirements**:
- R-1: An empty UID SEARCH result returns an empty message list WITHOUT attempting a UID FETCH
  (the confirmed root cause: building a fetch sequence from zero UIDs throws
  `InvalidArgumentException`, which the catch converts to "0 messages, errors=0").
- R-2: A GENUINE per-folder fetch failure (exception other than the empty-result case) increments
  the scan's errorCount and is visible in the scan record -- no longer indistinguishable from a
  clean empty folder.

**Affected components / files**:
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` -- empty-search guard
  (post-Task-1 code).
- `mobile-app/lib/core/services/email_scanner.dart` -- per-folder error surfacing into
  errorCount.

**Dependencies / blockers**: Task 1 lands first (same file; the batching loop is what R-1 guards
feed into).

**Non-functional requirements**:
- Platform: SHARED code, identical on both (ADR-0042 -- no exception).

**Acceptance criteria**:
- AC-1: A folder with messagesExists=0 (the live-confirmed `[Gmail]/Spam` case) yields 0 messages,
  0 errors, and NO exception in the log.
- AC-2: A folder whose fetch throws a non-empty-result exception yields errorCount >= 1 on the
  scan record while the remaining folders still complete.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT in `test/adapters/generic_imap_adapter_chunked_fetch_test.dart`: empty
  folder returns empty list, no throw, no error increment.
- T-2 (AC-2) -- TEST-UNIT in `test/unit/services/email_scanner_*`: injected fetch failure on
  folder 2 of 3 -> errorCount 1, folders 1 and 3 scanned. (Mutation-verify: restore the silent
  catch -> T-2 red.)

**Definition of Done**: None -- default DoD only.

**Model**: Haiku -- fix shape fully specified with confirmed root cause, 2 files, established
test seams.

**Executed-by** (filled at completion): Fable 5 -- single-session sprint execution (same
justification as Task 1).

**Step-types**: SVC-EDIT+TEST-UNIT

**Est-Effort**: 20-35m

**COMPLETION NOTES (2026-08-22)**: DONE, ~25m. AC-1: empty and unlistable search sequences
return an empty list with no FETCH attempted and no throw (adapter tests cover both, including
a `fromAll()` star-sequence modeling the live failure shape). AC-2: a genuine per-folder fetch
failure increments the scan's errorCount via the new `EmailScanProvider.recordFolderFetchError`
(chosen over `recordResult(success:false)`, which would have polluted the no-rule counters and
persisted a fake unmatched row) while surrounding folders complete -- proven end to end with an
injected failing folder; mutation (silent catch restored) goes red. Three files touched
(adapter guard, provider method, scanner catch); analyze clean.

---

### Task 3 -- F175: Scan concurrency control -- mutual exclusion + active-scan detection with wait estimate (Priority 12)

**Value**: This prevents the stacked-concurrent-scan cascade (4 scans queued behind AOL's session
cap, all stuck at 0 emails for 20+ minutes) and tells a user starting a manual scan WHY they
should wait and roughly how long.

**Requirements** (Harold's verbatim intent, 2026-08-19, decomposed):
- R-1: Background scans do not run concurrently with each other on a device (per-account AND
  cross-account -- they share one SQLite DB and one process on Android).
- R-2: Background scans do not run concurrently with manual live scans.
- R-3: A manual live scan started while a background scan is active DETECTS it and notifies the
  user to wait, presenting an average background-scan completion time where reasonably computable
  (rolling average from scan_results started_at/completed_at per scan_type/account).
- R-4: A scan that exceeds a timeout is terminated and its scan_results row marked failed with an
  error message -- no more forever-`in_progress` rows.
- R-5: On app startup, stale `in_progress` rows from dead processes are reconciled (marked
  `interrupted`), including the existing orphans (rows 44-60 class).
- R-6: The WorkManager retry-forever behavior is bounded: disabling background scanning cancels
  the pending TEST one-off as well as the periodic work, and a crashed task does not re-detonate
  indefinitely (bounded backoff/retry policy).
- R-7 (evaluation deliverable, NOT implementation): the F168 R-3 settings-interplay question --
  independent Manual/Background folder scopes AND Scan Range values have each caused one real
  surprise; deliver a written recommendation (shared selection with explicit per-type opt-out vs
  status quo) for Harold's decision at MV. Class-1 decision -- surface and WAIT, do not implement.

**Affected components / files**:
- `mobile-app/lib/core/services/scan_coordinator.dart` (NEW) -- shared mutual-exclusion +
  active-scan registry + average-duration query.
- `mobile-app/lib/core/services/background_scan_core.dart` + `android_background_scan_worker.dart`
  -- acquire/release around scans; timeout wrap.
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` (manual-scan start path) -- detection
  dialog with wait estimate.
- `mobile-app/lib/core/services/background_scan_scheduler.dart` -- R-6 cancel-test-task +
  backoff policy on registration.
- `mobile-app/lib/core/storage/scan_result_store.dart` -- startup reconciliation + average query.

**Dependencies / blockers**: Task 1 (F177) first -- bounded scan durations make the wait estimate
meaningful.

**Non-functional requirements**:
- Platform (ADR-0042, the load-bearing NFR): the coordinator contract and detection UX are
  SHARED. **Declared platform exception**: on Windows, background scans run in a SEPARATE
  headless process (Task Scheduler), where the existing F109/ADR-0039 foreground-deferral +
  per-account task serialization ALREADY provide cross-process exclusion -- the in-process
  coordinator cannot see across processes there, and duplicating the OS-level mechanism is not
  needed. The exception is recorded in the coordinator's doc comment citing ADR-0042, and the
  Windows manual-scan path still gets R-3's detection via the existing background-scan mutex
  probe (`windows/runner` exposes it) where available. Both branches tested per the ADR rule.
- Data: no schema change; `interrupted`/`failed` reuse the existing status column values.

**Acceptance criteria**:
- AC-1: Starting a second background scan while one runs on Android queues or refuses it; the
  two never execute concurrently (coordinator-level test).
- AC-2: Given a background scan in progress, When the user starts a manual live scan, Then a
  notice appears naming the active background scan and an average completion time (or "no
  history" fallback), and the manual scan does not open a second IMAP session until the user
  proceeds past the notice or the background scan completes.
- AC-3: A scan exceeding the timeout ends with status `failed` and a timeout error message;
  no scan_results row remains `in_progress` after its process dies (startup reconciliation
  marks it `interrupted`).
- AC-4: Disabling background scanning cancels BOTH the periodic unique work and any pending
  test one-off; a task that fails N times stops retrying (bounded policy asserted at
  registration payload level).
- AC-5: The R-7 recommendation is written into this plan's completion notes and surfaced to
  Harold at MV -- no settings-model change implemented this sprint.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT in `test/unit/services/scan_coordinator_test.dart`: exclusion,
  queue/refuse semantics, release-on-failure (a crashed scan releases the lock).
- T-2 (AC-2) -- TEST-WIDGET in `test/ui/screens/scan_progress_concurrency_test.dart`: detection
  dialog renders with the average (and the no-history fallback).
- T-3 (AC-3) -- TEST-UNIT in `test/unit/storage/scan_result_store_test.dart`: reconciliation
  marks stale in_progress rows `interrupted`; timeout marks `failed`.
- T-4 (AC-4) -- TEST-UNIT extend `background_scan_scheduler_test.dart`: cancel targets both
  unique names; registration payload carries the bounded backoff policy.
  (Mutation-verify T-1: remove the lock -> red; T-4: revert cancel to periodic-only -> red.)

**Definition of Done**: default DoD PLUS:
- On-emulator demonstration of AC-2 live (manual scan during a Test background scan) recorded in
  completion notes -- the exact scenario that burned 2026-08-19.

**Model**: Fable/Opus -- *why not the cheaper tier*: concurrency design with a cross-process
platform exception to reason through (the one place this sprint where ADR-0042 judgment, not a
fixed recipe, decides the shape); Sonnet heuristics cover multi-file work but not novel
concurrency-abstraction design on the core scan path.

**Executed-by** (filled at completion): Fable 5 -- as assigned.

**COMPLETION NOTES (2026-08-22)**: DONE (code); AC-2's live demonstration and AC-5's decision
are MV items as planned. Shipped:
- **`ScanCoordinator`** (NEW): FIFO async mutex with ONE acquisition chokepoint --
  `EmailScanner.scanInbox` acquires before any IMAP session opens and releases in its `finally`,
  so manual/background/test/demo scans are serialized in-process (R-1 + R-2); a queued waiter
  gives up with TimeoutException at its wait limit rather than waiting forever on a dead
  predecessor. Declared ADR-0042 exception documented in the class doc: Windows cross-process
  exclusion stays with F109/ADR-0039.
- **Detection + wait estimate (R-3)**: DATABASE-backed (`getActiveBackgroundScan`, age-guarded),
  so it sees the Windows worker's separate process too -- platform-uniform, no exception needed
  for detection. `startRealScan` shows the notice with `formatBackgroundWaitEstimate` (rolling
  average of the last 10 completed background scans via `getAverageScanDuration`; no history
  says so honestly). "Wait and start" proceeds into the coordinator queue; "Cancel" backs out.
- **Timeout (R-4)**: background scans are wrapped in `ScanCoordinator.scanTimeout` (30 min) in
  `BackgroundScanCore` -- a hung scan is marked `error` (timeout message) instead of sitting
  `in_progress` forever. Manual scans deliberately carry no timeout (a user is watching and can
  cancel); reconciliation is their backstop -- documented in the wrap's comment.
- **Reconciliation (R-5)**: `reconcileStaleInProgressScans` at app startup marks `in_progress`
  rows older than the timeout as `interrupted` (covers the Sprint 61 orphan rows 44-60 class on
  next prod/dev launch). Age guard makes it safe against a LIVE cross-process Windows scan.
- **R-6**: `cancel()` now also cancels the pending `_test` one-off (the Sprint 61 stuck-retry
  escape), and BOTH registrations carry `BackoffPolicy.exponential` + 10-minute delay so a
  killed task cannot re-detonate at every app launch.
- **Tests (14 new/updated, all mutation-relevant)**: coordinator contract (exclusion, FIFO,
  idempotent/stale release, wait-limit timeout) + an END-TO-END no-overlap proof running two
  concurrent real `scanInbox` calls (mutation: acquire removed -> red); store tests for
  reconcile/detection/average (manual + stale + errored rows excluded); estimate-wording units;
  scheduler cancel-both-names + backoff payload assertions. Dialog RENDERING is deliberately
  not widget-tested (needs the full account+DB screen harness); the wording function is
  unit-tested and the dialog itself is MV step 2 with the live demonstration DoD.

**R-7 RECOMMENDATION (Class-1, for Harold's decision at MV -- NOT implemented)**: Manual and
Background settings should move to ONE shared per-account selection (folders AND Scan Range)
with an explicit per-type override. Evidence: both independent-settings surprises were real
incidents -- Sprint 60 (background folder scope silently omitted Inbox while the manual scope
had it) and Sprint 61 MV (background Scan Range stayed 0 after the manual range was set,
re-triggering the full-mailbox fetch). In both cases the user changed the setting where they
expected it to apply and the background scan silently used something else. Proposed shape:
account-level "Scan folders" + "Scan Range" used by BOTH scan types by default; each Background
tab field becomes an opt-in "Override for background scans" that shows the inherited value when
off. The F168 warning and effective-settings resolution keep working unchanged (`getEffective*`
gains an inheritance step). Estimated ~2-3h with migration of existing overrides. Decision is
Harold's; status quo remains fully functional either way.

**Step-types**: SVC-NEW+SVC-EDIT+UI-MOVE+TEST-UNIT+TEST-WIDGET

**Est-Effort**: 70-110m

_**Risk & rollback**_: A wrong lock could BLOCK legitimate scans -- mitigated by
release-on-failure tests and the timeout (a stuck lock self-clears); rollback is removing the
coordinator acquire calls (isolated seams).

_**Decision-class interrupts**_: R-7 is an explicit Class-1 surface-and-wait item, delivered as
a recommendation at MV, never implemented unilaterally.

---

### Task 4 -- F178: Android review popup clips its bottom sections (Priority 14)

**Value**: This prevents "Block Subject" (and the block-rule row below it) from being unreachable
at phone height -- an action the user simply cannot perform.

**Requirements**:
- R-1: At phone height, the review popup's full content is reachable: either it fits, or its
  inner scroll extends to the true bottom (including "Block Subject" and the buttons below it).
- R-2: The popup's bottom edge never sits under the system status/navigation bars -- height and
  position math subtract view insets (the leading hypothesis: `MediaQuery.size.height` includes
  system bars, so the Sprint 60 clamp lets the bottom render under the nav bar).
- R-3: Windows popup placement (the Sprint 60 fix behavior) is unchanged.

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart` (~lines 1623-1700, the Sprint 60
  popup positioning block) -- safe-area-aware `popupHeight`/`maxTop`.

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform: SHARED widget; the fix is inset-awareness, which is a no-op where insets are 0
  (Windows) -- parity by construction, no exception (ADR-0042). R-3 pins it.

**Acceptance criteria**:
- AC-1: Given a phone-sized window with a simulated bottom system inset, When the popup opens
  from any list row and is scrolled to its end, Then the "Block Subject" row and the content
  below it are fully inside the safe area.
- AC-2: At a desktop-sized window with zero insets, popup position and cap match current
  behavior (regression pin).

**Tests to write**:
- T-1 (AC-1) -- TEST-WIDGET extend the Sprint 60 popup-fit test file: phone-height +
  `MediaQuery` padding simulation; assert the popup's bottom edge <= safe-area bottom and the
  last section is revealed at full scroll.
- T-2 (AC-2) -- TEST-WIDGET same file: zero-inset desktop case unchanged.
  (Mutation-verify T-1: revert to un-inset height -> red.)

**Definition of Done**: default DoD PLUS:
- Harold's on-emulator visual confirmation at MV (his two screenshots are the repro evidence).

**Model**: Haiku -- single widget file, confirmed hypothesis, existing test harness from the
Sprint 60 sibling fix. Escalate to Sonnet only if the inset hypothesis proves wrong.

**Executed-by** (filled at completion): Fable 5 -- single-session sprint execution.

**COMPLETION NOTES (2026-08-22)**: DONE, ~25m. The inset hypothesis held exactly. AC-1: new
phone-height test with a simulated 48px navigation-bar inset (FakeViewPadding) asserts the
popup bottom and the fully-scrolled "Block Subject" row stay inside the safe area; mutation
(un-inset math restored) goes red. AC-2: the two Sprint 60/F151e desktop regression tests pass
UNTOUCHED -- desktop is a no-op by construction (insets are zero). Test-environment note: the
new test runs at 500px width, not 411, because this screen's AppBar has a KNOWN unrelated
~21px icon overflow at 411 (the open F162 adaptation question) that throws in widget tests --
documented in the test. Harold's visual confirmation is the MV step.

**Step-types**: UI-MOVE+TEST-WIDGET

**Est-Effort**: 20-35m

---

### Task 5 -- F176: Show the account email on the Manual Scan and Live Scan screens (Priority 16)

**Value**: This prevents "which account is this scanning?" ambiguity the moment more than one
account is configured (Harold hit it live during multi-account MV).

**Requirements**:
- R-1: The Manual Scan screen and the Live Scan (scan progress/results) screen display the
  active account's email address, in small type so it fits phone width (Harold: "small in order
  to fit").
- R-2: The same display appears on Windows (Harold: "If not already on Windows screens, should
  probably be added there as well") -- one shared implementation.
- R-3: Long addresses ellipsize; the display never wraps the AppBar/header layout at 411px
  (the established phone-width test size).

**Affected components / files**:
- `mobile-app/lib/ui/screens/manual_scan_screen.dart` and
  `mobile-app/lib/ui/screens/scan_progress_screen.dart` -- account-email line (follow the
  Settings Background tab's Sprint 38 header precedent for style/source of truth).

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform: SHARED, identical on both (ADR-0042 -- no exception).
- Account-scoping: reads the CURRENT account's identity from the existing account context --
  no new state.

**Acceptance criteria**:
- AC-1: With an account selected, both screens render its email; with a long address at 411px
  width there is no overflow (ellipsis instead).
- AC-2: Demo Mode shows its demo identity (or omits the line) -- no crash, no misleading real
  address.

**Tests to write**:
- T-1 (AC-1) -- TEST-WIDGET in the two screens' existing test files: email rendered; 411px
  long-address overflow guard (the F169 pattern).
- T-2 (AC-2) -- TEST-WIDGET: demo-mode rendering. (Mutation-verify: remove the line -> T-1 red.)

**Definition of Done**: None -- default DoD only.

**Model**: Haiku -- two-screen mechanical UI addition with a named precedent and existing
harnesses.

**Executed-by** (filled at completion): Fable 5 -- single-session sprint execution.

**COMPLETION NOTES (2026-08-22)**: DONE, ~20m. Premise corrected by reading the code first:
both screens ALREADY show the email in their AppBar titles -- the gap is phone-width title
truncation behind the action icons (exactly Harold's MV experience). Delivered as one shared
`AccountEmailLabel` widget (small type, single-line ellipsis, renders nothing for an empty
email -- the demo-safety AC-2 answer) in ScanProgressScreen's header and ResultsDisplayScreen's
summary card; identical on both platforms, no exception. AC-1 pinned incl. a 411px
absurd-address no-overflow test; mutation (label removed) red. R-2 satisfied: the label IS the
Windows addition too (shared body render).

**Step-types**: UI-MOVE+TEST-WIDGET

**Est-Effort**: 15-30m

---

### Task 6 -- F163: Skipped-tests remediation -- the 11 approved update-to-working verdicts (Priority 26)

**Value**: This converts 11 permanently-skipped tests into working coverage of real safety
promises (delete recoverability, read-only enforcement) per Harold's blanket approval of the
F160 dispositions.

**Requirements** (the 4 approved work items, verbatim from the F160 record):
- R-1: gmail_api_adapter no-auth error-path tests -- channel-stub seam, or discontinue if the
  adapter cannot run stubbed (fallback pre-approved by Harold).
- R-2: delete_to_trash safety trio -- adapter mock-seam investigation (guards
  delete-recoverability, the highest-value item).
- R-3: email_scanner_readonly_mode group -- rebuild against the current provider architecture
  (read-only enforcement is the product's core safety promise, currently uncovered).
- R-4: yaml_migration backup-creation test -- fix the assert-timing race.

**Affected components / files**:
- The 7 test files carrying the 22 skip sites (enumerated in the F160 decision table,
  SPRINT_60_PLAN.md Task 1); production seams ONLY where a test needs an injection point
  (`@visibleForTesting`, no behavior change).

**Dependencies / blockers**: None. Independent of Tasks 1-5 (but runs LAST so any new Task 1-3
seams are stable).

**Non-functional requirements**:
- Platform: tests run on the shared suite; any new seam is shared code (ADR-0042 -- no
  exception).
- Testing: every un-skipped test is mutation-verified (break the guarded behavior -> red) --
  the F160 audit exists precisely because skipped tests were proving nothing.

**Acceptance criteria**:
- AC-1: Standing skip count drops from 26 by the number of tests un-skipped; each remaining
  skip in the touched files is one of the 15 approved keeps.
- AC-2: R-1's fallback, if taken, is recorded per test with the reason (discontinued, not
  silently deleted).
- AC-3: No production behavior change: `flutter analyze` clean and the full suite green with
  zero non-test source diffs beyond `@visibleForTesting` seams.

**Tests to write**: The task IS tests -- the 11 verdicts above; each mutation-verified.

**Definition of Done**: None -- default DoD only.

**Model**: Sonnet -- *why not the cheaper tier*: R-2/R-3 require designing mock seams against
the current adapter/provider architecture (the reason these tests rotted); R-1/R-4 alone would
be Haiku.

**Executed-by** (filled at completion): Fable 5 -- single-session sprint execution.

**COMPLETION NOTES (2026-08-22)**: DONE, ~70m. Skips 26 -> 15 (all approved keeps); suite
1,931 passed / 15 skipped / 0 failed.
- R-1: the three gmail no-auth tests needed NO channel stub -- their guard clauses are pure
  Dart (null `_gmailApi` -> fast StateError/failure); the skip reason was stale. Un-skipped
  as-is; the pre-approved fallback was not needed.
- R-2: delete-recoverability trio rewritten to run the REAL adapters: IMAP via the F177
  `debugSetImapClient` seam (asserts UID MOVE to Trash/Junk, expunge NEVER called; +1 bonus
  case for a configured deleted-rule folder), Gmail via a NEW `debugSetGmailApi` seam over a
  recording `http.BaseClient` (asserts the POST .../trash endpoint, asserts NO DELETE endpoint).
  The old skipped file contained mock classes wired to nothing. Mutation-relevant by
  construction (endpoint assertions).
- R-3: read-only enforcement group REBUILT to run the real full `scanInbox` pipeline (new
  `EmailScanner` `credStore` constructor seam + `PlatformRegistry.overrideFactoryForTest` +
  DB-loaded rules per the F160-recommended pattern). The core safety promise (read-only never
  calls `takeAction`; Issue #9's 526-deleted-emails class) is now REAL coverage;
  mutation (canExecuteRules forced true) goes red.
- R-4: the "timing" skip was a wrong-directory assertion -- the migration writes backups to
  `Archive/yaml_pre_migration_<ts>`, the test checked `backupDirectory`. Fixed to assert the
  real location AND the backup's pre-migration content.
- **OBSERVATION flagged for the backlog (not fixed -- out of scope)**: `ScanMode.rulesOnly`'s
  email test limit (user-reachable via account_setup_screen's scan-mode dialog) appears
  UNENFORCED at the platform layer since the Issue #144 batch architecture -- the provider
  still tracks `_emailTestLimit` per record, but phase 6b executes the whole batch without
  consulting it. The old skipped test's 2-of-5 expectation was therefore dropped rather than
  falsely pinned; registered for Harold's review at close-out.

**Step-types**: TEST-UNIT+SVC-EDIT(seams only)

**Est-Effort**: 60-120m (4 sub-items; R-2/R-3 carry unknowns, fallback paths pre-approved)

---

## Sprint totals

- **Estimated effort**: 245-430 minutes coding (~4-7h) across 6 tasks.
- **Model mix (cheapest-first)**: Haiku 3 (F174, F178, F176), Sonnet 2 (F177, F163),
  Fable/Opus 1 (F175). Planner/retro stay top-tier per SPRINT_PLANNING.md.
- **Cards**: GitHub issues created at Phase 3.3.1 (numbers recorded in `sprint_status.json`).
- **Draft PR**: created at Phase 3.3.1, stays DRAFT until end of Phase 7.7.

## MANUAL VALIDATION RESULTS (2026-08-22) -- COMPLETE, ALL ITEMS DISPOSED

- **F177 (survival run, the previously-fatal case)**: PASS. Manual daysBack=0 AOL scan (181
  emails, all folders) completed in 6m17s with progress moving throughout; no LOW_MEMORY kill
  (last sprint this exact case died repeatedly). Memory: peak ~1,006MB PSS vs the old
  817MB-1.4GB WITH death; in-flight cost ~1.6MB/message vs ~6MB. Registered **F180** (fetch/eval
  body caps) as phase 2 for the remaining peak -- full bodies through fetch+evaluation are the
  residual allocation source; Dart keeps freed heap pages mapped (no manual release exists; a
  live `am send-trim-memory` could not reduce it -- answered Harold's question empirically).
- **F175**: PASS. Wait notice rendered live with account name + rolling-average estimate
  ("average under a minute"); Cancel path verified live; queueing pinned by the automated
  no-overlap test. Startup reconciliation verified on-device: all 29 orphaned in_progress rows
  (incl. the Sprint 61 44-60 class) now `interrupted`, zero remaining. Copy nit fixed
  post-demo: sub-minute remainders now read "less than a minute remaining".
- **F175 R-7 DECISION (Harold, Class-1)**: recommendation DECLINED -- the fully-independent
  Manual/Background settings tabs are "correct and the desired behavior". Recorded as a
  deliberate Product Owner design decision; do not re-raise.
- **F178**: round 1 was INERT on-device (consumed MediaQuery padding read zero insets; the flat
  test harness kept padding and lied green) -- caught by Harold's first-row screenshot. Round 2
  redesigned per Harold's direction: compact screens BOTTOM-ANCHOR the popup (the Windows
  small-window pattern), insets from the unconsumable root view, useSafeArea false. **Harold:
  "popup looks good from both rows" -- PASS.**
- **F176**: PASS both platforms (labels visible in Harold's Windows and Android screenshots).
- **F161 AC-4 (Sprint 61 carry-over)**: PASS -- Harold: Windows Scan History "looks good".
- **testLimit observation -> F181 registered**: Harold decided the 50-email limit option is
  removed outright ("no longer appropriate... fully planned and executed with precision").
- **CI feedback**: draft PRs no longer run CI (fires at Ready-for-Review); the Linux-only
  scheduler-test failure root-caused (Workmanager singleton replaces injected fakes on hosts
  with a platform branch) and fixed.
- New backlog from MV: F179 (subject-phrase picker, GenAI-gated HOLD), F180, F181.

## Phase 5 evidence completed post-MV (2026-08-23)

Three mandatory Phase 5 items had no recorded evidence when the checklist was walked before
Phase 7; all three were executed on 2026-08-23:

- **5.1.2 F-PRECHECK**: all six classes ran against the sprint diff -- CLEAN. Full record in
  the PR #355 description (dogfood rule).
- **5.1.1 Automated code review** (`pr-review-toolkit:code-reviewer` on the 40-file sprint
  diff): 2 critical / 3 high / 4 medium findings; every one verified against the code before
  acting. Fixed in-sprint: C-2 (background-scan timeout never released the coordinator lease --
  the hung-scan case F175 exists for; new `releaseActiveByOwner`, owner-matched, mutation-
  verified test), C-1 (timed-out-waiter handoff guard -- analysis and a fakeAsync reproduction
  attempt showed the wedge interleaving is UNREACHABLE under the single-threaded event loop, so
  this is a zero-cost defensive guard, recorded honestly as such), H-1 (adapter wrapped the
  onBatch evaluation callback in the FETCH try/catch, relabeling scanner failures as
  FetchException -- hoisted out), H-3 (coordinator double-release and idle-after-timeout
  contracts pinned by new tests), M-1 (desktop show-above branch now respects safeTop),
  M-2 (width breakpoint unified on the fromView MediaQuery), M-3 (store defaults reference
  ScanCoordinator.scanTimeout instead of duplicated literals), M-4 (stray blank line), plus two
  F163 test-quality nits (vacuous retention loop removed; overclaiming reason reworded).
  NO CHANGE (intended design, now pinned by a test): H-2 -- getActiveBackgroundScan is
  deliberately NOT account-scoped, because the ScanCoordinator serializes ALL scans in the
  process regardless of account, so the wait notice must fire (and name the blocking account)
  across accounts. Verdicts: F174/F176/CI clean; F177/F175/F178/F163 findings all dispositioned
  above.
- **5.1.5 WinWright sweep (IMP-5 artifact)**: ran 2026-08-23, 3 active scripts (f37 + both f56
  remain documented exclusions). First run 0/3: f124/f129 hit a launch-flake class; the
  deterministic breakage was **F169 (Sprint 61) replacing the account-filter chips with a
  dropdown -- Sprint 61 shipped that UI change without a sweep, so all chip selectors rotted
  silently** (the exact Sprint 52-58 rot class; retro item). Repair, verified live against the
  running app: the dropdown face projects as a Text node (menu entries as Buttons), responds
  only to physical mouse clicks (InvokePattern reports success without opening the menu), and
  face clicks during the popup-close animation are swallowed -- the runner still replays no
  ww_wait (re-confirmed: it SKIPS the step), so f129 carries harmless resolving clicks on the
  screen title as settle buffers. mt2c baselines refreshed to the current unaddressed pool
  (@hiram.edu, @alphaxiv.org). Result after repair: **f124 PASS 31/31, mt2c PASS 29/29, f129
  PASS 19/19 (single-script rerun); DB drift none on every run**; full-sweep confirmation
  2026-08-23: **3/3 PASS (f124 31 steps, f129 19 steps, mt2c 29 steps), DB drift none**.
  Post-retrospective (IMP-5 retired f129 into mt2c): Windows binary REBUILT at HEAD and the
  final sweep re-run -- **2/2 PASS (f124 31 steps, mt2c 29 steps), DB drift none**.
  - sweep-head: d87b828
  - Post-sweep lib/ui commit `cc255b7` (Copilot review round): Scan History duration TEXT
    only ("Interrupted" for reconciled rows) -- no structural/selector change to any swept
    screen (the sweep only navigates Scan History and Backs out); pinned by its own widget
    test instead of a sweep re-run. Coverage gap per 5.1.5 step 5: none of the
  active scripts exercise this sprint's new UI (F178 bottom-anchored popup, F175 wait dialog,
  F176 AccountEmailLabel) -- Sprint 63 carry-in filed for that coverage (F99 integration_test
  is the right home for the dialog).

## Manual Validation -- planned steps (to be refined at Phase 5.3)

1. **F161 AC-4 carry-over (Windows, ~5m)**: open Windows Scan History and confirm scheduled
   background scans continued normally through the Sprint 61 scheduler refactor.
2. **F177/F175 live (Android)**: daysBack=0 AOL scan completes without a memory kill (the
   previously-fatal case); manual scan during a Test background scan shows the wait notice with
   an average.
3. **F178 (Android)**: the review popup reveals "Block Subject" at full scroll (Harold's repro).
4. **F176 (both)**: account email visible on both scan screens, both platforms.
5. **F175 R-7**: Harold decides the settings-interplay recommendation (Class-1).
