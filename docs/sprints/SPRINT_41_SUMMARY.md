# Sprint 41 Summary

**Branch**: `feature/20260613_Sprint_41`
**PR**: [#262](https://github.com/kimmeyh/spamfilter-multi/pull/262)
**Issues**: F83 Phase 1, F97, F76 (backlog feature IDs; no linked GitHub issue numbers found in PR history)
**Dates**: 2026-06-13 -> 2026-06-17 (plan approved -> retro), merged 2026-06-20
**Retrospective**: `docs/sprints/SPRINT_41_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | +1,642 passing / ~28 skipped |
| Analyzer | Clean |
| WinWright sweep | 6/6 read-only scripts green, `DB Drift: none` (verified live) |
| Manual Validation | Not separately recorded beyond the WinWright sweep verification in the PR body |
| Carry-forward | F98 (Sprint 42, gated on ADR-0039 approval); F99 (new backlog item, pre-MVP) |

## Scope

Approved 2026-06-13: F83 Phase 1 (research + ADR only), F97, F76 (3 items, carried in from the Sprint 40 backlog). No mid-sprint scope additions; two items were re-scoped/retired during execution per Harold's Class-3 decisions.

| Item | Planned | Outcome |
|---|---|---|
| F83 Phase 1 | Per-account background-scan research + ADR | **DONE** -- ADR-0039 written and Accepted (Harold, Chief Architect, Class-1 signoff 2026-06-15). F98 (implementation) unblocked for Sprint 42. |
| F97 | Re-port 2 F56 WinWright create+delete lifecycle scripts | **DONE as re-scoped** -- scripts authored to the current `testCases` schema, input format confirmed live; reliable unattended execution folded into F99 (Harold Class-3, 2026-06-17). |
| F76 | WinWright visual regression | **RETIRED -> F99** -- proven not implementable on the standalone WinWright CLI (no `get_attribute`, no bounds outside the MCP session); non-working artifacts reverted. |
| F37 (Sprint 40 carry, not in S41 scope) | -- | **Moved to F99** -- same Flutter dialog-settle race surfaced during Sprint 41 manual testing of the folder-picker script. |

## What shipped

**F83 Phase 1 -- ADR-0039 (per-account background scanning)**. `docs/adr/0039-per-account-background-scanning.md` enumerates every global `background_scan_enabled` read/write/artifact site (Settings UI, storage/DB, Windows Task Scheduler, Android WorkManager, log paths, export paths, CLI arg, Help text) and proposes the per-account schema, scheduling, and task-naming convention, including the F98 implementation change-site table. The research also surfaced a latent Android background-scan key mismatch and an orphaned schedule table, both routed to F98. Accepted by Harold as a Class-1 architecture decision on 2026-06-15.

**F97 -- WinWright F56 lifecycle scripts**. The two deferred create+delete scripts (`test_f56_create_block_rule.json`, `test_f56_create_safe_sender.json`) were re-ported to the current `testCases` schema. Three live-UIA fixes were required across two fix rounds: clicking the radio-button's parent `Group` (not the `RadioButton` itself) to actually select it, using the mode-dependent input field name (`Enter TLD` vs `Enter email, domain, or URL`), and maximizing the window before invoking the off-screen Save button. Reliable **unattended** execution remained flaky (UIA resolves 0 elements pre-settle) and was folded into F99 rather than continuing to chase fixes on WinWright's out-of-process model.

**F76 -- visual regression, retired**. Investigation proved the standalone WinWright CLI has no path to element `BoundingRectangle` data outside of an active MCP session (`inspect` has no bounds; `run` rejects `ww_get_attribute`/`ww_assert*`). The visual-check script, its runner wiring, and captured baseline JSON were reverted rather than left as a half-working feature; docs (README, CHANGELOG, TESTING_STRATEGY.md) were corrected in the same commits.

**New backlog item -- F99**. Created (Priority 76, pre-MVP) to absorb three deferred capabilities on one foundation: a parallel Flutter `integration_test` E2E harness with `pumpAndSettle`, replacing WinWright's out-of-process UIA for any flow that crosses a Flutter dialog/picker-settle boundary. Absorbs F76 (visual regression via golden-image/`RenderBox`), F56 reliable create/delete execution (F97's residual gap), and F37 (folder-picker E2E, moved from Sprint 40). Playwright was evaluated and ruled out (drives browser DOM only, cannot see a native Flutter desktop widget tree).

**WinWright sweep hardened to a truthful green state**. The default sweep was reduced to 6 read-only scripts with `test_f56_*` and `test_f37_*` explicitly excluded (still runnable via `-TestName`) rather than left in the default sweep intermittently failing. `run-winwright-tests.ps1` exclusion logic was later hardened (PowerShell `@()`-wrapped `Where-Object` result) to fix a Copilot-flagged bug where a single-match exclusion silently no-opped.

**Tooling side note**: diagnosed and fixed a Norton 360 HTTPS-interception issue (LiveUpdate re-asserting SSL scanning) that was intermittently breaking `git push`; documented in TROUBLESHOOTING.md.

**Copilot review follow-up (same PR)**: doc consistency fixes (TESTING_STRATEGY.md stale F76 section, ADR-0039 stray tool-transcript tags, ADR README status sync, WinWright README test-data mismatch) plus the PowerShell array-count fix above.

## Lessons worth carrying

1. **"Partial fix presented as done" occurred twice** (F37 step-4 selector change, F56/F37 round-3 click-verb change) before the actual root cause -- a Flutter dialog-settle race with no `ww_wait`/`ww_assert` primitive in WinWright's script-runner -- was diagnosed via live UIA inspection. Reinforced the "diagnose before patching" discipline after one failed patch.
2. **A tooling-capability pre-flight would have caught F76 before it was built.** The WinWright CLI's inability to read element bounds was discoverable in a 5-minute spike; instead a full visual-check feature was built and then reverted. Proposed as a standing convention for any "bolt capability X onto external tool Y" item.
3. **Estimates ran ~2-3.5x under** for the first time (prior sprints ran over), but the deeper finding was that roughly 7 unestimated reactive items (fix rounds, the tooling investigation, the F76 retire/F99 fold, the Norton fix) dominated actual wall-clock -- a research/tooling sprint carries a large reactive tail that per-item estimates do not capture.

**Note on this document**: written retroactively during the Sprint 57 documentation audit (2026-08-14), sourced from PR #262 (body + 12 commits) and the existing `SPRINT_41_PLAN.md` / `SPRINT_41_RETROSPECTIVE.md`, which were already complete and are unchanged by this backfill.
