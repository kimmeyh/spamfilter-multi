# Sprint 66 Summary

**Dates**: 2026-09-07 to 2026-09-08
**Branch**: `feature/20260907_Sprint_66` | **PR**: #389 -> develop
**Scope**: GP-4 (Gmail OAuth verification prep, Issue #388), GP-19 (Play Console entry,
Issue #387). F173 and F189 were considered and deferred at Harold's direction; both remain
periodic HOLD templates. F190 (version-bump timing) was taken mid-sprint at Harold's
request.

**Theme**: get the app INTO Google Play -- console entry, every declaration, the listing,
and a published closed test.

**Outcome**: the closed test is LIVE. Submission 1 (14 changes) went in at 2026-09-08
1:50 PM and was PUBLISHED at 2:00 PM. Ten minutes, against an expectation of days.

## What shipped

**GP-4, Gmail scope narrowing.** The app now requests only `gmail.modify` and
`userinfo.email`. Two declared-but-unused scopes were removed: `gmail.send`, which the app
never calls, and `gmail.readonly`, already covered by `modify`. A send scope on a spam
filter invites a reviewer question that should never arise.
`test/policy/gmail_scope_parity_test.dart` fails if either returns, and fails if the Windows
and Android scope sets ever diverge -- they are two independent literals with nothing else
holding them equal.

**GP-4, data-residency determination.** Every outbound connection in the app is enumerated
with evidence that none carries mail anywhere except between the user's device and their own
provider. `test/policy/data_residency_test.dart` fails the build if an analytics,
crash-reporting, or advertising dependency ever appears in `pubspec.yaml`, because that
would silently contradict a claim made to Google.

**GP-19, the console pass.** App created (`com.myemailspamfilter`, Play App Signing
accepted), all 8 App content declarations, content rating issued (All ages / Everyone /
PEGI 3 / USK 0 / 3+, no descriptors), target audience 18+, store settings, privacy policy,
Data safety, the store listing with copy and six graphics, and a closed-test release built
from a fresh 0.14.1 prod AAB.

**GP-19, tester instructions.** Written to steer testers to an App Password rather than
Google Sign-In, because an app password does not expire and keeps a tester connected for the
full 14 days. They also state the prerequisite that trips people: an app password needs
2-Step Verification enabled first.

**F190, version-bump timing.** The bump moved from Store-release Step 1 (the very end) to
sprint-plan approval (the beginning), so a tester can always tell a dev build from
production. `test/policy/dev_version_ahead_test.dart` enforces that the dev version is
strictly ahead of the last released version, and that `version:` and `msix_version` agree.
It caught the real condition on its first run.

## The defect that mattered

The listing copy advertised **five email providers**. The app offers **two**.

It was written in Sprint 65 by tracing the claim to `platform_registry.dart`
`getSupportedPlatforms()`, which returns every registered provider regardless of phase. The
screen is what a user meets: `platform_selection_screen.dart:26` filters to `phase <= 2`,
renders `phase == 1` under "Available Now", and DISABLES `phase == 2` under "Coming Soon".
Yahoo is phase 2, iCloud phase 3, Custom IMAP phase 4. Only Gmail and AOL are connectable.

It was caught at submission, by Harold's own screenshot of that screen -- which was destined
for the same listing and plainly showed Yahoo marked "Coming Soon". No gate caught it.
Harold chose to correct the copy rather than open the phase gate, and the corrected listing
is what published.

**The gate written to prevent recurrence failed its first mutation test.** Version 1
asserted `submitted.contains(displayName)` and passed while catching nothing: the registry
says "Yahoo Mail", the copy said "Yahoo", and anchoring on the longer string can never see
the shorter one. Fixed to match the brand word on a word boundary, then mutation-verified by
reintroducing the exact line that shipped -- it now fails naming both Yahoo and IMAP.

## Discoveries recorded so the next submission does not re-derive them

- The **privacy policy URL field lives inside the Data safety flow**, not under Store
  settings and not under Properties. Two wrong guesses before finding it.
- **`flutter build appbundle` invoked directly fails** the SEC-9 gradle gate. The supported
  command is `build-with-secrets.ps1 -BuildType release -Output aab`.
- The **join link does not exist** until the track is published and approved.
- Release notes need `<en-US>` tags and cap at **500 characters per language**.
- The **9:16 aspect-ratio bound in ASSET_SPEC was stale**. All five 1080x2340 captures
  uploaded without complaint; the spec had contradicted its own worked example. The ratio
  assertion was removed from the gate with the evidence recorded.
- **Screenshot slot 3 cannot show the Review No Rule Items screen** from Demo Mode. That
  screen reads persisted scans per stored account, and Demo Mode saves no account, so it
  renders "0 items" right after a scan reports 12 remaining. Not a defect -- the two read
  different sources.

## Data safety: the answer that changed

The per-category table said "Collected: Yes" for two categories. The submitted form says
**No**, and both are right, because they answer different questions. Play defines
"collected" as **transmitted off the user's device**; this app transmits nothing. The table
describes on-device storage, which is what its code evidence actually proves. The rows were
renamed and superseded rather than deleted, keeping the evidence that makes the privacy
policy verifiable.

## Backlog registered during the sprint

**F191** (~60-90m, Priority 20): ship Yahoo and iCloud by opening the phase gate. Both are
already built -- the factories construct `GenericIMAPAdapter` exactly as AOL does, and AOL
ships today. The code change is two integers; the work is the live validation the gate has
never permitted.

**F192** (~4-6h, Priority 32): build the Custom IMAP host-entry UI. Deliberately separate,
because it is a different kind of work: `GenericIMAPAdapter.custom()` expects a host to be
passed in and nothing passes one (`grep -rn "imapHost" lib/ui/` returns zero matches).

## Metrics

- Commits: 4 on the sprint branch through close-out
- Test suite: 2,051 passing / 15 skipped / 0 failing (measured at close-out); policy suite 96 passing
- Analyzer: clean
- WinWright: 2/2 at sweep-head `511dd2c`
- New policy gates: 5 (scope parity, data residency, tester instructions, dev-version-ahead,
  provider-claim truth)
- Version: 0.14.1 (patch bump at plan approval per F190; no user-facing feature this sprint)

## Carried into Sprint 67

Tester recruitment and opt-in tracking, then the production-access application. Harold's
call at close-out: the sprint delivered everything within its control, and the 14-day clock
is an external dependency rather than a reason to hold a sprint open.
