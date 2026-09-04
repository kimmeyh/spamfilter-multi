# Sprint 64 Summary

**Dates**: 2026-08-27 to 2026-09-04
**Branch**: `feature/20260827_Sprint_64` | **PR**: #378 -> develop
**Scope**: 11 items in one sprint, Harold's option 1 at Phase 8.4 -- GP-16 (Play account,
Issue #368) with GP-5 folded in, F186 (body-rule authoring, Issue #369), F187 (URL-shape body
rule removal, Issue #370), F188 (silent rule neutralization, Issue #371), SEC-9 (client-id
injection, Issue #372), GP-2 (release signing, Issue #373), GP-9 (R8 + obfuscation, Issue
#374), GP-8 (API level + 16KB verify, Issue #375), GP-3 (permission audit, Issue #376), SEC-4
(cleartext policy, Issue #377). Same-window context: 0.13.0.0 / Submission 20 certified live
2026-08-27 before the sprint's own work began. Harold's standing constraint, restated
verbatim at scope: everything must account for BOTH the Windows and Android apps per ADR-0042,
with anything platform-specific implemented as a declared platform exception.

## What Shipped

- **The Android release chain (headline)**: six of the eleven items converge on ONE signed,
  minified artifact, and every one of them was proven against that same artifact rather than
  a convenient debug build. SEC-9 injects the Gmail client id at build time from the single
  `secrets.*.json` source and fails a release build LOUDLY if it is missing. GP-2 implements
  the already-Accepted ADR-0027 Option B (no `key.properties`); the upload keystore was
  created, and its SHA-256 fingerprint PROVEN identical across keystore, AAB, and APK -- the
  claim that matters for Play App Signing enrollment. GP-9 adds R8, resource shrinking, and
  Dart obfuscation with symbols written outside the repo (-12.8% APK). SEC-4 disables
  cleartext app-wide. GP-3 reduced the manifest to exactly nine justified permissions. GP-8
  verified the build ALREADY meets Google Play's post-August-31 API 36 requirement and passes
  16KB page alignment on every 64-bit library. All four layers are documented in
  ARCHITECTURE.md as explicit ADR-0042 platform exceptions.
- **GP-16 + GP-5**: the Play developer account ("Kimmey Consulting, Ohio", personal route)
  was created AND cleared all three verifications the same evening. Privacy Policy and Terms
  are PUBLISHED at `myemailspamfilter.com/legal` -- GitHub Pages already served `main:/docs`
  on Harold's custom domain, discovered during the walkthrough.
- **F186**: a fifth manual rule type, Body Phrase -- the first non-domain one. It is also the
  sprint's most instructive item: the feature shipped green (36 widget + 4 unit tests) and
  then produced FOUR defects across Manual Validation and code review, every one of them in
  a cross-cutting contract the tests did not assert. See "Notable Process Events".
- **F187**: 647 obsolete URL-shape body rules removed from the dev database and 1,300 from
  prod (368 distinct link-domains, duplicated by successive legacy imports), each behind a
  Harold-approved per-database dry run with timestamped backups and untruncated verification.
- **F188**: unparseable rule conditions now warn per column, are marked in Manage Rules, and
  are counted by an integrity sweep AT LOAD.

## Verification

- Full suite at close: **2,011 passed / 15 skipped / 0 failed** (+56 this sprint); analyzer
  clean.
- **Android chain validation: 6 of 6 PASS** on the signed R8-minified 0.13.0 release APK.
  The release build's logging is silent by design, so evidence is device-level. The strongest
  single result is the background-scan check: WorkManager resolved
  `dev.fluttercommunity.workmanager.BackgroundWorker` BY FULL NAME on the minified build and
  `dumpsys jobscheduler` showed the registered job -- the one R8 keep rule PROVEN rather than
  inferred. Gmail and AOL sign-in were confirmed by established TLS sessions on port 993 from
  the release build's own uid.
- Manual Validation decisions: F186 fixes applied immediately (Harold's option 1), retest
  PASS; signing-file password left plaintext (Harold's option 2, file is outside the repo on
  a single-user machine).
- Phase 5.1.1 automated review: 8 findings across three passes, all verified against source
  before fixing, all fixed with tests. Phase 5.1.2 F-PRECHECK: class 1 caught a real one (see
  below); classes 2-6 clean.
- Copilot review: 1 inline finding, real, fixed and replied.

## Notable Process Events

- **F186 is a case study in what green tests do not prove.** Four defects, none of which any
  passing test could have caught, because all four live in contracts the tests never
  asserted: (1) `source_domain` is not "where the rule came from", it is THE UI DISPLAY VALUE
  (`sourceDomain ?? name`), so writing NULL leaked the internal `manual_<slug>_<ms>` name
  into Manage Rules; (2) the duplicate checker compared `condition_header` for EVERY
  category, a column that is always NULL on body rules, so body duplicates were never
  detected on any platform; (3) the edit screen never learned the new sub-type, so a body
  rule reopened AS A DOMAIN RULE and a plain Save silently rewrote its type; (4) the edit
  screen derived the condition bucket from the ORIGINAL rule while the sub-type followed the
  user's selection, so switching any rule to Body Phrase wrote the phrase into the SENDER
  condition -- the rule looked correct in the list and could never match. Defects 1 and 2
  were found by Harold on the first real Android create; 3 and 4 by the Phase 5.1.1 review.
- **A fix that mutation-testing proved was untested.** The category fix above stayed GREEN
  when mutated, meaning the fix had no test proving it. That result is what prompted the
  round-trip save test that now reds it. Mutation verification was used on every fix this
  sprint and reversed a conclusion twice (also on F188, where a background agent's mutation
  claim did not survive re-running it).
- **SEC-4 shipped a config that passed every static gate and crashed the app.** A
  `domain-config` ROOT is well-formed XML, passes AAPT, and passed its own policy gate --
  and Android's RUNTIME parser rejects it, killing the app at startup. Nothing in the test
  suite could catch it. This produced retro IMP-6, a once-per-sprint runtime launch gate,
  deliberately scoped cheap at Harold's direction.
- **The emulator silently reverted the installed build three times.** The AVD could not save
  state on shutdown ("RAM not mapped as shared"), so every boot restored an August 25 image.
  Harold tested against the WRONG build once as a direct result. Fixed in retro IMP-1.
- **The signing password broke on first live use.** Flutter's `.bat` shim let cmd
  metacharacters in a real password eat the argument list, so `-P` injection failed. Switched
  to environment variables (gradle's documented fallback), which also keeps the password off
  every process command line.
- **The prod database numbers did not match the dev numbers presented for approval** (1,300
  of 1,470 vs 647 of 732). Work STOPPED, the difference was diagnosed as legacy-import
  duplication, and explicit approval was obtained before deleting. The per-database approval
  discipline is what made that stop possible.
- Retro: Harold rated all 12 rated categories "Very Good", Categories 13 and 14 "none". Six
  improvement proposals, all decided "apply now", all applied and verified same-session, with
  Harold scoping IMP-6 to once per sprint under the efficiency guideline.

## Backlog Movement

- DONE this sprint: GP-16, GP-5, F186, F187, F188, SEC-9, GP-2, GP-9, GP-8, GP-3, SEC-4.
- Sprint 65 runway (sequenced): GP-7, then GP-6, then GP-10, then the closed-test submission.
  Play App Signing enrolls at first upload. The 12-tester / 14-day closed-test gate is the
  long pole, so tester recruitment should start BEFORE the code work. GP-10's Data Safety
  form already has its input: the nine-permission list from GP-3.
