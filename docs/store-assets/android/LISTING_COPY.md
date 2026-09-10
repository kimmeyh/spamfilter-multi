# Google Play Store Listing Copy (GP-6, Sprint 65, Issue #383)

This is the listing-copy master for the Google Play closed-track and eventual production
listing. Every claim below is traced to a code path or an existing repo record rather than
written from assumption, per R-5: no claim of a capability the Android build does not have,
and no "not available on Android yet" caveat for anything not shipped on any platform.

> **[RULE, Sprint 66 IMP-3] Trace every claim to the SCREEN a user reaches, not to a data
> structure that merely contains the capability.**
>
> A registry, a factory map, an enum, or a config table describes what the codebase KNOWS
> ABOUT. The screen describes what a user can actually DO. Those two diverge whenever a
> feature is built but gated -- which is a normal, healthy state for a codebase and a
> catastrophic one for a store listing.
>
> This document made exactly that error and it reached the Play Console: the provider claim
> was traced to `platform_registry.dart` `getSupportedPlatforms()` (which returns every
> registered provider regardless of phase) instead of to `platform_selection_screen.dart`
> (which filters to `phase <= 2`, disables `phase == 2` as "Coming Soon", and never renders
> phase 3+). The listing advertised five providers; the app offers two. It was caught only
> because Harold's own screenshot of that screen -- destined for the same listing -- showed
> Yahoo marked "Coming Soon".
>
> `test/policy/play_listing_assets_test.dart` now mechanically enforces this for PROVIDER
> names. It cannot enforce it for the other claims in this file, so the rule applies by
> hand: before writing that the app does something, open the screen where a user would do
> it.

Screenshot capture and any further public copywriting polish are Harold's people time
(excluded from this task's estimate); this document is the coding deliverable -- the words
and the structure Harold submits from, plus the gates that keep it honest.

## App name

**MyEmailSpamFilter**

Matches the Microsoft Store listing's app name exactly (`docs/STORE_LISTING_ASSETS.md`
"App Name: MyEmailSpamFilter"; `mobile-app/pubspec.yaml` `msix_config.display_name:
MyEmailSpamFilter`; Android's own launcher label is `MyEmailSpamFilter${appLabelSuffix}`,
`mobile-app/android/app/src/main/AndroidManifest.xml`). Same product, same name, on both
stores.

## Short description (80 character limit)

> Filter spam in Gmail and AOL with rules you control. Runs entirely offline.

**Character count: 75** (measured with the exact text above; `test/policy/
play_listing_assets_test.dart` re-measures this mechanically against the parsed section
below, not this prose restatement).

**CORRECTED 2026-09-08 (Sprint 66, GP-19 listing submission).** The original line read
"Filter spam across Gmail, AOL, Yahoo and IMAP with rules you control. Offline." That was
FALSE against the shipped app and was caught at submission time, with the contradicting
evidence sitting in the same listing: `phone_01_choose_provider.png` shows Yahoo under a
"Coming Soon" heading with a "Phase 2" badge.

Root cause of the bad claim: this document traced the provider list to
`platform_registry.dart` `getSupportedPlatforms()`, which returns every registered entry
regardless of phase. It never checked the SCREEN. `platform_selection_screen.dart:26`
filters to `phase <= 2`, renders `phase == 1` under "Available Now" and `phase == 2`
under "Coming Soon", and disables the latter outright (`enabled: !isPhase2`). So the
registry is a catalogue of intent; the screen is the shipped truth. What a user can
actually connect today is Gmail (phase 1) and AOL (phase 1) -- nothing else. Yahoo
(phase 2) is visible but not selectable; iCloud (phase 3) and Custom IMAP (phase 4) are
filtered out of the UI entirely and never appear.

Lesson for the next listing edit: a store claim about what the app DOES must be traced to
the code path a user reaches, not to a data structure that merely contains the capability.

Traced to the actually-registered providers only (`mobile-app/lib/adapters/
email_providers/platform_registry.dart` `_factories`: `aol`, `gmail`, `gmail-imap`,
`yahoo`, `icloud`, `imap`, `demo`) -- Outlook is commented out and unimplemented
(`outlook_adapter.dart` throws `UnimplementedError('Outlook adapter is Phase 2 - not yet
implemented')` at every call site), so it is not claimed. "Offline" mirrors the Windows
short description's own "Works offline" claim (see Cross-store comparison below) and is
true on Android: rules, credentials and scan history are all local; the only network
traffic is to the user's own provider.

## Full description (4000 character limit)

