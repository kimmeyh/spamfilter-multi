# ADR-0028: Android Permission Strategy

## Status

Accepted

## Date

2026-02-15

## Context

The app's main `AndroidManifest.xml` declares NO permissions. The `INTERNET` permission is only declared in the debug and profile build variants, not in the main (release) manifest. This means a release build would lack even basic network access.

The app uses several features that require Android permissions:

| Feature | Permission Needed | Type | API Level |
|---------|------------------|------|-----------|
| IMAP/Gmail API access | `INTERNET` | Normal | All |
| Background scan notifications | `POST_NOTIFICATIONS` | Dangerous | 33+ (Android 13+) |
| Background scan scheduling | `RECEIVE_BOOT_COMPLETED` | Normal | All |
| Background scan execution | `WAKE_LOCK` | Normal | All |
| Long-running background scan | `FOREGROUND_SERVICE` | Normal | 28+ |
| Foreground service type | `FOREGROUND_SERVICE_DATA_SYNC` | Normal | 34+ (Android 14+) |

### Runtime Permission Complexity

Android 13+ (API 33) requires `POST_NOTIFICATIONS` to be requested at runtime (not just declared in manifest). The app must:
1. Declare the permission in the manifest
2. Create a notification channel before requesting permission
3. Request permission at runtime with a rationale dialog
4. Handle denial gracefully (background scans work but silently)

Android 14+ (API 34) requires foreground services to declare their type. Background email scanning qualifies as `dataSync` type. Without the proper foreground service type declaration, the system may kill long-running scans.

### Exact Alarm Considerations

The `workmanager` package may use `SCHEDULE_EXACT_ALARM` for precise scheduling. However:
- `USE_EXACT_ALARM` is restricted to core alarm/timer apps
- `SCHEDULE_EXACT_ALARM` is denied by default on Android 14+ for new installs
- WorkManager uses `setInexactRepeating` by default, which does NOT require exact alarm permission
- The app's background scanning does not require exact timing (a few minutes of variance is acceptable)

### Permission Minimization

Google Play Store reviewers evaluate whether requested permissions are justified. Over-requesting permissions can result in app rejection or user distrust. The principle of least privilege applies: request only permissions the app actually needs.

## Decision

**Option B: Full background support permissions.** Declare all permissions needed for reliable background scanning, including foreground service support.

### Permissions Declared in Main AndroidManifest.xml

| Permission | Type | API Level | Purpose |
|------------|------|-----------|---------|
| `INTERNET` | Normal | All | IMAP/Gmail API network access |
| `POST_NOTIFICATIONS` | Dangerous | 33+ (Android 13+) | Background scan completion notifications |
| `RECEIVE_BOOT_COMPLETED` | Normal | All | Re-schedule background scans after device restart |
| `WAKE_LOCK` | Normal | All | Keep CPU awake during background scan execution |
| `FOREGROUND_SERVICE` | Normal | 28+ (Android 9+) | Run long background scans without system kill |
| `FOREGROUND_SERVICE_DATA_SYNC` | Normal | 34+ (Android 14+) | Required foreground service type declaration |

### Runtime Permission Strategy

- `POST_NOTIFICATIONS` is the only dangerous permission (requires runtime request on Android 13+)
- Request when user first enables background scanning in Settings
- Show rationale dialog explaining why notifications are needed for scan results
- Create notification channel BEFORE requesting permission
- Handle denial gracefully: background scans work but complete silently without notifications
- All other permissions are normal (auto-granted at install time)

### Key Points

- WorkManager handles background scheduling without exact alarm permissions
- `SCHEDULE_EXACT_ALARM` is NOT requested (inexact scheduling is acceptable for background scans)
- Foreground service ensures scans of large mailboxes (>500 emails) complete without system kill
- Android 14+ requires foreground service type declaration (`dataSync`) for all foreground services

## Alternatives Considered

### Option A: Minimal Permissions
- **Description**: INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, WAKE_LOCK only. No foreground service permissions.
- **Pros**: Fewest permissions to justify in Play Store review, highest user trust
- **Cons**: Background scans may be killed by the system on large mailboxes without foreground service protection
- **Why Rejected**: Reliability of background scanning is a core feature; users with large mailboxes would experience silent scan failures

### Option C: Progressive Permission Requests
- **Description**: Start with INTERNET only, request POST_NOTIFICATIONS when user enables background scanning, add foreground service permissions only when needed.
- **Pros**: Most user-friendly, minimizes upfront permission requests
- **Cons**: Most complex to implement, requires multiple permission request flows and state tracking
- **Why Rejected**: Implementation complexity not justified for a single-developer project; can always refactor to progressive requests later if user feedback warrants it

## Consequences

### Positive
- Background scans complete reliably even for large mailboxes (foreground service prevents system kill)
- All requested permissions are justified by actual app features (defensible in Play Store review)
- Single runtime permission request (`POST_NOTIFICATIONS`) keeps UX simple

### Negative
- More permissions listed in Play Store than the minimal option, which may reduce install rate slightly
- `POST_NOTIFICATIONS` requires a runtime request UX with rationale dialog (implementation effort)

### Neutral
- All permissions except `POST_NOTIFICATIONS` are normal (auto-granted), so the effective user-facing permission count is low
- Foreground service type declaration (`dataSync`) is a standard Android 14+ requirement for background processing apps

## References

- `mobile-app/android/app/src/main/AndroidManifest.xml` - Current manifest (no permissions declared)
- `mobile-app/android/app/src/debug/AndroidManifest.xml` - Debug-only INTERNET permission
- `mobile-app/lib/core/services/background_scan_notification_service.dart` - Notification implementation
- `mobile-app/lib/core/services/background_scan_manager.dart` - Background scan scheduling
- GP-3 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- [Notification runtime permission (Android 13+)](https://developer.android.com/develop/ui/views/notifications/notification-permission)
- [Foreground service types (Android 14+)](https://developer.android.com/about/versions/14/changes/fgs-types-required)
- ADR-0022 (Throttled UI Progress Updates) - Background scan UI updates
