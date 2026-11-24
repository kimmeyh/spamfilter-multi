## Candidates at a glance

- **F67a. iOS prerequisites: Apple Developer enrollment, build machine, test iPhone, iOS OAuth client (~45-90m plus Apple lead time) Priority 2**
- **F304. iOS build machine and signed build pipeline to TestFlight (~90-180m plus a 120m time-boxed signing setup) Priority 4**
- **F67b. iOS first build and foreground parity validation (~180-300m) Priority 6**
- **F67c. iOS background scan spike on a real iPhone (~120-240m plus a 7-day observation window) Priority 8**
- **F67d. iOS store readiness: privacy manifest, App Privacy, listing, TestFlight, upload (~150-240m plus App Review time) Priority 12**
- **F95 (revised). iOS variants: dev and prod side by side on one iPhone (~60-120m) Priority 24**
- **F364. Analyze the Google Play policy and Console changes and their impact on this repository; then propose backlog cards to bring it into compliance (~60-120m analysis, estimate unverified) Priority 30**
- **F363. Task clock: every task's start and finish are recorded by a script and enforced by gates, so no task ever ends with no minutes (~180-270m) Priority 32**
- **F362. Store every question, decision and improvement in full, and re-ask an open one in full (~45-60m) Priority 34**
- **F307. Remove the "Create rule" page (RuleQuickAddScreen) -- IN SPRINT 86 (~45-75m) Priority 36**
- **F336. Python conversion batch S7: emulator, adb and Android helper scripts (~150-260m, estimate unverified) Priority 37**
- **F361. Retrospective improvement Effort states what the change adds to full-suite and CI test time (~30-45m) Priority 38**
- **F337. Windows-bound scripts: decide per file, add thin Python entry points where useful (~90-150m, estimate unverified) Priority 38**
- **F338. Audit the rule-data one-off scripts: delete, keep or convert (~45-90m, estimate unverified) Priority 38**
- **F339. Skills: a script for the deterministic part, the skill stays a short `.md` (~120-200m, estimate unverified) Priority 38**
- **F346. Log the device state when WorkManager stops a background scan (~30m) Priority 38**
- **F311. Research: known spam and phishing sender sources for delete-rule suggestions (~60-90m research) Priority 39**
- **F344. Prompts: rewrite the deterministic ones as Python tools; shared helpers for the rest (~60-120m audit, estimate unverified) Priority 39**
- **F359. Android emulator integration test for the paths only a phone found (~120-180m) Priority 40**
- **F263. Background scan spacing: per-worker budget, Test Background Scan, sign-in skip Priority 40**
- **F313. Evaluate the No Rule recommender: hide the rules, recommend, compare (~90-150m) Priority 40**
- **F340. Audit the `.claude/scripts/` memory scripts and the retired `memory-restore` skill (~20-40m, estimate unverified) Priority 40**
- **F347. Log the phase and network type of an IMAP connect timeout (~45m) Priority 40**
- **F273. Privacy policy and Data safety revision for the content history and learning (~60m) Priority 40**
- **F240. Body-rule sub-type consistency Priority 40**
- **F213. Migrate Android Gmail OAuth off Custom URI schemes to Google Identity Services (~180-300m) Priority 40**
- **F316. Make the fallback export folder visible (~45-90m) Priority 41**
- **F360. WinWright runner: restore the screen-reader flag, and find why F124 fails only through the runner (~60-120m) Priority 42**
- **F348. Update the stale sprint62_surfaces integration tests (~45-60m) Priority 42**
- **F272. Per-user on-device spam classifier (pure Dart) ranking No Rule Review (~300m) Priority 42**
- **F349. Windows Task Scheduler tests time out on the dev machine (~45-60m) Priority 44**
- **F262. Gmail renewal failures named by cause; stale log line Priority 45**
- **F343. F309 trusted-sender hint: decide after Sprint 83 Task 5 ships (~15m decision, estimate unverified) Priority 45**
- **F244. Tell the user when a Gmail background scan skips for sign-in Priority 45**
- **F254. Home-screen widget: last scan and new No Rule count Priority 45**
- **F290. Tell the user when content-history rows could not be deleted (~30-45m) Priority 45**
- **F351. AppBar action icons overflow on narrow phones (~60-120m) Priority 46**
- **F353. Four empty states can overflow on a short screen (~30-45m plus a WinWright re-sweep) Priority 48**
- **F260. Stale log-lock takeover by atomic rename Priority 50**
- **F279. Listener gap 2 minutes vs 5 minutes (~30-45m) Priority 50**
- **F356. Android first-run polish (~45-90m, estimate unverified) Priority 50**
- **F242. Span-replacing edit scripts assert what the span contains Priority 50**
- **F358. "All reviewed" shows before any scan has run (~30-60m, estimate unverified) Priority 52**
- **F257. Scan History shows which mechanism started each background scan Priority 55**
- **F256. Rename `GmailWindowsOAuthHandler` to reflect both platforms Priority 60**
- **F241. Remove or wire `ScanResultStore.getActiveBackgroundScan` Priority 60**
- **F95b. Gmail new-mail push through a server (not estimated until the ADR exists) Priority 60**
- **F95. iOS variants + cross-store hardening (not re-estimated; iOS part moved to F95 (revised)) Priority 62**
- **F261. Export header recognized by its first column, not the full text Priority 65**
- **F67. Platform validation - iOS, Linux, macOS (~120-240m per platform) Priority 70**

## ON HOLD Candidates

