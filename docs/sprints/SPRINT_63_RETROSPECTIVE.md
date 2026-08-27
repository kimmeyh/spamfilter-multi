# Sprint 63 Retrospective

**Sprint**: 63 (2026-08-24 to 2026-08-27, branch feature/20260824_Sprint_63, PR #366)
**Scope delivered**: F181, F180, F184, F182, F164 (closed), GP-12, GP-16 (prep; walkthrough
carried to Sprint 64), GP-5 (drafts approved; publication carried to Sprint 64), F94, plus
F185 pulled in-sprint by Harold.
**Feedback recorded**: 2026-08-27. Harold provided combined Product Owner / Scrum Master /
Lead Developer feedback (his message titled the block "Sprint 62 Review/Retrospective" -- a
copy-paste artifact of the recurring template; the feedback was given for Sprint 63 at Sprint
63 Manual Validation completion and is recorded as such). Claude Code Development Team
feedback drafted in parallel per the 7-Step Protocol (Step 2 draft:
`drafts/SPRINT_63_RETROSPECTIVE_claude_draft.md`).

## Sprint 63 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Good
- **Claude Code Development Team**: Good. Nine planned tasks plus one pulled-in fix (F185)
  landed in three days with the suite green throughout (final 1,955/15/0). The F180 deferral
  design (header-first oracle instead of the originally-registered body-size cap) delivered a
  ~10x live speedup (36s vs 6m17s) and halved peak memory while keeping full-body matching --
  a better outcome than the planned scope. Efficiency losses were self-inflicted and are
  itemized in Category 9.

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Needs improvement as
  noted by dev team during sprint
- **Claude Code Development Team**: Good, with two caught weaknesses. Mutation verification
  was applied to every new gate and caught real gaps twice: the first F185 tests exercised
  only the decoder and survived a call-site mutation (conversion-path test added, went red
  properly), and the second review pass proved the F180 exc.body deferral clause -- the branch
  preventing header-only deletion of body-exception-protected mail -- was deletable with a
  fully green suite (closed with 3 isolated single-rule guard tests; the mutation now fails
  exactly one test). The F184 in-VM E2E suite covered the three Sprint 62 surfaces that had
  shipped without any E2E asset. F182 ended the thrice-repeated mt2c baseline rot. Live MV
  evidence went beyond spot-checks: a four-line independent audit proved the headers-only
  claim and the deferral demo proved the body-fetch path with per-message log evidence.
  Weakness: scratch probe files and mutation runs happen in the working tree; a stray probe
  file nearly reached a commit (caught by the git-status accounting rule).

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Good
- **Claude Code Development Team**: Good. The plan estimated in minutes per
  CODING_VELOCITY.md and the coding tasks tracked close to estimate. Unplanned additions
  (F185 fix, C-1 repair, emulator resize, MV demo tooling, review round 2 guard tests) were
  absorbed without displacing planned scope. The emulator resize was the largest unplanned
  block (wipe-data forced account re-adds on Harold's side).

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Good
- **Claude Code Development Team**: Very good. The 9-card plan with augmented task cards
  survived contact with execution: no task was descoped, none needed re-design mid-sprint.
  Harold's F180 design objection at planning time ("body rules must match the entire body,
  not a stub") directly shaped the deferred-fetch-instead-of-truncation architecture, which
  is the sprint's best outcome -- the plan-stage design conversation earned its cost.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Good
- **Claude Code Development Team**: No issues -- expectations met. Planner and all execution
  ran on the top tier this sprint; cheapest-first was considered per task but the sprint's
  tasks were dominated by design-bearing work (F180 oracle semantics, F94 flavor/build-script
  interplay, review-round fixes) where the tier was justified and recorded in the plan.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Very Good
- **Claude Code Development Team**: Good. Live MV coordination (scan monitoring while Harold
  drove the emulator, screenshot-driven verdicts, numbered-digit questions) worked smoothly.
  Two misses: (a) a compound question (GP-5 "approve text AND choose URL") got a single-part
  answer and the second part had to be re-derived -- the single-answer question rule exists
  for exactly this; (b) one mid-turn steering message ("no need to do twice") showed Harold
  could not tell whether background work had already started -- narrating in-flight
  background tasks earlier would have prevented the doubt.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Very Good
- **Claude Code Development Team**: Very good. Harold's verbatim design constraints (F180
  body-matching objection, ADR-0042 platform parity, GP-16 personal-account/12-tester route)
  were specific enough to design against directly. The F186/F187 backlog asks were enumerated
  as discrete numbered items at registration per the multi-part-request rule.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Very Good
- **Claude Code Development Team**: Good. GP-5 legal drafts were code-verified against actual
  app behavior rather than templated; GP-16 setup guide written for the decided route only;
  ARCHITECTURE.md updated in-sprint (F94 flavors, stale scan-mode block) before MV per the
  no-defer rule; MV evidence recorded in the plan with numbers, not adjectives. CHANGELOG
  entries were written per-change at commit time.

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Good - see issues
  noted by dev team during sprint
- **Claude Code Development Team**: Three real ones, all resolved in-sprint, all with the
  class prevented:
  1. **C-1 control-byte corruption (self-inflicted)**: python heredoc non-raw strings turned
     `\a`/`\f` into BEL/FF bytes in 4 places in build-with-secrets.ps1, masked locally by an
     untracked file. Root causes: ignored python escape SyntaxWarnings, and "verification"
     that did not exercise the actual script path. Repaired byte-verified; unmasked re-run
     proved the real path. Lesson recorded: never ignore escape warnings; verify through the
     code path, not beside it.
  2. **Edited build config during a running Android build**: broke the in-flight build. The
     serialize-platform-builds rule must explicitly cover EDITS of build inputs, not just
     concurrent builds.
  3. **Demo-rule insert stored invalid JSON**: the hand-insert used an invalid escape; the
     rule was silently neutralized and the first demo scan showed nothing. Fixed with
     json.dumps; the PRODUCT defect it exposed (silent neutralization, no warning) is
     registered as F188 -- a textbook silent-failure find made by a process mistake.
  Also noteworthy (not a defect): the emulator /data exhaustion (91% full) surfaced as an app
  freeze that looked like a product hang; diagnosis correctly separated installd purge storms
  from app fault before any code was touched.

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Very Good
- **Claude Code Development Team**: Good. The F180 risk (verdict divergence between
  header-only and full evaluation) was pinned by an oracle-equivalence suite BEFORE the live
  run, and the failed-body-fetch degradation path was made a recorded deliberate decision
  with a loud log. The F94 risk (breaking Harold's daily sign-in) was contained by defaulting
  -Env to prod. The C-1 episode is the risk-management counterexample: an untracked local
  file masked a broken committed path -- the unmasked re-run is now the standard.

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Very Good
- **Claude Code Development Team**: Ready. Sprint 64's first task is decided (GP-16 guided
  walkthrough incl. GP-5 hosting/URL), the Android/GP track is prioritized in the master
  plan, and three fresh MV-sourced items (F186 body-rule authoring, F187 URL-rule cleanup
  647/732, F188 silent neutralization) are registered with verified scopes. Carry-outs are
  explicit; nothing is implicitly dangling.

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: Very Good
- **Claude Code Development Team**: Good. F180 is the sprint's architectural change
  (two-stage evaluation contract on SpamFilterPlatform via fetchFullBody) and is documented
  in ARCHITECTURE.md with the degradation semantics; F94 flavor architecture documented;
  GP-12 executed an existing ADR decision (ADR-0030/0033) rather than inventing a new one; no
  ADR-worthy decision was made without an ADR home.

### 13. Minor Function Updates for the Next Sprint Plan (carry-ins)

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: none
- **Claude Code Development Team**: Three candidates surfaced for Step 5 decision (per
  protocol, not auto-added): GP-16 walkthrough as Sprint 64 first task (already Harold's MV
  decision); F94 follow-on -- the four Firebase/GCP console registrations for the .dev
  package are now OPTIONAL (dev sign-in works via appauth without them), re-scope or close
  that prerequisite list at refinement; SEC-9 now unblocked (was sequenced after F94).

### 14. Function Updates for the Future Backlog

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: none
- **Claude Code Development Team**: Already registered during the sprint (F186, F187, F188).
  One additional candidate surfaced for Step 5: a scratch-directory convention for in-repo
  probe tests to remove the stray-commit hazard.

### Questions to be discussed before ending the sprint

- **Product Owner / Scrum Master / Lead Developer (Harold, combined)**: none

## Improvement Decisions (Step 6)

**Harold, 2026-08-27: "all now"** -- all seven proposals apply-now, plus an eighth improvement
Harold added in the same message. All eight applied 2026-08-27 (Step 7):

1. **IMP-1 Isolated-branch guard rule** -- APPLIED: TESTING_STRATEGY.md "Isolated-Branch
   Guard Tests" section (shared fixtures mask deletable clauses; checklist + mutation-verify
   requirement).
