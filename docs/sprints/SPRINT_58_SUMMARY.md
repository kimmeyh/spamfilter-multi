# Sprint 58 Summary

**Dates**: 2026-08-14 -- 2026-08-15
**Branch**: `feature/20260814_Sprint_58` | **PR**: #317 -> develop
**Scope**: F151 -- Windows first-run/onboarding UX (Issue #318), expanded by Manual Validation
feedback into F151h (Issue #319) and F151i (Issue #320). F150 (Android build blocker) deferred,
blocked on Harold's Firebase Console action.

## What Shipped

Nine tasks plus nine Manual Validation follow-up items, all Windows-scoped per Harold's explicit
steering (Android adaptations deferred to the Android rollout track):

- **F151a**: zero-accounts empty state explains what the app does + "Try Demo Mode instead"
  secondary action (reuses `PlatformSelectionScreen`'s demo navigation verbatim).
- **F151b**: Help screen "First time? Start here" callout deep-linking to the walkthrough --
  closes the gap F75 (Sprint 34) explicitly deferred.
- **F151c**: tooltips on all Scan Results summary chips; dead "Moved" chip removed (feature
  unimplemented, always read 0); Read-Only wording clarified via tooltips.
- **F151d**: real bug found and fixed -- Demo Scan never showed a Safe result. The demo dataset
  already had 21 correct safe-sender emails, but a real-scan "already in target folder, skip
  entirely" optimization silently ate all of them (every demo safe-sender email is deliberately
  in INBOX). Fix scoped to Demo Mode only (`shouldSkipSafeSenderAlreadyInTarget()` predicate);
  planned as a 10-minute data-add, scope change surfaced and Harold-approved mid-task.
- **F151e**: email-detail popup layout -- first fix (480px centered) revised per MV to
  left-edge-at-~1/3 extending to the far right, keeping list rows' sender/subject visible.
- **F151f**: 3 raw-exception error paths humanized via new `ErrorMessages.humanize()` helper
  (the planned `ErrorDisplay` widget family fit none of the call sites -- premise corrected by
  reading the real UI).
- **F151g**: Windows environment-compatibility investigation -- clean at all window sizes/DPI
  tested, plus the sprint's biggest discovery: the `SPI_SETSCREENREADER` OS flag was the missing
  prerequisite for WinWright to see/click Flutter content at all. F140's Sprint 54 "Flutter
  exposes zero UIA patterns" finding was likely measuring this missing flag, not a platform
  ceiling. F153 upgraded to Priority 10 for a clean re-test; flag left enabled.
- **F151h (MV)**: AppBar icon order audited to Harold's canonical spec -- one reorder in the F134
  shared builder fixed every screen; Help screen gained the No-Rule icon; policy gate now asserts
  the FULL declaration order.
- **F151i (MV)**: Help content rendered as formatted Markdown via `flutter_markdown_plus` (the
  official continuation of Google's discontinued `flutter_markdown`); content files were already
  valid Markdown (ADR-0038 discipline); all 31 F145 deep-link tests passed unchanged.
- **MV follow-ups**: search auto-focus, back-arrow close + Escape-to-close for search,
  walkthrough Step 7 rewrite (Harold's text), Help-from-Select-Account missing icons fixed via
  the F135 lazy account-resolution pattern.

## Verification

- Full suite at close: **1,891 passed / 29 skipped / 0 failed** (from 1,864 at Sprint 57 close);
  `flutter analyze` clean throughout every task; every change mutation-verified (13+ mutations,
  each caught by exactly its own test).
- Manual Validation: two rounds, complete (Harold, 2026-08-15).

## Notable Process Events

- Backlog Refinement included a live first-run walkthrough of the real 0.7.0.0 production exe
  with a genuinely empty account/data state -- reaching it required discovering and clearing
  three independent data-persistence layers (AppData dir, legacy `com.example` migration source,
  `flutter_secure_storage` account list), all backup-verified byte-for-byte and fully restored.
- Store release 0.7.0.0 (Submission 14) built, verified, submitted, certified, and Check-C
  confirmed live during this sprint's opening days -- first MINOR release under the enforced
  semver policy.
- Three planned-task premises (F151d/e/f) corrected by reading real code during execution; all
  corrections recorded in the plan with reasoning, all resulting fixes smaller than planned.
- Retro: Harold rated Category 1 "Good" (three tooling-friction items, root-caused) and all
  other categories "Very Good"; 2 improvements approved and applied (shell-homogeneous-pipelines
  memory, Dart-LSP-noise-signature memory).

## Reference Docs

`SPRINT_58_PLAN.md` (per-task cards + completion notes), `SPRINT_58_RETROSPECTIVE.md`,
`drafts/SPRINT_58_RETROSPECTIVE_claude_draft.md`, CHANGELOG.md 2026-08-15 entries,
`docs/CODING_VELOCITY.md` Sprint 58 rows.
