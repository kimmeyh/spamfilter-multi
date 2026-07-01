# Sprint 44 Plan: ADR/ARSD promotion + background-deferral visibility + dependency hardening

**Sprint**: 44
**Date**: 2026-06-26 (Planning / Phase 1-3)
**Branch**: `feature/20260626_Sprint_44` (created off merged `develop` per Phase 6.6)
**PR**: created at Phase 3.3.1 (draft) -- stays DRAFT until end of Phase 7.7 (IMP-2)
**Status**: DRAFT -- pending Harold Phase 3.7 approval (design decisions below CONFIRMED 2026-06-26; awaiting plan approval to execute)

**Scope (Harold-selected, 2026-06-26)**: F107, F109, F108.

**Harold decisions at refinement (2026-06-26)**:
- **F107**: (a)+(b) -- Accept ADR-0037 (Proposed -> Accepted) AND promote ARSD.md from "1.0 (Draft)" to a stable version.
- **F109**: (a)+(b)+(c) -- all three surfaces: Settings/Background status line, Scan History hint, AND a logged skip row in `background_scan_log`.
- **F108**: (c) -- spike-first; assess each major bump's breaking changes + retest cost (~30 min), then decide which to actually adopt this sprint (the adopt step is gated on the spike + a Class-2 go/no-go).

**Harold design confirmations (2026-06-26, pre-approval)**:
- **F109c design -- CONFIRMED**: the **handoff-file** design (C++ `main.cpp` appends the skip to a small file; Dart ingests it into a `status='deferred'` row in `background_scan_log` on next launch -- NO DB migration). NOT the move-detection-to-Dart alternative.
- **main.cpp v0.5.4 fix -- CONFIRMED**: bump the stale `v0.5.3` log-filename hardcode in `windows/runner/main.cpp` to v0.5.4, and add `main.cpp` to the version-bump checklist.
- **Model assignments -- CONFIRMED** (cheapest-first per IMP-1, see Model Assignments section).

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

---

## Sprint Objective

Close three Sprint-43-spawned backlog items: ratify the implemented UI/accessibility standards (F107), make the correct-but-invisible background-scan deferral visible to the user across three surfaces (F109), and de-risk three security-relevant dependency major bumps via a spike before any upgrade (F108).

---

## Sprint Scope (3 items, IN EXECUTION ORDER)

### 1. F107 -- Accept ADR-0037 + promote ARSD (FIRST -- smallest, unblocks nothing)
- **F107a**: ADR-0037 status **Proposed -> Accepted** (the AccessibilityHelper + Semantics standards are implemented in 3+ UI files). Update the ADR's Status block + the date, and the ADR index row in `docs/adr/README.md` (currently `Proposed | 2026-04-18`).
- **F107b**: ARSD.md **"1.0 (Draft)" / Status: Draft -> 1.0 (Accepted)** (or "1.1" if any content changes). Update the header Version + Status fields.
- **Acceptance**: ADR-0037 reads Accepted in both the ADR and the index; ARSD reads a non-Draft status. No code change.
- **Model**: **Haiku** -- pure doc-status edits to known fields, no judgment beyond what Harold already decided. (Cheapest-first: fits Haiku.)
- **Step-types**: DOCS. **Est-Effort: 15-25m | Est-Wall: 15-25m.**

### 2. F109 -- Surface the "background run deferred (UI open)" state (SECOND)
The per-account scheduled task launches with `--background-scan`; `main.cpp` does a read-only mutex probe and, if the foreground UI is running, logs `Background scan skipped: Foreground UI is running (mutex held); scan deferred to next interval.` and **exits BEFORE Flutter/Dart/DB start** (verified `windows/runner/main.cpp` ~L62/L90). This is correct (F98 DB-contention protection) but invisible in the UI. Three surfaces:

- **F109a (Settings/Background status line)** -- show on Settings > Background: e.g. "Background scans pause while this app is open." Static, always-true explanatory line (cheap, most discoverable). Optionally append the last-deferral time IF F109c lands (see below).
  - **Model**: **Haiku** -- a static helper/info line on an existing tab, following existing Settings widgets. **Est-Effort: 20-30m.**
- **F109b (Scan History hint)** -- a hint on the Scan History screen explaining why no recent *background* scan appears while the app is open.
  - **Model**: **Haiku** -- a conditional info banner on an existing screen. **Est-Effort: 20-30m.**