2. **IMP-2 Scratch-probe file convention** -- APPLIED: TESTING_STRATEGY.md "Scratch Probe
   Tests Stay Out of the Repo" section; `test/scratch/` gitignored in mobile-app/.gitignore;
   memory `feedback_scratch_probes_outside_repo`.
3. **IMP-3 No compound decision questions** -- APPLIED: memory `feedback_yes_no_questions`
   extended (two decision parts = two numbered questions; unanswered half = re-ask trigger).
4. **IMP-4 Announce background work at launch** -- APPLIED: new memory
   `feedback_announce_background_launches` (indexed in MEMORY.md).
5. **IMP-5 Python escape-warning hard rule** -- APPLIED: memory
   `feedback_python_heredoc_windows` extended (raw strings for file content; SyntaxWarning =
   stop-and-fix; verify through the real consuming code path, unmasked).
6. **IMP-6 Serialize build-input EDITS** -- APPLIED: CLAUDE.md concurrent-build rule extended
   to ban editing build inputs while any Flutter build runs; memory
   `feedback_serialize_platform_builds` extended.
7. **IMP-7 Sprint 64 refinement carry-ins** -- APPLIED: SPRINT_64_PLAN.md stub created (GP-16
   walkthrough as FIRST task incl. GP-5 publication; F94 console-prereqs optional; SEC-9
   unblocked); SEC-9 master-plan entry annotated.
8. **IMP-8 Timestamp footer (Harold, added at Step 6)**: "When completing a response like you
   did above can you add the date/time at the bottom (likely a hook). Example: 08/27/2026
   12:07am" -- APPLIED as a standing behavioral rule (new memory `feedback_timestamp_footer`,
   indexed in MEMORY.md): decision-point and milestone-completion responses end with the real
   current date/time in that format. Recorded here rather than as a hook because hooks cannot
   append text to a rendered reply.