- F265. Android Gmail native one-pick sign-in -- revisit only when a second device reproduces the failure Priority HOLD
- F274. On-device GenAI rule explanations (~240m) Priority HOLD
- F275. Cloud GenAI classification (~360m) Priority HOLD
- F246. Android Gmail background renewal through a server-side token exchange (~30m scope-matched spike retry; the server path is a Class-1 decision, not estimated) Priority HOLD
- F165. Cross-device rules-DB sharing -- user cloud storage (iCloud/OneDrive/Box/Google Drive) exploration + hosted-tier option (~half-day exploration) Priority HOLD
- F173. Periodic "Test Coverage and Appropriate Testing" Deep Dive (~4-8h per review) Priority HOLD
- F183. Upstream civyk-winwright request: script-runner replay support for ww_wait (~15m to file, then external) Priority HOLD
- F179. Subject-blocking phrase picker -- user selects (or GenAI recommends) the blocking SUBSET of a subject (~3-5h) Priority HOLD
- F152. Periodic User-Centric First-Run Evaluation (~2-3h per review, plus fix-item time if findings warrant) Priority HOLD
- F189. Periodic Skills Audit -- what tooling would make sprints, development, recovery and prevention measurably better (~4-8h per review, research-led) Priority HOLD
- GP-4. Gmail API OAuth Verification / CASA -- THE SUBMISSION ITSELF (~40-80h) Priority HOLD
- F199-b. Partner Center publisher display name -- the last surface of the LLC rename (~15m once reopened) Priority HOLD
- F285. Re-ask: keep or delete `email_detail_view.dart` (~5m) Priority HOLD
- F289. WinWright default sweep with no mouse steps (~30-60m) Priority HOLD
- F111. Periodic Windows App Store upload readiness verification (~110-175m per review) Priority HOLD
- F139. Local-install smoke test for a release-candidate MSIX (~30-50m per review) Priority HOLD
- F70. Periodic Security Deep Dive (~4-8h per review) Priority HOLD
- F130. Periodic Process-Docs Consistency Deep Dive ([no-history] -- unbounded discovery; see estimating note) Priority HOLD
- F71. Periodic Architecture Deep Dive (~4-8h per review) Priority HOLD
- F201. Periodic Web Property Accuracy Re-Review -- myemailspamfilter.com + GitHub Pages (~1-2h per review, plus fix time if findings warrant) Priority HOLD
- F63. Responsive design framework -- [SUPERSEDED 2026-08-03 by Sprint 54 F141's per-screen findings] Priority HOLD
- F6. Provider-Specific Optimizations (~10-12h) Priority HOLD
- SEC-11b. Database-at-rest encryption via SQLite3MultipleCiphers (sqlite3mc) + plaintext-to-encrypted migration (~8-12h) Priority HOLD
- F106. SEC-11b verification-window cleanup (~30m) Priority HOLD
- H1. GenAI Pattern Suggestions - Crowdsourced Spam Intelligence (TBD) Priority HOLD
- H2. Rule Pattern Consistency - Domain Matching Standards (~4-6h) Priority HOLD
- H3. Requirements Documentation System (TBD) Priority HOLD
- H4. Sent Messages Scan for Safe Senders (~12-16h) Priority HOLD
- H5. Outlook.com / Office 365 email provider adapter (~16-20h) Priority HOLD

## Details

**F67a. iOS prerequisites: Apple Developer enrollment, build machine, test iPhone, iOS OAuth client (~45-90m plus Apple lead time) Priority 2**
- Sprint 81 status: walkthroughs DONE (`docs/IOS_SETUP.md` Parts A-D). AC-2/AC-3 (enrollment, iOS OAuth client, App
  Store Connect API key) moved to Sprint 82 by Harold, 2026-10-26: *"move to next sprint"*. Creating a new Apple
  Account on the web failed about six times 2026-10-26/27 (Apple's generic refusal). Harold 2026-10-27: enroll with his
  EXISTING Apple ID (the iCloud test email account). The Apple Developer Program License Agreement PDF is dated
  2026-10-27 and kept outside the repo (path in `docs/IOS_SETUP.md`). Sprint 82 starts with Part A.
- Phase: Multi-Platform Readiness
- Platform: iOS
- **Harold 2026-10-23**: Individual (Q1 = 1); build machine = GitHub `macos-26` runner (Q2 = 1); he has an iPhone on iOS 26 (Q3 = 1). Selected for Sprint 81 with F304 and the F67b code.
- Scope: enroll in the Apple Developer Program (99 USD per year) on the account type Harold chooses. Individual needs
  no D-U-N-S Number. Organization needs one: D&B "allow up to 5 business days", then "allow up to 2 business days"
  for Apple (developer.apple.com/help/account/membership/D-U-N-S/, read 2026-10-23), plus a domain website and
  domain email the LLC does not have (`docs/LEGAL_ENTITY.md`). Choose the build machine (F304). Confirm a test
  iPhone on iOS 26. Create the iOS OAuth client in Google Cloud Console with bundle ID `com.myemailspamfilter`
  (mirrors the Android applicationId; ADR-0026) and record the restricted Gmail scope verification status for it.
- Claude writes the console walkthroughs and records the results; Harold performs the console steps.
- Settles UNVERIFIED items: enrollment processing time, seller name shown for the chosen account type, Gmail
  verification for the iOS client.
- Depends on: none (Harold's go decision 2026-10-23; ADR-0050 accepted 2026-10-22).

**F304. iOS build machine and signed build pipeline to TestFlight (~90-180m plus a 120m time-boxed signing setup) Priority 4**
- Sprint 81 status: the unsigned `macos-26` compile job is DONE (run 40012148625 green). Signing and the first
  TestFlight build moved to Sprint 82 with F67a (they need the Apple account and API key).
- Phase: Build and Release Infrastructure
- Platform: iOS (build tooling)
- Value: the project has no Mac. Without a build machine nothing in F67b-F67d can run.
- Scope, by Harold's build-machine answer: (a) a GitHub Actions `macos-26` runner (the runner-images README, read
  2026-10-23, lists macOS 26.6.2 with Xcode 26.6 as default) with a `workflow_dispatch` job that builds, signs with
  an App Store Connect API key, and uploads to TestFlight; certificate, provisioning profile and API key live in
  repository secrets, never in the tree; or (b) an owned or rented Mac with interactive Xcode.
- UNVERIFIED: whether macOS runner minutes are free on this public repository. GitHub's billing page says Actions is
  free "for public repositories that use standard GitHub-hosted runners" and does not say whether macOS is one.
- Signing setup is discovery: time-box it at 120m; do not estimate it.
- AC: one command produces a signed build that installs on Harold's iPhone through TestFlight internal testing.
- Depends on: F67a (enrollment and account type).

**F67b. iOS first build and foreground parity validation (~180-300m) Priority 6**
- Sprint 81 status: code DONE (#511 closed: project, Info.plist, AppDelegate, `PlatformCapabilities` iOS answers;
  unsigned build green, run 40012148625). REMAINDER: the device check (smoke test, IMAP scan, Gmail sign-in, rules,
  review screens, export to Files, notification permission) once F304 delivers a TestFlight build.
- Phase: Multi-Platform Readiness
- Platform: iOS
- Scope: generate the iOS project first (`flutter create --platforms=ios`; whether this runs on Windows is
  UNVERIFIED), bundle ID `com.myemailspamfilter`. The plist, AppDelegate and `PlatformCapabilities` work below needs
  no Mac to write, only to compile, so it lands in Sprint 81.
- `flutter build ios` on Xcode 26 with Swift Package Manager; deployment target iOS 14 (plugin floor);
  Info.plist (`GIDClientID`, reversed-client-ID URL scheme, background modes `fetch`, `BGTaskSchedulerPermittedIdentifiers`,
  `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`); AppDelegate lines for notifications and workmanager;
  fill every `PlatformCapabilities` iOS answer from ADR-0050; smoke test, IMAP scan, Gmail sign-in, rules, review
  screens, export to Files, notification permission.
- Settles UNVERIFIED items: custom-scheme browser fallback, Files app visibility, `drawsUnderSystemBars`.
- Depends on: F67a; F304 for the device check; F294 seam (merged Sprint 80).

**F67c. iOS background scan spike on a real iPhone (~120-240m plus a 7-day observation window) Priority 8**
- Phase: Multi-Platform Readiness
- Platform: iOS
- Scope: `BGAppRefreshTask` per the ADR-0050 exception (interval is a floor; a time-boxed scan slice that resumes
  from the cursor; confirm the `workmanager_apple` `frequency` finding and pass the interval as the earliest start);
  locked-phone run with two Gmail accounts and one IMAP account; log every background launch for 7 days; completion
  notification from the background engine; Background App Refresh "off" warning in Settings; decide whether
  `BGContinuedProcessingTask` keeps a manual scan alive (iOS 26).
- Settles UNVERIFIED items: real refresh frequency, multi-account Gmail renewal while locked, Google Sign-In SDK
  keychain accessibility, background notification.
- Depends on: F67b; a test iPhone. Start the 7-day window early in Sprint 82. Outcome may change the Gmail renewal design (a Class 2 decision to surface).

**F67d. iOS store readiness: privacy manifest, App Privacy, listing, TestFlight, upload (~150-240m plus App Review time) Priority 12**
- Phase: Build and Release Infrastructure
- Platform: iOS
- Scope: Xcode privacy report on an archive; app `PrivacyInfo.xcprivacy` with the required-reason entries the report
  finds; App Store Connect App Privacy answers (expected "Data Not Collected", ADR-0030); privacy policy link in app
  and metadata; release notes per ADR-0043; TestFlight internal group, then an external group (first build goes
  through App Review); help and store text that describe background scanning as best effort on iOS without a
  platform caveat (ADR-0042 rule on caveats).
- App Store Connect listing: iPhone screenshots at the required sizes, description, age rating, review notes.
- App Review sign-in path: the Gmail consent screen is in Testing and unverified (F301, ADR-0029), so a reviewer
  cannot sign in with Gmail unless listed as a test user. Give the reviewer an IMAP (AOL) demo account. Whether
  App Review requires demo credentials is UNVERIFIED; read guideline 2.1 at submission.
- Settles UNVERIFIED items: required-reason API set, plugin manifests.
- Depends on: F67b. (Relaxed from F67c on 2026-10-23: F67c's result changes only the help and store text that
  describe background scanning, so it does not block the upload.)

**F95 (revised). iOS variants: dev and prod side by side on one iPhone (~60-120m) Priority 24**
- Phase: Build and Release Infrastructure
- Platform: iOS
- Scope: separate bundle IDs for dev and prod (ADR-0035 on iOS), so both install on one device; separate OAuth iOS
  clients or URL schemes per variant; separate keychain items and app data by construction (separate bundle IDs);
  TestFlight as the "store" channel. The cross-store multi-variant polish for Windows and Android stays on the
  existing F95.
- Shipping iOS prod-only first departs from ADR-0035 side-by-side for a short period; that is Harold's call.
- Depends on: F67b.

**F364. Analyze the Google Play policy and Console changes and their impact on this repository; then propose backlog cards to bring it into compliance (~60-120m analysis, estimate unverified) Priority 30**
- Phase: Release Readiness (Google Play)
- Platform: Android (Play); no app code in this card
- Source: Harold, 2026-11-23 (verbatim): "add to backlog for next sprint: analyze changes to google play
  store/console and their impact on this repository. Follow-up analysis with suggested additions to the backlog to
  bring the repository into compliance https://support.google.com/googleplay/android-developer/answer/18100766"
- The page is "Policy announcement: October 29, 2026" (fetched 2026-11-23). It gives "at least 30 days from October
  29, 2026" to comply. Topics it names (summary of the fetch, not yet checked against the app): new Local Network
  and Manage Contacts permission policies (Play Console declaration for API 37+ / core use); AppFunctions API;
  eligibility-based subscription discounts; Location permission rules mandatory 2027-01-27 (`ACCESS_FINE_LOCATION`
  declaration); All Files Access; Accessibility API; Deceptive Behavior; SMS / Call Log (`READ_CALL_LOG` phone-call
  verification ends 2027-01-27); Payments through AI or agentic flows; Play Age Signals API; Japan payments
  authorization by 2026-12-01; trader status declaration in Play Console "Starting in November 2026"; app quality
  memory and code-optimization thresholds by February 2027 (answer/17492799); car apps; Android XR.
- R-1: for each topic, read the Google page it links (including answer/17594752 trader status and answer/17492799
  app quality) and record the exact requirement, date and source link. Do not state a policy from memory.
- R-2: check each requirement against the repo with evidence: the merged `AndroidManifest.xml` permissions,
  `targetSdk` / `compileSdk` in `mobile-app/android/app/build.gradle.kts`, the plugins in `pubspec.lock` that add
  permissions, `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` (declarations already submitted) and the Play Console state Harold
  reports (the Console cannot be read from here; ask for a screenshot when a fact is only there).
- R-3: classify each topic: applies (with the file:line or Console screen), does not apply (with the evidence), or
  unknown (with what would settle it).
- R-4: write the result to `docs/GOOGLE_PLAY_POLICY_2026-10-29_ANALYSIS.md` and propose one backlog card per gap
  (F-number, effort, priority, deadline), presented to Harold as register items for a decision.
- R-5: record the EU / trader-status position in `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` (Harold, 2026-11-23: "I have a
  EU declared development account"). Declared status: non-trader (Harold, 2026-11-23, register q4 = 2). Check, with
  a source, what a non-trader declaration requires or limits for this account.
- AC-1: every topic on the page has a classification and a source link. AC-2: every "applies" topic has a proposed
  card or a recorded reason none is needed. AC-3: no claim about a Google rule without a same-session source.
- Depends on: none. Deadline pressure: the 30-day window from 2026-10-29 ends about 2026-11-28 (unverified how
  Google counts it; the Policy Deadlines page settles it).

**F363. Task clock: every task's start and finish are recorded by a script and enforced by gates, so no task ever ends with no minutes (~180-270m) Priority 32**
- Phase: Process
- Platform: development process (hooks and scripts; no app code)
- Trigger: six of the sixteen Sprint 85 task cards (Tasks 1, 2, 4, 5, 7, 8) closed with "actual minutes not
  recorded, 0 min logged". Open question q1 in `docs/DECISION_REGISTER.md` covers those six rows; this card stops
  the miss from happening again.
- Root causes (evidence read 2026-11-23):
  - RC-1: close-out check 3d-3 accepted the text of the miss. `EXECUTED_BY_MINUTES`
    (`.claude/hooks/verify-closeout-complete.py:74`) matches any `\d+ min`, so "0 min logged" passed.
  - RC-2: nothing blocks at the time. `warn-commit-without-velocity.py` always exits 0 (warn only), and Sprint 85
    retro i7 ("add the velocity row with `Started <date HH:MM>` when the task starts") is a document line with no gate.
  - RC-3: a close-out check can only detect. By then the clock reading is gone and cannot be recovered.
  - RC-4: the misses are main-session work. Five of the six involve the main session (Task 8 was a Haiku sub-agent
    whose launch and handback times were not written down). The ten recorded rows are mostly sub-agent tasks, whose
    launch and handback give a start and an end. A task with no commit (Task 7, decisions only) had no event at all.
- R-1: `scripts/task-clock.py` with `start <task>`, `stop <task>` (end of one work segment, for interleaved tasks),
  and `finish <task>`. The script reads the clock itself; Claude never types a time. It writes a per-sprint ledger
  `docs/sprints/SPRINT_<N>_TASK_CLOCK.json` (committed), and at `finish` it writes the CODING_VELOCITY row (Started,
  Finished, minutes) and the plan's `**Executed-by**` minutes from the ledger total.
- R-2 handoff and handback (sub-agent tasks): a PreToolUse hook on the Agent tool records the task's start when
  the prompt names `Task <N>` of the current sprint and no start exists. A PostToolUse hook records the handback
  time for a foreground agent. For a background agent, the end comes from `finish` at handback; verify first
  whether Claude Code's SubagentStop hook event carries enough to name the task (unverified 2026-11-23; read the
  hooks reference before building).
- R-3 main-session start: during Phases 4-5 (read from `sprint_status.json`), a PreToolUse hook on
  Edit|Write|NotebookEdit BLOCKS an edit to a tracked file when no task clock is open. Exempt list: the sprint plan,
  the ledger, `docs/CODING_VELOCITY.md`, `docs/DECISION_REGISTER.md`, `.claude/sprint_status.json`. The block text
  gives the one command to run. This is the gate that would have caught Sprint 85 Tasks 1, 2, 4 and 5.
- R-4 finish: a `git commit` whose message has `Closes #<card>` is BLOCKED unless that task's ledger has `finish`.
  A commit naming `Task <N>` is BLOCKED unless that task has a start. The warn-only velocity hook is replaced by
  this gate (or kept only for commits the gate does not cover).
- R-5 end-of-task checklist: `finish` prints and checks the task's close lines: ledger start and finish present,
  CODING_VELOCITY row complete, Executed-by line names the model and the ledger minutes, `sprint_status.json` task
  status updated. A line that fails is printed as FAIL and the script exits non-zero.
- R-6 close-out 3d-3 hardened: every task card needs a ledger entry with start and finish, and its Executed-by
  minutes must equal the ledger total. "0 min" and "not recorded" are rejected. The only exception is a line that
  names a register decision `d<n>` in which Harold accepted the gap.
- R-7 fail closed: every gate that cannot read the ledger or `sprint_status.json` BLOCKS and says "the check did
  not run", never passes in silence. Outside Phases 4-5 the gates do nothing (Phase 8 and refinement are free).
- R-8 a task with no commit and no edit (a decisions-only task such as Sprint 85 Task 7) is covered by R-6: it
  cannot close out without `start` and `finish`.
- AC-1: a fixture plan with the exact Sprint 85 line "actual minutes not recorded, 0 min logged" BLOCKS 3d-3.
- AC-2: an Edit to `mobile-app/lib/` in Phase 4 with no open task BLOCKS; the same edit after `start` passes.
- AC-3: an Agent call naming `Task 3` writes a start to the ledger; a commit with `Closes #<card>` before `finish`
  BLOCKS.
- AC-4: an unreadable ledger BLOCKS with "the check did not run".
- AC-5: Sprint 86 itself closes out with every task clocked by this mechanism (the card is built first in the
  sprint, so the other Sprint 86 tasks are its first real use).
- Effort for test time (F361 style, estimate, to be measured): about 12-15 new hook cases and unittests, +3-6 s to
  `python .claude/hooks/run-test-cases.py` locally and +3-6 s to the CI hook unittest step; +0 to `flutter test`.
  Runtime cost: one extra hook per Edit/Write in Phases 4-5, target under 100 ms.
- Decided: register q2 = 1 (Harold, 2026-11-23): add all three gates -- new `.claude/settings.json` matchers for
  Agent (PreToolUse and PostToolUse) and Edit|Write|NotebookEdit (PreToolUse), and the commit gate on Bash|PowerShell.
- Depends on: F362 (the register that holds `d<n>` exceptions). Pairs with F362 (Priority 34).

**F362. Store every question, decision and improvement in full, and re-ask an open one in full (~45-60m) Priority 34**
- Phase: Process
- Platform: N/A
- Harold, 2026-11-22: *"please store all quesitons, decisions and Improvement in full. If you still need an answer
  to one and it has scrolled off the screen, always re-ask with the full contents every time (it is to hard to
  scroll back to find them)."* Trigger: the 7.7.5 announcement asked how to record six Executed-by lines with no
  minutes; the question was in the terminal only, not in any file.
- Harold, 2026-11-23 (register d1): the items live in a repository file OUTSIDE the sprint plan, because they cross
  sprints and some are not plan items; easy to find by search or index; short ids (i1, q1, d1). Started
  2026-11-23: `docs/DECISION_REGISTER.md` exists with an index, q1, q2, d1 and d2.
- R-1: every question, decision and improvement put to Harold is written to `docs/DECISION_REGISTER.md` IN FULL at
  the time it is asked: the id (q<n>, i<n>, d<n>; counters run across sprints, never reused), what it decides,
  every option with its pros and cons, the recommendation, and later Harold's verbatim answer and the date. A
  one-line summary or a reference to the chat is not enough.
- R-2: the register's Index lists every open item. An item leaves Open only when Harold answers or withdraws it.
- R-3: a message that needs an answer to an open item copies the FULL entry from the register, never a reference to
  it (extends the existing "re-present, do not reference" rule in CLAUDE.md with a stored source to copy from).
- R-4: decide with Harold whether a close-out check blocks on an open register entry with no answer (prevention by
  gate, like check 3d-4) or whether the rule stays documentation only.
- R-5: CLAUDE.md, `SPRINT_EXECUTION_WORKFLOW.md` 7.3 STEP 5 and the retrospective template name the register as the
  place improvements and questions are written.
- Effort for test time (F361): a close-out check adds about 3-4 hook cases, under 2 s locally and in CI; documentation
  only adds +0.
- Depends on: none. Pairs with F361 (both change how retrospective items are written).

**F307. Remove the "Create rule" page (RuleQuickAddScreen) -- IN SPRINT 86 (~45-75m) Priority 36**
- Phase: Core App Quality
- Platform: All
- Sprint 86 scope (Harold, 2026-11-18, Sprint 85 Manual Validation q1: *"there is already a backlog item to remove
  this - find and ensure in next sprint"*). Sprint 85 Task 8 (#568) did the R-1 audit only and moved the removal
  here; #568 stays open for Sprint 86. Audit facts: the page pre-fills only the From pattern
  (`rule_quick_add_screen.dart:105-112`); its Subject, Body and Body URL patterns have no text field and its "Edit
  pattern" pencil does nothing (`:715-719`); no screen blocks a free body phrase, before or after removal.
- Harold (2026-10-25): *"I don't think that the Create rule page will be needed, but keep it for now as reference but
  backlog to remove it in 5 sprints from now."*
- Scope: remove `rule_quick_add_screen.dart` and its two callers: the F271 "Create rule" button on Review No Rule
  Items (`no_rule_review_screen.dart:520`) and `email_detail_view.dart:551`. First confirm F306 covers what the page
  did (its four condition buckets: From header, subject, body, body URL).
- Target: Sprint 86 (Sprint 81 + 5). Depends on: F306.

**F336. Python conversion batch S7: emulator, adb and Android helper scripts (~150-260m, estimate unverified) Priority 37**
- Phase: Process / Tooling
- Platform: Development process (Android tooling; the phones cannot use adb, the emulator can).
- Files (about 800 lines): `mobile-app/scripts/run-emulator.ps1` (83), `start-emulator.ps1` (54),
  `setup-android-oauth.ps1` (157), `export-tokens-for-android.ps1` (114), `capture-diagnostic-logs.ps1` (303),
  `enable-screen-reader-flag.ps1` (46), `fix-flutter-git.ps1` (57).
- Care: resolve tools through the environment (`ANDROID_HOME`, `common.find_tool`), never a hardcoded path (CLAUDE.md
  Sprint 67 IMP-3: this machine has two SDK installs).
- AC: each script runs against the emulator (launch it, leave it running); a `unittest` for the path resolution.

**F361. Retrospective improvement Effort states what the change adds to full-suite and CI test time (~30-45m) Priority 38**
- Phase: Process
- Platform: N/A
- Harold, 2026-11-21: *"add to Improvements Effort, what the change adds to full-suite and CI testing time"*. Each
  retrospective proposal's Effort field (`SPRINT_EXECUTION_WORKFLOW.md` Phase 7.3 STEP 5, and the CLAUDE.md
  retrospective-improvement exception line) gains a second part: the time the change adds to the local full suite
  (`flutter test`, the Python tests, the hook cases) and to the CI jobs, in seconds or minutes, with how it was
  measured or estimated (for example "local: +3 hook cases, ~2 s, timed; CI: +1 unittest, ~0.1 s"). CI today runs
  `flutter analyze`, `flutter test`, the Windows build, and the Python unit tests in `.claude/hooks/tests` and
  `scripts/tests` (`.github/workflows/ci.yml:50,58`).
- Measure, not guess: name where the number comes from (the run time of the new tests, a timed run before and
  after). An improvement that adds nothing to either says "+0".
- Depends on: none.

**F337. Windows-bound scripts: decide per file, add thin Python entry points where useful (~90-150m, estimate unverified) Priority 38**
- Phase: Process / Tooling
- Platform: Windows only by nature (MSIX, WinWright, Windows Error Reporting, MTP through the Windows shell).
- Files: `mobile-app/scripts/build-windows.ps1` (577), `build-msix.ps1` (238; DEPRECATED, CLAUDE.md says do not use:
  delete), `launch-msix.ps1` (68), `create-test-cert.ps1` (24), `generate-appinstaller.ps1` (126),
  `run-winwright-tests.ps1` (962), `winwright-db-snapshot.ps1` (435); `scripts/enable-crash-dumps.ps1` (72),
  `scripts/pull-phone-screenshots.ps1` (286).
- Do: per file, record "stays PowerShell" (with the reason) or "Python entry that calls PowerShell on Windows and
  exits with a clear message elsewhere". Delete `build-msix.ps1` and update its references. No conversion of the
  Windows tool calls themselves.
- AC: every file has a recorded decision in the ADR-0051 classification; the deleted script has no remaining
  reference (grep).

**F338. Audit the rule-data one-off scripts: delete, keep or convert (~45-90m, estimate unverified) Priority 38**
- Phase: Process / Tooling
- Platform: Development process.
- Files: `mobile-app/scripts/cleanup-url-body-rules.ps1` (129), `fix-header-patterns.ps1` (42); Dart one-offs
  `cleanup_body_rules.dart`, `dedup_rules.dart`, `fix_tld_rules.dart`, `fix_wildcard_tld.dart`,
  `remove_ambiguous_tld_rules.dart`, `repair_safe_sender_types.dart`, `split_rules.dart`, `tld_audit_and_gapfill.dart`;
  Python `rebuild_rules_yaml.py`; `split_edge_cases.txt`. Rules are in the database since Sprint 20, so most one-offs
  may be dead.
- Do: for each, grep for a caller; delete the dead ones, convert none that nothing calls. Record the result.
- AC: a list of kept and deleted files with the evidence (no caller found, or the caller named).

**F339. Skills: a script for the deterministic part, the skill stays a short `.md` (~120-200m, estimate unverified) Priority 38**
- Phase: Process / Tooling
- Platform: Development process.
- Skills: deterministic `startup-check` (130 lines), `full-test` (40), `validate-rules` (31), `deploy-debug` (32); hybrid
  `phase-check` (71) and `memory-save` (139: the script gathers the facts, the model writes the resume string).
  `plan-sprint`, `backlog-refinement` and `first-principles` are GenAI and stay `.md` (no work).
- Do: one Python script per skill under `scripts/`, and the skill `.md` runs it and keeps only the instructions about
  what to do with the output. `startup-check` keeps the staleness checks of `sprint_status.json`.
- AC: each skill produces the same report as before on the current repo (compare outputs); the skills still load.

**F346. Log the device state when WorkManager stops a background scan (~30m) Priority 38**
- Phase: Core App Quality
- Platform: Android (WorkManager stop; declared Android exception). Windows and iOS: no equivalent stop event.
- Evidence: 3 AOL worker stops with `reason=deviceState raw=4` on the Fold (10-29, 11-02 x2); which device state fired
  is unknown (`docs/research/F342_FOLD_BACKGROUND_ERRORS_S84.md` group 4).
- Do: at `onWorkerStopped`, log power-save mode, device-idle mode and thermal status, so the next stop names its cause.

**F311. Research: known spam and phishing sender sources for delete-rule suggestions (~60-90m research) Priority 39**
- Phase: Core App Quality (research only)
- Platform: All (the result would feed F306)
- Harold (2026-10-25): *"should we add an item to the backlog for a compliment to F309 for known spam/phishing
  senders - do some research?"*
- Leads found 2026-10-25 (search results only; verify terms on each vendor's own page at card time):
  - Spamhaus DBL (domain blocklist, DNS query): free only under fair use for non-commercial use; the official page
    sets no number; commercial use needs the paid Data Query Service. Whether a Store app counts as commercial use is
    the first question.
  - abuse.ch URLhaus (malicious URLs): free under fair use (terms effective 2025-11-04); whether the API needs a key
    is reported both ways.
  - OpenPhish community feed (phishing URLs, updated about every 12 hours) and PhishTank (Cisco Talos; free with
    registration): from secondary sources only.
- Also research a most-abused TOP-LEVEL-DOMAIN list (for F306 TLD idea (a), Harold Q1 = 1, 2026-10-26): candidate
  sources, update cadence, license for a shipped app. A static list shipped in the app sends nothing off the device.
- Questions: coverage of the senders and body URLs in the content history, licence for a shipped app, and privacy.
- Decision class: a lookup sends the sender domain or a body URL off the device. That is Class 1 and a privacy-policy
  change. A downloaded list checked on the device avoids the per-email disclosure but needs a licence for
  redistribution.

**F344. Prompts: rewrite the deterministic ones as Python tools; shared helpers for the rest (~60-120m audit, estimate unverified) Priority 39**
- Phase: Process / Tooling
- Platform: Development process.
- Harold (2026-11-04, Q8): *"prompt that can be easily rewritten deterministically should be rewritten. If there are
  common tools needed by prompts that can be written deterministically (python), then these helper tools should be
  written and then used by the prompts."* Python 3.14 preferred.
- Scope: prompts outside skills (agent briefs in `docs/`, hook-delivered prompts such as the hourly wake-up, review
  prompts). Skill scripts are F339; do not duplicate them.
- Do: list each prompt, mark it deterministic, hybrid or GenAI; for deterministic and hybrid ones, name the Python
  helper that does the fixed part. Build the helpers used by two or more prompts first.
- AC: the inventory with a disposition per prompt; the shared helpers exist under `scripts/` with `.SYNOPSIS`
  headers and are called by the prompts.
- Also (Sprint 83 MV Question D = 2, Harold 2026-11-04): move the hook registrations in `.claude/settings*.json` from
  `python` (3.12.10 on PATH) to Python 3.14 (`py -3.14`), then run `python .claude/hooks/run-test-cases.py`. A `.claude`
  settings change: confirm with Harold at the start of that sprint.

**F359. Android emulator integration test for the paths only a phone found (~120-180m) Priority 40**
- Phase: Core App Quality
- Platform: Android
- F350 R-2: no automated test runs on an Android emulator or device; four defects in Sprints 78-84 were found only
  on an emulator or a phone (`docs/research/F350_RISK_BASED_TESTING.md` R-2). Add an `integration_test` run on the
  emulator (adb is allowed on the emulator only) for those paths: the WorkManager worker start and stop, the
  per-process file lock in the diagnostic log, and the background-scan enable dialog.
- Depends on: none.

**F263. Background scan spacing: per-worker budget, Test Background Scan, sign-in skip Priority 40**
- (Harold, 2026-10-06: "3. a" -- confirmed as backlog.) The 5-minute spacing and 6-minute busy cap are per ACCOUNT, so one Android worker scanning several accounts in sequence can exceed WorkManager's ~10-minute run limit and leave an `in_progress` row. Test Background Scan also waits out the spacing (up to 5 minutes with nothing visible), and an account that needs sign-in still waits before it is skipped. Prevention: one spacing budget per worker run in `BackgroundScanCore` (extends the existing `cappedBusyWait` cap), the test trigger exempt, and the sign-in check before the wait.

**F313. Evaluate the No Rule recommender: hide the rules, recommend, compare (~90-150m) Priority 40**
- Phase: Core App Quality
- Platform: Windows DEV (developer tool, extends F267)
- Harold (2026-10-25, verbatim): *"we are trying to build a "best in class"/"World's finest" recommendation system for
  emails marked "no rule" so that the user has a very good idea (still they decide) if the no rule is likely to be a
  safe sender, delete rule and specifically what rule we are recommending they apply. To some extent we can test
  using the kimmeyharold.com emails by assuming no rules on any emails and use the recommendation system to recommend
  and then compare to known rules."*
- R-1: run every content-history email through the recommender as though no rule matched. Compare the suggestion with
  the rule that actually matched: right class (safe or delete), right type (email, domain, entire domain, subject,
  body), and the regex covers the same mail.
- R-2: prevent a self-graded score. Patterns mined (F308, F310) from the same emails they are tested on score too
  high, so train on older mail and test on newer mail (a time split), or hold out one rule at a time.
- R-3: report agreement per class and per type, and list each disagreement. Agreement with the current rules means
  the recommender REPRODUCES them, not that it is right. Harold's own decisions in the content history (69 rows on
  2026-10-25) are the stronger check, and they are reported apart.
- R-4: rerun after each recommender change; record the scores in the sprint plan.
- Depends on: F267, F306; the miners F308, F310.

**F340. Audit the `.claude/scripts/` memory scripts and the retired `memory-restore` skill (~20-40m, estimate unverified) Priority 40**
- Phase: Process / Tooling
- Platform: Development process.
- Files: `.claude/scripts/archive-memory.ps1` (47), `check-memory-on-startup.ps1` (34), `save-memory.ps1` (85);
  `.claude/skills/memory-restore/` (RETIRED in Sprint 51; `.claude/memory/current.md` is frozen at Sprint 39).
- Do: grep for callers (settings, hooks, skills, docs). Delete what nothing calls; convert any survivor under the
  F329 rules.
- AC: the list of deleted and kept files with the grep evidence.

**F347. Log the phase and network type of an IMAP connect timeout (~45m) Priority 40**
- Phase: Core App Quality
- Platform: All (shared IMAP adapter); seen on the Fold only.
- Evidence: 2 AOL 20-second connect timeouts on 10-30; the log has no DNS, TCP or TLS phase, so the cause is unknown
  (`imap_certificate_trust.dart:371`, F342 research group 5).
- Do: log which phase (DNS lookup, TCP connect, TLS handshake) timed out and the network type at the time.

**F273. Privacy policy and Data safety revision for the content history and learning (~60m) Priority 40**
- Phase: Core App Quality
- Platform: All (one policy; Play and Microsoft Store)
- Value: keeps the published policy true before any build stores more content or learns from it.
- Scope: the rewrites listed in Section 4.7 "Exactly what would change"; cite the Workspace policy; re-run
  `data_safety_declarations_test.dart`; Play Data safety stays "No" while nothing leaves the device.
- Control and screen: N/A (documents and the website).
- Depends on: Harold's Class-1 decision on R76-4 (and on F272 if it is selected); it is written before
  either ships.

**F240. Body-rule sub-type consistency Priority 40**
- Quick-add and the default rule-set split store body rules as `entire_domain`; manual and imported body rules use `keyword`. Same shape as the subject-rule label fix (DB v10). Decide per body pattern kind (URL/domain vs phrase), then align the creators and reclassify stored rows.

**F213. Migrate Android Gmail OAuth off Custom URI schemes to Google Identity Services (~180-300m) Priority 40**
- Phase: Android / Google Play Store Readiness
- Platform: Android only (Windows uses a loopback redirect and is unaffected)
- **Not urgent. Filed so it is not rediscovered under pressure**, which is exactly how F211
  arrived -- as a tester-blocking surprise.
- Google now disables Custom URI schemes BY DEFAULT on newly-created Android OAuth clients,
  because the scheme can be claimed by another app on the device (app impersonation). F211's
  fix re-enables the setting on the existing client, which works today and required no code
  change.
- **But Google describes this as the legacy path.** Verbatim from their developer blog: *"In
  the future, we may disallow Custom URI scheme methods."* The recommended replacement is the
  **Google Identity Services for Android SDK**, which delivers the OAuth 2.0 response directly
  to the app instead of via a registered URI scheme.
- **No cutoff date has been published.** That is the reason to file rather than schedule: there
  is nothing to race, but if Google does set a date, the migration becomes urgent on their
  timetable rather than ours, and it touches the sign-in path every tester uses first.
- **What it would touch**: `flutter_appauth` is built on the custom-scheme mechanism, so this
  is a dependency swap, not a settings change -- `AndroidManifest.xml`'s
  `${appAuthRedirectScheme}` intent filter, `build.gradle.kts:96`'s placeholder derivation, and
  `google_auth_service.dart`. A new Play submission would be required.
- **Do NOT start this speculatively.** Re-check Google's stated position before scheduling; the
  recommendation may change again, and the current setup is working.
- Depends on: nothing. Blocks nothing.
- Source: found 2026-09-11 while verifying Google's current wording for F211 R-2. Sources:
  developers.googleblog.com "Improving user safety in OAuth flows through new OAuth Custom URI
  scheme restrictions"; developers.google.com/identity/protocols/oauth2/native-app.

**F316. Make the fallback export folder visible (~45-90m) Priority 41**
- Phase: Core App Quality
- Platform: All (shared Dart, `export_directories.dart`; Settings > General)
- Defect: when the DEFAULT export folder (`Documents\MyEmailSpamFilter[_Dev]` on Windows,
  `/storage/emulated/0/Documents/MyEmailSpamFilter[_Dev]` on Android) fails its write probe, `ExportDirectories.resolve`
  switches to the app's own folder (Windows: the app-support folder, for DEV
  `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter\MyEmailSpamFilter_Dev`; Android:
  `/storage/emulated/0/Android/data/com.myemailspamfilter[.dev]/files/MyEmailSpamFilter[_Dev]`) and logs it to the
  console only, which a release build does not keep. The diagnostic log and per-scan exports then go somewhere the
  user does not look, with no message. A folder the user chose in Settings is never replaced.
- Causes: Windows Controlled Folder Access on Documents; Android 7-10 (no storage permission requested); Android 11+
  refusing a folder left by an earlier install. Sprint 81 Task 9 fixed the one observed cause (probe race).
- R-1: write a `DiagnosticLogger` line when the fallback is used, naming both folders.
- R-2: Settings > General, export folder line: when the fallback is in use, show "Writing to <fallback> (the default
  folder cannot be written)".
