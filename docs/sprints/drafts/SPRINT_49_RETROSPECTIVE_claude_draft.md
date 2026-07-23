# Sprint 49 Retrospective -- Claude Code Development Team DRAFT

**Author**: Claude (Claude Code Development Team role, the 4th role).
**Status**: DRAFT for Step 3 use only. NOT a substitute for Harold's PO/SM/Lead Developer input.
Never written into the official retrospective in place of Harold's words.

Sprint 49 scope (7 tasks, all delivered): F119-c (native [DEV]-title root cause + CMake
dart-define derivation + both-sides --print-env probe + 0.5.7 bump), F120 (quick-action
freeze: delta-scoped re-eval + time-based yields), BUG-DECODE (report-not-delete),
F121 (dedup script + F73 idempotency guard; LIVE prod apply 12,539 -> 6,528),
F33-PROD (LIVE prod body-rules cleanup -> 5,776 final), F-VERSION-DERIVE (no hardcoded
versions; bump = pubspec-only), F-PRECHECK (mandatory 5.1.2 six-class checklist).
Model: Fable 5 (Harold-directed escalation for the F119-c deep dive; retained all sprint).

---

## Claude Code Development Team feedback -- 14 categories

### 1. Effective while as Efficient as Reasonably Possible
High-leverage sprint: two field-reported production defects (the [DEV] title's REAL root
cause; the 1-2-min quick-action freeze) plus the prod-DB restoration, all landed with the
release still pending only Harold's merge. The rehearse-on-a-copy discipline for Part C was
the efficiency star: it caught two script defects pre-live and made the live run zero-surprise.
Efficiency losses: (a) ~20m of AOT-binary forensics on F119-c before pivoting to the cheap
diagnostic (the secrets keys / CMake source); (b) repeated full-suite re-runs chasing the
isolate-connection flakiness (3 occurrences).

### 2. Testing Approach
Every change carried tests (+12 net: dedup 6, F73 guard 2, BUG-DECODE 1, F119-c pins 3),
and the layered checks repeatedly caught REAL problems: the existing NULL-orphan test caught
my over-broad BUG-DECODE first draft; the F-PRECHECK dogfood caught the dedup separator on
first use; Copilot's NULL-vs-empty finding was answered with a NO-HARM PROOF against the
pre-dedup backup (fixed analyzer reproduces exactly 6,528/6,011) -- proving-not-asserting at
its best. Gap worth fixing: the full-suite isolate-connection flakiness (3x this sprint)
wastes verification time; a standing --concurrency policy or runner fix is needed.

### 3. Effort Accuracy
Estimates were materially better than Sprint 47's: F119-c ~75m (est 60-120), F120 ~40m
(45-90), BUG-DECODE ~20m (30-45), F121 ~55m (60-120), F33-PROD ~15m (30-60),
F-VERSION-DERIVE ~50m (90-180, over-padded for the native caution that did not bite),
F-PRECHECK ~25m (45-90). Actuals logged AT COMPLETION per the Sprint 47 IMP-2 rule -- the
process fix held. Trend: estimates still ~1.5-2x high on the smaller items; the two-metric
table should recompute at this retro.

### 4. Planning Quality
Unusual but sound shape: the sprint was re-planned twice in flight (F119-c escalation, then
Harold's "all" on the perf/DB triple) and the augmented task-card template (Sprint 47 IMP-1)
carried it well -- the R-N/AC-N/T-N structure made the mid-sprint additions unambiguous, and
AC-2-style behavioral criteria (the no-env-var A-test; the both-sides probe) were the actual
proof points used. The retroactive Sprint 48 plan + this sprint's plan kept the record
coherent through the hotfix turbulence.

### 5. Model Assignments
Fable 5 (Harold-directed) earned the escalation on F119-c: the diagnosis required overturning
the prior sprint's own accepted conclusion (F119-b) against its recorded evidence and tracing
flutter-tool -> generated CMake -> C++ preprocessor -> Win32 title. The cheaper-tier tasks
(F-PRECHECK docs, BUG-DECODE) were executed in-session rather than delegated -- cheapest-first
was honored in the plan's assignments but not in execution delegation; defensible given the
tight coupling, worth noting.

### 6. Communication
The three-part validation plan (A/B/C/D) with exact expected values per step was the right
artifact -- Harold's item-by-item "Working as expected. Can be closed." pass and the
zero-surprise Part C came directly from it. Two corrections taken this sprint and memorized:
build/launch proactively (never "say the word"), and Claude launches EVERY app including the
Store install.

### 7. Requirements Clarity
Harold's screenshots were again decisive (the [DEV] title bar vs the clean About text was THE
diagnostic clue), and his challenges materially improved the work twice: "are you sure you are
looking at the Windows Store production database?" forced the three-way verification, and
"why would tests hardcode the version?" seeded F-VERSION-DERIVE. Co-lead review at its best.

