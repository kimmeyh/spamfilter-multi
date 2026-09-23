# Sprint 73 Plan -- APPROVED, IN EXECUTION

**Status**: **APPROVED 2026-09-23, Phase 4 EXECUTION.** Harold's amendments: MINOR bump 0.16.0,
F234 previews BOTH block rules and safe-sender moves, F229 MAY remove the Select Account icon at
phone width.
**Branch**: `feature/20260922_Sprint_73` | **PR**: #435 (draft)
**Version**: 0.15.3+6 -> **0.16.0+7** (done, Task 0)

**Scope requested by Harold, 2026-09-23**: F235, F232, F234, F229, F226, F205, F224 + F207.

**Store note**: 0.15.3 was NOT pushed to either store (Harold, 2026-09-22). Live remains 0.15.2 on
Play and 0.15.2.0 on the Microsoft Store, so **F219 AC-1 and F227 stay blocked** -- they need a
Play-INSTALLED build. Nothing in this sprint depends on a store release.

---

## ADR-0042 applies to EVERY task in this sprint

Harold, restated 2026-09-23: *"everything needs to take into account both the Windows App and the
Android app and ADR stating that everything should be functionally and UI the same unless it cannot
be - and where it cannot be it should be implemented as a platform exception for what is needed --
this applies to all backend code, frontend code, data, architecture, development, security,
testing, deployment."*

Two rules govern how that is satisfied, and the second is the one Sprint 70 paid for:

1. **A difference must be a DECLARED exception** -- narrow, justified, covering only what genuinely
   cannot be shared.
2. **A PARITY claim needs the SAME verification as an exception** (CLAUDE.md IMP-5, Sprint 70).
   "No exception needed" is not the safe default. For shared code touching OS-level behavior, the
   card NAMES the OS behavior assumed identical, or declares the exception. Sprint 70's F220 ran a
   lifecycle handler on every platform under a comment asserting nothing was platform-specific --
   but `AppLifecycleState.paused` means "your sockets are gone" on Android and merely "your window
   is not visible" on Windows, so it killed healthy Windows scans.

Every card carries a **`Platform parity`** line. Where behavior differs, BOTH branches are tested.

**Known platform asymmetries in this sprint's scope:**

- **Doze (F235)** is Android-only at the OS level -- a genuine declared exception.
- **Scan mode by environment** (`project_scan_mode_by_environment`): Windows DEV/Prod are READ-ONLY
  with background OFF; the Android closed test is the only build that acts on mail. This is a
  CONFIGURATION difference, not a code exception -- and **F234 makes it visible rather than
  silent**, which is the point of that card.
- **WinWright (F226)** is Windows-only tooling by nature.

---

## Task 0 -- Version bump (Phase 3.7.0b, at approval)

**Value**: This keeps a tester able to tell a dev build from what shipped (F190).

**Requirements**:
- R-1: Bump `version:`, `msix_config.msix_version` and the `+N` build number.
- R-2: **PATCH vs MINOR is Harold's call.** This sprint contains F234 and the F229 version strip,
  both of which are user-visible additions, so MINOR (0.16.0) is defensible. Recommendation:
  **PATCH 0.15.4+7**, because F234 is a safety/preview behavior rather than a new capability and
  F229 is provenance. Harold decides.
- R-3: `+7` regardless -- Play permanently consumes a versionCode.