> MyEmailSpamFilter scans your email inbox and identifies spam using rules that run
> entirely on your device. Nothing is sent to any server: there is no backend, no
> analytics, and no advertising of any kind.
>
> Connect Your Account
> Connect a Gmail account with Google Sign-In, or an AOL Mail account with an app
> password. Manage your accounts in one place and scan them for spam.
>
> Customizable Rules
> The built-in default rules work for most spam out of the box. Build your own rules to
> match sender addresses, domains, or a phrase anywhere in the message body -- type the
> phrase in plain language and the app builds the matching pattern for you. Advanced
> users can write full regular expression patterns for precise control. Import and
> export your rule set in a portable YAML format to back it up or move it to another
> device.
>
> Safe Sender Whitelist
> Add trusted senders to your safe sender list so their messages always reach your
> inbox, bypassing every block rule -- choose exact address, exact domain, or entire
> domain to match how broadly you trust each sender.
>
> Background Scanning
> Schedule automatic background scans so your inbox stays clean without manual effort.
> Set the frequency that fits how much mail you get, and review scan history any time.
>
> Manual and Demo Scanning
> Run a scan on demand whenever you want an immediate check. Try Demo Mode first: it
> loads a sample inbox with dozens of realistic messages so you can explore every
> feature, including deleting matched spam, before you ever connect a real account.
>
> Review No-Rule Items
> Emails that do not match any existing rule are collected in one place so you can
> quickly decide, one at a time: block the sender, mark them safe, or skip for now.
> Every decision immediately re-applies to the rest of the list.
>
> Read-Only by Default
> Every scan can run in read-only mode first, showing you exactly what would be deleted
> or moved without changing anything. Switch to active mode only when you are satisfied
> with your rules.
>
> Privacy First
> The app does not collect analytics, telemetry, crash reports, or usage data of any
> kind. Email credentials are stored using your device's encrypted credential storage.
> Message content is read only to evaluate your rules; most evaluation uses message
> headers alone, and a message body is fetched only when a rule you created actually
> needs it. A short excerpt (up to 100 characters) is kept only for messages awaiting
> your review, and full message bodies are never stored. Remove an account at any time
> to delete its stored data, or uninstall the app to remove everything.
>
> No Subscription
> MyEmailSpamFilter is free, with no account, subscription, or in-app purchase required.