- AC: with the probe forced to fail (`debugWritableOverride = false`), the diagnostic line is written and the Settings
  line shows the fallback path. Mutation-verified. Paths above are from the code; confirm on disk at card time.

**F360. WinWright runner: restore the screen-reader flag, and find why F124 fails only through the runner (~60-120m) Priority 42**
- Phase: Process / Testing
- Platform: Windows Desktop
- The runner turns the Windows screen-reader flag on (`run-winwright-tests.ps1:507`) and never turns it off; restore
  the state it found when it ends (`enable-screen-reader-flag.ps1` has status, enable and disable).
- `test_f124_rule_labels` failed 6 of 6 through the runner at step 2 ("No main window found") and passed 29 of 29
  eight times run directly on the same build (Sprint 85 5.1.5). Ruled out: a background scan, a second window with
  the same title, the window state, the flag, the script. Remaining suspect: WinWright does not retry the main-window
  lookup. Investigate with WinWright's own log.
- Depends on: none.

**F348. Update the stale sprint62_surfaces integration tests (~45-60m) Priority 42**
- Phase: Core App Quality
- Platform: All (shared integration test); found on the iOS Simulator, stale on every platform by code reading.
- Evidence (`docs/research/F345_IOS_SIMULATOR_S84.md` section 2): two F175 cases (lines 121 and 150) expect the dialog
  "Background scan in progress" and the button "Wait and start"; the app shows "A scan is already running" with OK
  (`scan_progress_screen.dart` showScanAlreadyRunningDialog), and the check is per account since Sprint 74 while the
  test seeds the row under another account. The F175 negative case (line 182) passes for a weak reason. The F178/F176
  case fails at line 271 (`AccountEmailLabel` text not found); stale or iOS-only is unknown: run it on Windows first.
