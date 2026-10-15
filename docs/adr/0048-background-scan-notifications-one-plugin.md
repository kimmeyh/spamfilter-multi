# ADR-0048: Background-Scan Completion Notifications Through One Plugin on Both Platforms

## Status

Accepted

## Date

2026-10-13 (Sprint 79, F286 and F287; Harold Q1 = 1, Q2 = 2)

## Context

After a background scan of an account completes, the user should see a notification naming the account and the
counts. Until Sprint 79:

- Android posted one through `flutter_local_notifications` 17.2.4, titled `Background scan complete`, with no account
  named (Harold's 0.18.0 Fold feedback, 2026-10-10: the notifications read as repeats because nothing said which
  account each was for).
- Windows posted NOTHING. Two Windows services existed: `WindowsNotificationService` (a placeholder written for plugin
  16.x, created at startup, `showBackgroundScanComplete` never called) and `WindowsToastNotificationService` (ADR-0018,
  a PowerShell WinRT toast, never called from `lib/` -- `git log -S` finds only its creating commit d47ac7a). The
  ADR-0042 parity gap was undeclared.

`flutter_local_notifications` added Windows support in 19.0.0 ("[Windows] Added support for Windows.", pub.dev
changelog). The latest stable at planning was 22.3.2.

## Decision

1. **One plugin on both platforms**: `flutter_local_notifications` 22.3.2 (with `desugar_jdk_libs` 2.1.4, which 19.0.0
   requires). ADR-0018's PowerShell route is retired.
2. **One text builder** (`ScanNotificationText`) and **one notifier** (`ScanCompleteNotifier`), called by both
   platform workers:
   - Title `Back. scan k*@aol completed`; body `No rule 9 Deleted 1 Safe 0`, ` Errors N` only when N > 0 (Harold,
     2026-10-10).
   - ID = FNV-1a 32-bit of the account id, masked to 31 bits; the same account always gets the same ID, so a newer
     notification replaces the older one (the plugin sets the Windows toast Tag to the ID, `ffi_api.cpp:60`).
   - A mode other than live names itself in the title (`read-only`, `rules-only`, `safe-senders-only`) on both
     platforms.
3. **Declared platform exception (ADR-0042), delivery only**:
   - Android: a notification channel with an HTML body (`DefaultStyleInformation(true, false)`, passed to
     `Html.fromHtml`), so a count the mode did not act on is struck through.
   - Windows: a toast with the plain body. Toast text has no strikethrough markup; the title word alone carries the
     mode. An unpackaged build registers its app ID itself (the plugin writes HKCU
     `Software\Classes\AppUserModelId\<id>`): `MyEmailSpamFilter.Dev` for DEV and `MyEmailSpamFilter.App` for PROD,
     each with its own activation GUID (ADR-0035 separation); a packaged (MSIX) build uses its package identity.
4. Both platforms post only for a COMPLETED scan; a stopped or skipped scan posts nothing. A notification failure is
   logged (diagnostic log `scan/post`) and never fails the scan. The OS's own per-app notification setting turns
   them off; the app has no separate switch.

## Alternatives Considered

### Wire the existing ADR-0018 PowerShell toast (route 1)
- **Description**: Call `WindowsToastNotificationService` from the Windows worker, adding a Tag/Group per account and
  registering an app ID.
- **Pros**: No dependency change.
- **Cons**: Two notification mechanisms to maintain; a PowerShell child process per toast; the app-ID registration
  the plugin does natively would have to be built by hand; a temporary script file per toast.
- **Why Rejected**: Harold chose route 2 (Q2 = 2, Sprint 79 planning): one plugin on both platforms is the parity
  shape ADR-0042 asks for.

### Keep separate text on each platform
- **Description**: Let each worker format its own notification.
- **Pros**: None beyond locality.
- **Cons**: The exact drift that left Windows with a never-called summary builder.
- **Why Rejected**: ADR-0042 parity.

## Consequences

### Positive
- Windows shows a background-scan notification for the first time.
- The text, mode word and one-per-account rule cannot drift between platforms.

### Negative
- A major plugin upgrade (17 -> 22): `initialize()` and `show()` take named parameters since 20.0.0.
- Strikethrough is Android-only; on Windows the mode is in the title only.

### Neutral
- Tap-to-open on the MSIX build may need an `msix_config` `toast_activator` (UNVERIFIED); not required by Sprint 79's
  acceptance criteria.

## References
- Supersedes ADR-0018 (Windows Toast Notifications via PowerShell).
- ADR-0042 (platform parity), ADR-0035 (DEV/PROD side by side), ADR-0014 (Windows background scanning).
- `mobile-app/lib/core/services/scan_notification_text.dart`, `scan_complete_notifier.dart`.
- Sprint 79 plan Tasks 3 and 4; Issues #482, #483.
- pub.dev changelog for flutter_local_notifications (19.0.0 Windows support; 20.0.0 named parameters).
