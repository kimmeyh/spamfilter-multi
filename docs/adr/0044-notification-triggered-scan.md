# ADR-0044: Scan when a mail app says new mail arrived (Android notification listener)

**Status**: Accepted
**Date**: 2026-10-05
**Deciders**: Harold (Chief Architect / Product Owner)
**Sprint**: 76 (F253, Issue #458)

## Context

Harold, 2026-10-05: *"Generally the app makes no sense if it can't run without
the user going to the app - as they would have to come back to the app about
every 15 minutes or less in order to use it effectively (auto-delete and flag
new no-rules)."*

Android limits background work in two documented ways
(developer.android.com, read 2026-10-05):

- **Doze** "Suspends network access" and "Doesn't let `JobScheduler` run";
  WorkManager uses JobScheduler.
- **App Standby Buckets**: an app with "No user interaction for 8 days" enters
  the Restricted bucket -- "Jobs: Once per day", "Alarms: One per day".

The options analyzed that day ranged from WorkManager alone (today), through
battery-optimization exemption, exact alarms, foreground services, Gmail push
through a server, IMAP IDLE, provider-side filters, and an off-phone scanner.
Harold then narrowed the goal: *"we are ONLY wanting to do the same thing that
the email app currently does - periodically wake up, scan for new emails,
update the app and go quit again."* F252 covers the periodic path (a guided
battery exemption plus wake-to-scan measurement). This ADR covers the
event-driven complement Harold asked to explore: *"can we catch new emails as
they are discovered"*.

On a phone the only on-device signal that mail arrived is the mail app's own
notification. Gmail, AOL and Yahoo get it from their servers by push, so it
arrives even while the phone is idle.

## Decision

1. An Android `NotificationListenerService` (`MailNotificationListener.kt`)
   starts ONE background scan of every account whose background scanning is
   on, when a notification is posted by an app on a single allowlist of mail
   apps (`MailNotificationPolicy.MAIL_APP_PACKAGES`: Gmail, AOL, Yahoo Mail,
   Samsung Email, Outlook).
2. **Privacy is the contract.** The listener reads ONLY the posting package
   name and the post time. It never reads the notification's title, text or
   extras and stores nothing from it. Pinned by a source gate
   (`f253_new_mail_switch_test.dart`, AC-4).
3. **Opt-in twice.** Inert unless the user turns on Settings > Background >
   "Scan when new mail arrives" (off by default) AND grants Notification
   access in Android settings. Access is requested only from that switch.
4. **Reuse, do not fork.** The scan is the existing WorkManager one-off worker
   (`DozeScanTrigger.enqueueAllAccounts`), so the per-account claim, the
   per-account background switch, and every protection in the worker apply.
   The work requires a network connection.
5. **Bounded.** One unique work name with KEEP, plus a 2-minute minimum gap
   between triggers (`MIN_GAP_MS`): a burst of notifications starts one scan.
6. Harold's design point: a notification only says mail arrived; the scan
   covers all selected folders, Bulk included, so junk the mail app never
   announces is still handled.

## Consequences

- **What a triggered scan fetches depends on the account's Background Scan
  Range.** A date window fetches only new mail (Gmail history delta; IMAP from
  the oldest unaddressed No Rule UID). "Scan all" fetches the whole mailbox
  every time by design (F147). Changing "Scan all" to mean "since the last
  scan" would change F147 and is a separate decision.
- **Users with mail notifications off get nothing from this**; F252's periodic
  path remains their mechanism.
- **Doze**: whether a triggered scan reaches the network while the phone is
  idle is unverified; the battery exemption (F252) is expected to be needed.
  The worker start line (`trigger=notification app=... delay=Ns`) measures it.
- **Google Play**: notification access is sensitive. The general rule applies
  (*"You may only request permissions and APIs that access sensitive
  information that are necessary to implement current features or services in
  your app that are promoted in your Google Play listing"*). Before a
  PRODUCTION release: the store listing must describe the feature, and the
  Data safety form must be reviewed for it (`GOOGLE_PLAY_RELEASE_PROCESS.md`).
  Closed testing may run without it.
- **Tests**: the decision rule runs as a JVM unit test
  (`android/app/src/test/.../MailNotificationPolicyTest.kt`) -- the project's
  first. CI runs `flutter test` only, so it runs locally
  (`gradlew :app:testDevDebugUnitTest`).

## Platform scope (ADR-0042)

Android only, declared exception. Windows has neither Doze nor a mail-app
notification to listen to, and its background scans already run on schedule.

## Alternatives rejected (for this ADR)

- **Gmail push through a server** -- a backend this app does not have; Gmail
  only.
- **IMAP IDLE in a permanent foreground service** -- a permanent notification,
  battery cost, and the Android 15 `dataSync` limit of 6 hours a day.
- **Reading notification content to scan only the named message** -- violates
  the privacy contract above for a small gain; the incremental fetch already
  finds new mail.