- Do: rewrite the F175 cases to the current dialog and per-account rule; make the negative case seed the same account;
  settle the F178/F176 cause; then put `sprint62_surfaces_test.dart` back in the iOS Simulator gate.

**F272. Per-user on-device spam classifier (pure Dart) ranking No Rule Review (~300m) Priority 42**
- Phase: Core App Quality
- Platform: All
- Value: learns each user's own spam from their own decisions and sorts likely spam to the top of review.
- Scope: hashed-token naive Bayes over From domain, subject and header tokens (body optional and off by default);
  trained incrementally on the device from the user's own actions; about 2 MiB of state; no new dependency
  (probe: about 161 microseconds per 1.2 kB text on the development laptop; Fold timing to measure first). The
  score ranks and suggests; it does not delete until it passes the F267 bar and Harold approves acting.
- Control and screen: Settings > General switch "Learn from my decisions" (off by default) and the No Rule Review
  sort order.
- Policy: inside the Workspace policy's "specific user's personalized model" carve-out; never trained on one
  user's data for another user.
- Privacy precondition: F273 published before a shipped build carries it. Parity: shared Dart.
- Depends on: R76-4 (labels), F267, F273. Decision class: Class-1 (new derived data store).
**HOLD (no viable runtime or contradicts the privacy posture):**

**F349. Windows Task Scheduler tests time out on the dev machine (~45-60m) Priority 44**
- Phase: Core App Quality
- Platform: Windows Desktop (the tests run real PowerShell; CI ubuntu does not run them).
- Evidence: Sprint 83 7.7.1 and Sprint 84 5.2 full suites (`--concurrency=4`): 3 tests time out at 30 s
  (`windows_task_scheduler_service_test` taskExists / getScheduleStatus for a missing task, and
  `powershell_script_generator_test` "the real New-ScheduledTaskTrigger gets a StartBoundary in the past"). They pass
  alone. Timed 2026-11-06 14:58: `Get-ScheduledTask` for a missing task takes 7.1 s in-process and 8 to 13 s with a
  PowerShell start; a bare PowerShell start takes 0.9 s. So the query is slow, not the process start. Last boot
  2026-10-30, so the Sprint 83 "re-time after a reboot" check has not run. Code and tests unchanged since b00669e4.
- Do: re-time after a reboot; if still slow, find why the query is slow (cause unknown), then either give these
  tests a timeout sized from the measurement with the reason in a comment, or replace the real query with the
  existing seam. Do not raise the timeout without the measurement.

**F262. Gmail renewal failures named by cause; stale log line Priority 45**
- Three refresh failures all read "Session expired. Please sign in again.": a build-configuration error (`ANDROID_GMAIL_CLIENT_ID is not set`, which signing in cannot fix), a revoked refresh token (`invalid_grant`), and a network drop (transient -- should not mark the account as needing sign-in). The diagnostic line "refresh token present, not used on Android" is false since Sprint 76. Prevention: classify in the existing `GmailSignInRequiredException` / `humanize` path rather than per call site.

**F343. F309 trusted-sender hint: decide after Sprint 83 Task 5 ships (~15m decision, estimate unverified) Priority 45**
- Phase: Core App Quality
- Platform: All.
- Harold deferred the F309 trusted-sender hint in Sprint 83 MV (Q5 = 6).
- Do: once Sprint 83 Task 5 is in use, ask Harold again whether the hint is still wanted, with the DEV count of
  rows where it would fire.
- AC: a recorded yes (then a sized card) or no (then close).

**F244. Tell the user when a Gmail background scan skips for sign-in Priority 45**
- F239 records a skip -- no notification, no export -- when Gmail needs the user, and relies on the per-account `gmail_sign_in_required` flag to show "Sign In Again" in the account list. That write is best effort: if it fails (a locked database), background scans of the account skip every cycle and nothing tells the user. Fix: a one-time notification for a needs-sign-in skip, independent of the flag, or a retry of the flag write.

