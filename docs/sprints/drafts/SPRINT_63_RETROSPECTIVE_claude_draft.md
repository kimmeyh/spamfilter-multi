# Sprint 63 Retrospective -- Claude Code Development Team DRAFT

**AUTHOR: Claude (Claude Code Development Team role ONLY).** This draft is Step 2 of the
7-Step Retrospective Protocol. It is combined with Harold's PO/SM/Lead Developer feedback at
Step 3 and is never a substitute for his input.

**Sprint**: 63 (2026-08-24 to 2026-08-26, branch feature/20260824_Sprint_63, PR #366)
**Scope delivered**: F181, F180, F184, F182, F164 (closed), GP-12, GP-16 (prep; walkthrough to
Sprint 64), GP-5 (drafts approved; publication to Sprint 64), F94, plus F185 pulled in-sprint.

## 1. Effective while as Efficient as Reasonably Possible

Good. Nine planned tasks plus one pulled-in fix (F185) landed in three days with the suite
green throughout (1,952/15/0). The F180 deferral design (header-first oracle instead of the
originally-registered body-size cap) delivered a ~10x live speedup (36s vs 6m17s) and halved
peak memory, while keeping full-body matching -- a better outcome than the planned scope.
Efficiency losses were self-inflicted and are itemized in Category 9: the C-1 control-byte
corruption cost a diagnosis-and-repair cycle, and editing gradle config while an Android build
ran broke that build.

## 2. Testing Approach

Good, with one caught weakness. Mutation verification was applied to every new gate and caught
a real gap: the first F185 tests exercised only the decoder and SURVIVED a call-site mutation;
the conversion-path test was added and went red properly. The F184 in-VM E2E suite covered the
three Sprint 62 surfaces that had shipped without any E2E asset, through the real
startRealScan entry point. F182 ended the thrice-repeated mt2c baseline rot with synthetic
seeding. The live MV evidence went beyond spot-checks: a four-line independent audit proved
the headers-only claim, and the deferral demo proved the body-fetch path with per-message log
evidence. Weakness: my scratch probe files and mutation runs happen in the working tree; a
stray probe file nearly reached a commit (caught by the git-status accounting rule).

## 3. Effort Accuracy

Good. The plan estimated in minutes per CODING_VELOCITY.md and the coding tasks tracked close
to estimate. Unplanned additions (F185 fix, C-1 repair, emulator resize, MV demo tooling) were
absorbed without displacing planned scope. The emulator resize was the largest unplanned block
(wipe-data forced account re-adds on Harold's side).

## 4. Planning Quality

Very good. The 9-card plan with augmented task cards survived contact with execution: no task
was descoped, none needed re-design mid-sprint. Harold's F180 design objection at planning
time ("body rules must match the entire body, not a stub") directly shaped the
deferred-fetch-instead-of-truncation architecture, which is the sprint's best outcome -- the
plan-stage design conversation earned its cost.

## 5. Model Assignments

No issues -- expectations met. Planner and all execution ran on the top tier this sprint;
cheapest-first was considered per task but the sprint's tasks were dominated by design-bearing
work (F180 oracle semantics, F94 flavor/build-script interplay, review-round fixes) where the
tier was justified and recorded in the plan.

## 6. Communication

Good. Live MV coordination (scan monitoring while Harold drove the emulator, screenshot-driven
verdicts, per-question numbered digits) worked smoothly. Two misses: (a) a compound question
(GP-5 "approve text AND choose URL") got a single-part answer and the second part had to be
re-derived -- the yes/no-single-answer rule exists for exactly this; (b) mid-turn steering
messages arrived while background work ran, and one ("no need to do twice") shows Harold could
not tell whether work had already started -- narrating in-flight background tasks earlier
would have prevented the doubt.

## 7. Requirements Clarity

Very good. Harold's verbatim design constraints (F180 body-matching objection, ADR-0042
platform parity, GP-16 personal-account/12-tester route) were specific enough to design
against directly. The F186/F187 backlog asks were enumerated as discrete numbered items at
registration per the multi-part-request rule.

## 8. Documentation

Good. GP-5 legal drafts were code-verified against actual app behavior rather than templated;
GP-16 setup guide written for the decided route only; ARCHITECTURE.md updated in-sprint (F94
flavors, stale scan-mode block) before MV per the no-defer rule; MV evidence recorded in the
plan with numbers, not adjectives. CHANGELOG entries were written per-change at commit time.

## 9. Process Issues

Three real ones, all resolved in-sprint, all with the class prevented:
1. **C-1 control-byte corruption (self-inflicted)**: python heredoc non-raw strings turned
   `\a`/`\f` into BEL/FF bytes in 4 places in build-with-secrets.ps1, masked locally by an
   untracked file. Root causes: ignored python escape SyntaxWarnings, and "verification" that
   did not exercise the actual script path. Repaired byte-verified; unmasked re-run proved the
   real path. Lesson recorded: never ignore escape warnings; verify through the code path, not
   beside it.
2. **Edited build config during a running Android build**: broke the in-flight build. The
   serialize-platform-builds rule now explicitly covers EDITS of build inputs, not just
   concurrent builds.
3. **Demo-rule insert stored invalid JSON**: my hand-insert used an invalid escape; the rule
   was silently neutralized and the first demo scan showed nothing. Fixed with json.dumps; the
   PRODUCT defect it exposed (silent neutralization, no warning) is registered as F188 -- a
   textbook silent-failure find made by a process mistake.
Also noteworthy (not a defect): the emulator /data exhaustion (91% full) surfaced as an app
freeze that looked like a product hang; diagnosis correctly separated installd purge storms
from app fault before any code was touched.

## 10. Risk Management

Good. The F180 risk (verdict divergence between header-only and full evaluation) was pinned by
an oracle-equivalence suite BEFORE the live run, and the failed-body-fetch degradation path was
made a recorded deliberate decision with a loud log. The F94 risk (breaking Harold's daily
sign-in) was contained by defaulting -Env to prod. The C-1 episode is the risk-management
counterexample: an untracked local file masked a broken committed path -- the unmasked re-run
is now the standard.

## 11. Next Sprint Readiness

Ready. Sprint 64's first task is decided (GP-16 guided walkthrough incl. GP-5 hosting/URL),
the Android/GP track is prioritized in the master plan, and three fresh MV-sourced items
(F186 body-rule authoring, F187 URL-rule cleanup 647/732, F188 silent neutralization) are
registered with verified scopes. Carry-outs are explicit; nothing is implicitly dangling.

## 12. Architecture Maintenance

Good. F180 is the sprint's architectural change (two-stage evaluation contract on
SpamFilterPlatform via fetchFullBody) and is documented in ARCHITECTURE.md with the
degradation semantics; F94 flavor architecture documented; GP-12 executed an existing ADR
decision (ADR-0030/0033) rather than inventing a new one; no ADR-worthy decision was made
without an ADR home.

## 13. Minor Function Updates for the Next Sprint Plan (carry-ins)

- GP-16 guided account-creation walkthrough as Sprint 64 FIRST task (Harold decision), folding
  in the GP-5 hosting/URL decision and publication.
- F94 follow-on: the four Firebase/GCP console registrations for the .dev package are now
  OPTIONAL (dev sign-in works via appauth without them) -- re-scope or close that prerequisite
  list at refinement.
- SEC-9 (hardcoded Android client id) was sequenced "after/alongside F94" -- F94 is done, so
  SEC-9 is now unblocked for selection.

## 14. Function Updates for the Future Backlog

Already registered during the sprint (F186, F187, F188). One additional candidate: the review
agent's live mutation-verification creates scratch files in the working tree (zz_probe*);
formalizing a scratch-directory convention for in-repo probe tests would remove a
stray-commit hazard (S effort, process/tooling).
