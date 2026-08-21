# ADR-0042: Cross-platform parity -- same everywhere, with explicit minimal platform exceptions

**Status**: **ACCEPTED** (Chief Architect decision, Harold, 2026-08-18). Approved with one addition: platform FACTORIES are endorsed for whole-capability exceptions, used sparingly (see "Platform factories" below). The open policy-gate question was resolved at the same time (no gate for now).
**Sprint**: 61
**Related**: ADR-0035 (production/development side-by-side), ADR-0037 (UI accessibility standards), ADR-0038 (content management for long strings), ADR-0039 (per-account background scanning), ADR-0041 (environment propagation)

## Context

The project ships one Flutter codebase to Windows and Android (with iOS/macOS/Linux architecturally supported but unvalidated). Until now, "how much should these platforms match?" was answered case by case, in code review or not at all. That produced two failure modes, both observed:

**1. Silent divergence in SHARED code, masked by one platform.** In Sprint 60, `scan_results` had a foreign key to `accounts`, but the ONLY code creating the accounts row lived in the WINDOWS background-scan worker. Windows exercised that path every 15 minutes, so it looked healthy for months. On Android nothing created the row, every interactive scan's persistence failed the FK, the error was caught and logged, and scans completed with **no history, no email actions, and no no-rule items**. The defect was in shared architecture; only the platform coverage was uneven. This is why parity is not a UI concern.

**2. Unmarked platform forks.** The repo currently has ~51 `Platform.is*` references across 12 files. Most are legitimate (Windows Task Scheduler, system tray, Win32 toast notifications, OAuth handlers, path separators). But nothing distinguished "this platform genuinely cannot do it" from "nobody got around to the other platform". In Sprint 61, `scan_history_screen` still gated the Review No Rule Items shortcut behind `Platform.isWindows` with a comment claiming that was "consistent with the other Review entry points" -- F143 had un-gated every other entry point a sprint earlier, leaving that comment actively misleading.

Harold stated the governing rule on 2026-08-17 while scoping Sprint 61, and asked that it be captured as an ADR.

## Decision

**Functionality and UI are the SAME on both platforms unless they cannot be. Where they cannot be, the difference is implemented as an explicit, minimal PLATFORM EXCEPTION covering only what is actually needed.**

This applies to **all layers**: backend code, frontend code, data, architecture, development, security, testing, and deployment. It is not a UI-only rule.

### What counts as "cannot be"

A platform exception is justified only when the platform genuinely cannot support the shared behavior:

- **The API does not exist**: Windows Task Scheduler, the Win32 system tray, Android WorkManager.
- **The platform convention conflicts**: touch long-press versus desktop Ctrl+click (F143); path separators.
- **A platform policy forbids it**: runtime permission models, store requirements.
- **The hardware/form factor makes it meaningless**: window resizing on a phone.

Not justified: "we only tested Windows", "the Android version came later", "it was easier", or an unexamined assumption that a feature is desktop-only.

### How an exception is implemented

1. **Fork at the narrowest possible point.** Prefer one platform-conditional line inside a shared widget or service over a parallel implementation. Eight screens do not get eight edits when one shared builder serves them.
2. **Declare it in a comment that names WHAT cannot be shared and WHY.** A reader must never have to guess whether a fork was deliberate. A fork whose comment has gone stale is a defect (see the `scan_history_screen` case above).
3. **Prefer the testable seam.** Where a fork is behavioral, read the platform through an injectable seam (`Theme.of(context).platform`) rather than `dart:io Platform`, so both branches can be tested. F143 established this pattern precisely because the global override trips a test invariant.
4. **Cover BOTH branches with tests.** A cross-platform behavior needs coverage proving the platform branch AND the guard that the other platform is unchanged. F143's touch-selection tests assert the touch branch and a desktop no-regression guard in the same file.
5. **Degrade, do not disappear.** Where a shared element does not fit a platform's form factor, prefer graceful degradation over silent absence, and pin the threshold with a test (F172's version label is suppressed below 600px, with a test proving it survives at the Windows minimum).

### Platform factories -- the preferred shape for a WHOLE-CAPABILITY exception

**Approved by Harold, 2026-08-18**: "it is OK to use the object oriented idea of 'factories' where
the same function has two different versions with the same name and is called based on platform.
Should be used sparingly, but when it meets the long-term architecture needs."

A platform factory resolves ONE implementation of a shared interface at construction time, so every
caller downstream talks to the interface and contains no platform branch at all. This is
requirement 1 above (fork at the narrowest point) taken to its conclusion: instead of N call sites
each carrying `if (Platform.isWindows)`, there is one decision and N platform-free callers. It also
satisfies requirement 3 by construction -- the implementation is injectable, so tests select it
directly instead of mocking a global.

**Use a factory when the WHOLE CAPABILITY differs per platform**, and the platforms share only the
contract:

