---
name: memory-restore
description: RETIRED (Sprint 51) -- sprint state now lives in .claude/sprint_status.json; use /startup-check instead
allowed-tools: Read
user-invocable: true
model: haiku
---

# Memory Restore Skill -- RETIRED

**Status**: RETIRED 2026-07-28 (Sprint 51, F130-S51), with Harold's approval.

**Do not restore anything from `.claude/memory/current.md`.**

## Why this was retired

This skill read `.claude/memory/current.md` + `.claude/memory/memory_metadata.json` and restored that
snapshot into the session. That mechanism was already superseded -- `memory-save/SKILL.md` states
plainly that nothing should be written to `current.md` any more -- but this skill and `/startup-check`
step 3 kept reading it.

Both files are frozen at **Sprint 39 (2026-05-24)** and are self-labelled `[STALE -- DO NOT TRUST]`.
They did not misfire only because `pending_restore` happened to be `false`. The moment anything set
that flag, a Sprint-39 snapshot would have been restored into a Sprint-51+ session and presented as
current context -- silently, and with confidence.

That is a failure mode this repo has already paid for once: `.claude/sprint_status.json` drifted 15
sprints before Sprint 50 caught it, precisely because a stale state file that *looks* authoritative is
worse than no state file at all.

Found by the F130-S51 process-docs consistency audit and surfaced as a Class-3 decision rather than
changed unilaterally, because it touches the session-startup contract.

## What to do instead

| You want | Read this |
|---|---|
| Current sprint state -- number, branch, approval flags, task status, test metrics, next actions | `.claude/sprint_status.json` (maintained at Phase 7.7 every sprint) |
| The full startup health check, including that file with staleness validation | Run **`/startup-check`** |
| Durable process context -- phase definitions, decision classes, stopping criteria, the 4-step resume sequence | `docs/SPRINT_RESUME_GUIDE.md` |
| Long-lived preferences and corrections | The auto-memory directory (`MEMORY.md` + `feedback_*.md`), loaded automatically at session start |

## If you were invoked

Do not read `.claude/memory/*`. Tell the user this skill is retired, then run the `/startup-check`
flow instead -- it reads `.claude/sprint_status.json` and applies staleness checks before reporting
anything as current.

## Note on the old files

`.claude/memory/current.md` and `.claude/memory/memory_metadata.json` are deliberately left on disk,
unmodified, as a historical record of the Sprint-39-era mechanism. They are inert -- nothing reads
them now. Do not "refresh" them; that would recreate the trap. If they are ever deleted, nothing
breaks.
