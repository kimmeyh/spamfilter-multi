# Sprint 58 Retrospective -- Claude Code Development Team Draft

Drafted 2026-08-15 in parallel with Harold's combined PO/SM/Lead Dev feedback, per the Phase 7
7-Step Protocol. Combined into `SPRINT_58_RETROSPECTIVE.md` after Harold's verbatim feedback was
recorded.

### 1. Effective while as Efficient as Reasonably Possible

Good, with three concrete inefficiencies Harold also flagged (root causes below, all
tooling-hygiene rather than product-work):

1. **Bash-into-PowerShell pipeline errors (`Select-Object: command not found`, exit 127)** --
   at least 3 occurrences. Root cause: composing a command in the Bash tool that piped the
   output of `powershell -Command "..."` into `Select-Object`, a PowerShell cmdlet -- the pipe
   executes in BASH context, which has no such command. Each occurrence wasted one tool call and
   a retry. The fix is mechanical: keep pipelines shell-homogeneous (put the whole pipeline
   INSIDE the `powershell -Command` string, use bash-native `head`/`tail` for post-processing,
   or use the dedicated PowerShell tool).
2. **TaskCreate batch-parameter error** -- 1 occurrence. Passed a `tasks` array to a tool that
   takes one task per call. The error message self-documented the correct usage and the retry
   pattern worked immediately, but the wasted call was avoidable by checking an unfamiliar
   tool's schema before first use.
3. **Dart LSP diagnostics noise** (the long "Target of URI doesn't exist:
   'package:flutter/material.dart'" cascades Harold quoted) -- these are NOT errors I produced
   or actions I took; they are the Claude Code harness's language-server integration reporting
   after each Edit/Write, new in recent client versions (Harold: never seen before this sprint,
   client v2.1.229). The whole-file every-symbol-undefined cascade signature means the Dart
   analyzer lost PACKAGE RESOLUTION (`.dart_tool/package_config.json` absent or stale --
   `build-windows.ps1` runs `flutter clean`, which deletes it), not that the code is wrong.
   I treated `flutter analyze` as authoritative throughout and took zero wrong actions from the
   noise -- but each cascade cost context tokens. Important counterpoint: the SAME integration
   produced genuinely useful signal later in the sprint (it caught the 6-positional-argument
   call-site errors during F151c instantly, before any test run), so the right response is
   noise-recognition, not disabling it.

### 2. Testing Approach

Very Good. Every code change this sprint was mutation-verified (13+ deliberate mutations across
the sprint, each confirmed caught by exactly its own test before reverting). The F151i Markdown
conversion validated the highest-risk prediction (Harold's steering that section heights would
stress the F145 deep-link scroll) with the full 31-test integration suite rather than assumption
-- it passed unchanged. One test-design lesson recorded in-sprint: `find.text()` cannot prove
visibility on an eager-Column screen (F151b), and single-Text-widget content assertions break
under Markdown rendering (F151i) -- both corrected toward assertions that survive widget-shape
changes.

### 3. Effort Accuracy

Very Good. All estimated tasks landed inside or below their minute bands (F151a ~15m vs 20-30,
F151b ~15m vs 10-20, F151c ~30m vs 30-45, F151e ~25m vs 25-40, F151f ~25m vs 25-40, F151h ~15m
vs 15-25, F151i ~40m vs 45-75). The one overrun (F151d ~35m vs a 10-15m estimate) was a genuine
scope change (planned data-add became a root-caused pipeline bug), surfaced and approved rather
than absorbed.

### 4. Planning Quality

Very Good, with an honest observation: three of the seven planned tasks (F151d, F151e, F151f)
had their written premise corrected by reading the actual code during execution -- the demo data
was already correct, the button grid was already side-by-side, the ErrorDisplay widgets did not
fit any call site. In all three cases the plan's ACs were revised in the plan doc with the
reasoning, and the corrected implementations were smaller and better-targeted than the planned
ones. Lesson: for UI-fix tasks planned from screenshots/walkthrough observations, a 2-minute
read of the target widget during planning would have written the right premise the first time.

### 5. Model Assignments

Very Good. Cheapest-first held: 3 Haiku-designed tasks (F151a/b/d-as-planned), Sonnet for the
cross-cutting/judgment tasks, with recorded "why not cheaper" on each. The three premise
corrections (Category 4) validated the Sonnet assignments on exactly the tasks that needed
live re-diagnosis.

### 6. Communication

Very Good. Scope changes were surfaced before acting (F151d via question; MV card-worthy items
per Harold's steering), mid-turn steering was incorporated without re-litigating, and the
auto-mode/default-mode question was answered with verified settings contents rather than
recollection.

### 7. Requirements Clarity

Very Good. Harold's MV feedback was enumerated item-by-item (8 items, tracked to completion),
the one truncated item was flagged and confirmed before implementation, and the icon-order spec
was applied as an audit against a stated canonical order rather than ad hoc.

### 8. Documentation

Very Good. Plan doc carries per-task completion notes including premise corrections;
CODING_VELOCITY actuals logged at task completion with root-cause notes; CHANGELOG updated in
the same commits as code; the WinWright screen-reader-flag discovery was written into F153,
Task 7 notes, and the F139 stale reference was corrected rather than left asserting a
possibly-wrong limitation.

### 9. Process Issues

Very Good. Two hook catches this sprint were both legitimate and both fixed properly rather
than bypassed (require-sprint-cards caught the unpopulated `github_issues` array; the earlier
verify-closeout catch predates this sprint's execution). The MV round followed Harold's
"full planning + card for substantial items" steering with real cards (#319/#320) and plan
tasks before execution.

### 10. Risk Management

Very Good. The sprint's riskiest operation (clearing three data-persistence layers to reach a
true first-run state during Backlog Refinement) was backup-verified byte-for-byte before and
after, and restoration was confirmed against live account data. The F151d pipeline fix was
constrained to Demo Mode with a regression proof across the full EmailScanner suite (52 tests)
before commit.

### 11. Next Sprint Readiness

Very Good. F150 (Android build blocker) remains the queued candidate, blocked only on Harold's
Firebase Console action. F153 (WinWright/UIA re-test with the screen-reader flag) is now
Priority 10 with a concrete, cheap first step. F152 template ready for future first-run
evaluations.

### 12. Architecture Maintenance

Very Good. One new dependency added deliberately (flutter_markdown_plus, with the
discontinued-upstream rationale documented in pubspec); the F134 single-builder architecture
proved its value twice this sprint (one-line icon reorder fixed every screen; the audit was
mostly reading). No ADR-level changes.

### 13. Minor Function Updates for the Next Sprint Plan

None from the Claude side.

### 14. Function Updates for the Future Backlog

None beyond what is already registered (F152, F153 during this sprint).