- Background-scan scheduling: Windows Task Scheduler (ADR-0039) vs Android WorkManager (F161). The
  canonical case -- same contract (schedule/cancel per-account periodic work), entirely different
  mechanisms.
- Notifications: Win32 toast vs Android notification channels.
- OAuth handling: loopback-redirect desktop flow vs the Android intent flow.

**Do NOT use a factory for a two-value difference.** A path separator, a dialog corner radius, an
export-directory choice, or a single suppressed widget is clearer as one conditional expression at
the point of use. Wrapping those in a factory buries a one-line difference behind an indirection
layer, making the code harder to follow while claiming to make it cleaner. "Sparingly" is the
operative word: the test is whether a reader benefits from the abstraction, not whether one can be
constructed.

**The failure mode a factory can HIDE, and the rule that prevents it**: a factory makes it easy for
one platform's implementation to quietly do nothing -- an empty method, a silent early return -- and
for that to look intentional. This is exactly the Sprint 60 shape, where the accounts-row creation
existed only on the Windows path and Android silently persisted nothing for months. Therefore:

- **Every implementation of a factory-produced interface gets its own tests.** A shared interface
  with one tested implementation is the same uneven coverage in a nicer wrapper.
- **A deliberate no-op implementation must be explicit and named as a decision** (a class whose name
  and doc comment say it does nothing on this platform, and why), never an empty method body.
- **The interface is defined by the shared contract, not by the richer platform's capabilities.**
  Otherwise the weaker platform's implementation is forced into no-ops by construction.
- **Call-site verification is part of introducing a factory, not optional cleanup** (IMP-2, Sprint
  61 retro, approved by Harold 2026-08-21). When a factory replaces inline platform checks, grep
  EVERY former call site for residual platform guards, and pin the reroute with a test or policy
  gate. A reroute is never "mechanical": Sprint 61's F161 shipped the factory fully tested while
  both `settings_screen` call sites kept their `if (Platform.isWindows)` guards, so Android
  silently got no scheduling -- found live by Harold in Manual Validation, one file away from the
  9 mutation-verified adapter tests. The factory's whole value (platform-free callers) is only
  real if the callers are verified platform-free. First instance:
  `test/policy/factory_call_site_test.dart`.

### Deliberate non-parity, recorded

Two divergences are accepted and are NOT defects:

- **Background scan scheduling**: Windows uses per-account Task Scheduler tasks (ADR-0039). Android has no equivalent today; F161 implements the WorkManager mirror. **This is a temporary DEVELOPMENT-time gap, not a shipped platform difference** -- Harold, 2026-08-18: "we have not delivered to customers an Android package yet. The scheduler will need to be in place (key requirement) before shipment." So Android ships WITH background scanning or it does not ship; no customer will ever meet an Android build that lacks it.
  - **Consequence for user-facing content**: do NOT write "not available on Android yet" caveats for this gap. They would document a limitation no customer encounters and would become stale text the moment F161 lands. Help describes the CAPABILITY ("the operating-system scheduler"), not per-platform mechanisms -- pinned by `test/policy/help_platform_claims_test.dart`.
  - **Consequence for release gating**: F161 is a SHIPMENT PREREQUISITE for the Google Play track (F94, GP-*), not an optional enhancement.
- **Store/release path**: the Microsoft Store release (Phase 8.3 of the Release Cycle) covers the Windows app. The Google Play track is a separate future path (F94, GP-*).

## Consequences

- Every future cross-platform decision cites this ADR rather than being re-litigated; divergences found in audits are filed as items referencing the rule they violate.
- Existing `Platform.is*` forks are grandfathered, not retroactively rewritten. They are reviewed opportunistically when their file is touched -- a sweeping rewrite would carry more regression risk than value.
- The rule creates real work: a shared-code change must be verified on both platforms, not just the one at hand. That cost is the point, given failure mode 1 above cost months of silent Android data loss.
- Testing burden rises for behavioral forks (both branches), which is the smallest reliable way to prevent a fork drifting into a one-platform feature.

## The policy-gate question -- RESOLVED

Sprint 61 asked whether to add a gate asserting that every `Platform.is*` fork in `lib/` carries an
explanatory comment. **Decision: NO, not now.**

Two reasons. First, the audit found 51 forks with 39 already documented and, on individual review,
none of the remaining 12 hiding a real parity gap -- so the gate would fire on correct code, and a
gate that fires on correct work trains people to bypass it. That is not theoretical: this same
sprint fixed a `verify-closeout-complete` check that false-positived three times in one session for
exactly that reason, and the hook's own comments record the principle.

Second, the factory guidance above moves whole-capability forks OUT of scattered call sites, so the
population a comment-gate would police is shrinking by design. Revisit only if undocumented forks
start accumulating in review.