**Affected components / files**: `mobile-app/pubspec.yaml`, `docs/STORE_VERSION_STATUS.md` dev row.
**Existing abstraction checked**: N/A. **Callers of any guard being changed**: none.
**User-reachable control**: N/A (the version STRING is F229's job).
**Dependencies / blockers**: Harold's R-2 decision.

**Acceptance criteria**:
- AC-1: `dev_version_ahead_test` and `version_consistency_test` both GREEN.

**Tests to write**: none new -- the two policy gates are the verification.
**Definition of Done**: default DoD PLUS both version gates green.
**Model**: Haiku -- *why not cheaper*: n/a, cheapest tier.
**Step-types**: DATA, DOCS
**Est-Effort**: 10-15m

**Platform parity**: one `version:` field feeds both platforms (ADR-0043). `msix_version` is
Windows-only by FORMAT and `+N` is Play-only in EFFECT, but both derive from that one field -- one
source of truth, not an exception.

**Decision-class interrupts**: Class-3 -- R-2 at approval.

---

## Task 1 -- F235: Make Android background scans actually fire in Doze (Priority 4)

**Value**: This makes background scanning actually run on a real phone, which is the feature's
entire point for closed-test users.

**Audit-first**: **Is any of this present? NO.** `grep` for `setExactAndAllowWhileIdle`,
`AlarmManager`, `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` across `android/` and `lib/` returns
nothing. Genuine build work. **Check the MERGED manifest, not the source** -- Sprint 70 recorded
that `FOREGROUND_SERVICE` and `WAKE_LOCK` arrive via workmanager and are invisible in the source.

**R-1 DETERMINATION -- COMPLETE, 2026-09-23. Source: Android's own alarm documentation
(developer.android.com/develop/background-work/services/alarms/schedule).**

**The answer changes the approach, and for the better: NO PERMISSION IS NEEDED AT ALL.**

| Method | Permission | Fires in Doze? | Timing |
|---|---|---|---|
| `setExactAndAllowWhileIdle()` | **SCHEDULE_EXACT_ALARM or USE_EXACT_ALARM** | Yes | Precise |
| `setAndAllowWhileIdle()` | **NONE** | **Yes** | Within ~1 hour |
| `set()` / `setInexactRepeating()` | None | **No -- respects Doze** | ~1 hour |

`setAndAllowWhileIdle()` **escapes Doze with no permission and no Play policy exposure whatsoever**.
Both exact variants carry a Play policy burden -- `SCHEDULE_EXACT_ALARM` is user-revocable and
subject to Play's exact-alarm policy, and `USE_EXACT_ALARM` is restricted to a narrow acceptable-use
list (alarm clocks, calendars). The documentation's own recommendation: *"Use
`setAndAllowWhileIdle()` for most use cases unless your app's core functionality requires precise
timing."*

**A spam filter does not require precise timing**, which is exactly the argument that would have
made the exemption route hard to defend at review. The same reasoning that weakens the permission
case strengthens the no-permission case.

**DECISION: use `setAndAllowWhileIdle()`. No permission, no policy risk, no Class-1 escalation.**

**The cost, stated plainly rather than buried**: a ~1 hour delivery window. Against the app's
frequency options that means:

- `every15min` (15) -- a 1-hour window is FOUR TIMES the interval. The schedule becomes
  approximate at best.
- `every30min` (30) -- still 2x the interval.
- `every1hour` (60) -- the window matches the interval; reasonable.
- `daily` (1440) -- the window is negligible.

**This is honest, not a defect.** Today at 15 minutes the scans often do not run AT ALL while the
phone is idle -- Harold's complaint was *"background jobs only run when the app is open and in view.
This completely renders background jobs as useless."* A scan that fires within an hour is strictly
better than one that does not fire. **R-6's honest caveat therefore stays and gets MORE accurate**
rather than softer: it should say the phone may delay scans by up to about an hour while idle.

**Deferred to Harold at Manual Validation, NOT blocking**: whether `every15min` should remain
offered on Android given the OS window, or whether the label should say "about every 15 minutes
when the phone is in use". No code depends on that answer -- the alarm works either way -- so the
work proceeds and the question is asked at the natural break.

**Requirements**:
- R-1: **COMPLETE -- see the determination above. `setAndAllowWhileIdle()`, no permission.**
- R-2: Android scheduling uses `setAndAllowWhileIdle()` (NOT the exact variant -- see R-1).
  Windows is untouched.
- R-3: **Reboot persistence.** An alarm does NOT survive a restart the way WorkManager persisted
  work does. A `BOOT_COMPLETED` receiver must reschedule, or this is a REGRESSION versus today.
- R-4: The 9-minute OS floor must be enforced or documented; the app's floor is 15 minutes, so it
  does not bind today, but a future lower frequency would be silently clamped.
- R-5: **Preserve the network constraint.** The current periodic task uses
  `Constraints(networkType: connected)`. An alarm has no such constraint, so the scan itself must
  check connectivity and defer gracefully rather than failing.
- R-6: **Keep the F217 honest-timing caveat.** Even an exact alarm can be delayed; soften the
  wording, do not delete it.

**Affected components / files**:
- `mobile-app/android/app/src/main/AndroidManifest.xml` -- permission + boot receiver
- `mobile-app/lib/core/services/background_scan_scheduler.dart:258` -- the Android scheduling path
- `mobile-app/lib/ui/screens/settings_screen.dart` -- soften the F217 caveat

**Existing abstraction checked**: `BackgroundScanScheduler` -- the card ADDS an Android
implementation behind the existing interface rather than a parallel scheduler. The factory already
owns the platform decision (F161).
**Callers of any guard being changed**: the scheduler's `schedule`/`cancel` are called from
`settings_screen.dart` (toggle + frequency) and `background_scan_core.dart`. Both go through the
interface, so neither changes -- **which is exactly what to verify rather than assume.**
**User-reachable control**: no NEW control. The existing Settings > Background toggle and frequency
selector must keep working unchanged.

**Dependencies / blockers**: R-1's permission determination. If it returns `USE_EXACT_ALARM`,
**STOP and surface** (Class-1).

**Non-functional requirements**:
- Security/privacy: an exact-alarm permission is scrutinized at Play review; the listing
  justification must be accurate, not persuasive (Sprint 66 IMP-2).
- Platform: Android-only by nature.

**Acceptance criteria**:
- AC-1: R-1 answered in writing, with the source, BEFORE implementation begins.
- AC-2: Given background scanning is enabled, When the phone is idle with the screen off, Then a
  scan fires within one interval + the OS tolerance.
- AC-3: Given the device reboots, When it comes back up, Then the schedule is restored without
  opening the app.
- AC-4: Windows is unaffected -- no new permission, no behavior change.
- AC-5: Given no network, When the alarm fires, Then the scan defers gracefully rather than
  recording an error.

**Tests to write**:
- T-1 (AC-1) -- DOCS: the permission determination recorded in the plan with its source.
- T-2 (AC-3) -- TEST-UNIT: the boot receiver reschedules.
- T-3 (AC-4) -- TEST-UNIT: the Windows path is untouched by the Android change.
- T-4 (AC-5) -- TEST-UNIT: no-network defers rather than errors.
- T-5 -- TEST-UNIT policy gate on the MERGED manifest: the permission appears exactly once.
- **What these do NOT catch** (IMP-1): none of them proves a scan actually fires while the phone is
  locked over a real interval. That is Harold's device, and it is the only evidence that matters
  for this card's VALUE.

**Definition of Done**: default DoD PLUS Harold confirms on the S24+ that a background scan fires
while the app is closed and the phone is locked, **and again after a reboot** (R-3).

**Model**: Sonnet -- *why not the cheaper tier*: native manifest work, a permission with
store-review consequences, and a platform-exception design.
**Step-types**: NATIVE-WIN (Android), SVC-EDIT, TEST-UNIT, DOCS
**Est-Effort**: 90-180m

**Platform parity**: **DECLARED EXCEPTION -- Android only, and genuine.** Verified per IMP-5: the
differing OS behavior is named -- Android's Doze/App Standby defers background work and requires an
explicit mechanism to escape it; **Windows has no equivalent arbiter**, its background scanning
being a scheduled task. The exception covers the SCHEDULING MECHANISM only; scan logic stays
shared. AC-4 and T-3 verify Windows is untouched.

**Risk & rollback**: R-3 is the real risk -- if the boot receiver is missed, background scanning
silently stops after every restart, which is WORSE than today. Rollback: revert to
`registerPeriodicTask`, which is one call site.

**Decision-class interrupts**: Class-1 if R-1 returns `USE_EXACT_ALARM`.

---

## Task 2 -- F232 mechanism B: a live batch fails 9 of 9 on a healthy connection (Priority 6)

**Value**: This closes the last half of a data-loss defect, and it is the first real use of the
diagnostic log Sprint 72 built specifically for it.

**Audit-first**: **Is it already diagnosed? NO -- and that is the point.** Mechanism A shipped.
What remains is a batch that RAN and failed with full signal, which the readOnly path cannot
produce. **Already eliminated, each with evidence**: shared-adapter interference
(`PlatformRegistry.getPlatform` returns a fresh instance), malformed UIDs (FALSIFIED -- every
`Email ID` in the device's own CSV exports is a clean integer), and cross-folder batching
(`moveToFolderBatch` does group by folder).

**Requirements**:
- R-1: **DIAGNOSE BEFORE FIXING.** Reproduce with the diagnostic log ON and capture which of
  NOT_CONNECTED / SERVER_REFUSED / SKIPPED fires. That single fact selects between the remaining
  hypotheses.
- R-2: Remaining candidates: `ScanCoordinator.acquire()` timing out behind a background scan
  (the 22:20 background scans were 5 minutes before the 22:25 failure -- **suggestive, NOT
  evidence**); stale-but-valid UIDs already moved by that scan; a credentials/connect failure.
- R-3: If the cause is lease contention, it overlaps Task 4 (F224/F207) -- **coordinate, do not fix
  it twice.**
- R-4: Fix only what the evidence names. If the diagnosis shows a cause outside this sprint's
  scope, record it and STOP rather than widening.

**Affected components / files**: unknown until R-1. Candidates:
`mobile-app/lib/ui/screens/results_display_screen.dart:3216-3248` (lease + credentials),
`mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` (the batch itself).

**Existing abstraction checked**: `ScanCoordinator` -- if the fix touches leasing, it changes an
existing member rather than adding one.
**Callers of any guard being changed**: to be enumerated once R-1 names the guard. **This line is
not optional here** -- Sprint 72's CRITICAL was exactly a guard changed without enumerating its
callers.
**User-reachable control**: N/A -- this is a correctness fix behind existing UI.

**Dependencies / blockers**: **Harold reproducing the failure with logging enabled.** Cannot
proceed past R-1 without it.

**Acceptance criteria**:
- AC-1: The mechanism is NAMED with a log line quoted as evidence.
- AC-2: Given the reproduction steps, When re-run after the fix, Then the batch succeeds or fails
  with an accurate reason.
- AC-3: A regression test covers the named mechanism.

**Tests to write**:
- T-1 (AC-3) -- TEST-UNIT: pins whatever R-1 names.
- **What this does NOT catch** (IMP-1): a test written against ONE reproduction cannot prove there
  is only one cause. If the log shows two distinct kinds across runs, say so rather than fixing the
  first and declaring victory.

**Definition of Done**: default DoD PLUS the log line that identified the cause quoted in the
completion notes.

**Model**: Fable/Opus -- *why not the cheaper tier*: an open diagnosis with three live hypotheses
and one already falsified; the work is determining the cause, not applying a known fix.
**Step-types**: SVC-EDIT, TEST-UNIT
**Est-Effort**: 60-120m

**Platform parity**: **SAME on both**, verified per IMP-5: the OS behavior assumed identical is
none -- this is Dart logic over an IMAP session. Windows is configured read-only so it will not
reproduce naturally; **the reproduction is Android-only for CONFIGURATION reasons, not code ones**,
and the fix must be verified to change nothing on Windows.

---

## Task 3 -- F234: Read-only as a PREVIEW mode (Priority 8)

**Value**: This turns read-only from a refusal into a rehearsal -- a broad rule's blast radius can
be vetted before anything is deleted.

**Audit-first**: **Is the data already there? YES, and that is what makes this cheap.**
`_reProcessAffectedEmails` builds `toDelete` and `toMoveSafe` BEFORE the mode check
(`results_display_screen.dart:~3500`); the read-only path currently returns and discards them.

**Requirements**:
- R-1: When an account resolves to `readOnly`, record what WOULD have been actioned instead of
  discarding it.
- R-2: **Surface it where the user already looks** -- the F231 session activity list is the natural
  home. A second surface would be a new thing to find.
- R-3: **It must be UNMISTAKABLE as a non-action.** Wording and color must make "would have"
  unambiguous. Sprint 72's F228 exists because a message implying a mailbox change that did not
  happen is a defect.
- R-4: **Scope question for Harold**: block rules only, or safe-sender moves too? Same mechanism,
  different message. Recommendation: **both**, since the preview's value is seeing the full effect.
- R-5: Persist it for the session at minimum; F231 already made the argument that transient
  outcomes are lost outcomes.

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart` -- the read-only branch of
  `_reProcessAffectedEmails`, and `_showActionOutcome`

**Existing abstraction checked**: `ReProcessOutcome` -- this ADDS a field (the would-have list) to
an existing type rather than introducing a parallel one. `_showActionOutcome` already branches on
`skippedReadOnly`, so the surface exists.
**Callers of any guard being changed**: `_reProcessAffectedEmails` has THREE callers. The
screen-load path passes `userInitiated: false` and must NOT gain a preview message. **This is the
exact guard Sprint 72's CRITICAL was about** -- enumerate before touching.
**User-reachable control**: the F231 session-activity control on the scan results screen, which
already exists; the preview appears as entries within it.

**Dependencies / blockers**: R-4 at approval.

**Non-functional requirements**:
- Accessibility: the "would have" distinction cannot rely on color alone (ADR-0037).

**Acceptance criteria**:
- AC-1: Given a read-only account, When a block rule is created, Then the count that WOULD have
  been deleted is recorded and visible.
- AC-2: Given the same, Then no mailbox action occurs -- verified by re-fetching, not by the UI.
- AC-3: The preview entry is visually and textually distinct from a real action.
- AC-4: Given the screen-load path, Then NO preview message appears (it is not a user action).

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT: the would-have list is populated on the read-only path.
- T-2 (AC-2) -- TEST-UNIT: no IMAP call is attempted.
- T-3 (AC-3) -- TEST-WIDGET: wording differs from a real action.
- T-4 (AC-4) -- TEST-UNIT: `userInitiated: false` produces no preview.
- **What these do NOT catch** (IMP-1): they cannot prove the user READS it as a preview rather than
  a completed action. That is Harold's judgement at manual validation, and it is the whole risk.

**Definition of Done**: default DoD PLUS Harold confirms on Windows (configured read-only) that the
preview is unmistakable.

**Model**: Sonnet -- *why not the cheaper tier*: touches the guard that produced Sprint 72's
CRITICAL, and the wording carries the F228 risk.
**Step-types**: SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET
**Est-Effort**: 90-150m

**Platform parity**: **SAME on both, no exception.** Verified per IMP-5: no OS behavior is
involved. **Windows is where this is most VALUABLE**, because Windows DEV/Prod are configured
read-only -- so the platform that could never see results now gets the preview. That is a
configuration difference being served by shared code, not a divergence.

**Decision-class interrupts**: R-4 (Class-2, scope of the preview) at approval.

---

## Task 4 -- F224 + F207 TOGETHER: user-facing cancel, and the stale in-progress block (Priority 6)

**Value**: This gives the user a way out of a scan that is taking too long, and removes a refusal
that outlives the thing it is refusing for.

**Planned as ONE task at Harold's observation**: *"above seems very related to F207"*. **He is
right, and the shared thing is `ScanCoordinator`'s lease.** F224 needs a way to release a lease
early and stop the work behind it; F207 is a lease (or a wait) that is not released when it should
be. Fixing them separately means reasoning about the same lease lifecycle twice.

**Audit-first**: **Is cancellation present? NO.** `grep` for `CancellationToken`, `cancelToken`,
`isCancelled` across `lib/` returns NOTHING. Genuine new work, and the card's existing warning is
correct: `Future.timeout` does NOT cancel underlying work.

**Requirements**:
- R-1: **Cooperative cancellation must be designed FIRST.** A cancel that only released the
  coordinator lease would let a second scan open an IMAP session while the first still holds one --
  the Sprint 61 per-account session-cap failure. `[no-history]` on this portion; **time-box the
  design** before committing to the UI.
- R-2: **F207 diagnosis**: determine whether the stale block is a lease never released, a wait that
  outlives its scan, or a UI state not cleared. `ScanCoordinator.acquire` bounds the wait with
  `waitLimit` (`scan_coordinator.dart:99-140`), so a wait SHOULD expire -- which makes "the block
  outlives the scan" the interesting part.
- R-3: Cancel is reachable from **where the user actually is** -- the scan results screen and the
  Manual Scan popup, per the original F224 filing.
- R-4: **Cancelling must leave no lease held and no session open.** That is the acceptance bar, not
  "the button responds".
- R-5: If R-2 shows F207 is the same root cause as F232 mechanism B (lease contention), **fix it
  once** and record the overlap.

**Affected components / files**:
- `mobile-app/lib/core/services/scan_coordinator.dart` -- release-on-cancel
- `mobile-app/lib/core/services/email_scanner.dart` -- the cooperative check points
- `mobile-app/lib/ui/screens/scan_progress_screen.dart`, `results_display_screen.dart` -- the control

**Existing abstraction checked**: `ScanCoordinator` (`releaseActiveByOwner` already exists from
F175/F220) -- extend it rather than adding a parallel cancellation path.
**Callers of any guard being changed**: `acquire`/`release` have several call sites across the
scanner, the re-process path and the background worker. **Enumerate all of them and state what
cancellation does to each** -- a scan cancelled while another waits behind it is the case that
matters.
**User-reachable control**: a Cancel affordance on the scan progress screen AND in the Manual Scan
popup when a background scan is running.

**Dependencies / blockers**: R-1's design time-box. **If the design shows cooperative cancellation
cannot be done safely within the estimate, STOP and surface** rather than shipping a cancel that
leaks sessions.

**Non-functional requirements**:
- Account-scoping: a cancel must release only the CURRENT account's lease.
- Platform: the IMAP session teardown differs in failure modes between platforms -- name it or
  declare it.

**Acceptance criteria**:
- AC-1: Given a running scan, When the user cancels, Then the scan stops AND
  `ScanCoordinator.instance.active` is null.
- AC-2: Given a cancelled scan, When a new scan starts immediately, Then it acquires without
  waiting and opens exactly one session.
- AC-3 (F207): Given a background scan has finished, When a manual scan is requested, Then it is
  NOT refused.
- AC-4: Given a scan is cancelled mid-batch, Then partial results are recorded honestly, not
  reported as a completed scan.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT: cancel releases the lease.
- T-2 (AC-2) -- TEST-UNIT: no session leak across a cancel/restart.
- T-3 (AC-3) -- TEST-UNIT: the stale block does not outlive the scan.
- T-4 (AC-4) -- TEST-UNIT: partial results are labeled.
- **What these do NOT catch** (IMP-1): a unit test cannot prove a real IMAP session was torn down
  on the server. The per-account session cap is the real-world symptom, and only a device run
  against a live account shows it.

**Definition of Done**: default DoD PLUS Harold cancels a real scan on the S24+ and immediately
starts another without a session error.

**Model**: Fable/Opus -- *why not the cheaper tier*: R-1 is an unsolved design problem with a known
failure mode (Sprint 61's session cap), and it changes a shared lifecycle with multiple callers.
**Step-types**: SVC-EDIT, UI-NEW, TEST-UNIT
**Est-Effort**: 150-300m (F224 120-240 + F207 30-60)

**Platform parity**: **SAME on both, verified per IMP-5.** The OS behavior assumed identical is
socket teardown on `disconnect()`, which `dart:io` provides on both -- **and Sprint 70's F220 is
the warning here**: Android tears down sockets when backgrounded and Windows does not, so a cancel
path must not assume the socket is still alive. BOTH branches tested.

**Risk & rollback**: A half-built cancel is worse than none -- it invites the user to cancel and
leaks the session. Mitigation: R-1's time-box gates the UI work. Rollback: the Cancel control can
be removed without touching the coordinator.

**Decision-class interrupts**: Class-1 if R-1 concludes cooperative cancellation needs an
architecture change (e.g. a cancellation token threaded through the scanner).

### R-1 / R-2 DETERMINATION (done first, as the card required)

**R-1: cooperative cancellation is SAFE within the estimate. No Class-1 escalation.**

The card reserved a Class-1 interrupt for "a cancellation token threaded through the scanner".
That is not needed, because the teardown the card demands already exists and runs on every path.

`EmailScanner.scanInbox`'s `finally` (`email_scanner.dart:973-994`) ALREADY does exactly the two
things R-4 makes the acceptance bar:

- `ScanCoordinator.instance.release(scanLease)` -- the lease, on every path;
- `await platform.disconnect()` -- the IMAP session, on every path, inside its own try/catch.

It is a `finally`, so a THROWN exception runs it just as a normal return does. That changes the
design problem completely: cancellation does not need a new teardown path, and must not add one.
It needs a way to make the scan **stop and throw**, and the existing `finally` does the rest.

So the Sprint 61 failure mode the card was protecting against -- "a cancel that only released the
coordinator lease would let a second scan open an IMAP session while the first still holds one" --
cannot occur by construction, PROVIDED cancellation is expressed as a throw out of `scanInbox`
rather than as an out-of-band lease release. **That constraint is the whole design.**

**The check point: `batchSink`** (`email_scanner.dart:398`). It is a single funnel -- the IMAP
streaming path feeds it via `onBatch`, and the list-returning paths (Gmail, demo, mock) are fed
through the same sink in m=20 slices at `:431-439`. One check there covers every platform path,
which is why no token needs threading. Worst-case cancel latency is one m=20 batch.

**What cancellation does to each of the enumerated call sites** (the card asked for this):

- `email_scanner.dart:170` (acquire) / `:977` (release) -- the owner. Cancel throws; the `finally`
  releases and disconnects. No change to either call.
- `results_display_screen.dart:3732/3886` -- the re-process path. It is NOT a scan and has no
  fetch loop, so it is out of scope for cancel; its lease is short-lived and already released in a
  `finally`.
- `background_scan_core.dart:169`, `main.dart:522`, `scan_progress_screen.dart:883` -- all three
  are `releaseActiveByOwner` FORCE-release paths for scans that are already dead or unreachable.
  Cancel must NOT reuse this path: force-release frees the lease while the scan's own stack may
  still hold a socket, which is precisely the leak R-4 forbids. Recorded as the design's one hard
  "do not".
- **A scan cancelled while another WAITS behind it** (the case the card singled out): the waiter is
  unaffected. The cancelled scan's `finally` calls `release`, which runs `_handOffOrIdle` and hands
  the lease to the next FIFO waiter exactly as a normal completion does.

**R-2: F207 is a THIRD cause -- not the two the card proposed, and NOT the same root as F232-B.**

The card offered "a lease never released, a wait that outlives its scan, or a UI state not
cleared". The evidence says none of those. The manual-scan block reads
`ScanResultStore.getActiveBackgroundScan()` (`scan_progress_screen.dart:676`), which queries the
DATABASE, not the coordinator:

    status = 'in_progress' AND scan_type = 'background' AND started_at >= now - 30min

So the block is driven by a **database row**, and is therefore completely independent of the
in-process lease. A background scan that dies WITHOUT writing a terminal status -- process kill,
force-stop, crash -- leaves that row `in_progress`, and the query keeps matching it for the full
30-minute `scanTimeout` freshness window. For up to 30 minutes the user is warned about, and told
to wait for, a scan that is already dead.

**Precision, because it changes the fix**: this is NOT a hard refusal. The dialog offers "Wait and
start" and the user can proceed (`scan_progress_screen.dart:685-702`). So F207's user-visible
damage is a FALSE WAIT ESTIMATE and a misleading prompt, not a lockout -- and a user who proceeds
then queues on a lease nobody holds, so the scan actually starts. The card's title ("the stale
in-progress block") overstates it. Verified by reading the dialog, not inferred from the query.

`reconcileStaleInProgressScans` fixes exactly this, but its age guard is ALSO `scanTimeout`, so it
cannot clear a row until the row has already stopped being returned by the query. **The reconciler
and the blocker use the same 30-minute constant, so the reconciler can never shorten the block.**
That is the defect, and it is a one-line class of fix rather than a lifecycle change.

This also means **R-5 does not apply**: F207 is not lease contention, so it is not the same root
cause as F232 mechanism B. Recorded as the overlap the card asked about, resolved NEGATIVE.

**Revised estimate**: unchanged at 150-300m. R-1 removed the architecture risk rather than the
work; the UI control and its tests are the remaining cost.

**R-3 CORRECTED after checking both named surfaces.** The card named "the scan results screen and
the Manual Scan popup". Opening them changed the answer twice:

- The **"Manual Scan popup"** is an AppBar icon whose action (`StandardAppBarActions
  .openManualScan`) NAVIGATES to `ScanProgressScreen`. It needs no control of its own -- the user
  who taps it lands on the screen where Cancel lives.
- The **results screen** DOES need one, for a reason the card did not name: "Scan Again" calls
  `startRealScan(useReplacement: true)`, so the scan runs with the user still on the results
  screen and `ScanProgressScreen` is never shown on that path. It is also the way testers actually
  restart scans -- the same navigation quirk F220 had to account for in Sprint 70. **A control on
  the scan screen alone would have missed the commonest route to a long scan.**

On the results screen the SAME button swaps to Cancel while scanning, rather than adding a second:
"Scan Again" is disabled during a scan anyway, so a separate control would be a permanently-dead
widget in that row.

---

## Task 5 -- F229: a version visible on the first page of EVERY screen (Priority 12)

**Value**: This makes any screenshot self-identifying, which Sprint 72 proved the release process
depends on.

**Harold's direction, 2026-09-23**: *"need to do a deep dive because we need to find a place
somewhere on the first page of every screen (V<n>.<n>.<n>). Be creative on this one - Font can be
small (10pt equivalent) - wrap the line, suggest removal of an item from View Results History..."*

**Audit-first -- the DEEP DIVE, run before proposing an approach:**
- The version label ALREADY exists (`AppBarVersionLabel`) and renders above 600px. It hides below
  that because adding it unconditionally overflowed the AppBar by ~81px at 411px (F172).
- **Sprint 72 tried the obvious fix and it FAILED**: a short form (`0.15.3` instead of
  `Version 0.15.3`, max width 140 -> 76) still overflowed by **18px** and turned four tests red.
  The action row holds **SIX icons** -- Review No Rule Items, View Scan History, Manual Scan,
  Select Account, Settings, Help -- plus a back button and a title.
- **`AppBar.bottom` is NOT uniformly free**: `email_detail_view.dart:614` and
  `settings_screen.dart:594` already use it for a `TabBar`. A strip there would collide on those
  two screens.
- **ELEVEN screens build their own `AppBar`**, so any title-line change touches all of them.

**Requirements**:
- R-1: A version string of the form `V<n>.<n>.<n>` is visible on the FIRST page of every screen at
  phone width, without scrolling.
- R-2: **Harold's own suggestions are live options, and one is a trade he offered**: shrink to ~10pt
  equivalent; WRAP the line; or **remove an item from the action row** to make space. Evaluate all
  three and RECOMMEND, with the measurement behind the recommendation.
- R-3: **Do NOT just lower the 600px threshold.** Sprint 72 measured that it does not fit.
- R-4: Keep the `[DEV]` suffix visible -- it is what would have caught the 0.5.5/0.5.6 Store
  dev-leak, and phones are where dev builds are hardest to tell apart.
- R-5: Use the runtime `AppVersion.get()`. **Never a literal** -- `stale_footer_test` and
  `version_consistency_test` both police this.
- R-6: Whatever is chosen must pass the F169/F172 width tests at 411px AND at the 1024x640 epx
  Windows minimum.

**Candidate approaches to evaluate under R-2** (the deep dive's output, not a decision):
1. **Remove an action-row icon at phone width.** "Select Account" is the strongest candidate -- it
   duplicates the account chips already on the results and history screens. This is Harold's own
   suggestion and the only option that BUYS space rather than borrowing it.
2. **Version in the AppBar TITLE line as a subtitle.** Real space exists, but 11 screens construct
   their own AppBar, so the change is broad and the Results title is already long
   ("Results - kimmeyharold@aol.com -").
3. **A thin strip under the AppBar** -- blocked on two screens by the existing TabBar, so it would
   need a per-screen exception, which is the opposite of uniform.
4. **Overlay on the screen body's first row**, e.g. right-aligned above the filter bar. Uniform and
   cheap, but it is not "near the top" in the AppBar sense.

**Affected components / files**:
- `mobile-app/lib/ui/widgets/standard_app_bar_actions.dart:394+` -- the label and breakpoint
- whichever screens the chosen approach touches (up to 11)

**Existing abstraction checked**: `AppBarVersionLabel` and `StandardAppBarActions` -- extend, do not
add a second version widget.
**Callers of any guard being changed**: the `< 600` breakpoint is inside `AppBarVersionLabel` and
affects every screen using `StandardAppBarActions`. **Enumerate which screens actually use it**
before changing it.
**User-reachable control**: N/A -- this is display, not a control. (If option 1 is chosen, a
control is REMOVED at phone width, which needs its own acceptance criterion.)

**Dependencies / blockers**: R-2 recommendation needs Harold's approval before implementing, since
option 1 removes a control.

**Acceptance criteria**:
- AC-1: At 411px, `V0.15.4` (or current) is visible on the first page of every screen using
  `StandardAppBarActions`, without scrolling.
- AC-2: No RenderFlex overflow at 411px or at 1024x640 epx.
- AC-3: `[DEV]` still renders at phone width on a dev build.
- AC-4 (if option 1): the removed control remains reachable another way, and that way is named.

**Tests to write**:
- T-1 (AC-1/AC-2) -- TEST-WIDGET at 411px: version present AND no overflow.
- T-2 (AC-2) -- TEST-WIDGET at 1024x640 epx.
- T-3 (AC-3) -- TEST-WIDGET: `[DEV]` survives at narrow width.
- T-4 (AC-4) -- TEST-WIDGET: the alternative route to a removed control.
- **What these do NOT catch** (IMP-1): they cannot prove a 10pt string is LEGIBLE on real hardware.
  Harold's eyes at manual validation are the acceptance, on a phone and on Windows.

**Definition of Done**: default DoD PLUS the F169/F172 width tests re-run, `text_contrast_test`
re-run (a 10pt font changes the WCAG threshold band -- Sprint 72's named trap), and Harold confirms
legibility on the S24+.

**Model**: Sonnet -- *why not the cheaper tier*: the deep dive is a design decision across 11
screens with a measured failure behind it; Sprint 72 proved the naive approach does not fit.
**Step-types**: UI-MOVE, TEST-WIDGET, DOCS
**Est-Effort**: 60-120m implementation, PLUS 30-45m for the deep dive itself

**Platform parity**: **SAME on both, no exception.** Verified per IMP-5: no OS behavior involved --
this is Flutter layout and a string. The real variable is WINDOW WIDTH, which both platforms span;
a narrow Windows window enters the same regime, which is why T-1 and T-2 both exist.

**Risk & rollback**: `text_contrast_test` enforces WCAG ratios whose thresholds DEPEND ON FONT
SIZE. A 10pt version string may fall below the large-text exemption and require a darker color.
**Fix by darkening, not by reverting the size.**

**Decision-class interrupts**: Class-2 -- R-2's chosen approach, especially option 1 (removing a
control), needs Harold at approval or immediately after the deep dive.

---

## Task 6 -- F226: WinWright sweep flakiness (Priority 14)

**Value**: This makes the sweep's result trustworthy, so a red run means a real regression.

**HAROLD HAS ALREADY DIAGNOSED THIS, 2026-09-23**: *"this is because it uses the Product Owner
screen and sometimes there is activity going while testing is going on and they conflict. Only need
to run once unless it stops for some reason, then just run it again - usually I am not aware it is
about to start and mess up the first run."*

**That changes the card completely.** The filed hypothesis was residual app state between scripts.
The actual cause is EXTERNAL INTERFERENCE -- Harold using the app while the sweep runs. **This is
not a code defect and must not be "fixed" as one.**

**Audit-first**: **Is there a guard against concurrent use? NO.** The runner launches a fresh dev
instance per script but nothing detects a human driving the app at the same time.

**Requirements**:
- R-1: **Do NOT chase the residual-state hypothesis.** It is falsified by Harold's account. Update
  the card so no future sprint re-investigates it.
- R-2: **Do NOT add sleeps.** That is the f56/f37 dialog-settle debt already quarantined out of the
  sweep, and it would mask interference rather than handle it.
- R-3: The sweep should WARN Harold before it starts, so he knows not to touch the app -- he says
  he is *"usually not aware it is about to start"*. A countdown or a prominent banner is enough.
- R-4: A single automatic retry on failure is acceptable and matches his stated workflow:
  *"just run it again"*. The retry must be VISIBLE in the output, not silent, or a genuinely broken
  script looks flaky.
- R-5: Record the real cause in the card and in `TESTING_STRATEGY.md`, so a red sweep is triaged as
  "was someone using the app?" before "what did the sprint break?".

**Affected components / files**:
- `mobile-app/scripts/run-winwright-tests.ps1` -- the pre-run warning and the retry

**Existing abstraction checked**: the runner already excludes three dialog-settle scripts and takes
DB snapshots; the retry belongs in the same place, not a new wrapper.
**Callers of any guard being changed**: the runner is invoked manually and at Phase 5.1.5. Neither
changes.
**User-reachable control**: N/A -- developer tooling. The pre-run warning IS the user-facing part.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: The runner prints a prominent warning and pauses briefly before launching, so Harold can
  stop if he is mid-task.
- AC-2: A failed script is retried ONCE automatically, and the output states that a retry occurred.
- AC-3: The card and `TESTING_STRATEGY.md` record the real cause.
- AC-4: A script that fails BOTH attempts is still reported as a failure -- the retry must not hide
  a real break.

**Tests to write**:
- T-1 (AC-2/AC-4) -- the runner's own behavior, verified by forcing a failure.
- **What this does NOT catch** (IMP-1): it cannot prove interference was the cause of any PAST
  failure. Harold's account is the evidence, and the retry is a mitigation, not a proof.

**Definition of Done**: default DoD EXCEPT Flutter tests/analyzer (PowerShell tooling), PLUS a
sweep run to confirm the warning and retry behave.

**Model**: Haiku -- *why not cheaper*: n/a, cheapest tier. A warning and a retry in an existing
script, with the diagnosis already supplied.
**Step-types**: DOCS, HOOK
**Est-Effort**: 30-60m (REDUCED from 60-120m -- Harold's diagnosis removes the investigation, which
was most of the estimate)

**Platform parity**: **N/A -- WinWright is Windows-only tooling by nature.** No app behavior
changes, so ADR-0042 does not engage.

---

## Task 7 -- F205: what ARE the 53 errors? (Priority 18)

**Value**: This turns a number nobody understands into either a defect or a known-benign class.

**Audit-first**: **Is the data already available? PARTLY, and that is new since filing.** The count
comes from `EmailScanProvider._errorCount`, but WHAT the errors were was never recorded. **F233's
diagnostic log now captures failure paths**, which is what makes this cheap -- the card was filed
before that existed.

**Requirements**:
- R-1: **INVESTIGATION ONLY.** Name what the errors are. Do not fix them in this task.
- R-2: Enable the diagnostic log on the S24+, run a scan, and classify the errors from the log.
- R-3: If the log does NOT capture them, say so -- that is itself a finding about F233's coverage,
  and it should become a card rather than being patched here.
- R-4: Output is a written classification with counts, and a recommendation: benign / needs a card /
  already covered.

**Affected components / files**: none expected. If the investigation shows the log misses these
paths, name the file that needs instrumenting.

**Existing abstraction checked**: `DiagnosticLogger` -- use it; do not add a second capture path.
**Callers of any guard being changed**: none.
**User-reachable control**: N/A -- investigation.

**Dependencies / blockers**: **Harold running a scan on the S24+ with logging enabled**, and
sending the log. Cannot proceed without it.

**Acceptance criteria**:
- AC-1: The 53 errors (or the current equivalent) are classified by kind with counts.
- AC-2: Each class is labeled benign, needs-a-card, or already-covered, with the reason.

**Tests to write**: none -- this is an investigation. Any card it produces carries its own tests.
**Definition of Done**: default DoD EXCEPT tests/analyzer (no code change expected) PLUS the
classification recorded in the plan's completion notes.

**Model**: Haiku -- *why not cheaper*: n/a. Reading a log and classifying; Claude prepares the
steps, Harold runs the scan.
**Step-types**: DOCS
**Est-Effort**: 30-60m of Claude time; Harold's device time separate

**Platform parity**: the ERRORS are observed on Android because that is the only build that acts on
mail (a CONFIGURATION difference). The classification applies to shared code, so any card it
produces must state parity then.

---

## Progress (live)

| Task | Item | Status |
|---|---|---|
| 0 | Version bump 0.16.0+7 | **DONE** -- both version gates + release-notes gate green |
| 1 | F235 Doze scheduling | **DONE** -- 13 tests, mutation-verified, Android APK builds |
| 2 | F232 mechanism B | pending -- needs Harold's reproduction with logging ON |
| 3 | F234 read-only preview | **DONE** -- 17 tests; a mutation SURVIVED the first test file and was closed |
| 4 | F224 + F207 cancel | **DONE** -- 20 tests, 2 mutations; R-1 cleared Class-1, R-2 falsified the card's 3 causes |
| 5 | F229 version everywhere | pending |
| 6 | F226 sweep interference | **DONE** -- warning + one visible retry |
| 7 | F205 classify the errors | pending -- needs Harold's device run |

**Suite 2,233 -> 2,283. Analyzer clean.**

**F235 cost more than the 90-180m estimate**, and the reason is worth recording for the next
native card: the app had NO MethodChannel at all, so the work included building the first native
bridge (MainActivity was a bare 5-line class), a Kotlin alarm scheduler, two BroadcastReceivers, a
manifest change and a gradle dependency. The estimate was derived from step-types that assumed an
existing bridge. **Actuals go in CODING_VELOCITY.md at completion.**

**Task 4 came in UNDER the 150-300m estimate, and the reason is the opposite of Task 1's.** The
card time-boxed an unsolved design problem; the design turned out to be already paid for. Reading
`scanInbox`'s `finally` -- which releases the lease AND disconnects on every path, including a
throw -- collapsed "thread a cancellation token through the scanner" into "throw at one funnel".
**The estimate priced a token-threading exercise that the existing teardown made unnecessary.**

The cost that DID land was not in the card at all: the per-folder `catch (e, st)` would have
swallowed the cancellation and continued scanning the remaining folders. Found by asking what the
change does to its NEIGHBOURS, not by a test -- every test written at that moment passed.

## Sprint summary

| Task | Item | Model | Est (min) | Depends on |
|---|---|---|---|---|
| 0 | Version bump | Haiku | 10-15 | approval |
| 1 | F235 Doze scheduling | Sonnet | 90-180 | R-1 permission gate |
| 2 | F232 mechanism B | Fable/Opus | 60-120 | Harold reproduction |
| 3 | F234 read-only preview | Sonnet | 90-150 | R-4 scope decision |
| 4 | F224 + F207 cancel + stale block | Fable/Opus | 150-300 | R-1 design time-box |
| 5 | F229 version everywhere | Sonnet | 90-165 | deep-dive recommendation |
| 6 | F226 WinWright interference | Haiku | 30-60 | none |
| 7 | F205 classify the errors | Haiku | 30-60 | Harold device run |

**Total estimated**: **550-1,050 minutes (~9-17.5 hours).**

**Model mix**: Haiku 3, Sonnet 3, Fable/Opus 2. The two top-tier assignments are the genuinely
open problems -- F232's diagnosis and F224's cancellation design.

**Critical path**: none strictly. Tasks 6 and 7 are independent and cheap. Task 2 and Task 4 should
be sequenced together if R-2 shows lease contention is shared.

**Calibration note**: Sprint 72 estimated 1,090-1,845m and the tasks that ran came in well under.
These estimates are derived from the Estimate Table by step-type plus Sprint 72 actuals, per
`CODING_VELOCITY.md` Rule 2 -- not converted from hours.

## Open questions for Harold at approval

1. **Version bump (Task 0)**: PATCH `0.15.4+7` or MINOR `0.16.0+7`? Recommendation: PATCH.
2. **F234 scope (Task 3, R-4)**: preview for block rules only, or safe-sender moves too?
   Recommendation: both.
3. **F229 approach (Task 5, R-2)**: the deep dive will recommend, but option 1 REMOVES the "Select
   Account" icon at phone width. Acceptable in principle?
4. **Sprint size**: ~9-17.5 hours across 8 tasks. Accept in full, or defer Task 5 (F229), which is
   the largest non-blocking item?

## Phase 3.7 approval

**NOT APPROVED YET.** No task execution begins until Harold approves.