**Character count: 2672** (measured with the exact text above, blockquote markers
stripped, paragraph line-wraps counted as single spaces the way Play's text field would
join them; well under the 4000 limit -- deliberately, so Harold has headroom to add
Google Play's own required disclosures such as the Families policy answer or the Data
safety summary line if Play's editor prompts for one at submission time).

Every paragraph is traced:
- "Connect Your Account" providers: traced to the SCREEN, not the registry --
  `platform_selection_screen.dart:26` filters to `phase <= 2`, lists `phase == 1` under
  "Available Now" and disables `phase == 2` (`enabled: !isPhase2`). Only `gmail` and
  `aol` are phase 1, so only those two are claimed. `yahoo` (phase 2) renders as
  "Coming Soon" and is not selectable; `icloud` (phase 3) and `imap` (phase 4) never
  reach the UI at all. The earlier version of this bullet cited
  `getSupportedPlatforms()`, which returns the whole catalogue irrespective of phase --
  that is what produced the false multi-provider claim corrected above.
- "Customizable Rules" phrase-rule claim: F186 (Sprint 64, Issue #369), the Body Phrase
  rule type in Manage Rules, confirmed shipped and Android-validated
  (`CHANGELOG.md` 2026-08-27 Sprint 64 chain-validation entry: "Item 4 retest confirms
  both F186 fixes").
- "Background Scanning": F161 (Sprint 61, Issue #346), Android WorkManager per-account
  periodic scheduling, shipped.
- "Manual and Demo Scanning... including deleting matched spam": GP-18's verified Demo
  Mode reviewer path (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` "App access" section --
  "the traced path deletes 26 of 59 sample messages, so a reviewer sees real filtering").
- "Review No-Rule Items": `no_rule_review_screen.dart`; its Windows-only AppBar gate was
  removed in Sprint 60 (F143/F169, CHANGELOG.md), so the entry point is shared on
  Android.
- "Read-Only by Default": the app's read-only scan mode, exercised by GP-18's reviewer
  walk and by the read-only-enforcement test group (F163, Sprint 62).
- "Privacy First" claims (no analytics/telemetry/crash-reporting, encrypted credential
  storage, header-first evaluation, 100-character body preview cap, account/uninstall
  deletion): identical wording basis to `docs/legal/PRIVACY_POLICY.md` and the GP-10
  Data safety declarations already recorded and cross-checked in
  `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md`.
- "No Subscription": the app has no billing/payment code path at all (confirmed by the
  GP-10 Data safety "Financial info" row and the GP-18 "Financial features" answer, both
  grep-verified against `lib/`).

No caveat of the form "not yet available on Android" appears anywhere, per R-5 and the
`feedback_no_caveats_for_unshipped_platforms` rule -- Outlook support is simply not
mentioned, on either store, rather than flagged as a gap.

## App category

**Productivity** (Play's closest first-level category to the Microsoft Store's
"Productivity / Utilities & Tools", per `docs/STORE_LISTING_ASSETS.md`). This agrees with
the content-rating category already recorded for Play in
`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` ("App category for rating | Utility / Tools").

## Contact email

**myemailspamfilter.dev@gmail.com** -- the published developer address
(`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` "Public developer email"; also the contact address
published in `docs/legal/PRIVACY_POLICY.md`).

## Privacy policy URL

**https://myemailspamfilter.com/legal/PRIVACY_POLICY.html**

Matches the URL already recorded and cross-checked in the GP-10 Data safety section of
`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md`, and the canonical URL published in
`docs/legal/PRIVACY_POLICY.md` itself.

---

## Cross-store claim comparison (AC-4)

Reference: `docs/STORE_LISTING_ASSETS.md` (Microsoft Store listing, live at
Store ID 9N5QK9G904C0). Every row states whether the claim agrees, and if it
deliberately differs, why.

| Claim | Microsoft Store (Windows) | Google Play (Android, this document) | Agreement |
|---|---|---|---|
| App name | MyEmailSpamFilter | MyEmailSpamFilter | Same. |
| Publisher | Kimmey Consulting LLC | Kimmey Consulting LLC (Play Console "Developer name (public)") | Same identity; punctuation is each console's own convention. |
| Category | Productivity / Utilities & Tools | Productivity | Same substance -- Play's category taxonomy has no combined "Utilities & Tools" leaf; the closest single Play category is used. |
| Privacy policy | https://myemailspamfilter.com/privacy | https://myemailspamfilter.com/legal/PRIVACY_POLICY.html | Deliberate difference: the Windows listing predates the GP-5 (Sprint 64) publication of the canonical `/legal/` path. The Windows Store entry is stale and should be updated to the canonical URL at the next Windows listing edit -- recorded here as a follow-up, not silently left inconsistent. |
| Providers supported | "multiple email providers... including AOL Mail and Gmail" (short description names AOL/Gmail only; long description does not enumerate further) | Gmail and AOL | Agree. **This row previously claimed Play supported "Gmail, AOL, Yahoo, iCloud, and any IMAP account" and argued Play's copy was "more precise" than Windows'. That was backwards** -- the Windows copy naming only AOL and Gmail was the accurate one, and this comparison talked itself into the error by reasoning from the provider registry rather than the provider screen (see the CORRECTED note under Short description). Corrected 2026-09-08. |
| Local/offline processing | "All processing happens locally on your device with no data sent to external servers"; "Works offline" | "rules that run entirely on your device"; "Offline" | Same claim. |
| Customizable rules | "define your own spam filtering rules using powerful regular expression patterns... Match against sender addresses, subject lines, and email content" | "match sender addresses, domains, or a phrase anywhere in the message body... Advanced users can write full regular expression patterns" | Same substance. Play's copy additionally names the plain-language Body Phrase assist (F186, shipped after the Windows copy was last written) -- an addition, not a contradiction. |
| Safe sender whitelist | "adding trusted senders to your safe sender list... bypass all spam rules" | "trusted senders... bypassing every block rule" | Same claim. |
| Background scanning | "automatic background scans... Configure scan frequency from every 5 minutes to once daily" | "Schedule automatic background scans... Set the frequency that fits how much mail you get" | Same capability. Play's copy omits the specific 5-minutes-to-daily range because Android's WorkManager delivers periodic work approximately rather than on an exact schedule (documented in F161, CHANGELOG 2026-08-18) -- stating an exact range Android cannot guarantee would itself be a false claim, so the wording is deliberately looser. This is the one place platform mechanics genuinely constrain the claim, not a caveat about a missing feature. |
| Demo mode | "Try Demo Mode with 50+ sample emails to explore the app features" | "loads a sample inbox with dozens of realistic messages... including deleting matched spam" | Same claim; Play's copy is more specific about what Demo Mode lets a reviewer or new user actually do, verified end-to-end for GP-18. |
| Privacy / no telemetry | "does not collect analytics, telemetry, or usage data... Email content is read transiently during scans and never stored" | "does not collect analytics, telemetry, crash reports, or usage data... A short excerpt (up to 100 characters) is kept only for messages awaiting your review" | Deliberate refinement, not a contradiction: the Windows copy's "never stored" is imprecise against current behavior -- a bounded 100-character preview IS stored for items awaiting review (confirmed by the GP-10 Data safety declarations and `docs/legal/PRIVACY_POLICY.md`, both more recent and more carefully verified than the Windows listing text). The Play copy states the more accurate, currently-true version. The Windows listing should be corrected to match at its next edit; recorded here as a follow-up rather than propagated as a fresh inaccuracy on Play. |
| Price | Free | Free | Same. |
| Import/export rules | "Import and export rule sets in portable YAML format" | "Import and export your rule set in a portable YAML format" | Same claim. |
| Outlook / Office 365 | Not mentioned | Not mentioned | Same -- Outlook is deferred on both platforms (`outlook_adapter.dart` unimplemented; no MSAL wiring). Per R-5 and the no-caveats-for-unshipped-platforms rule, neither listing flags this as a gap; it is simply absent from both. |

**Summary**: no claim on the Play listing describes a capability the Android app does not
have, and no claim contradicts the Windows listing's substance. Two items are flagged as
follow-ups where the WINDOWS listing is the stale one (canonical privacy URL; the "never
stored" body-preview claim) -- both are pre-existing Windows Store listing drift,
discovered by this comparison, not something this task's scope authorizes editing (the
Windows listing lives in Partner Center, outside this repo, and editing a live public
Store listing is a Class-2/3 decision outside GP-6's scope). Recorded for Harold to correct
at the next Windows Store listing edit.