- **F109c (logged skip row in `background_scan_log`)** -- record each deferral so it appears in history. The deferral is detected in **C++ (`main.cpp`) before any Dart/DB access exists**, so there is no clean way to write a `background_scan_log` row from the native probe directly. **APPROVED design (Harold 2026-06-26): the handoff-file approach** -- `main.cpp` appends the skip event to a small handoff file (it already writes the file log); on the NEXT foreground launch (or next successful worker run), Dart reads the handoff file and inserts a `status='deferred'` row into `background_scan_log` (the table already has a `status` column -- **NO DB migration**), then clears/rotates the handoff file. F109a's status line reads the latest `deferred` row to show "last run deferred at HH:MM." (The rejected alternative was moving the mutex-deferral detection into the Dart worker -- that reintroduces DB access under contention, the exact thing the native probe avoids.)
  - **Model**: **Sonnet** -- spans the C++ native probe + a Dart-side ingest + a new persisted status value across the worker/startup boundary; cross-layer, beyond Haiku's single-file heuristic. **Est-Effort: 60-90m.**
- **Acceptance**: Settings + Scan History both explain the deferral; a deferral produces a `background_scan_log` row visible in history; no DB migration; tests cover the deferral-row ingest.
- **Step-types**: UI-EDIT (x2) + native/Dart cross-layer + tests.

### 3. F108 -- Security-relevant dependency upgrades, SPIKE-FIRST (THIRD)
- **F108-spike (do FIRST, gates the rest)**: for each of `flutter_secure_storage` 9->10, `flutter_appauth` 8->12, `workmanager` 0.5->0.9: read the changelog/migration guide, identify breaking API changes that touch our call sites, and estimate the retest cost. Output a go/no-go recommendation per dep. **~30m.**
  - **Model**: **Sonnet** -- reading migration guides + mapping breaking changes onto our adapters is judgment work, not mechanical. **Est-Effort: 30-45m.**
- **F108-adopt (CLASS-2 -- surface spike findings + get go/no-go before upgrading)**: upgrade only the deps the spike clears, each with a targeted retest (secure_storage -> Windows + Android secure-storage round-trip; appauth -> full Gmail + AOL sign-in; workmanager -> per-account WorkManager scheduling). Fold in low-risk minor/patch drift.
  - **Model**: **Sonnet** (or Opus if a bump turns out to need cross-cutting adapter rework -- decide post-spike). **Est-Effort: 60-120m, gated on spike outcome.**
- **Acceptance**: cleared deps upgraded, each path retested green; `flutter analyze` + full suite green; deferred deps documented with why.
- **Step-types**: SPIKE -> deps + retest.

---

## Incidental fix folded in (found during planning)

- **F105 follow-up**: `windows/runner/main.cpp` still hardcodes the **v0.5.3** background-scan log filename (`dev_background_scan_v0.5.3.log` / `background_scan_v0.5.3.log`) -- the F105 5-file version checklist did NOT include `main.cpp`, so it was missed. Bump to **v0.5.4** to match the rest, and **add `main.cpp` to the version-bump checklist** in `docs/STORE_RELEASE_PROCESS.md` so it is not missed again. **Model: Haiku. ~10m.** (Trivial correctness fix; folds naturally into F109 since both touch `main.cpp`.)

---

## Estimated Effort

**Est-Effort ~230-385m | Est-Wall ~210-350m.** F108-adopt is the variable (gated on the spike). Well under the 400-HOUR stopping threshold.

## Model Assignments (cheapest-first per Sprint 43 retro IMP-1)

- **F107a/b, F109a, F109b, main.cpp version fix**: **Haiku** -- doc-status edits + static/conditional info lines on existing screens + a string constant; single-surface, no cross-cutting judgment.
- **F109c**: **Sonnet** -- *why not Haiku*: spans the C++ native probe + a Dart-side ingest + a new persisted status value across the worker/startup boundary (cross-layer, beyond Haiku's single-file heuristic).
- **F108-spike + F108-adopt**: **Sonnet** -- *why not Haiku*: reading migration guides and mapping breaking changes onto our auth/storage/background adapters is judgment work; escalate F108-adopt to **Opus** only if a bump needs cross-cutting adapter rework (decide post-spike).
- **Planning / this plan / retro**: **Opus** (per SPRINT_PLANNING.md "Activities Requiring Opus").

---

## Decision-Class interrupts (NOT pre-authorized -- surface + wait)

- **F107** (Class-1): RESOLVED at refinement -- Accept ADR-0037 + promote ARSD (Harold 2026-06-26).
- **F109c design** (Class-1/2): RESOLVED pre-approval -- handoff-file design confirmed (Harold 2026-06-26).
- **F108-adopt** (Class-2): STILL OPEN -- surface the spike's per-dep findings + get go/no-go before upgrading each dep (the spike is in-plan; the adopt go/no-go is the live interrupt).

---

## PR lifecycle (per SPRINT_EXECUTION_WORKFLOW.md, IMP-2)

PR created draft at 3.3.1. On 3.7 approval -> update to approved plan (keep DRAFT). End of dev -> update (keep DRAFT). End of 7.7 (retro improvements done) -> `gh pr ready` (the ONE ready conversion). 7.7.5 -> notify PO/SM for final approval. NEVER mark ready earlier.
