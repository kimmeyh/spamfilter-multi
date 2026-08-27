# Sprint 63 Summary

**Dates**: 2026-08-24 to 2026-08-27
**Branch**: `feature/20260824_Sprint_63` | **PR**: #366 -> develop
**Scope**: F181 (testLimit removal, Issue #357), F180 (deferred body fetch, Issue #358), F184
(Sprint 62 UI E2E, Issue #359), F182 (sweep seeding, Issue #360), F164 (Android perf
investigation, Issue #361), GP-12 (Firebase removal, Issue #362), GP-16 (Play account prep,
Issue #363), GP-5 (privacy/terms drafts, Issue #364), F94 (Android flavors, Issue #365), plus
F185 (Gmail base64url body decode) pulled in-sprint by Harold. Same-window context: 0.12.0.0 /
Submission 19 certified live 2026-08-24; the Android/Google Play track was ACTIVATED off HOLD
at this sprint's refinement (Harold: "everything Android related... off hold").

## What Shipped

- **F180 (headline)**: scans fetch message HEADERS first (`BODY.PEEK[HEADER]` chunked on
  IMAP, `format=metadata` batched on Gmail) and retrieve a full body ON DEMAND, one message
  at a time, only when `RuleEvaluator.evaluateWithoutBody` -- a tri-state header-only oracle
  -- reports the verdict genuinely needs it (body rules or body exceptions). Body rules
  always match the COMPLETE body (Harold's design requirement; the originally-registered
  truncation shape was rejected at planning). **Live PASS**: the daysBack=0 AOL scan went
  from 6m17s / ~1.0GB peak (Sprint 62 anchor) to **36s / 456MB / 0 body fetches** (~10x)
  under the real rule set, headers-only confirmed by a 4-line independent audit; with a body
  rule present, exactly the 40 undecidable messages fetched bodies (1m16s / 529MB), each
  deferral individually logged. Failed body fetches degrade loudly to header-only evaluation
  (recorded decision).
- **F185**: Gmail `payload.body.data` is base64url-encoded and was assigned RAW as the
  message body -- body rules on the Gmail path could essentially never match, ever. F180 made
  the path load-bearing; the review found it; Harold pulled the fix in-sprint. Decoder +
  conversion-call-site tests, mutation-verified.
- **F181**: the 50-email "Test Limited Emails" scan mode removed -- the cap was UNENFORCED by
  the batch path, a promised safety limit the app did not keep. Mode renamed "Process Rules
  Only"; 3 deliberate legacy keeps annotated at their sites; stored legacy values migrate.
- **F184**: in-VM E2E coverage for the three Sprint 62 surfaces that shipped without E2E: the
  F175 wait dialog (all branches + stale-row negative, DB-seeded through the real
  startRealScan), F178 bottom-anchored popup under a simulated inset, F176 account label.
- **F182**: the WinWright no-rule sweep seeds its own synthetic baselines (RFC 2606
  `.invalid` domains) and unseeds after -- ending the live-data baseline rot refreshed in
  Sprints 59/60/62. Post-review: seeding now runs only when mt2c is in the selected set.
- **F94**: Android dev/prod product flavors mirroring the Windows split -- side-by-side
  packages (`.dev` suffix, " [DEV]" label, isolated data dirs), `build-with-secrets.ps1
  -Env` in lockstep with `APP_ENV` (default prod), committed dev google-services stub, CI on
  the prod flavor. **Surprise finding**: dev-flavor Gmail sign-in WORKS despite the stub --
  the appauth redirect-scheme flow never consults google-services.json, so the four console
  registrations recorded as prerequisites are optional.
- **GP-12**: firebase-analytics/firebase-bom removed per the accepted ADR-0030/0033
  zero-telemetry decision (plugin + JSON kept for OAuth registration). Prod sign-in verified
  by Harold post-removal.
- **GP-16 / GP-5**: Play-account setup guide written for the decided PERSONAL route (12
  testers / 14 days, no DUNS); Privacy Policy + Terms drafted from ADR-0030 and code-verified
  against actual behavior -- text APPROVED; publication (hosting/URL) and the guided account
  walkthrough are Sprint 64's first task.
- **F164 CLOSED**: the Android-vs-Windows scan-speed gap was body fetching, not
  debug/emulator overhead -- F180 removed it on the same debug emulator (36s vs 6m17s).

## Verification

- Full suite at close: **1,955 passed / 15 skipped / 0 failed**; analyzer clean; hook suite
  51/51; Windows build verified (7.1).
- Phase 5 evidence BEFORE MV (the new gate's first sprint -- it held): automated review
  (1C/2H/3M all fixed), F-PRECHECK six classes clean on the PR, WinWright sweep 2 consecutive
  greens with sweep-head recorded.
- Manual Validation 2026-08-26: all 7 verdicts recorded (see SPRINT_63_PLAN.md "Final MV
  verdicts"), including the live F180 measurement set and a body-rule deferral demo on
  Harold's real mailbox.
- Post-MV review round 2: the reviewer mutation-tested its own first "no HIGH findings"
  conclusion and reversed it -- the `exc.body` deferral clause (prevents header-only deletion
  of body-exception-protected mail) was deletable with a fully green suite because the shared
  test rule set always deferred earlier. Closed with 3 isolated single-rule guard tests; the
  mutation now fails exactly one test. Implementation was correct throughout.
- Copilot review: 3 comments -- 2 fixed, 1 documented F110 policy keep; all replied +
  resolved.

## Notable Process Events

- **C-1 control-byte corruption (self-inflicted, review-caught)**: python heredoc non-raw
  strings embedded BEL/FF bytes into 4 build-script paths, masked locally by an untracked
  file; "verification" had not exercised the script path. Repaired byte-verified + unmasked
  re-proof. Produced the raw-string/SyntaxWarning hard rule (retro IMP-5).
- **Build config edited during a running Android build** broke that build -- the
  serialize-builds rule now bans build-input EDITS during any build (IMP-6).
- **The MV demo exposed F188**: a hand-inserted rule with invalid JSON was silently
  neutralized (loads with empty conditions, matches nothing, no warning) -- registered as a
  product silent-failure fix.
- **Emulator environment**: /data at 91% caused an install crawl and an app freeze correctly
  diagnosed as installd purge storms, not a product hang; AVD resized 6GB -> 16GB
  (config.ini alone does not grow the partition -- wipe-data required; accounts re-added).
- Retro: Harold -- Testing "Needs improvement as noted by dev team during sprint", Process
  "Good - see issues noted by dev team", all else Good/Very Good; Cats 13/14 "none". **All 7
  improvement proposals decided "all now" + Harold added an 8th (timestamp footer on
  decision-point responses); all 8 applied same-session.**

## Backlog Movement

- NEW: F186 (body-rule authoring UI, P22), F187 (remove 647 URL-shape body rules, P24), F188
  (silent rule neutralization warning, P26).
- DONE and stubbed for pass-1 pruning: F164, F180, F181, F182, F185, F94, GP-12; GP-5 mostly
  done (publication remains); GP-16 prep done (walkthrough carried).
- Sprint 64 carry-ins (stub created): GP-16 guided walkthrough as FIRST task (incl. GP-5
  hosting/URL + publication), F94 console-prereq re-scope, SEC-9 unblocked.
