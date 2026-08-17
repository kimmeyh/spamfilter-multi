# Sprint 61 Plan (STUB -- created at Sprint 60 Phase 7.7)

**Status**: NOT STARTED. Scope selection happens at Sprint 61 Phase 1/2 (Backlog Refinement +
Pre-Kickoff) from `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates".

## Category 13 carry-ins from Sprint 60 retrospective

- None (all four roles: none).

## Approved early-sprint chore (Harold, 2026-08-16)

- **Line-ending normalization**: add `.gitattributes` (`* text=auto eol=lf`; `*.bat`/`*.cmd`/`*.ps1`
  pinned `eol=crlf` -- cmd.exe LF-label edge cases and Authenticode CRLF assumptions) plus the
  one-time `git add --renormalize .` commit, with that commit's hash recorded in
  `.git-blame-ignore-revs`. Run as the FIRST commit(s) on the Sprint 61 branch so the repo-wide
  content-neutral diff stays out of feature history. Watch-item: if Visual Studio regenerates
  `windows/runner` files as phantom-dirty CRLF, add a targeted `eol=crlf` line for those paths
  rather than reverting the policy. Ends the "LF will be replaced by CRLF" warning noise.

## Harold-targeted for THIS sprint (2026-08-16)

- **F169** (Priority 4): the Review No Rule Items account filter clips accounts off-screen at
  phone width -- a horizontally scrollable chip Row with no scroll affordance, so with two
  accounts the AOL account is unreachable. Harold: "All account must be viewable", and approved
  reusing the F166 Scan Results dropdown pattern (single-select, default All) on BOTH Windows and
  Android. Assigned to this sprint at registration.

- **F168** (Priority 6): background scan skipped the Inbox (ran Bulk/Bulk Mail only) while the
  manual scan over Bulk/Bulk Mail/Inbox found and deleted 6 rule-matching Inbox emails. **Cause
  confirmed by Harold same-day: Inbox was genuinely not selected in the background folder scope
  ("but thought I had") -- specifically in the PRODUCTION app's background/bulk scan scope, which is a separate settings store from dev (ADR-0035), so verify the fix against the production surface.** So this is a UX/discoverability item, not a scanner defect: the app
  let a user believe Inbox was covered, and a wrong scope is indistinguishable from "no spam
  found" in the results. Scope: surface the active background folder scope at selection time,
  consider warning when Inbox is omitted, and re-examine whether background and manual scopes
  should be independently editable. Harold asked that this be targeted for this sprint.

## Standing context for scope selection

- 0.9.0.0 / Submission 16: if certified by sprint start, Step 7 release close-out is pending
  (STORE_VERSION_STATUS Live row, CHANGELOG [0.9.0] heading + links, dev bump 0.9.0 -> 0.9.1).
  Note: [Unreleased] contains Sprint 60 `feat` entries, so the NEXT release after 0.9.0 is MINOR.
- Android track candidates in priority order: F161 (scheduler), F162 (parity audit + ADR --
  Harold steering: may descope after the current-app re-validation, which completed 2026-08-16),
  F167 (Android Help text, governed by the F162 ADR), F163 (skipped-test remediation), F164
  (scan performance), F165 (cloud rules sharing exploration).
- Harold to re-add his Android account persists going forward via the `adb install -r` deploy flow.

This stub is replaced by the real plan at Phase 3.