**F254. Home-screen widget: last scan and new No Rule count Priority 45**
- A widget showing the last background scan time and the No Rule emails waiting. Two reasons: users see that unattended scanning runs without opening the app, and Android exempts apps with an active widget from the Restricted standby bucket (developer.android.com/topic/performance/appstandby: exemptions include "Apps with active widgets"), the bucket that limits jobs to once a day after 8 days without interaction. Android first (a declared ADR-0042 exception unless a Windows equivalent is wanted). Context: Sprint 76 unattended-scanning analysis, F252 (#457), F253 (#458).

**F247. Behavior tests for navigation and platform-gated paths (~120-180m) -- CLOSED (Harold, 2026-10-18, Sprint 80 scope selection: *"Close - will re-open if they re-occur"*). Not delivered; re-open if a review finds the same gaps again. Text kept for that case.** (PR #448 review carry-in, 2026-10-04; targeted for Sprint 76 but NOT delivered -- that sprint was redirected to unattended Android scanning)
- From the PR #448 Claude reviews (test analyzer items 5 and 7, code reviewer MINOR 5, plus test MINORs). Each needs a new navigation harness or a production test seam, so one planned card is more effective than piecemeal fixes at merge time.
  1. `scan_progress_screen.dart` `startRealScan` F238 branches as BEHAVIOR, not source gates: OK returns; `requested == false` proceeds; `!closed` shows "did not stop" and returns; plus the end-to-end success case (holder row present, stop chosen, row closed, manual scan claims). Harness: `s75_t7_scan_busy_snackbar_test.dart` already drives the real `startRealScan`.
  2. Gmail add flow as a widget test: push `AccountSetupScreen`, complete a stubbed `GmailOAuthScreen` with an address, assert the route on top -- and settle where Back lands (code review says the provider picker; Harold's MV round 4 saw the account list). Decide the WebView and manual-token fallback screens, which still open the folder step.
  3. Run the Windows token-path tests (`gmail_adapter_sign_in_flag_test.dart`, 5 cases) on CI: an injectable platform check in `GmailApiAdapter` (Class-2: a production seam -- surface at planning).
  4. Android `initialize` EXCEPTION path (review M-2: network -> ConnectionException, other -> AuthenticationException, never flagged) needs a seam in `GoogleAuthService`; no host test reaches it today.
  5. Sign In Again: the button disappears after success; the `_running` double-tap guard; `showLiveRefusal`'s `isViewingHistory` negative case.
  6. DONE in Sprint 85 (F329): `scripts/tests/test_mutation_test.py` covers the BASELINE and INVALID verdicts of `scripts/mutation-test.py`.

**F290. Tell the user when content-history rows could not be deleted (~30-45m) Priority 45**
- Phase: Core App Quality
- Platform: All (dev builds only -- the content history exists only there, ADR-0047)
- Origin: Sprint 78 7.7.1 silent-failure review M-4, UI half. The 7.7.1 fix removed the `catch (_)` blocks that hid
  real table-delete failures (2 files). Reporting a failed content-history delete to the user needs 4 code files
  (`data_deletion_service.dart`, `database_helper.dart`, `account_selection_screen.dart`, `settings_screen.dart`), over
  the 7.7.1 size limit, so it is carded rather than done without asking.
- Today: `deleteAccount` / `deleteAll` of the content history failing is logged only; the snackbar still reads
  "Deleted <email>" or "All app data deleted".
- Scope: `DeletionReport.contentHistoryDeleteFailed`; `deleteAllData` / `wipeAllData` return whether the history was
  removed; both snackbars name the leftover. Tests on both paths.

**F351. AppBar action icons overflow on narrow phones (~60-120m) Priority 46**
- Phase: Core App Quality
- Platform: All (shared `StandardAppBarActions` builder); seen in widget tests at phone widths.
- Evidence: Scan History in a widget test (`test/ui/screens/scan_history_narrow_test.dart` setup) overflows by 24 px in
  the AppBar's trailing slot at 360 logical px wide (and at 320); 384 (S24+) and 412 (Fold) pass. Scan History shows
  two screen icons (Clear, Reload) plus the shared Accounts, Settings, Help and exit icons. Predates Sprint 84 (the
  builder is unchanged this sprint). Not reported on a real phone; whether any shipped phone is under 384 wide is unknown.
- Do: measure the narrowest width each screen fits (one widget test per screen with `StandardAppBarActions`); then
  decide one shared rule (for example, move the lowest-priority icons into an overflow menu below a width), applied in
  the builder so every screen follows it. Decision for Harold: which icons may go into the menu.

**F353. Four empty states can overflow on a short screen (~30-45m plus a WinWright re-sweep) Priority 48**
- Phase: Core App Quality
- Platform: All (shared Flutter screens).
- Evidence: Sprint 84 5.1.2 class 1 (mirror sites). The Folder Selection error, the Manage Rules search with no match,
  the Manage Safe Senders search with no match and the Gmail sign-in error use the same `Center > Column` shape that
  36b724ac fixed elsewhere. Estimate: they need about 126 px, and about 74 px is left with the keyboard open. Not seen
  on a device.
- Added by the Sprint 84 7.7.1 code review (grep `Center(child: Column(` and `Center(child: Padding(... Column(` in
  `lib/ui`): `scan_history_screen.dart:541` `_buildEmptyState` (no `mainAxisSize.min`, inside the `Expanded` at :362;
  the Sprint 84 chip `Wrap` makes the header above it taller on a narrow screen), `email_detail_view.dart:876`,
  `scan_progress_screen.dart:546`, `rules_ready_gate.dart:50` and `:65`, `gmail_webview_oauth_screen.dart:187`.
  For each, either apply the fix or record why it cannot get short. The estimate above covers the first four only.
- Do: apply the 36b724ac scrollable layout to the four screens with a short-viewport widget test each; sprint with F351.

**F260. Stale log-lock takeover by atomic rename Priority 50**
- Two writers that break the same stale `<log>.lock` can race (one deletes the other's fresh lock, or one writes unlocked beside the other). Extend the existing lock-file mutex with an atomic takeover: rename the stale lock to a unique name -- only one rename can succeed on Android/Linux and Windows -- and only that winner deletes it and retries the create; losers simply retry. This makes the lock a true binary semaphore without a new mechanism. Also have `deleteAll` remove orphaned `.lock` files.

**F279. Listener gap 2 minutes vs 5 minutes (~30-45m) Priority 50**
- Phase: Core App Quality
- Platform: Android
- Needs a change to `MailNotificationPolicy.MIN_GAP_MS`; likely redundant with the worker's 5-minute `kMinScanSpacing`. A/B in results doc section R77-BAT-3.

**F356. Android first-run polish (~45-90m, estimate unverified) Priority 50**
- Phase: Core App Quality
- Platform: Android (seen on a clean emulator install, Sprint 84 F341 round 2/3); check Windows for the shared text.
- Observations from the Sprint 84 Android first run (`SPRINT_84_PLAN.md` F341 round 2/3):
  1. A demo scan is labeled "Live Scan".
  2. In Read-Only mode it is not clear what "Deleted (not processed)" means.
  3. The Help walkthrough is out of date.
  4. No message appears after the user refuses the notification permission.
  5. Some titles are cut off.
  6. The "Background" tab label breaks inside the word ("Backgrou / nd"). Also seen on the iPhone 17 Simulator
     (Sprint 85 F341 R-5, iOS run 42916648939, `iphone-4-settings.png`).
  7. (Sprint 85 F341 R-5, DEV builds only) Settings > General "Content history" says "in a file on this computer" on
     a phone (`content_history_row.dart:107`; seen on the iPhone 17 Simulator).
- Do: confirm each one on the current build, then fix it or close it with a reason.
- AC: each observation has a fix with a test, or a written reason it stays; a screenshot of each fixed screen.

**F242. Span-replacing edit scripts assert what the span contains Priority 50**
- A script that replaces the text between two anchors must assert the span's content (for example exactly one `testWidgets(`) and compare the test count before and after. Sprint 74: an end anchor matched one test too far and deleted a neighboring widget test; only an unused-import warning revealed it. Prevention: extend CLAUDE.md IMP-3 ("every mutation script asserts its anchor matched"); consider a span-replace mode in `scripts/mutation-test.ps1` or a shared edit helper.

**F358. "All reviewed" shows before any scan has run (~30-60m, estimate unverified) Priority 52**
- Phase: Core App Quality
- Platform: All (shared `no_rule_review_screen.dart`); confirmed on the Android emulator, Windows check pending (F341 R-4).
- Evidence: a fresh 0.25.0 release install, one Custom IMAP account added and never scanned, app restarted. The start
  screen read "No unaddressed items" / "All "No rule" emails have been reviewed." while Scan History showed no scan.
  The text is chosen only by `_allItems.isEmpty` (`no_rule_review_screen.dart:1031-1043`); nothing checks whether a
  scan ran.
- Do: when no scan has completed for the selected account(s), show a "No scan yet" state with a Scan action; keep
  "All reviewed" for the case where a scan ran and every No rule item was addressed.
- Signal fires on: an account with zero completed scans (count on DEV data before shipping, ADR-0047).
- AC: a widget test for each state (no scan; scan with zero No rule items; filters hiding items); screenshots on
  Windows and Android.

**F257. Scan History shows which mechanism started each background scan Priority 55**
- The worker already logs `trigger=doze-alarm|periodic|notification|test` (F252/F253); persist it on the scan row and show it in Scan History, so "why did this scan run" is answerable without the diagnostic log.

**F256. Rename `GmailWindowsOAuthHandler` to reflect both platforms Priority 60**
- Since Sprint 76 it serves Android too (`refreshAccessTokenMobile`, the mobile browser sign-in), so the name misleads. Rename the class and file; update callers, tests and docs.

**F241. Remove or wire `ScanResultStore.getActiveBackgroundScan` Priority 60**
- No production caller since the manual-scan dialog moved to the per-account `getActiveScanForAccount`; kept with its tests. Delete with its tests, or wire it. F238 shipped without it (Sprint 75).

**F95b. Gmail new-mail push through a server (not estimated until the ADR exists) Priority 60**
- Phase: Architecture
- Platform: iOS (Gmail accounts only)
- Scope: only if Harold wants "Scan when new mail arrives" on iPhone. Gmail `users.watch` to Cloud Pub/Sub, a relay
  that sends an APNs background push, renewal of the watch at least every 7 days. Background pushes are rate
  limited above three per hour. Requires an ADR superseding ADR-0030's "No backend server".
- Depends on: F67c; a Class 1 decision by Harold.

**F95. iOS variants + cross-store hardening (not re-estimated; iOS part moved to F95 (revised)) Priority 62**
- Phase: Build and Release Infrastructure
- Platform: iOS, plus polish across all 9 variants (3 stores x 3 channels: dev, production, store)
- Renumbered from the ambiguous "F52 Phase 3+" to a distinct F# (was sharing F52 with the Android phase, now F94). Moved to HOLD with the multi-variant track per Harold (2026-05-25) -- blocked until iOS development begins (requires macOS + Apple Developer account).
- All variants must run simultaneously without rebuild on same machine/device.
- [Detail](#f52-multi-variant-side-by-side-install)
- Source: ADR-0035 dev/prod separation.

**F261. Export header recognized by its first column, not the full text Priority 65**
- The daily `.data.csv` header row is skipped by exact match with the CURRENT header text, so after any column change an older day file's header would read as a data row; two scans creating the same new day file at once could write two headers. Prevention: recognize the header by its first column name in the one shared `scanSheetHeaderLine` helper.

**F67. Platform validation - iOS, Linux, macOS (~120-240m per platform) Priority 70**
- Phase: Multi-Platform Readiness
- Platform: iOS, Linux, macOS
- Shared tasks (all 3): validation build, smoke test, IMAP scan test, storage path verification, auth flow testing
- iOS-specific: Xcode config, signing, keychain access for credentials
- macOS-specific: entitlements, sandbox config, notarization requirements
- Linux-specific: desktop entry, packaging (snap/flatpak/AppImage), dependency verification (GTK, libsecret)
- HOLD rationale: No current business need. Activate when distribution is prioritized by Product Owner.
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gap G25)

## ON HOLD Details

**F265. Android Gmail native one-pick sign-in -- revisit only when a second device reproduces the failure Priority HOLD**
- Phase: Core App Quality
- Platform: Android
- F250 (#454, closed in Sprint 76): the native `authenticate()` fails with `[16] Account reauth failed` on the Fold, and the browser fallback then succeeds; since Sprint 76 Android renews through the stored refresh token, so users stay signed in. The cause is outside the changed code (OAuth clients, package and SHA-1 verified, `SPRINT_76_PLAN.md:783-795`). Harold chose to wait for a SECOND device that reproduces it before spending more time.
- Trigger to leave HOLD: a reproduction on another device (S24+ or a tester), with the diagnostic log's `gmail/renewal` and sign-in lines.

**F274. On-device GenAI rule explanations (~240m) Priority HOLD**
- Phase: Core App Quality
- Platform: All (would be two platform exceptions today)
- Why HOLD: Android ML Kit GenAI is foreground-only, Beta and absent from the Galaxy S24 family; Windows Phi
  Silica needs a Copilot+ NPU or a Developer Mode GPU path and is removed in January 2027; a bundled LLM costs a
  100+ MB download (size UNVERIFIED) under the Gemma pass-through terms.
- Revisit trigger: a GenAI API available to Store users on both platforms that runs in background work, or the
  Windows successor model (Aion Instruct) reaching retail with a non-Developer-Mode path.

**F275. Cloud GenAI classification (~360m) Priority HOLD**
- Phase: Core App Quality
- Platform: All
- Why HOLD: sends personal mail content to a third party; contradicts four sentences of the privacy policy; flips
  Play Data safety to "Emails collected and shared"; Gmail data transfer limits; no server for key management.
  About $0.0002-$0.0006 per email (Section 4.4).
- Revisit trigger: Harold decides the product posture changes (Class-1), with an explicit per-user opt-in design.

**F246. Android Gmail background renewal through a server-side token exchange (~30m scope-matched spike retry; the server path is a Class-1 decision, not estimated) Priority HOLD**
- Phase: Google Play Readiness
- Platform: Android
- From a WorkManager worker, `clientAuthorizationTokensForScopes(email, promptIfUnauthorized: false)` returned NULL for an already-granted Gmail account (emulator, google_sign_in 7.2.0 / android 7.2.7; ADR-0011 known limit). Android stores no refresh token, so a Gmail background scan more than about an hour after the app was last opened skips with "Gmail needs you to sign in again". Google's documented route: request a server auth code at sign-in and exchange it on a server for a refresh token. Needs a backend this app does not have (hosting, secret handling, privacy-policy update, ADR); a Class-1 architecture decision. Before committing to it, a 30-minute scope-matched retry of the spike would rule out a requested-vs-granted scope mismatch. The switched-off `GoogleAuthService.authorizeWithoutActivity` is the code to remove or reuse.

**F165. Cross-device rules-DB sharing -- user cloud storage (iCloud/OneDrive/Box/Google Drive) exploration + hosted-tier option (~half-day exploration) Priority HOLD**
- Phase: Product direction / architecture exploration
- Platform: All
- Direction (Harold, 2026-08-16): long-term, the recommended deployment is a PHONE (Android/iPhone) doing the periodic background scans instead of the Windows app -- which makes the rules DB per-device divergence a real problem. Explore letting the user share their rules DB between devices via THEIR OWN cloud storage (iCloud / OneDrive / Box / Google Drive), e.g. exported-snapshot sync or file-provider integration. Additionally evaluate a hosted-sync option as a paid tier (~$4/year, non-free app option) -- pricing/product decision stays with Harold.
- Exploration deliverables: sync-model options (file-based snapshot vs true sync; conflict handling for rule edits on two devices), per-provider integration effort, security posture (rules contain sender addresses -- privacy note), and a recommendation. Builds on the existing YAML export invariants as the likely interchange format.
- Source: Harold, Sprint 60 Manual Validation, 2026-08-16.

**F173. Periodic "Test Coverage and Appropriate Testing" Deep Dive (~4-8h per review) Priority HOLD**
- Phase: Testing / periodic review
- Platform: All -- backend, frontend/UI, data layer, Windows app, Android app
- Scope (Harold, 2026-08-17): a recurring deep dive answering TWO distinct questions, not one: (1) **coverage** -- what is tested and what is not, across backend, frontend/UI, data layer, and both apps; (2) **appropriateness** -- *does each test clearly test what it intends to test, AND does each SET of tests do what the set intends to do?* The second question is the one ordinary coverage metrics cannot answer.
- Why this matters here specifically: Sprint 60 produced three concrete instances of tests that passed while proving nothing -- a popup-fit test that stayed green against the broken code until it was tightened, a chip-tooltip test that passed off unrelated AppBar tooltips after the widget it guarded was deleted, and a long-press test that would have passed with the gesture wiring removed. All three were caught only because mutation-verification was run by hand. A periodic sweep institutionalizes that check.
- Method: mutation-verify a sample of existing gates (break what each guards, confirm red); look for assertions that prove EXISTENCE where the claim is about behavior, ordering, or sizing; check that test names still describe what the test does; check per-layer coverage gaps; report findings as backlog items.
- Cadence: same periodic-HOLD model as F70 (Security) and F71 (Architecture) -- triggered by Harold, not calendar-automatic.
- Source: Harold, 2026-08-17.

**F183. Upstream civyk-winwright request: script-runner replay support for ww_wait (~15m to file, then external) Priority HOLD**
- Phase: Testing / E2E tooling (external)
- Platform: Windows Desktop (WinWright harness)
- Scope: the WinWright script runner does not replay `ww_wait` steps -- re-confirmed live 2026-08-23 (the runner SKIPS the step: "Replay of 'ww_wait' is not supported by the script runner"). This forces the settle-buffer workaround in the sweep scripts (harmless resolving clicks to outlast Flutter popup animations) and is the root reason the f37/f56 dialog-settle scripts stay EXCLUDED from the default sweep. File the feature request with civyk-winwright (ww_wait mode=element_state would suffice); when it lands, remove the settle buffers and re-evaluate readmitting the excluded scripts.
- HOLD rationale: external project owns the fix; our action is filing + tracking.
- Source: Sprint 62 sweep repair + retrospective IMP-7, 2026-08-23.

**F179. Subject-blocking phrase picker -- user selects (or GenAI recommends) the blocking SUBSET of a subject (~3-5h) Priority HOLD**
- Phase: Core App Quality / rules UX
- Platform: All (shared review popup)
- Scope (Harold, 2026-08-22, verbatim intent): "The scan results of a single email needs to have a 'from' dialog as it is not normal to mark an entire subject as a blocking phrase, but often a subset phrase and will need to have the user pick the subset -- likely this will wait until after the genai integration as an app 'recommended' subject phrase or matching string would be far better than have the user guess."
- Today's Block Subject action uses the whole (20-char-previewed) subject; a subset-phrase picker dialog is the right shape, and an H1-style GenAI-recommended phrase beats manual guessing.
- HOLD rationale: deliberately sequenced AFTER the GenAI integration (H1) so the recommendation flow ships with it rather than building a manual picker twice.
- Source: Harold, Sprint 62 Manual Validation, 2026-08-22.

**F152. Periodic User-Centric First-Run Evaluation (~2-3h per review, plus fix-item time if findings warrant) Priority HOLD**
- Phase: UX Spike (reusable template)
- Platform: Windows Desktop (this run); extend per-platform when other platforms are release-ready
- **Generic scope**: re-run Harold's user-centric MVP test script + "First-Run Evaluation Summary Page" checklist (7 sections: Installation & Launch, First-Run Orientation, Completing the Primary Task, Feedback & Confirmation, Emotional Experience, Environment Compatibility, Quick User Feedback Capture) against the CURRENT app build, via a genuine live walkthrough (not just static code analysis) -- build the target platform's release-equivalent binary, reach a truly empty first-run state, and walk the checklist with a real user (Harold) driving and Claude observing/recording via the platform's UI-automation tooling (WinWright on Windows) where available.
- **Method** (validated this run): (1) static/code-analysis pass first via an Explore agent to establish a baseline hypothesis cheaply; (2) confirm/refute live via an actual build+launch with a genuinely empty account/data state (see F151's Investigation Note for this repo's specific data-persistence gotchas); (3) Harold drives interactively while Claude screenshots/narrates each step against the checklist's 7 sections; (4) consolidate into backlog candidate items; (5) always fully back up and restore any real account/rule/scan data touched to reach the empty state -- verify byte-for-byte before declaring restoration complete.
- **Deliverable**: a gap analysis against the 7-section checklist + concrete backlog candidate item(s) for anything found, sized and scoped like F151.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable each time a first-run/onboarding review is warranted -- e.g. after a significant first-run-path UI change, before a major release, or periodically (suggested cadence: every 10-15 sprints, or whenever F75's walkthrough/onboarding gap is finally addressed and needs re-validation).
- Source: Harold, 2026-08-15 -- "at the end this first-use analysis will be added as a permanent backlog ON HOLD item that we can re-use."

_(Sprint 61 shipped and pruned at the 2026-08-21 Phase 8.2 pass-1 sweep: F161, F162, F167, F168 (its R-3 settings-interplay question is now DECIDED -- Harold, 2026-08-22: the fully-independent Manual/Background tabs are "correct and the desired behavior"; a deliberate Product Owner design decision, do NOT re-raise), F169, F170, F171, F172 -- history in `docs/sprints/SPRINT_61_PLAN.md` / `SPRINT_61_SUMMARY.md` and CHANGELOG.md. F143, F144, F156, F157, F158, F159, F160, and F166 shipped Sprint 60 (stubs also cleared this sweep) -- see `SPRINT_60_PLAN.md` / `SPRINT_60_SUMMARY.md`.)_

_(F149 shipped Sprint 57 -- see `docs/sprints/SPRINT_57_PLAN.md` and CHANGELOG.md 2026-08-14. Root-caused as an always-existing gap in F91's (Sprint 39) design, not a regression: F91 only reconciled the SOURCE folder after a safe-sender move; F149 added a symmetric pre-move check against the TARGET folder using the existing `searchByMessageId` capability. F148 shipped Sprint 56 -- see `docs/sprints/SPRINT_56_PLAN.md` and CHANGELOG.md 2026-08-13. F145/F146/F147 all shipped Sprint 55 -- see `docs/sprints/SPRINT_55_PLAN.md`, CHANGELOG.md 2026-08-10, and `docs/WINWRIGHT_SELECTORS.md`'s new F145 entry (WinWright false-failure finding + the real HelpScreen scroll-timing bug it led to). F145 also produced `integration_test/help_deep_link_test.dart`, the durable regression suite for all 22 HelpSection values.)_

**F189. Periodic Skills Audit -- what tooling would make sprints, development, recovery and prevention measurably better (~4-8h per review, research-led) Priority HOLD**
- Phase: Process / tooling (repo instruction surface)
- Platform: N/A (repository tooling, harness configuration, agent definitions)
- **Scope (Harold, 2026-09-07, verbatim intent)**: analyze the codebase, recent conversation history, memories, hooks, docs, agents and `CLAUDE.md`, looking for SKILLS that would help us: (1) run sprints more effectively and efficiently; (2) develop features that are aligned with the defined architecture and tested effectively; (3) recover from mistakes; and (4) prevent the same AND SIMILAR mistakes from happening again. **Research latitude granted**: it is explicitly OK to research what this item is trying to achieve and to propose improvements to the item itself.
- **Why now**: the project already has 10 skills, 5 hooks and ~60 memory entries, all added reactively -- each one traceable to a specific escape. Nobody has ever asked the inverse question: given everything we now know went wrong, what is the RIGHT set? Sprint 65 alone produced two commit races, a false Play declaration in committed history, a gate that asserted a document's own claim of diligence, a gate defeated by a substring, and a fixed-duration wait on the wrong side of its margin. Those are five instances in one sprint, and every one was caught by adversarial probing rather than by a skill.
- **The (4) clause is the hard part and the most valuable.** "The same mistake" is what hooks already do well -- a specific string, a specific command, a specific file. "**Similar** mistakes" is a generalisation problem: the substring-shadow defect and the "verified by grep" defect are the SAME defect (a check that cannot fail) wearing different clothes, and no existing hook would have caught the second from having seen the first. The audit should ask what mechanism generalises, not just what rule to add next.
- **Method**: (a) inventory what exists -- skills, hooks, memories, agent definitions, CLAUDE.md rules -- and classify each by which of the four goals it serves; (b) mine the retrospectives and Process Issues categories for the actual failure taxonomy, since that is the ground truth of what goes wrong here; (c) identify the gaps, especially failure classes that recur under different surface forms; (d) propose specific skills with the cost of each, and be willing to conclude that some existing tooling should be REMOVED or merged -- more instruction surface is not automatically better, and F130 exists precisely because contradictory instructions cause their own defects.
- **Deliverable**: a written audit with concrete proposals presented for approval, in the same shape as retrospective improvement proposals (title, source, type, effort, recommendation), NOT auto-applied.
- **Guard against the obvious failure mode**: this item could easily produce a long list of plausible-sounding skills nobody uses. Each proposal must name the specific past escape it would have caught, or state honestly that it is preventive with no precedent.
- **Each proposal is evaluated like an ADR, not pitched** (Harold, 2026-09-07). Per proposed skill, state: **what it does**; **pros**; **cons**; **why we would do it** (the specific escape it would have caught, or an honest "preventive, no precedent"); and **what else it needs to work**. That last field matters -- a skill is often inert on its own, and may require a companion hook, a memory entry, a doc change, or an agent definition. Those companions are PART OF THE PROPOSAL and must be costed with it, not discovered later.
- **Not all proposals will be accepted, and that is the intended outcome.** The deliverable is a slate to evaluate, not a plan to execute. Rejecting a well-argued proposal is a valid result; the evaluation is the value.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable. Duplicate when the instruction surface has accumulated enough change to warrant re-asking the question -- suggested triggers: after a sprint that produced several process escapes, after a run of retrospectives whose Process Issues category repeats a theme, or when new tooling capabilities become available.
- Depends on: nothing. Reads the repository and its history; changes nothing without approval.
- Source: Harold, 2026-09-07. Made a periodic template at his direction, alongside F70 (Security), F71 (Architecture), F130 (Process-Docs), F152 (First-Run) and F173 (Test Coverage).

**GP-4. Gmail API OAuth Verification / CASA -- THE SUBMISSION ITSELF (~40-80h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android
- Trigger: 2,500+ users or $5K/yr revenue. **Do NOT set the OAuth consent screen to "In production" before verification completes** -- publishing while unverified caps the project at 100 new users FOR ITS LIFETIME, and that cap cannot be raised or reset.
- **Sprint 66 delivered the PREPARATION, not the submission**: scopes narrowed to `gmail.modify` + `userinfo.email` (removing `gmail.send`, never called, and the redundant `gmail.readonly`); the data-residency determination recorded with every outbound connection enumerated; and two gates -- Windows/Android scope parity, and a build failure if any analytics/crash/ad SDK ever enters `pubspec.yaml`. A Phase 5.1.1 review independently confirmed no live call path needs a removed scope.
- What remains on this card: the verification submission to Google, and the CASA security assessment IF it applies. Current determination is that it does NOT -- CASA is required only where restricted-scope data is stored or transmitted on servers, and this app is client-only with no backend. Re-verify that determination at submission time rather than trusting this line.

**F199-b. Partner Center publisher display name -- the last surface of the LLC rename (~15m once reopened) Priority HOLD**
- Phase: Release Readiness
- Platform: Windows Desktop
- Origin: Sprint 68 remnant; EXTERNALLY BLOCKED (Microsoft Store account surface).
- **HOLD (Harold, 2026-10-10, Sprint 78 planning)**: *"update the repo Windows store section to match what the
  Microsoft Partner Center says for now. Then close and state that no real business is being done by either entity and
  will resolve later."* Done in Sprint 78 Task 8: `LEGAL_ENTITY.md`, `STORE_LISTING_ASSETS.md` and the `pubspec.yaml`
  comment now record `Kimmey Consulting - Ohio` as the Partner Center name, which `pubspec.yaml:140` mirrors.
- **Trigger to reopen**: Harold reopens it (business activity starts under either name, or Microsoft raises the
  publisher name). Then: support ticket, console first, repo second.
- Depends on: Harold's Microsoft support ticket (only once reopened).
- Sprint 68 delivered every other surface: the repo (10 replacements, 7 files), the Play
  developer name, and the Partner Center listing fields (Copyright / Developed by), the latter
  folded into Submission 25 rather than paying a separate listing-only certification pass.
- **What remains**: Partner Center still shows `Kimmey Consulting - Ohio` as the publisher
  display name. **Microsoft's own documentation contradicts itself** on whether an Individual
  account can change it -- the Windows Store FAQ says publisher display name "cannot be changed
  after registration", while the Partner Center account doc says you can "select the Update
  link to change your contact info, such as publisher display name", and the console DOES show
  that link. Unresolvable from documentation.
- **Next action is Harold's, not code**: a support ticket at
  https://aka.ms/windowsdevelopersupport asking (a) can this Individual account's publisher
  display name be changed, and (b) can a published app be transferred to a new Company account.
- **Do NOT touch** `msix_config.publisher` (`CN=84EA8722-...`) -- that is the Partner-Center
  assigned GUID, not a name; changing it breaks package identity and every installed copy's
  upgrade path.
- Account type is CLOSED: both stores stay Personal/Individual (`docs/LEGAL_ENTITY.md`).
- Depends on: a Microsoft support answer. Nothing in the repo blocks it.

**F285. Re-ask: keep or delete `email_detail_view.dart` (~5m) Priority HOLD**
- Phase: Core App (code hygiene)
- Platform: Windows Desktop + Android (shared Dart)
- Origin: Sprint 78 planning decision F5. `lib/ui/screens/email_detail_view.dart` (1,005 lines) has no caller in `lib/`.
  Harold, 2026-10-10: *"keep it for 5 sprints then ask again"*.
- **Trigger**: Sprint 83 planning -- ask Harold again as a numbered question (1. Delete 2. Keep).
- Depends on: None.

**F289. WinWright default sweep with no mouse steps (~30-60m) Priority HOLD**
- Phase: Testing
- Platform: Windows Desktop (test tooling only)
- Origin: Sprint 78 F284 AC-1 finding, accepted by Harold at Manual Validation 2026-10-13. Six steps in the default
  sweep still use the mouse, so the PC must stay unlocked while it runs: `test_f124_rule_labels.json` has four
  `ww_click` label probes (static Text nodes have no InvokePattern, and the script runner skips `ww_get_value`), and
  `test_s75_new_controls.json` has two `ww_hover` steps. `test/policy/winwright_script_strings_test.dart` pins them
  exactly (`knownPending`).
- Trigger: a WinWright release whose script runner replays a cursor-free read step (for example `ww_get_value` or
  `ww_assert`). Check the WinWright changelog at each sprint's 5.1.5 sweep.
- Scope: replace the six steps, empty `knownPending`, and let the runner's locked-PC gate pass on a locked PC.
- Depends on: an upstream WinWright change.

**F111. Periodic Windows App Store upload readiness verification (~110-175m per review) Priority HOLD**
- Phase: Release Readiness (reusable template)
- Platform: Windows Desktop
- **Generic scope**: verify develop/main parity, version compatibility vs the currently-published Store version, MSIX build-path integrity (`msix_config.windows_build_args` OAuth-credential injection -- note the key is `windows_build_args`; the transposed `build_windows_args` is the F119 defect), and Store-submission preconditions (`docs/STORE_RELEASE_PROCESS.md` checklist) BEFORE any Store build/upload. Produces a GO/NO-GO readiness finding; does not build or upload.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable each time a new Windows Store release is planned. First run: Sprint 45 (see `docs/sprints/SPRINT_45_F111_STORE_READINESS.md`).
- Source: Sprint 45 backlog refinement (2026-07-02) -- captured as a recurring template since Store readiness verification will be needed for every future release.

**F139. Local-install smoke test for a release-candidate MSIX (~30-50m per review) Priority HOLD**
- Phase: Release Readiness (reusable template)
- Platform: Windows Desktop
- **Generic scope**: build a release-candidate MSIX and run a full manual smoke pass (Gmail sign-in, About screen version, title bar, data directory) on the SAME machine that has the live Store build installed -- WITHOUT merging to `develop`/`main`, without uploading to Partner Center, and without disturbing the installed Store build. Produces a PASS/FAIL smoke-test finding on a release candidate; does not release anything.
- **What this covers (do this)**:
  1. Build from a **local, unpushed** checkout: merge the sprint feature branch into the prod worktree's local `main` (`git merge --no-edit origin/feature/...`) so `pubspec.yaml`'s `msix_version` bump and any other release-affecting changes are present, WITHOUT pushing or asking Harold to merge to `develop`/`main` first. Record the pre-merge HEAD SHA so the worktree can be restored (`git reset --hard <sha>`) after the smoke test.
  2. **The Store-submission MSIX config (`store: true, install_certificate: false`) produces an UNSIGNED package that cannot be locally installed** -- `Add-AppxPackage` fails with `0x800B0100 / HRESULT 0x80073CF0: The app package must be digitally signed for signature validation`. This is expected and is NOT a defect (Partner Center signs the real submission; a local smoke test never goes through Partner Center).
  3. **To make it locally installable**, temporarily flip the two flags already documented in `pubspec.yaml`'s own comment (`mobile-app/pubspec.yaml`, `msix_config` block, ~line 119-122): `store: false` and `install_certificate: true`, then rebuild with `flutter pub run msix:create`. This self-signs the package with a locally generated test certificate.
  4. A self-signed local build installs as a **separate package** alongside the live Store build (different signing identity -> different package family), so `Add-AppxPackage` does NOT need `-ForceApplicationShutdown` to replace anything and the live Store install is untouched. Both versions coexist and are separately launchable (`Get-AppxPackage -Name "*MyEmailSpamFilter*"` lists both; `Get-StartApps` shows two Start-menu entries with different AppIDs).
  5. Verify the installed release candidate the same way as any Store build: `<InstallLocation>\MyEmailSpamFilter.exe --print-env` (launch via `Start-Process ... -RedirectStandardOutput` to reliably capture output; a bare `&` invocation from a script can silently produce nothing) should show `APP_ENV=prod`, empty `displaySuffix`/`dataDirSuffix`, `windowTitle=MyEmailSpamFilter`, `NATIVE_APP_ENV=prod`. Launch the actual window via its AppX identity (`Start-Process "shell:AppsFolder\<AppID>"`, from `Get-StartApps`) for the visual title-bar/About-screen check, not the raw exe path directly (packaged apps are normally activated through their app identity). **Gap CLOSED by F153's Sprint 59 re-test (2026-08-15)**: with the `SPI_SETSCREENREADER` flag enabled and the semantics tree primed (one `ww_get_snapshot` after attach), WinWright reads the Settings > General version text directly (`ww_dump_tree` selector `name*="Version 0.8"` returned `Version 0.8.0 [DEV]`, on-screen -- the version now sits at the TOP of the tab and the whole tab fits the default window). The visual version confirmation CAN now be automated; the `--print-env` probe and title-bar check remain independently reliable. Pre-flight: check flag status + prime the tree per `docs/WINWRIGHT_SELECTORS.md` Prerequisites.
  6. Extract and grep `AppxManifest.xml` for `Version=` to confirm the manifest matches the target version, and check file size (~16-17 MB expected) -- same checks as a real release, see `docs/STORE_RELEASE_PROCESS.md` Step 4.
  7. After the smoke test: revert `pubspec.yaml`'s `store`/`install_certificate` flags back to `true`/`false` (do NOT commit the local-testing flip), and reset the prod worktree back to the recorded pre-merge SHA (`git reset --hard <sha>`) so it is clean and ready for the REAL release build later.
- **What this does NOT require (avoid re-deriving these)**:
  - Does NOT require merging the sprint branch to `develop` or `main` first -- a local, unpushed merge into the prod worktree is sufficient to get the version bump for a smoke-test build.
  - Does NOT require uploading anything to Partner Center.
  - Does NOT require a code-signing certificate purchase or Windows SDK signtool workflow -- the `install_certificate: true` msix-package option self-signs automatically.
  - Does NOT require uninstalling or disturbing the live Store build first -- self-signed and Store-signed packages install side-by-side under different package identities.
  - Does NOT require Developer Mode / sideload registry changes on a machine that already has them (check `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` -> `AllowAllTrustedApps`/`AllowDevelopmentWithoutDevLicense` -- Harold's dev machine already had both set to 1; the earlier signature-validation error was NOT a sideload/trust problem, it was purely the unsigned-package error above).
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable each time a release-candidate smoke test is needed before committing to a full Store release. Complements F111 (pre-build readiness check) and `docs/STORE_RELEASE_PROCESS.md` Step 4 (post-upload verification) by covering the middle step: proving an unreleased build installs and runs correctly on real hardware.
- Source: Sprint 53 (2026-08-03) -- F-STORE-53 scope was corrected mid-sprint from "full release pipeline" to "smoke test only" after Harold flagged the scope creep; the local-install signing workaround was discovered live during that task and is captured here so it does not need to be re-derived on the next release.

**F70. Periodic Security Deep Dive (~4-8h per review) Priority HOLD**
- Phase: Security Spike (reusable template)
- Platform: All
- **Generic scope**: Security review based on Application Development Best Practices and OWASP Mobile Top 10 (use current year edition)
- **Application-specific scope**:
  - Dependency CVEs (flutter pub outdated, known vulnerability databases)
  - SQL injection and parameterization audit
  - Regex injection and ReDoS pattern review
  - Credential storage and logging audit
  - Platform-specific security: Windows 11 Store (MSIX sandbox, AppContainer), Android (APK/AAB signing, manifest permissions, ProGuard), iOS (App Transport Security, keychain, sandbox), Linux (file permissions, desktop integration)
  - App store compliance: Microsoft Store certification requirements, Google Play data safety policies, Apple App Store review guidelines
  - Device-specific concerns: biometric auth, secure enclave, clipboard access, screenshot protection
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for next review.
- HOLD rationale: Template item. Duplicate when periodic security review is needed.
- Source: Sprint 31 retrospective feedback

**F130. Periodic Process-Docs Consistency Deep Dive ([no-history] -- unbounded discovery; see estimating note) Priority HOLD**
- Phase: Process Spike (reusable template)
- Platform: N/A (repo documentation + harness configuration)
- **Generic scope**: audit the sprint-execution instruction surface for logical consistency, so that any Claude model tier (Haiku / Sonnet / Opus / Fable) executing the sprint process reaches the SAME correct behavior from whichever document it happens to read. The architecture deep dive (F71) does this for the CODE; nothing does it for the PROCESS DOCS, which are equally load-bearing -- they are the actual control system for development on this project.
- **Surfaces in scope** (the full instruction surface, not just `docs/`):
  - The 11 SPRINT EXECUTION docs (`SPRINT_EXECUTION_WORKFLOW.md`, `SPRINT_CHECKLIST.md`, `SPRINT_PLANNING.md`, `SPRINT_RETROSPECTIVE.md`, `SPRINT_STOPPING_CRITERIA.md`, `BACKLOG_REFINEMENT.md`, `TESTING_STRATEGY.md`, `QUALITY_STANDARDS.md`, `ALL_SPRINTS_MASTER_PLAN.md`, `STORE_RELEASE_PROCESS.md`, `CODING_VELOCITY.md`)
  - `CLAUDE.md` and `AGENTS.md` (read by every model tier; must not diverge from each other). Since 2026-10-23 (Harold) `AGENTS.md` does not copy the sprint process; it points to the sprint execution docs, so check only that its pointers resolve.
  - `.claude/hooks/*` (enforcement must match what the docs say, and must not false-positive)
  - `.claude/skills/*/SKILL.md` (skills encode deterministic processes; must match their source doc)
  - `.claude/agents/*` if present, `.claude/settings.json` hook registrations, `.claude/sprint_status.json` schema
  - Auto-memory `MEMORY.md` + `feedback_*.md` (**recall re-teaches whatever it says** -- a stale memory silently overrides corrected docs)
- **Defect classes to hunt** (each seeded by a real escape):
  1. **Same instruction, contradictory recipes** -- e.g. Phase 6.6 branch creation was stated 5 different ways across 2 docs + 2 memory entries; the cheat sheet said "off updated develop" while the detailed section said "from the current feature branch", and the detailed section's own "Why" paragraph contradicted its own "Steps" block two lines later (found 2026-07-27, Sprint 51).
  2. **Summary-vs-detail drift** -- cheat-sheet / table-of-contents / quick-reference rows that paraphrase a detailed section and fall out of sync when the section is corrected. Check EVERY summary row against its section.
  3. **Superseded recipes left in place without a supersession marker** -- old instructions retained "for context" that read as current. Require an explicit `SUPERSEDED by X (date)` marker or delete.
  4. **Memory-vs-doc divergence** -- a `feedback_*.md` `description:` field or `MEMORY.md` index line still teaching a corrected-away behavior. These surface during recall and outrank docs in practice.
  5. **Orphan instructions** -- a step referenced in one doc but defined nowhere (or a file like `.claude/sprint_status.json` mentioned in exactly ONE line with no definition of what to put in it -- how it drifted 15 sprints unnoticed).
  6. **Hook-vs-doc mismatch** -- enforcement that blocks something the docs permit, permits something the docs forbid, or false-positives (e.g. the stash-guard hook blocking a Bash command whose text merely *documents* the stash prohibition, 2026-07-27).
  7. **Unenforced MANDATORY steps** -- steps marked MANDATORY with no gate, hook, test, or checklist line that would catch omission. Rank by blast radius; propose the cheapest enforcement.
  8. **Tier-inconsistent guidance** -- instructions that only work if the reader is a top-tier model (implicit judgment calls, unstated context). Haiku executing the same step must reach the same outcome.
  9. **Dead references** -- links/paths/section anchors/issue numbers/skill names that no longer resolve.
- **Method**: build an inventory of every instruction that appears in more than one place, diff the statements pairwise, and produce a findings table (`Instruction | Sites | Statements | Authoritative version | Action`). Prefer ONE authoritative statement plus pointers over duplicated prose -- duplication is what drifts.
- **Deliverable**: findings table + corrections applied in-sprint + any new enforcement proposed; log the count of contradictions found so the trend is visible across reviews.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable. Duplicate when the process docs have accumulated enough change to warrant a consistency pass -- suggested triggers: after any sprint that applies 4+ process improvements, after any repeat-offense correction (the same mistake corrected 3+ times suggests contradictory guidance rather than model error), or every ~5 sprints.
- Source: Harold 2026-07-27, after the Sprint 50/51 close-out escapes traced to instruction-surface defects rather than one-off model error: a multi-part request treated as a theme, a checklist reported complete without being opened, and the Phase 6.6 branch recipe stated inconsistently in 5 places (2 of them in memory, which re-teaches on recall).

**F71. Periodic Architecture Deep Dive (~4-8h per review) Priority HOLD**
- Phase: Architecture Spike (reusable template)
- Platform: All
- **Generic scope**: Architecture review based on Application Development Best Practices
- **Application-specific scope**:
  - ADR drift detection: compare all ADRs against current codebase implementation
  - ARCHITECTURE.md alignment: verify documented components, services, and patterns match code
  - ARSD.md alignment: verify architectural requirements and standards document is current
  - Platform-specific architecture: Windows 11 Store (MSIX packaging, single-instance mutex, app data paths), Android (activity lifecycle, WorkManager, flavors), iOS (SwiftUI/UIKit bridge, entitlements, provisioning), Linux (GTK integration, libsecret, packaging)
  - App store constraints: store-specific sandboxing, capability declarations, update mechanisms
  - Device constraints: screen size breakpoints, input methods (touch, mouse, keyboard), offline capability
  - Dead code and deprecated class detection
  - Test coverage gaps relative to architecture
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for next review.
- HOLD rationale: Template item. Duplicate when periodic architecture review is needed.
- Source: Sprint 31 retrospective feedback (based on Sprint 30 architecture deep dive experience)

_(Sprint 51-52 detail sections pruned per Maintenance Rule 2 -- all shipped/resolved/retired, history lives in the sprint docs and CHANGELOG: F130-S51 process-docs consistency deep dive + stash-guard hook fix (Sprint 51); F129 WinWright coverage + F128-residual RuleSetProvider audit (Sprint 51); F131 WinWright create-path -- resolved as no app defect, root cause was an inherited bad selector (Sprint 52); F132 retired, superseded by F133; F133/F133-S52 accessibility audit template + first run -- see `docs/ACCESSIBILITY_STANDARDS.md` and `SPRINT_52_F133_FINDINGS.md`; F134 AppBar icon order + F135 session-scoped accounts + F136 Skip button, all shipped Sprint 52 -- see `SPRINT_52_RETROSPECTIVE.md`; ENV-1 dev-machine AppXSvc/Acronis conflict, resolved 2026-07-30 via an Acronis exclusion, machine-local and never an app defect.)_

**F201. Periodic Web Property Accuracy Re-Review -- myemailspamfilter.com + GitHub Pages (~1-2h per review, plus fix time if findings warrant) Priority HOLD**
- Phase: Web Property (reusable template)
- Platform: All (the site represents every shipped platform)
- **Generic scope**: re-review everything served at `https://myemailspamfilter.com/` and from
  GitHub Pages (`main:/docs`) for ACCURACY against the current app, the current legal
  documents, and the current store presence -- then make the updates the review finds.
- **Method**: (1) enumerate what is actually served LIVE, following every internal link, rather
  than reasoning from the repo -- the two have already diverged once; (2) diff every factual and
  privacy claim against `docs/legal/PRIVACY_POLICY.md`, `TERMS.md` and the shipped behavior;
  (3) verify publisher identity, contact details and store links against reality -- names and
  account facts change (F199); (4) confirm exactly one canonical privacy policy and one
  deletion page remain reachable; (5) check that any gate covering the served site still
  actually covers it.
- **Why this is periodic and not one-shot**: the site is hand-written HTML with no build step,
  so it does not track the app. It drifted ~6 months carrying a privacy claim the app had
  already stopped honoring, while the Markdown legal documents beside it stayed correct
  automatically. Anything without a build step or a gate needs a human on a schedule.
- **Suggested triggers**: after any change to `PRIVACY_POLICY.md` or `TERMS.md`; after a
  publisher/account identity change; after a new store or platform ships; after a feature
  changes what the app stores or transmits; otherwise periodically (suggested: every 10-15
  sprints).
- **ALSO RE-REVIEW THE IN-APP PROVIDER SETUP STEPS** (added Sprint 68 IMP-3):
  `platform_selection_screen.dart`'s `_build{Aol,Yahoo,ICloud}Steps` name vendor URLs and UI
  labels, and they went stale exactly the way the website did -- four of six iCloud steps were
  wrong, pointing at a page Apple had renamed. `test/policy/provider_setup_steps_test.dart`
  now gates app-vs-doc AGREEMENT, but **no gate can watch someone else's website**: only a
  human re-checking the vendor pages catches a rename. That is this item's job.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep
  this template for the next review.
- HOLD rationale: Template item, reusable. Dormant until a trigger above fires.
- Depends on: F200 (which establishes the canonical state this re-review checks against).
- Source: Harold, 2026-09-09 -- the periodic companion is the F200 final acceptance criterion,
  alongside F70 (Security), F71 (Architecture), F130 (Process-Docs), F152 (First-Run), F173
  (Test Coverage) and F189 (Skills).

**F63. Responsive design framework -- [SUPERSEDED 2026-08-03 by Sprint 54 F141's per-screen findings] Priority HOLD**
- Phase: UX Improvement
- Platform: All
- Original scope: adaptive breakpoints per ARSD AR-7 (phone/tablet/desktop), priority screens scan progress/results display/settings.
- **Superseded**: the Sprint 54 F141 deep dive (`docs/sprints/SPRINT_54_F141_ANDROID_DEEP_DIVE.md` Section 2) audited all 23 screens directly -- only 2 use `MediaQuery` at all (both incidental, not breakpoint logic), zero `LayoutBuilder`/`OrientationBuilder` anywhere. Concrete per-screen findings now exist: 16 screens work-as-is, 5 need touch-target/density adaptation (`results_display`, `rules_management`, `safe_senders_management`, `account_setup`, `settings`), 2 need a genuine new interaction pattern (`yaml_import_export` -- data-layer, not layout; `no_rule_review` -- see F143). Use that document's Section 2 as the authoritative scope instead of this item's original vague framing.
- Source: Sprint 30 gap analysis (gap G23); superseded by Sprint 54 F141.

**F6. Provider-Specific Optimizations (~10-12h) Priority HOLD**
- Phase: Performance
- Platform: All
- Moved to HOLD per Harold (2026-05-25). [Detail](#f6-provider-specific-optimizations)

**GP-11. Account and Data Deletion Feature** -- Moved to F66 (off HOLD, all platforms including Windows Store). See F66 in Core App section above.

**SEC-11b. Database-at-rest encryption via SQLite3MultipleCiphers (sqlite3mc) + plaintext-to-encrypted migration (~8-12h) Priority HOLD**
- Phase: Security
- Platform: All (Windows desktop + Android + iOS)
- **Moved to Post-MVP, removed from Sprint 43** (Harold direction 2026-06-24): the original `sqflite_sqlcipher` approach is mobile-only (no Windows desktop support), which blocked SEC-11b on the app's primary platform. After research, the cipher was switched to **SQLite3MultipleCiphers (sqlite3mc)** -- the modern cross-platform answer -- and the item was re-scoped and deferred rather than attempted with a half-working driver.
- **What Sprint 33 already shipped (infrastructure, reusable as-is)**: `DatabaseEncryptionKeyService` (`lib/core/security/database_encryption_key_service.dart`) -- 256-bit key in `flutter_secure_storage` under `db_encryption_key_v1`, base64-returned for `PRAGMA key`; `getOrCreateKey()` / `hasKey()` / `deleteKey()`. Opt-in `encrypt_database` settings toggle (default off). These do NOT change.
- **Cipher decision (Harold 2026-06-24): use SQLite3MultipleCiphers (sqlite3mc), NOT SQLCipher.** Rationale:
  - Truly cross-platform from one prebuilt source: Android (armv7a/aarch64/x86/x64), iOS, and **Windows desktop** all covered -- SQLCipher's `sqflite_sqlcipher` has no Windows desktop support.
  - Per the drift/sqlite3 maintainers, as of drift 2.32.0 / sqlite3 v3.x, sqlite3mc is the supported/easy path and `sqlcipher_flutter_libs` is being deprecated. SQLCipher is now the harder route.
  - sqlite3mc can still read SQLCipher-format DBs if ever needed (`PRAGMA cipher='sqlcipher'; PRAGMA legacy=4`), so it is not a dead end.
- **Key integration caveat -- this app uses `sqflite` / `sqflite_common_ffi`, NOT drift / the `sqlite3` package binding.** sqlite3mc is wired most cleanly through the `sqlite3` package; to use it with the existing `sqflite_common_ffi` driver on Windows desktop you must:
  - Provide a custom `ffiInit` to `createDatabaseFactoryFfi(ffiInit: ...)` that loads the sqlite3mc native library via `open.overrideFor(OperatingSystem.windows, ...)` (and for `OperatingSystem.android`/`iOS` as needed). Reference: [sqflite_common_ffi encryption_support.md](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/encryption_support.md).
  - Set the key + cipher via `PRAGMA key='<base64>'` in `DatabaseHelper._initializeDatabase()`'s `onConfigure` (alongside the existing `foreign_keys`, `busy_timeout=30000`, WAL setup at `lib/core/storage/database_helper.dart`).
  - Bundle/ship the sqlite3mc native lib per platform (Windows: lib in the same folder as the executable for release; debug bundles automatically). Confirm prebuilt-binary availability vs the `hooks: user_defines: sqlite3: source: sqlite3mc` pubspec mechanism, and whether that mechanism is reachable from a sqflite-based (non-`sqlite3`-package) access layer -- if not, evaluate either (a) a thin `sqlite3`-package shim just for the native-lib resolution, or (b) shipping the sqlite3mc binaries directly.
- **Recommended approach when picked up: spike first.** A focused spike ("wire sqlite3mc through `ffiInit` and prove the Windows DB file on disk is encrypted, with the existing sqflite access layer intact") de-risks the whole feature before the migration work. Far more tractable than compiling/linking SQLCipher for Windows.
- **Migration logic (cipher-independent, unchanged by the cipher switch)**:
  - Atomic plaintext-to-encrypted migration on first opt-in: backup -> re-open with key -> copy -> swap -> verify -> retain backup.
  - **Dual-DB verification window (Harold 2026-06-23)**: Dev keeps an encrypted + plaintext dual-write for ~2 sprints; Prod is encrypted-only after migration with the original plaintext `spam_filter.db` retained as a rollback backup. Cleanup tracked separately as **F106** (spawned by this design).
  - **Existing prod-user upgrade path (Harold question 2026-06-23)**: users on <= 0.5.3 have a plaintext DB; on upgrade to the version that ships SEC-11b, the first launch detects the plaintext DB (no key set / `hasKey()` false but DB exists), runs the one-time migration, and retains the original as the rollback backup.
- **QA on real installs**: Windows desktop + Android emulator + physical device; verify the on-disk DB is unreadable without the key.
- **Flip `encrypt_database` default to true after QA (Class-1 -- surface to Chief Architect before flipping).**
- **Estimate revised to ~8-12h** (was ~6-10h) to cover the custom-`ffiInit` native-lib wiring + the spike.
- Source: Sprint 33 SEC-11 scoping decision (partial completion); driver switch + Post-MVP deferral Harold direction 2026-06-24. Research sources: [drift encryption docs](https://drift.simonbinder.eu/platforms/encryption/), [sqlite3.dart UPGRADING_TO_V3.md](https://github.com/simolus3/sqlite3.dart/blob/main/UPGRADING_TO_V3.md), [sqlite3 hook topic](https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html), [sqflite_common_ffi encryption_support.md](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/encryption_support.md).

**F106. SEC-11b verification-window cleanup (~30m) Priority HOLD**
- Phase: Security / cleanup
- Platform: All
- After ~2 sprints of verified encrypted+plaintext dual-DB operation (per the SEC-11b dual-DB design above): remove the Dev plaintext-mirror dual-write code path, and delete the retained pre-migration plaintext `spam_filter.db` file in prod (kept as a rollback backup during the verification window). Gated on Harold confirming the encrypted DB has been verified working across the window.
- Depends on: **SEC-11b shipped + ~2 sprints of verified encrypted-DB operation.** Moved from Priority 30 to HOLD/Post-MVP (Harold 2026-07-01) -- F106 cannot start until the SEC-11b DB-encryption backlog item ships, so it is paired here under it.
- Source: Harold direction 2026-06-23 (SEC-11b dual-DB verification requirement); HOLD/dependency clarification 2026-07-01.

**H1. GenAI Pattern Suggestions - Crowdsourced Spam Intelligence (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#142](https://github.com/kimmeyh/spamfilter-multi/issues/142)

**H2. Rule Pattern Consistency - Domain Matching Standards (~4-6h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#140](https://github.com/kimmeyh/spamfilter-multi/issues/140)
- Ask: standardize the regex pattern conventions across `rules.yaml`/`rules_safe_senders.yaml` -- define a fixed taxonomy (exact-email / exact-domain / domain+subdomains / entire-TLD), add a new "domain + all TLDs" type, enforce the standard in tooling/UI, and refactor the ~3000+ inconsistent legacy patterns to conform.
- **Current state (verified 2026-05-25)**: PARTIAL. The standardized taxonomy + generators now exist for NEWLY created rules: `mobile-app/lib/core/utils/pattern_generation.dart` (`generateExactEmailPattern`, `generateDomainPattern`, `generateSubdomainPattern`, `detectPatternType`) and the user-facing `ManualRuleType` enum in `manual_rule_create_screen.dart` (entireDomain `@(?:[a-z0-9-]+\.)*domain$`, exactDomain `@domain$`, TLD `@.*\.tld$`), with `pattern_type` persisted to the DB. Subsumption/dedup (Sprints 36-38, `manual_rule_duplicate_checker.dart`) addresses the "consolidate duplicates" goal for new rules. **Remaining**: (1) the requested "domain + all TLDs" type (`@(?:[a-z0-9-]+\.)*spammer\..*$`) does NOT exist (the UI's `topLevelDomain` is the entire-TLD type, a different thing); (2) the ~3000 legacy `rules.yaml` patterns are NOT categorized/refactored/consolidated; (3) no YAML-schema pattern-type metadata field or build-time validation enforcing the standard on the YAML files. Standardization is prospective (manual-create path) only.

**H3. Requirements Documentation System (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: N/A
- Issue [#137](https://github.com/kimmeyh/spamfilter-multi/issues/137)

**H4. Sent Messages Scan for Safe Senders (~12-16h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#49](https://github.com/kimmeyh/spamfilter-multi/issues/49)
- Ask: add a "Sent Messages Scan for Safe Senders" flow -- read every message the account owner sent, collect normalized To:/CC: addresses as safe-sender candidates, flag/exclude ones hitting a delete rule or "unsubscribe," dedupe against existing safe senders, persist progress for resume, and give the user a filterable/sortable review UI (with auto-accept option) to approve additions.
- **Current state (verified 2026-05-25)**: NOT DONE -- entire feature remains. `email_scanner.dart` scans inbox/bulk folders only; no Sent-folder traversal and no safe-sender derivation. `CanonicalFolder.sent` exists as generic folder-classification plumbing in the adapters but nothing consumes it for a sent-scan. No sent-scan service, no resume-state store, no candidate-review UI. Reusable building blocks exist but are unwired: address normalization (`pattern_normalization.dart` `normalizeFromHeader`) and safe-sender storage (`safe_sender_database_store.dart`, `safe_senders_management_screen.dart`). Full scope remains: Sent-folder scan, To/CC candidate collection + normalization, delete-rule/unsubscribe flagging, dedup vs existing safe senders, resumable progress, and the approval UI.

**H5. Outlook.com / Office 365 email provider adapter (~16-20h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Source: Issue [#44](https://github.com/kimmeyh/spamfilter-multi/issues/44) (closed 2026-06-23, deferred to this backlog item).
- **Current state**: `mobile-app/lib/adapters/email_providers/outlook_adapter.dart` is a stub that throws `UnimplementedError`; all methods need implementation. (Outlook.com OAuth is listed under Known Limitations in CLAUDE.md as deferred.)
- **Scope (from #44)**:
  - **Auth (OAuth 2.0)**: Microsoft Identity Platform; scopes `Mail.ReadWrite` + `offline_access`; `msal_flutter` package; interactive browser/webview auth; cache + refresh tokens.
  - **Core methods** via Microsoft Graph API: `loadCredentials()` (init OAuth), `fetchMessages()` (OData `$filter=receivedDateTime ge {date}`, `$top` pagination), plus the rest of the `EmailProvider`/`SpamFilterPlatform` interface (move/delete/folder-list) mapped to Graph endpoints.
  - Register the platform in `PlatformRegistry`; folder/canonical-folder mapping for Outlook's well-known folders.
- **Why HOLD**: post-MVP provider expansion; large (~16-20h) and gated behind a Microsoft app registration. The existing AOL/Gmail/IMAP providers cover current users.

---

