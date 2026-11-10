# F350: Risk-based testing -- effective, and as efficient and quick as reasonably possible

Sprint 85, Task 2 (Issue #562). Status: DRAFT (R-1, R-2 and R-5 written) -- R-3 local timings PENDING (need an idle
machine); R-6 and R-7 PENDING (R-7 decisions are Harold's).

## Summary (BLUF)

- The suite is large and mostly cheap: 397 test artifacts, about 3,567 Dart test cases. The cost is not the tests. It
  is the order of the steps around them: Phase 5 runs its checks one after another, and a sprint waits on macOS CI rounds
  of 35-75 minutes each.
- The tests mostly miss the same defect classes, sprint after sprint. In Sprints 78-84, 180 defects escaped the tests
  and were found by review or by Harold. The two largest classes, silent swallows (42) and false comments (18), occur in
  all seven sprints. No test kind in the suite targets either class.
- No automated test runs on an Android emulator or device. Four of the escaped defects in Sprints 78-84 were found only
  on an emulator or a phone.
- 16 of the 49 policy gates can pass when nothing matched, and 19 were never shown to fail. Five pairs or groups
  repeat each other.
- Mutation proofs are many (about 850 mutants in Sprints 74-84) but 13 proven tests later missed their defect. Re-running
  the same mutants would have changed the verdict in 1 of the 13; the cheaper checks are mutating the call site and
  asserting a match count.
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

The 49 files in `mobile-app/test/policy/` (`section_scope.dart` is a helper), read one by one on 2026-11-10 against
the plans, retrospectives and `CODING_VELOCITY.md` of every sprint. Four of the vacuity findings below were checked
again by hand at file:line before they were written here (android_signing, legal_docs, version_consistency,
gmail_label_id_gate).

Kind: 44 read source or docs as text, 4 mix text and runtime checks, 1 runs app code (`gmail_label_id_gate`).

Proof that the gate can fail:
- 22 have a recorded KILLED or red result. For six of them the proof covers one test of several (factory_call_site,
  msix_config, version_consistency, winwright_script_strings, behavioral_coverage first version, screen_version_line).
- 8 have only a card-level mutant count that does not name the file.
- 19 were never shown to fail: android_icon_assets, android_minify, android_network_security, android_signing,
  app_content_declarations, cited_test_names, data_residency, debug_allowlist_gate, dev_version_ahead,
  doc_control_chars, f219_task_affinity, legal_docs (planned only), log_redaction, play_listing_assets,
  provider_setup_steps, stale_footer, system_inset_wiring, test_inventory_coverage, tester_instructions.

Gates that pass when nothing matched (16). The pattern is the Sprint 69 F210 class: green because nothing matched looks
the same as green because nothing is wrong.
- `android_signing_test.dart:37`: `git ls-files` exit code is never checked. If git fails, the list is empty and the
  test passes.
- `legal_docs_test.dart:110`, `:147`: a missing served page is skipped. With both pages gone, both tests pass.
- `version_consistency_test.dart:101`: a missing folder is skipped, and nothing asserts that any version literal was
  found.
- `gmail_label_id_gate_test.dart:175-182` (and three more loops): the loop asserts each recorded label id, but nothing
  asserts that a call was recorded. With no call, it passes.
- `msix_config_test.dart:152-206`: the secrets tests are generated per file found; zero files gives zero tests.
- `play_listing_assets_test.dart:136-155`: an absent asset is skipped with a print. The file itself records that the
  mutation was not re-run after a rewrite (`:270-303`).
- No count of matched items: behavioral_coverage (`:112-133`), f298_rule_write_reload_gate (`:48-57`),
  log_redaction (`:58-66`), screen_version_line_wiring (`:59-96`), system_inset_wiring (`:59-103`).
- Whole-file `contains()` that a comment can satisfy: f219_task_affinity (`:71`, `appAuthRedirectScheme`), the
  Sprint 70 SEC-9 class; android_minify (`:29`).
- app_content_declarations (`:155`) takes the text to the end of the file, the defect `section_scope.dart:11-17`
  exists to prevent.
- Self-checks that cannot fail: appbar_action_order (`:64-70`, a literal checked against itself), text_contrast
  (`:47-54`, tests a copy of the regex, not `failingGrey`).
- release_notes: missing files and separators `return` or `continue` (`:60`, `:97`, `:150-178`).
- Five more are low risk (no count, but a narrow scan): data_safety_declarations, doc_control_chars,
  provider_setup_steps, stale_footer, test_inventory_coverage (skipped on non-Windows hosts without Python).

Duplicates (5 groups, 11 files):
- `dev_version_ahead_test.dart:190-210` and `version_consistency_test.dart:134-162`: both compare `msix_version` with
  the pubspec version. version_consistency is stricter.
- `msix_config_test.dart:53-65` and `r76_4_content_history_policy_test.dart:44-52`: both require
  `--dart-define=APP_ENV=prod` in `windows_build_args`.
- `android_client_id_test.dart:82-92`, `:130-145` and `f219_task_affinity_test.dart:70-74`: `appAuthRedirectScheme`;
  f219 is the weaker copy (comments not stripped).
- `data_residency_test.dart:31-47` and `app_content_declarations_test.dart:128-146`: ad SDK ban lists overlap.
- `platform_check_seam_test.dart:104-118` bans `Platform.isX` in all of `lib/` outside `core/platform`, which
  subsumes `f142_android_nav_removal_test.dart:34` and `factory_call_site_test.dart:61-70`.

Text-only gates with no behavior test beside them: 28 of 44. Ten of them guard app code or build configuration, not
docs: android_client_id, android_minify, android_network_security, android_signing, f219_task_affinity,
gmail_scope_parity, msix_config, provider_setup_steps, stale_footer, text_contrast.

Hook cases: `.claude/hooks/test-cases/` holds 208 JSON cases (72 at the top level; closeout 27, commit-lock 14,
heredoc-guard 31, sprint-cards 14, staging-guard 25, stash-guard 13, velocity-warn 12). They feed a payload to the
real hook, so they are behavior tests. They were not analyzed case by case.

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

Tight rule, computed on the 2026-11-10 inventory (400 artifacts; the script itself is unchanged, the count comes from
its JSON):
- Impact from the categories only, churn 40 or more: 61 files (unit 43, widget 9, integration 5, policy 4). By reason
  (a file can have several): deletes or moves mail 32, background workers 25, credentials 16, scan coordinator 11,
  credentials and transport security 2, migrations 1.
- The same rule with churn 25 or more: 84 files.
- Only 4 of the 49 policy files were high because of the blanket "policy = high" rule alone; the other 45 policy files
  stay where their categories put them. Policy gates are fast text checks, so they can run on every change whatever
  their tier.
- Limit: impact is read from imports, so a test that imports a mail-moving file for a type counts as mail-moving
  (example: `diagnostic_logger_test.dart`). The rule over-includes; it does not miss a file that imports the code.
- Its run time is not yet measured (R-3 needs an idle machine).

## R-5: Mutation-proof policy

Volume: about 850 mutants in Sprints 74-84 (about 45 in S74, rising to about 140 in S83), plus about 16 proof records
without mutant counts in Sprints 70-73. Approximate: one proof can appear in a plan, a retrospective and
`CODING_VELOCITY.md`. `SPRINT_71_RETROSPECTIVE.md` does not exist and `SPRINT_71_PLAN.md` records no mutation.

Cases where a test was mutation-proven and then found not to guard the defect: 13. For each, git was read to see what
changed between the proof and the discovery.

- S70 F220 first test (e6e2a4da; found at 5.1.1, f180ad08). The handler file changed; the defect was the lease, which
  no mutant touched.
- S70 F220 replacement (f180ad08; PR #418 C-2): the test asserted against its own harness copy.
- S72 F233 (070d3fee; Manual Validation): no toggle existed. The tests used the `debugSetEnabled` seam.
- S72 F232 (26f591b4; 5.1.1): the screen-load caller and the cross-account leak were never tested.
- S73 F234 (344a139e; review C-2): the feature was inert from its first commit; the text gate still matched.
- S73 F234 after the fix (0e4267ab): the pure function was tested; the mutation SURVIVED at the call site. The re-run
  found it before ship.
- S73 F224 (83d72e69): a review mutation passed all 14 tests.
- S73 F229 wiring gate (f1dcbde5; PR #435 C-2) and S73 behavioral_coverage (142b9990; PR #435 I-2): gates that matched
  nothing.
- S76 4-isolate lock test (M188 KILLED): correct on Windows, wrong on Android (POSIX locks are per process).
- S81 F302 gate v1 (fd12e065; 7.7.1) and v2 (b5268a50; improvement review): missed identifierValue, then a swap and
  a tear-off.
- S84 F342 wiring test (5a315e47, 7 of 7; 7.7.1 L4 and M1): text-only, and the handler order was wrong. A re-run
  after 36b724ac (4 KILLED) still missed it.

Would a "re-run when the guarded code, the test or a shared helper changes" rule have triggered before discovery? In 7
of 13 (S70 F220 first, S72 F233, S72 F232, S73 F234 twice, S81 F302 v1, S84 F342). Would the re-run have changed the
verdict? In 1 of 13 (S73 F234 after the fix, which is how that gap was found). In the other triggered cases the re-run
repeats a mutation the test already kills, because the defect lies outside what was mutated.

Conclusion: re-running the same mutants buys little. The 13 cases fail in three ways, and each has a cheaper check:
- the defect is outside the mutated code (wiring, a second caller, the other half): mutate the CALL SITE and every
  caller, which is the Sprint 72 IMP-1 and Sprint 73 IMP-3 rules;
- the gate matches nothing: assert a non-zero match count in every source gate (16 files above lack one);
- the platform differs: test on the platform that ships (Sprint 76 IMP-3).

Where specs live: no mutation spec is tracked (`git grep -l '"find"' -- '*.json'` is empty). Specs exist only in
ignored scratch folders, so a proof cannot be re-run from the repository. `scripts/mutation-test.ps1:51` points its
example at a path outside the repo.

## R-6: Which full runs are needed

Today, per sprint: local 5.2 full suite; CI run 1 (by hand, at 7.7.1); CI run 2 (at `gh pr ready`). `ios.yml` runs on
`workflow_dispatch` or a push that touches `mobile-app/ios/**` or `ios.yml`.

PENDING: recommendation with the measured timings.

## R-7: Decisions

PENDING: each recommendation as a numbered decision, prevention first, asked at Manual Validation.

## Target (AC-5)

A small fix is verified in its development time plus about 15 minutes: the changed files' tests plus the tight high
tier locally (minutes), and CI as the backstop.
