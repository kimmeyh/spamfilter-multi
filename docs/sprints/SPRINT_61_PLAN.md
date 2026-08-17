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

- **F168** (Priority 6): background scan skipped the Inbox (ran Bulk/Bulk Mail only) while the
  manual scan over Bulk/Bulk Mail/Inbox found and deleted 6 rule-matching Inbox emails. Suspected
  cause: background-specific folder override resolving ahead of the per-account selection in
  `SettingsStore.getEffectiveFolders`. Harold explicitly asked that this be targeted for the next
  sprint. Confirmed NOT fixed by Sprint 60 (those fixes were Android-only).

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