### 8. Documentation
CHANGELOG per-item; STORE_RELEASE_PROCESS Step 4.0 now demands the both-sides compiled proof;
the F119-b record was corrected HONESTLY (retro addendum, master plan, memory) rather than
papered over; master plan pruned per the Maintenance Guide after Harold's validation; PR #276
description carries scope + dogfood record + Part C results. The F33-PROD run report is
committed as a sprint artifact.

### 9. Process Issues
(a) The isolate-connection test flakiness (3x) -- needs a durable fix, not re-runs. (b) I
initially violated the branch-from-feature carry-forward rule AGAIN at Sprint 48->49 planning
(caught by Harold, 5th correction; memory now states his directive overrides the old recipe)
-- the recurrence pattern says the rule needs to be in SPRINT_EXECUTION_WORKFLOW.md Phase 6.6
text itself, not just memory. (c) An ambiguous yes/no question was asked once (secrets file)
-- corrected + memorized (numbered options only).

### 10. Risk Management
Strong sprint for this: every destructive DB step was rehearsed on a copy first, backed up
before apply, and reconciled after; the two live applies matched their dry-runs exactly; the
Copilot NULL-collapse concern was closed with a proof against the retained backup rather than
an assurance. The 4 ambiguous legacy rows were left untouched (report-only) for Harold's call.
Residual risk: 0.5.7 is not yet built/submitted -- the [DEV]-title fix is proven at dev scope
(A-test) but the prod MSIX proof (NATIVE_APP_ENV=prod) happens at Part D.

### 11. Next Sprint Readiness
Clean handoff state: PR #276 draft/green/self-documenting; prod DB restored (5,776 rules);
backups retained. Next-sprint queue: 0.5.7 cert-pass close-out (CHANGELOG release heading,
dev bump 0.5.7 -> 0.5.8), Android/Google Play track OFF HOLD on verified-live, plus deferred
candidates (F-COPILOT-INSTR, CI_* secrets, NO-RULE-POLISH, F-WINSTORE-ASSETS, F108-RETEST)
and two cosmetic observations from Harold's validation (safe-sender classification display;
legacy uncategorized rule label).

### 12. Architecture Maintenance
F119-c modified the Sprint 37 F52 native-env design (dart-define-first with env-var fallback)
-- surfaced as a Class-2 decision, Harold chose option 1, and the change is documented in
CMakeLists/main.cpp comments + STORE_RELEASE_PROCESS. Assess at Step 5 whether an ADR
(or ADR-0035 note) should capture the single-source-of-truth environment flow; no other
architectural deltas (AppVersion is a small additive service).

### 13. Minor Function Updates for the Next Sprint Plan (carry-ins)
(a) 0.5.7 post-cert close-out actions; (b) the 4 ambiguous legacy TLD-block rows (Harold
decision: delete or keep); (c) test-runner flakiness fix (standing concurrency policy);
(d) the 2 cosmetic UI observations from Harold's validation pass.

### 14. Function Updates for the Future Backlog
(a) Codify the carry-forward branch rule into SPRINT_EXECUTION_WORKFLOW Phase 6.6 text
(process, prevents the 6th correction); (b) consider extending the --print-env probe into a
tiny self-test suite the release process runs (env + version + data-dir in one shot);
(c) safe-sender classification-display fix; (d) F-COPILOT-INSTR audit remains queued.
