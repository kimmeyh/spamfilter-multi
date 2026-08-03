# Sprint 52 Retrospective -- Claude Code Development Team draft

**AUTHORED BY CLAUDE** (Phase 7.3 Step 2). Drafted in parallel with Harold's
PO/SM/Lead-Developer feedback and never substituted for it.

Sprint 52: F133-S52, F131, F134, F134-ALL, F135, F136, F133-REMEDIATE.
16 commits, 40 files, +3,332/-1,607. 1,815 -> 1,828 tests. Analyzer clean throughout.

---

### 1. Effective while as Efficient as Reasonably Possible

Scope roughly doubled mid-sprint (SC-1, SC-2, SC-3) and still landed. The
efficiency loss I own is Task 2: I re-ran the two `test_f56_*` scripts that
`run-winwright-tests.ps1:237` already documented as excluded, then read their
known settle failure as new evidence. That was ~20 minutes spent re-deriving a
fact the repo already recorded. The pattern -- not checking whether a failure is
already a known-and-documented one before investigating it -- is worth naming.

### 2. Testing Approach

The strongest part of the sprint, and specifically because tests were verified to
FAIL before being trusted. Four separate mutation checks: the Skip `onTap`, the
Accounts `popUntil`, the No-Rule silent refresh, and the contrast/AppBar gates.
The Manage-Rules assertion in `sprint52_surfaces_test.dart` is the clearest
lesson -- my first version ("some node has a label >2 chars") PASSED while being
worthless, and only tightening it revealed my matcher was wrong. A green
assertion that cannot fail is not coverage.

The gap this sprint exposed: `appbar_action_order_test.dart` is a source-text
gate. It proved every screen CALLS the shared builder and that the order was
canonical -- and was structurally incapable of catching MV-1, where the handler
itself went nowhere. Source-text gates verify shape, not behavior.

### 3. Effort Accuracy

Two of the largest tasks ran low: Task 4 ~95m (est 45-75) and Task 7 ~165m (est
90-150). Task 2 ran ~2x low (~70m vs 20-35m). The common factor is that all
three had hidden breadth discovered during execution -- 28 nullable-accountId
sites, 27 screens instead of 8, five doc surfaces carrying a wrong claim.
Estimates were accurate for the mechanical tasks (3, 5, 6) and low wherever the
work involved finding out how much work there was.

### 4. Planning Quality

The plan was sound for what it knew. What it did not know was that F134's
acceptance criterion was repo-wide while its task listed 3 screens, and that
F133's audit would find 5-of-27 Semantics coverage. Both surfaced as scope
expansions rather than plan defects -- but AC-3 being repo-wide was knowable at
planning time from the AC text alone, and I did not catch it.

I also deviated on F135 R-1 on "large refactor" grounds and Harold correctly
rejected that: "large" is not a stopping criterion, and Criterion 9 is a
400-wall-clock-hour threshold this sprint was nowhere near.

### 5. Model Assignments

No escalation was needed; Harold explicitly offered Fable 5 for complexity and it
was not required. The work was breadth-heavy rather than depth-heavy -- many
mechanical edits plus a few genuine diagnoses (F131 root cause, MV-1
intersection). Opus handled both registers without a tier change.

### 6. Communication

Harold had to correct my framing three times, and each correction was the same
shape: I reported a conclusion more narrowly or more confidently than the
evidence supported. "Flagging and stopping are 2 different things" (I stopped
when I should have flagged and continued); "again no need to stop, you replanned
a task that had already been approved"; and MV-1, where I diagnosed "the No-Rule
screen" from one screenshot when Harold's follow-up -- "have not found a screen
where the icon is working" -- revealed it was global.

What worked: surfacing deviations explicitly at Manual Validation, per Harold's
standing request, rather than burying them.

### 7. Requirements Clarity

Harold's steering was consistently precise and arrived at the right moments --
the Task 5 button reuse, the "all screens OR all screens except Manual Scan"
pattern, the R-8 re-scope. Where I went wrong was not asking: I invented an
opt-in design for the Manual Scan icon when the codebase already had ONE
consistent pattern (default-on, self-referential suppression) that I could have
read off the existing five actions.

### 8. Documentation

Wrong findings were struck through rather than deleted -- in the winwright
README, `WINWRIGHT_SELECTORS.md`, `SPRINT_51_F130_FINDINGS.md`, and
`CODING_VELOCITY.md`. That was deliberate: the F131 failure mode was a wrong fix
recorded as verified, and deleting the evidence would have destroyed the lesson.

Gap I caught late: Sprint 52 had NO GitHub issue cards and NO CHANGELOG entries
through six task commits. Both belong at Phase 3 and were backfilled at the end
of Phase 4.

### 9. Process Issues

Two real ones, both mine:

1. **Phase 3 card creation was skipped entirely.** I went from plan approval
   straight into execution. Six commits landed with no issue cards and no
   CHANGELOG entries. The `sprint_status.json` note explicitly says cards are
   created at Phase 3 -- I did not walk that step.
2. **Re-investigating a documented exclusion** (Task 2, above).

### 10. Risk Management

The riskiest change was deleting 911 lines of screens. I verified dead THREE ways
before asking -- class/filename search, zero test references, and the decisive
one: the background-scan path never calls `runApp`, so the progress screen cannot
render on any path. That was the right level of caution given a broken glob
earlier in the same sprint had produced a false "0 imports" result.

The `git add -A` in two commits was sloppier than it should have been -- it swept
in `0Backlog Refinement.txt`. Correct per Harold's `0*` rule, but by luck rather
than intent.

### 11. Next Sprint Readiness

Nothing carries forward. R-7 and R-8 were closed at Harold's direction before
validation, so the F133 remediation set is 9/9 complete. Issues #289/#290/#291
are open and accurate. Sprint 52 is a clean handoff.

### 12. Architecture Maintenance

`StandardAppBarActions` became a genuine single source of truth, and MV-1 proved
its value: the fix landed once and every screen got it. The `openManualScan`
consolidation removed a platform-lookup duplication I had myself introduced.

No ADR was required. `docs/ACCESSIBILITY_STANDARDS.md` extends ADR-0037 rather
than superseding it, which was the right call for a standards doc.

### 13. Minor Function Updates for the Next Sprint Plan

None. (Improvement suggestions are carried in the Step 5 list rather than here.)

### 14. Function Updates for the Future Backlog

- Tooling: a behavior-level AppBar gate that pumps each screen and asserts every
  action's handler NAVIGATES, rather than asserting source text -- Medium.
- Five rule-editing screens (`rules_management`, `safe_senders_management`,
  `rule_test`, `rule_quick_add`, `yaml_import_export`) carry no `accountId`, so
  they cannot show Manual Scan/Settings/Accounts. Whether that is right is a
  product decision, not a defect -- Low.
