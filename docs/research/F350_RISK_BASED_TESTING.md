# F350: Risk-based testing -- effective, and as efficient and quick as reasonably possible

Sprint 85, Task 2 (Issue #562). Status: DRAFT (R-1 committed) -- R-3 local timings PENDING (need an idle machine); R-7 decisions
PENDING (Harold).

## Summary (BLUF)

- The suite is large and mostly cheap: 397 test artifacts, about 3,567 Dart test cases. The cost is not the tests. It
  is the order of the steps around them: Phase 5 runs its checks one after another, and a sprint waits on macOS CI rounds
  of 35-75 minutes each.
- The tests mostly miss the same defect classes, sprint after sprint. In Sprints 78-84, 180 defects escaped the tests
  and were found by review or by Harold. The two largest classes, silent swallows (42) and false comments (18), occur in
  all seven sprints. No test kind in the suite targets either class.
- No automated test runs on an Android emulator or device. Four of the escaped defects in Sprints 78-84 were found only
  on an emulator or a phone.
- A risk tier (ISTQB likelihood x impact) can be computed from the repository. Today's rule puts 112 of 397 artifacts
  (28 percent) in the high tier, which is too many to be "the fast set". R-4 proposes a tighter rule.

## Sources

- ISTQB Certified Tester Foundation Level Syllabus v4.0.1, 2024-09-15 (fetched 2026-11-10 from istqb.org, 78 pages):
  - 5.2: "The test approach, in which test activities are selected, prioritized, and managed based on risk analysis and
    risk control, is called risk-based testing."
  - 5.2.1: "A risk can be characterized by two factors: Risk likelihood - the probability of the risk occurrence ...;
    Risk impact (harm) - the consequences of this occurrence. These two factors express the risk level ... The higher
    the risk level, the more important is its treatment."
  - 5.2.3: "In the quantitative approach the risk level is calculated as the multiplication of risk likelihood and risk
    impact." Results are used to "Prioritize testing in an attempt to find the critical defects as early as possible"
    and to "Determine whether any activities in addition to testing could be employed to reduce risk".
  - 5.1.5: "Risk-based prioritization, where the order of test execution is based on the results of risk analysis ...
    Test cases covering the most important risks are executed first."
  - 5.1.6: "Tests in the bottom layer are small, isolated, fast ... The top layer represents complex, high-level,
    end-to-end tests. These high-level tests are generally slower".
- Repository records: sprint plans and retrospectives 78-84, `docs/CODING_VELOCITY.md`, git history of
  `feature/20261105_Sprint_84`, `.github/workflows/ci.yml` and `ios.yml`, `gh run list` / `gh run view` (read
  2026-11-10).
- Inventory: `scripts/test-inventory.py` (R-1, this sprint), output of 2026-11-10 16:5x.

## R-1: Inventory

`python scripts/test-inventory.py --out <file.json> --markdown <file.md>` lists every test artifact: Dart unit, widget,
policy and integration files, `integration_test/` files, Python `unittest` modules, hook-case folders and WinWright
scripts. Per artifact: kind, what it guards, the lib files it imports or reads, test count, where it runs, platforms,
last `fix` commit that touched it (heuristic, labeled), 60-day churn, impact, likelihood and tier. `--measure` times
files with `flutter test --reporter json`; `--ci` reads job and step durations from `gh`.

`mobile-app/test/policy/test_inventory_coverage_test.dart` walks `test/` and `integration_test/` itself and requires
the script's `--list-paths` to match in both directions, so a test file in a new folder fails the gate. Mutation-checked
(3 of 3 KILLED); the script's own unittest has 29 cases (10 of 10 mutants KILLED).

Counts (2026-11-10):
- By kind: unit 197, widget 80, policy 49, integration 34, python-unittest 22, hook-case 8, winwright 7.
- By where it runs: CI Linux "Analyze and Test" 359; iOS Simulator tests job 8 (one file excluded there,
  `sprint62_surfaces_test.dart`); iOS Simulator screens job 1; local only 7 (WinWright).
- By platform: Windows host 375, CI Linux 359, iOS Simulator 9, any host 22 (Python), Android emulator 0.

Limits: "last caught a real defect" is a heuristic (a commit whose subject starts with `fix` touched the test). Per-file
CI time is not available, because CI runs the suite as one `flutter test` step.

## R-2: Effectiveness

### Defects the tests did not catch, Sprints 78-84

180 escaped defects, read from the 7.7.1 records, Phase 5 evidence and Manual Validation notes of Sprints 78-84.

By class, with the cheapest check that would have caught the class:

- **S, silent swallow (42; every sprint).** A catch or skip whose failure reaches only the log. Cheapest catch: a source
  gate that lists every `catch` in `lib/` with its handling, plus a failure-path test per new catch that asserts what
  the USER sees. Today silent-failure-hunter finds these at 7.7.1, which is the last possible step.
- **H, tooling gate vacuous (25).** A hook or gate that passes because nothing matched. Cheapest catch: a
  must-block case for every new gate pattern (`scripts/test-hook.ps1 -ExpectBlock`), already the rule; the escapes are
  gates shipped without one.
- **F, false comment or doc (18; every sprint).** A comment that asserts a mechanism the code does not have. No test
  kind can catch this. The cheapest check is the existing rule (grep the mechanism in the same turn), applied by the
  5.1.2 self-review.
- **W, wiring (17).** A correct, tested function called from the wrong place, or not called. Cheapest catch: a test
  through the real entry point (the screen or the worker), not the extracted seam; re-run the mutation after the fix.
- **C, concurrency and cross-isolate (11).** Cheapest catch: a two-isolate or two-process test on the platform that
  ships.
- **V, vacuous test (11).** A test that asserts the half that works. Cheapest catch: the "what would this NOT catch"
  line plus a mutation of the other half.
- **T, UI text that promises behavior (8).** Cheapest catch: a widget test per new control that asserts the action
  the label names.
- **D data/migration 7, L layout 7 (rising, S83-S84), O OS primitive 5, R neighbour regression 5, P performance 4,
  X other 20.**

Who found them: silent-failure-hunter 62, other stages 45, code-reviewer 43, Manual Validation 21, unnamed 11,
Copilot 7, improvement review 7, CI 3, hooks 0.

Defects found only in one environment:
- Phone only: S80 new-mail trigger; S78/S79 delivery timing.
- Android emulator: S79 stop handler; S84 F355 ANR.
- Real Windows shell: S82 toast click.

### Tests that fail for unrelated reasons

- **F349**: three Task Scheduler tests time out at 30 s in the full suite (`windows_task_scheduler_service_test` x2,
  `powershell_script_generator_test` x1). They pass alone. `Get-ScheduledTask` for a missing task takes 7.1 s
  in-process on this machine, so the query is slow, not the test. Every full run since Sprint 83 is red for this reason.
- **F302 timing tests**: two failures at the default concurrency in Sprint 84 5.2; pass alone and at
  `--concurrency=4` (TESTING_STRATEGY.md:31).
- Effect: a red suite that is "known red" hides a new failure. Sprint 84 5.2 had to inspect every failure by name.

### Gates that cannot fail, or repeat another gate

PENDING: cross-check of the 49 policy files against their mutation records. To be filled before the decisions.

## R-3: Efficiency

### Cost per test kind and place (measured)

- CI "Analyze and Test" (ci.yml, ubuntu-latest), median of the 2 successful runs of the last 10 (read 2026-11-10):
  485.5 s total; `flutter test` 400.5 s; `flutter analyze` 20 s; flutter-action set-up 41 s; Python hook tests 8 s.
- CI Windows build verification: 296 s (build 135.5 s). CI Android build verification: 373 s (build 306.5 s).
- iOS Simulator (ios.yml, Sprint 84 figures): gate job 33 min; screens job 45-69 min (one Xcode build per test file).
- Local full suite (Sprint 84 measurement): 4 min 25 s at default concurrency (6 failures), 6 min 51 s at
  `--concurrency=4` (3 failures, all F349).
- WinWright: 8 min 22 s for 3 scripts (Sprint 84).
- Local per-file time: the 3-file sample from 2026-11-10 (109-178 s each) was taken on a loaded machine and is NOT a
  baseline. PENDING: re-measure on an idle machine.

### Why local runs are slow

PENDING (idle machine): full suite at `--concurrency` 2, 4, 6 and 8; one run with the Defender exclusion state
recorded; the real-PowerShell tests and the 500-message tests timed alone.

### Sprint 84 timeline, two tasks (AC-3, rebuilt from git and CODING_VELOCITY.md)

F345 (iOS Simulator CI, Task 8):
- 08:46 plan approved; 08:54 agent starts.
- CI runs at 09:40, 11:27, 13:08, 14:31, 15:22, 16:24, 17:39, 18:59; task done 19:44. 8 rounds, about 10 h 50 min wall
  clock for an estimate of 120-210 min. Active time was not recorded.
- Rounds that a cheaper step would have saved: run 2 timed out (fixed by splitting the job); run 4's probe was skipped
  because `IOS_PROBE=1` is not `"true"` (a local check of the workflow condition would have caught it); runs 6-7 found
  the soft-keyboard cause.
- F345 was the critical path: Manual Validation started at 20:11, 27 minutes after it finished.

F342 (Android worker stop, Task 2):
- 08:49-10:33 agent (about 104 min); commit 11:02.
- Phase 5 rehearsal fixes 17:17 (36b724ac); Manual Validation 11-07; 7.7.1 fix 11-07 21:13 (d4178c5b).
- Its proof needs the Fold or the emulator; no automated Android run exists, so its verification waited for Manual
  Validation.

Phase 5 on 2026-11-06, one after another: 5.2 full suite (about 14:58), WinWright sweep 15:24-15:34 and a re-run
15:35-15:41, 5.1.2 and 5.1.9 fixes 17:17, Manual Validation 20:11.

Steps that could run in parallel:
- Start CI run 1 by hand when the first task commits, not at 7.7.1.
- Run each changed file's tests (and its importers) during Phase 4, so 5.2 confirms rather than discovers.
- Run the WinWright sweep while the full suite runs (they use different resources: the screen versus the CPU).
- Share one Xcode build across the iOS screens test files.

## R-4: Risk tiers

Rule used by the inventory today (`scripts/test-inventory.py` docstring):
- Impact HIGH: a policy test, or a test that directly imports or reads mail-moving adapter code, credentials code, the
  scan coordinator, background workers or migrations.
- Likelihood: commits in 60 days touching the test or its lib files (high at 40 or more, medium at 10 or more;
  calibrated on today's data, median 15, 75th percentile 44).
- Tier: high impact and high or medium likelihood = high; high impact and low likelihood = medium; normal impact and
  high likelihood = medium; else low.

Result: high 112, medium 90, low 195. 112 high-tier files is too many for a "run on every change" set.

Proposal (for decision):
- Tight high tier: impact from the categories only (no blanket "policy = high"), likelihood high at 40 or more.
- Every change: the tight high tier plus the tests that import a changed file.
- A change to a shared file (a widely imported model, `main.dart`, a provider) runs everything.
- The full suite stays in CI as the backstop. Local runs start with the tests that failed last.
- Learned test selection: rejected (not enough failure history).

## R-5: Mutation-proof policy

PENDING: the Sprints 70-84 count of proofs a "re-run when the guarded code, the test or a shared helper changes" rule
would have triggered, and how many of those would have changed the verdict.

## R-6: Which full runs are needed

Today, per sprint: local 5.2 full suite; CI run 1 (by hand, at 7.7.1); CI run 2 (at `gh pr ready`). `ios.yml` runs on
`workflow_dispatch` or a push that touches `mobile-app/ios/**` or `ios.yml`.

PENDING: recommendation with the measured timings.

## R-7: Decisions

PENDING: each recommendation as a numbered decision, prevention first, asked at Manual Validation.

## Target (AC-5)

A small fix is verified in its development time plus about 15 minutes: the changed files' tests plus the tight high
tier locally (minutes), and CI as the backstop.
