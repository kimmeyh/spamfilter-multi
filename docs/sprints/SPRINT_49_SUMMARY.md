# Sprint 49 Summary

**Dates**: 2026-07-21 -- 2026-07-22
**PR**: #276 (`feature/20260720_Sprint_49` -> develop; marked ready at Phase 7.7.5)
**Model**: Fable 5 (Harold-directed escalation; first Fable 5 sprint)
**Docs**: SPRINT_49_PLAN.md · SPRINT_49_RETROSPECTIVE.md · SPRINT_49_F33_PROD_BODY_RULES_REPORT.md · ADR-0041

## Objective

End the recurring Store `[DEV]`-title defect at true root cause, fix the 1-2-minute quick-action UI freeze, restore the bloated prod rules DB, and ship the corrected build as 0.5.7 with proof both compiled surfaces are prod.

## Delivered (7/7 tasks)

- **F119-c**: the THIRD independent defect of the F119 family -- the native window title came from a `SPAMFILTER_APP_ENV` env var the msix path never set (CMake defaulted dev on 0.5.5 AND 0.5.6). Fix: CMake derives from the `APP_ENV` dart-define (one flag drives BOTH compiled surfaces); `--print-env` now reports `NATIVE_APP_ENV`; Step 4.0 requires both prod; 3 policy pins. Proven by the no-env-var A-test. Corrected the Sprint 48 F119-b causal record honestly. Captured as **ADR-0041** (Chief Architect approved).
- **F120**: quick actions froze the UI 1-2 min per rule on the Store build (197 no-rule emails x 12,539 rules re-evaluated on the main isolate per action; sync-completing await chain never pumped Win32 messages). Fix: delta-scoped re-evaluation (only the added rule/safe sender -- exact for additions) + time-based event-loop yields on the full-set path.
- **BUG-DECODE**: cleanup script reports (never deletes) undecodable rules; NULL/empty stays a legitimate orphan.
- **F121**: dedup script + F73 import idempotency guard. LIVE prod apply: **12,539 -> 6,528** (6,011 exact duplicates from the 2026-04-24 triple import; backup retained). Copilot's NULL-vs-empty finding answered with a no-harm PROOF against the backup.
- **F33-PROD**: LIVE prod body-rules cleanup: convert 1,302 to URL-anchored regex, reclassify 168, remove 752, 4 ambiguous report-only, 0 decode warnings. **Final prod DB: 5,776 working rules** (both applies matched dry-runs exactly).
- **F-VERSION-DERIVE**: no hardcoded app version remains in production source (`AppVersion` service + `FLUTTER_VERSION` CMake macro); a version bump is now a one-file change.
- **F-PRECHECK**: mandatory 5.1.2 six-class pre-PR checklist; its dogfood run caught a real defect in the sprint's own new script on first use.

## Verification

Full suite +1,775 / 29 skip; analyze clean; all policy gates green; Copilot review 3/3 fixed+resolved; Harold validated every Sprint 47 item plus Parts A/B/C of the four-part validation plan with zero functional deviations. 0.5.7 bump complete (Part D build/submit follows the merge).

## Retrospective highlights (all 6 improvements applied "now")

Anti-stop task-inventory rule (Phase 4.1.0); Edit exact-bytes discipline; Executed-by per task; ADR-0041; `--concurrency=4` suite policy; Phase 6.6 rewritten to the branch-from-current-feature-branch flow. Plus the Fable/Opus top-tier rename. Headline lesson: a batch-completion report is not a stopping point; and verify every independently-compiled surface -- a one-sided "proof" shipped two defective releases.

## Carried forward

0.5.7 build -> both-sides prod proof -> Partner Center submission (post-merge); post-cert close-out (release heading, dev 0.5.7 -> 0.5.8, Android/Google Play OFF HOLD); 4 ambiguous legacy TLD rows (Harold decision); 2 cosmetic UI observations; deferred candidates (F-COPILOT-INSTR, CI_* secrets, NO-RULE-POLISH, F-WINSTORE-ASSETS, F108-RETEST).
