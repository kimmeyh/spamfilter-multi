# Sprint 50 Summary

**Dates**: 2026-07-25 -- 2026-07-27
**PR**: #278 (`feature/20260723_Sprint_50` -> develop; merged, then develop -> main via #284)
**Model**: Fable 5 (execution); Opus 5 (1M) from Phase 7 onward
**Docs**: SPRINT_50_PLAN.md · SPRINT_50_RETROSPECTIVE.md (+ Claude draft)

## Objective

Close out the small, well-scoped quality items surfaced by Harold's 0.5.6/0.5.7 validation passes and the Copilot round-6 carry-in: remove the last ambiguous legacy rules from the prod DB, polish the Review-No-Rule load-error path, fix two Manage-screens display defects, and verify the F127 rescope leaves CI green.

## Delivered (5/5 planned + 5 mid-sprint + 1 escalated)

**Planned:**

- **F126**: removed the 4 ambiguous legacy `%`-wildcard TLD rows left report-only by F33-PROD (`/%.nl/`, `/%.ru/`, `/%.store/`, `/.*.xyz`). New script with exact-content matching, an abort-unless-exactly-4 gate, dry-run default and timestamped backup. LIVE prod apply: **5,887 -> 5,883**; re-run found 0; dev DB had none.
- **F122**: Review-No-Rule load errors now log a stack trace and show a friendly SnackBar instead of the raw exception (Copilot round-6 carry-in).
- **F123**: the "Entire Domain" mislabel was **DATA, not display logic** -- 350 of 525 prod safe-sender rows (341 dev) carried a `pattern_type` written by older classifier versions. Repair script recomputes with the current classifier (`custom` never touched; never degrades a labeled row to `unknown`). Applied live to both DBs, 0 repairable remaining. The Sprint 37 stored-type-authoritative precedence was left untouched, so the planned Class-2 interrupt never triggered. Also corrects duplicate detection, which keys on `pattern_type`.
- **F124**: legacy pre-classification rules show "Uncategorized (legacy)" instead of a blank sub-label, consistently across tile, details dialog, and a new filter chip -- which also exposed and fixed a latent key mismatch (`''` vs `'uncategorized'`) that made the bucket unfilterable.
- **F127** (rescoped): CI verified green with the corrected `secrets.ci.json` key names; the 5 `CI_*` secrets stay deliberately unset.

**Mid-sprint, from Harold's manual validation:**

- **MT-1**: fixed 3-column quick-action grid (Email | Exact Domain | Entire Domain across Safe and Block rows) with disabled placeholders and Block Subject on its own row, so Block Entire Domain always occupies the same cell. Harold chose this over two alternatives presented with ASCII previews. Pinned by a geometry test asserting column x-alignment.
- **MT-2**: quick actions made idempotent. Rule names are deterministic and `rules.name` is UNIQUE, so a second item on an already-blocked domain threw and stuck in the list ("failed to add block rule"). An existing rule/safe sender now reports "already covered" success carrying the existing rule as the F120 delta.
- **MT-2b**: the auto-resolve sweep moved to AFTER the post-action reload -- a newer scan completing while the screen was open re-populated the same senders as fresh rows, which the pre-reload sweep never saw.
- **MT-2c**: generalized to sweep on EVERY load. Covered rows were still listed on open; `_loadItems` now evaluates all items against the full rule set (F120-style yields), marking and dropping covered ones pre-display.
- **MT-3**: the Review "No Rule" Items entry point added to the Manual Scan and Scan Results app bars, mirroring the F112/F39 convention.

**Escalated from backlog during Copilot review:**

- **F128**: `RuleSetProvider.addRule`/`addSafeSender` no-oped silently on an unloaded cache -- the caller reported success with nothing persisted (BUG-S39-2's rethrow guard sat after the early return and could never fire). Filed as backlog mid-sprint; Copilot independently found it reaching into the new idempotency checks, which changed the decision. Fixed: load-on-demand + `StateError` if still unavailable; new `isRulesLoaded`/`isSafeSendersLoaded` getters distinguish "unloaded" from "genuinely empty" (both read as empty through the collection getters).

## Verification

Full suite **1,806 passed / 29 skipped / 0 failed**; `flutter analyze` clean; CI green on both jobs. Harold validated every item -- "All working as expected and can be closed." Both live-data tasks were rehearsed against scratchpad copies before applying, with timestamped rollback backups verified present on disk at the Phase 6.1.1 risk gate.

**Copilot review: 9 findings across 4 rounds, all fixed in-sprint, all threads replied to and resolved.** The two substantive ones: the idempotent fast-paths skipped conflict resolution (a surviving block rule kept deleting whitelisted mail, and symmetrically a surviving safe sender defeated a re-applied block rule), and `RuleEvaluator` logged one debug line per evaluation on bulk sweeps (fixed with an opt-in `silent` mode using closures, so a silenced call never interpolates). Three findings were self-inflicted by the IMP-1 rename sweep rewriting sentences that described the rename.

## Retrospective highlights (5 improvements applied "now", 2 to backlog)

Harold rated all 12 substantive categories "Very Good", none for categories 13/14. Applied: **IMP-1** terminology rename "manual testing" -> "manual validation" (81 case-preserving occurrences across 32 files; historical records deliberately excluded so the record is not falsified) -- a Sprint 49 carry-in that had never been converted into a numbered proposal; **IMP-2** retro Step-5 completeness gate, requiring proposals to be generated mechanically per category so a request buried in a rating line cannot vanish again; **IMP-3** F-PRECHECK class 1 now names local-Windows/CI-Linux as a parallel-site pair (the escape that failed CI this sprint); **IMP-4** fix-boundary reporting rule; **IMP-7** recorded justification whenever `Executed-by` deviates from the assigned model (Harold's steering). Backlogged: F128 residual and F129.

Headline lesson: the MT-2 requirement was complete in Harold's first message -- "re-checking the list for other items still in the list that are now covered by rules" IS the MT-2c behavior. Fixing the narrow symptom first cost three rounds for one requirement.

## Release

`0.5.8` MSIX built from merged main in the prod worktree (16.8 MB, manifest `0.5.8.0`). Full both-sides proof passed: `APP_ENV=prod` AND `NATIVE_APP_ENV=prod`, clean window title, real client ID verified embedded in `data/app.so`. **Submitted to Partner Center 2026-07-27**, certification expected 2026-07-28. No version bump was needed -- Sprint 50's F-VERSION-DERIVE inheritance meant prod arrived at 0.5.8 with the merge. First release to carry user-visible release notes in the Store listing; `STORE_RELEASE_PROCESS.md` Step 6 gained the previously-undocumented release-notes location.

## Carried forward

Post-certification close-out (CHANGELOG `[0.5.8]` heading, dev bump to 0.5.9, master-plan Store status); **F128 residual** -- the sibling early-returns (`removeRule`, `updateRule`, `removeSafeSender`) share the silent-no-op shape and were not audited (~15m); **F129** WinWright coverage for the three sprint-touched screens (Phase 5.1.5 exit criteria); standing backlog (F-COPILOT-INSTR, F125, F94/Android track, F108-RETEST). The Android/Google Play track remains the next major track per the 0.5.7 promotion trigger.
