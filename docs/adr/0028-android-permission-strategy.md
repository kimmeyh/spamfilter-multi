# ADR-0028: Android Permission Strategy

## Status

Proposed

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

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Option A: Minimal Permissions (Request Only What is Used)
- INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, WAKE_LOCK
- No foreground service permissions
- Background scans may be killed by system on long scans

#### Option B: Full Background Support Permissions
- All Option A permissions plus FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC
- Ensures background scans complete even for large mailboxes
- More permissions to justify in Play Store review

#### Option C: Progressive Permission Requests
- Start with INTERNET only
- Request POST_NOTIFICATIONS when user first enables background scanning
- Request foreground service permissions only when needed
- Most user-friendly but most complex to implement

### Decision Criteria

1. **User trust**: Fewer permissions = higher install rate
2. **Functionality**: Background scans must complete reliably
3. **Android version support**: Must work on API 26+ (Android 8+) through API 35+ (Android 15+)
4. **Play Store compliance**: All permissions must be justified
5. **User experience**: When and how to ask for runtime permissions
6. **Graceful degradation**: App must work even if permissions are denied

### Key Points

- `POST_NOTIFICATIONS` is the only dangerous permission needed (requires runtime request)
- All other permissions are normal (auto-granted at install)
- The notification channel must be created BEFORE requesting `POST_NOTIFICATIONS`
- WorkManager handles background scheduling without exact alarm permissions
- Foreground service may be needed for scans of large mailboxes (>500 emails) to prevent system kill
- Android 14+ requires foreground service type declaration for ALL foreground services
- The `workmanager` Flutter plugin may handle some permission requirements internally

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

## References

- `mobile-app/android/app/src/main/AndroidManifest.xml` - Current manifest (no permissions declared)
- `mobile-app/android/app/src/debug/AndroidManifest.xml` - Debug-only INTERNET permission
- `mobile-app/lib/core/services/background_scan_notification_service.dart` - Notification implementation
- `mobile-app/lib/core/services/background_scan_manager.dart` - Background scan scheduling
- GP-3 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- [Notification runtime permission (Android 13+)](https://developer.android.com/develop/ui/views/notifications/notification-permission)
- [Foreground service types (Android 14+)](https://developer.android.com/about/versions/14/changes/fgs-types-required)
- ADR-0022 (Throttled UI Progress Updates) - Background scan UI updates
