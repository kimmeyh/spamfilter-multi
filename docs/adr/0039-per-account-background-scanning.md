# ADR-0039: Per-Account Background Scanning

## Status

Accepted (2026-06-15, Harold -- Chief Architect, Sprint 41 Class-1 signoff). F98 (implementation) is now eligible for Sprint 42 planning.

## Date

2026-06-13 (Sprint 41, F83 Phase 1)

## Context

Background scanning today is an **app-wide global setting**. The on/off state lives
in the `app_settings` table under the key `background_scan_enabled` (a single global
boolean). Enabling background scanning on any account effectively enables it for the
whole installation: when the scheduled task fires, the worker iterates **every** saved
account and scans each one. On Windows there is exactly one Task Scheduler entry
(`SpamFilterBackgroundScan` plus an environment suffix); on Android there is exactly
one WorkManager periodic task (`background_scan_task`). The scheduled launch carries no
account context -- the executable is invoked with a bare `--background-scan` flag and
the worker decides which accounts to scan internally.

This global model conflicts with the per-account separation users already expect from
the rest of the product. Per ADR-0013, scan mode, scan folders, scan range, and even a
per-account `background_enabled` **override** are already stored per account in
`account_settings`. The user-facing Settings > Background tab is already account-scoped
(Sprint 38 Round 10 added a per-account header). The result is a confusing split: the
**configuration** is per account, but the **enable switch and the OS-level schedule**
are global. A user who wants background scanning on their work account but not their
personal account cannot express that cleanly: toggling the global switch on, then
relying on the per-account `background_enabled` override to suppress the unwanted
account, is fragile and undiscoverable.

There is also latent inconsistency in the current code:

- `SettingsStore.getEffectiveBackgroundEnabled(accountId)` resolves a per-account
  override stored under the `account_settings` key **`background_enabled`**
  (`settings_store.dart:383-397`).
- `BackgroundScanWorker._isBackgroundScanEnabled(...)` (the Android worker) queries
  `account_settings` for the key **`background_scan_enabled`**
  (`background_scan_worker.dart:125`) -- a different key string that the writer never
  populates, so the Android per-account check is effectively dead.
- An orphaned `background_scan_schedule` table already exists in the schema
  (`database_helper.dart:252-262`) with `account_id` as primary key plus `enabled`,
  `frequency_minutes`, `last_run`, `next_scheduled`, `scan_mode`, and `folders`
  columns. It is created and cleared on reset but is not read or written by the live
  background-scan path.

The goal of F83 is **full per-(provider, email-address) separation** of background-scan
enable state, scheduling, and artifacts (logs and CSV/XLSX exports), so that each
account is an independent unit: independently enabled, independently scheduled at the
OS level, and producing independently named artifacts.

This ADR is the Phase 1 deliverable. It is research and design only. No implementation
code, no schema migration, and no UI changes are produced in this sprint. The
implementation work is tracked separately as **F98** and is itemized in the change-site
inventory below so it can be minute-estimated.

## Decision

Move background scanning from an app-wide global to a per-account model. Three
decisions are **locked by the Chief Architect** and are not re-litigated here:

### Locked Decision 1 -- Migration preserves today's behavior

If the current global `background_scan_enabled` value is **true** at migration time,
**every existing account inherits `background_scan_enabled = true`**. This preserves the
exact behavior users have today (all accounts scanned). The user then disables the
accounts they do not want, one at a time. If the global value is false (the default),
no account is enabled. See the Migration plan below for the exact mechanics.

### Locked Decision 2 -- One OS-level scheduler entry per enabled account

There is **one OS-level scheduled entry per enabled account**, not a single iterating
entry:

- **Windows**: one Task Scheduler task per enabled account, named with the accountId
  (sanitized), for example `SpamFilterBackgroundScan_gmail_user_at_gmail_com` (plus the
  existing `_Dev` environment suffix). Each task's action launches the executable with
  `--background-scan --account-id=<accountId>`.
- **Android**: one WorkManager unique periodic task per enabled account, with a unique
  name derived from the accountId (for example `background_scan_task::<accountId>`),
  each carrying the accountId in its `inputData`.

The scheduled launch is **account-scoped**: the worker no longer iterates all accounts.
It scans exactly the one account named on the command line / in the work input.

### Locked Decision 3 -- Deliverable is this ADR plus the change-site inventory only

Phase 1 (this sprint) produces this ADR and the F98 change-site inventory. No code, no
schema migration, no UI changes ship this sprint.

### Proposed per-account data model

Promote background-scan enable state and schedule to per-account rows. Two design
choices are presented; the **recommended** choice is A.

**Option A (recommended): keep using `account_settings` key-value rows.**
Continue ADR-0013's key-value inheritance model. The per-account enable flag is the
existing `account_settings` key `background_enabled`; per-account frequency becomes a
new key `background_frequency`. This requires **no schema migration** (the table already
exists and already holds `background_enabled` overrides), aligns with ADR-0013's
"extensible without ALTER TABLE" principle, and only requires consolidating the two
divergent key strings (`background_enabled` vs `background_scan_enabled`) onto one
canonical key. The global `app_settings.background_scan_enabled` row is retained only as
the migration source and the inheritance fallback default.

**Option B (rejected for Phase 1): adopt the orphaned `background_scan_schedule` table.**
The `background_scan_schedule` table (`account_id` PK, `enabled`, `frequency_minutes`,
`last_run`, `next_scheduled`, `scan_mode`, `folders`) is purpose-built for exactly this.
However, it duplicates fields already resolved through `account_settings` inheritance
(scan_mode, folders), it is currently dead code, and wiring it in is a larger change
than Option A. It is rejected for Phase 1 to keep F98 minimal, but it remains a
candidate for a future consolidation ADR (see Out of Scope).

Under Option A, the effective enable resolution stays exactly as it is today
(`getEffectiveBackgroundEnabled`: account override, then global fallback). The behavior
change is that **the scheduler and worker now act on a single account at a time**, and
**the UI writes the per-account override** instead of the global flag.

### Proposed naming conventions

- **Account id sanitization** (reuse the existing pattern from
  `background_scan_windows_worker.dart:308-310`): replace `@` with `_at_` and `.` with
  `_`. Define this once as a shared helper so the Task name, the WorkManager unique name,
  the log filename, and the CSV/XLSX filename all derive from the same sanitized token.
- **Windows Task name**: `SpamFilterBackgroundScan_<sanitizedAccountId><taskNameSuffix>`
  (the `<taskNameSuffix>` is the existing `_Dev` for dev, empty for prod).
- **Android WorkManager unique name**: `background_scan_task::<accountId>`.
- **CLI**: `--background-scan --account-id=<accountId>`. Backward compatibility: if
  `--account-id` is absent, fall back to the legacy iterate-all-accounts behavior so an
  un-migrated Task Scheduler entry still works during the transition.
- **Per-account log file**: today the log is shared
  (`{logs}/{prefix}background_scan_v0.5.3.log`). Proposed:
  `{logs}/{prefix}background_scan_<sanitizedAccountId>_v0.5.3.log` so concurrent
  per-account runs do not interleave into one file. (The version token already exists.)
- **Per-account CSV/XLSX export**: already per-account today
  (`background_scan_<safeAccountId>_<date><devSuffix>.xlsx` /
  `.data.csv`, `background_scan_windows_worker.dart:313-314`). This naming is retained;
  no change required for separation, but the sanitization helper should be shared.

### CLI change

`BackgroundModeService.initialize(args)` currently only checks for the presence of
`--background-scan` (`background_mode_service.dart:24`). It must additionally parse an
optional `--account-id=<value>` argument and expose it (for example
`BackgroundModeService.backgroundAccountId`). `main.dart` then passes that accountId
into the worker, which scans only that account.

## Change-Site Inventory (F98)

Effort hint legend (per-site, for F98 minute-estimation):
**XS** = trivial (constant/string/key rename, < 10 min);
**S** = small (single method, one parse/branch, 10-30 min);
**M** = medium (multi-branch logic or new method, 30-90 min);
**L** = large (new scheduling loop / migration / cross-platform, 90+ min).

| # | File:line | Current behavior | Per-account change | F98 effort hint |
|---|-----------|------------------|--------------------|-----------------|
| 1 | `lib/ui/screens/settings_screen.dart:853-865` | Background "Enable" `SwitchListTile` writes the **global** `setBackgroundScanEnabled(value)`. | Write the **per-account** override `setAccountBackgroundEnabled(widget.accountId, value)`; drive Windows task create/delete for this one account. | M (UI + per-account wiring) |
| 2 | `lib/ui/screens/settings_screen.dart:161` | Loads `_backgroundScanEnabled` from the global `getBackgroundScanEnabled()`. | Load from `getEffectiveBackgroundEnabled(widget.accountId)`. | S |
| 3 | `lib/ui/screens/settings_screen.dart:793-843` (`_updateWindowsScheduledTask`) | Creates/updates/deletes the single global task. | Create/update/delete the **per-account** task (pass accountId to the scheduler service). | M |
| 4 | `lib/ui/screens/settings_screen.dart:873-883` (Frequency selector) | Saves global `setBackgroundScanFrequency(freq)`; re-registers the single task. | Save per-account frequency (new `account_settings` key `background_frequency`); re-register the per-account task. | M |
| 5 | `lib/core/storage/settings_store.dart:45-46,133-154` | `keyBackgroundScanEnabled` / `keyBackgroundScanFrequency` are global `app_settings` getters/setters. | Retain as migration source + inheritance fallback. Add per-account frequency override accessors (`getAccountBackgroundFrequency` / `setAccountBackgroundFrequency`) mirroring `getAccountBackgroundEnabled`. | S |
| 6 | `lib/core/storage/settings_store.dart:383-397` | `getAccountBackgroundEnabled` / `setAccountBackgroundEnabled` use `account_settings` key **`background_enabled`**. | Canonicalize this as **the** per-account enable key. This is the authoritative store for Decision 1. | XS |
| 7 | `lib/core/storage/settings_store.dart:662-669` (`getEffectiveBackgroundEnabled`) | Resolves account override then global fallback. | No logic change. Confirm all callers pass a concrete accountId (no global-only path). | XS |
| 8 | `lib/core/services/background_mode_service.dart:14,20-24` | Parses only `--background-scan` presence. | Parse optional `--account-id=<id>`; expose `backgroundAccountId`. | S |
| 9 | `lib/main.dart:53-95` | Background-mode entry calls `executeBackgroundScan()` (scans all accounts). | Read `BackgroundModeService.backgroundAccountId`; pass it to the worker so only that account is scanned. Keep legacy all-accounts path when accountId is null. | M |
| 10 | `lib/main.dart:196-216` | On startup, if the **global** flag is on, ensures the single task exists. | Iterate accounts; for each account whose effective enable is true, ensure its per-account task exists with its per-account frequency. | M |
| 11 | `lib/core/services/background_scan_windows_worker.dart:63,102-211` | `executeBackgroundScan` loads **all** accounts and loops, checking `getEffectiveBackgroundEnabled` per account. | Accept an optional `accountId`. When provided, scan only that account (skip the all-accounts loop). Retain `isTest` semantics for the single account. | M |
| 12 | `lib/core/services/background_scan_windows_worker.dart:40-54` (`_bgLog` / `_getLogDir`) | Single shared log file `{prefix}background_scan_v0.5.3.log`. | Include sanitized accountId in the filename: `{prefix}background_scan_<sanitizedAccountId>_v0.5.3.log`. | S |
| 13 | `lib/core/services/background_scan_windows_worker.dart:307-316` | CSV/XLSX filename already per-account (`background_scan_<safeAccountId>_<date>...`). | No separation change. Extract the sanitization to the shared helper (reuse, not behavior change). | XS |
| 14 | `lib/core/services/windows_task_scheduler_service.dart:16-17` (`taskName` getter) | Static task name `SpamFilterBackgroundScan<suffix>`. | Make task name a function of accountId: `SpamFilterBackgroundScan_<sanitizedAccountId><suffix>`. | S |
| 15 | `lib/core/services/windows_task_scheduler_service.dart:23-239` (create/update/delete/ensure/status) | All methods operate on the single global `taskName`. | Add `accountId` parameter to each method so it targets the per-account task; add an enumerate-all-tasks helper for cleanup of orphaned per-account tasks. | L |
| 16 | `lib/core/services/windows_task_scheduler_service.dart:248-306` (`verifyAndRepairTaskPath`) | Repairs the single task's exe path. | Repair every per-account task's exe path (iterate the per-account tasks). | M |
| 17 | `lib/core/services/powershell_script_generator.dart:23-79` (create) | Sets `$arguments = "--background-scan"`. | Set `$arguments = "--background-scan --account-id=<accountId>"`; accept accountId so the generated task is account-scoped. | S |
| 18 | `lib/core/services/powershell_script_generator.dart:84-197` (update/delete/status) | Operate on a single `taskName`. | Accept the per-account task name (already parameterized by `taskName`); no structural change beyond the caller passing the per-account name. | XS |
| 19 | `lib/core/services/background_scan_worker.dart:21-113` (Android `executeBackgroundScan`) | Loads all accounts via `AccountStore`, loops, checks per-account enable. | Accept an accountId from WorkManager `inputData`; scan only that account. | M |
| 20 | `lib/core/services/background_scan_worker.dart:116-139` (`_isBackgroundScanEnabled`) | Queries `account_settings` for key **`background_scan_enabled`** (wrong key -- dead check). | Replace with `SettingsStore.getEffectiveBackgroundEnabled(accountId)` (canonical `background_enabled` key). Fixes the latent key mismatch. | S |
| 21 | `lib/core/services/background_scan_worker.dart:239-246` (`callbackDispatcher`) | Dispatches the single `backgroundScanTaskId`. | Read accountId from `inputData`; route to the single-account scan. | S |
| 22 | `lib/core/services/background_scan_manager.dart:55-116` (`scheduleBackgroundScans` / `cancelBackgroundScans`) | Registers/cancels one periodic task `backgroundScanTaskId` for the whole app. | Register/cancel a **uniquely named** periodic task per account (`background_scan_task::<accountId>`) carrying accountId in `inputData`. | M |
| 23 | `assets/content/help/background_scanning.md:1-7` | Describes Enable as a "master on/off switch" that registers one scheduled task. | Reword: Enable is **per account**; each enabled account gets its own scheduled entry; frequency is per account. | XS |
| 24 | `lib/core/storage/database_helper.dart:252-262` | Orphaned `background_scan_schedule` per-account table (dead). | No change in Phase 1 (Option A). Documented as future-consolidation candidate. | XS (doc only) |

**Change-site count: 24.**

## Migration plan

A one-time, idempotent migration runs on first launch after the F98 build ships
(following the established pattern of other one-time migrations in `main.dart`). It does
**not** require an `ALTER TABLE` under Option A.

1. Read the global `app_settings.background_scan_enabled`.
2. If it is **true**:
   - Enumerate every saved account (the same source the worker uses today --
     `SecureCredentialsStore.getSavedAccounts()` on Windows; `AccountStore` on Android).
   - For each account that does **not** already have an explicit per-account
     `background_enabled` override, write `setAccountBackgroundEnabled(accountId, true)`.
     Accounts with an existing explicit override are left untouched (the user already
     expressed intent).
   - Copy the global `background_scan_frequency` into each account's new
     `background_frequency` override unless the account already has one.
3. If the global value is **false** (or unset), do nothing (fresh-install default).
4. Mark the migration complete (a sentinel `app_settings` key, for example
   `per_account_bg_migration_done`) so it never re-runs.
5. On the next startup pass (change-site #10), per-account Task Scheduler / WorkManager
   entries are created for every account whose effective enable is now true. The single
   legacy global task is deleted once its per-account replacements exist.

The global `app_settings.background_scan_enabled` row is retained (not deleted) so it
continues to serve as the inheritance fallback for any account with no override and so
the migration sentinel logic is unambiguous.

## Consequences

### Positive

- **True separation of concerns**: each (provider, email-address) account is an
  independent background-scan unit -- independently enabled, scheduled, logged, and
  exported. This matches the per-account model already used for scan mode, folders, and
  range (ADR-0013).
- **Discoverable**: the Settings > Background tab is already account-scoped; the enable
  switch now does what its account header implies.
- **Independent schedules**: per Decision 2, accounts can run at different frequencies
  without "the most frequent interval wins" coupling that ADR-0014 documented as a known
  limitation.
- **Fixes a latent bug**: consolidates the divergent `background_enabled` vs
  `background_scan_enabled` keys; the Android per-account enable check becomes live.
- **No schema migration** under Option A; aligns with ADR-0013's extensibility.
- **Non-interleaved logs**: per-account log files mean concurrent account runs no longer
  interleave into one file, easing diagnosis.

### Negative

- **More OS-level entries**: N enabled accounts means N Task Scheduler tasks / N
  WorkManager jobs. Cleanup must be robust -- removing an account must remove its task,
  and orphaned tasks must be reaped (change-site #15 enumerate-all helper).
- **More startup work**: the startup ensure-task pass (change-site #10) now iterates
  accounts and may run several PowerShell invocations, slightly increasing cold-start
  cost on Windows.
- **Migration window**: an un-migrated Task Scheduler entry (bare `--background-scan`)
  must keep working until migration completes; the CLI fallback (no `--account-id` =
  legacy all-accounts) covers this but is transitional complexity.
- **Per-account artifact proliferation**: more log and CSV files on disk (one set per
  enabled account). Retention/cleanup logic should account for per-account naming.

### Neutral

- The orphaned `background_scan_schedule` table remains unused under Option A. It is
  neither removed nor adopted in Phase 1.
- CSV/XLSX export filenames are already per-account, so artifact separation there is a
  no-op beyond sharing the sanitization helper.

## Out of scope for Phase 1 (this is F98)

The following are explicitly **not** done in this sprint (Phase 1 is ADR + change-site
inventory only):

- Any implementation code, including the CLI parser change, the per-account scheduler
  methods, the worker single-account path, and the per-account log filename change.
- The one-time migration code (designed above, implemented in F98).
- Any database schema migration or `ALTER TABLE`.
- Any UI change to the Settings > Background tab.
- Adopting or removing the orphaned `background_scan_schedule` table (Option B). A
  future consolidation ADR may decide whether to migrate the key-value background
  settings onto that purpose-built table or to delete it.
- iOS background scanning implementation (BGTaskScheduler). iOS is not yet validated
  (see Known Limitations in CLAUDE.md); the per-account naming convention defined here
  is forward-compatible with a future iOS implementation but no iOS code is in scope.
- Per-account notification routing changes beyond what the single-account worker path
  naturally produces.

## Cross-cutting variant correctness

The design must hold across {Windows Store (MSIX), Android, iOS} x {dev, prod}:

- **Windows dev vs prod**: the per-account Task name must carry the existing
  `AppEnvironment.taskNameSuffix` (`_Dev` for dev, empty for prod) **in addition to** the
  accountId, so dev and prod per-account tasks never collide
  (`SpamFilterBackgroundScan_<sanitizedAccountId>_Dev`). Log and CSV filenames already
  carry `AppEnvironment.logPrefix` (`dev_`) and the `_dev` CSV suffix; per-account names
  must keep those tokens.
- **Windows Store (MSIX)**: Task Scheduler management is **skipped** under MSIX
  (`main.dart:185`, `AppEnvironment.isMsixInstall`). The per-account create/ensure path
  must preserve that skip -- per-account tasks are equally unavailable in the MSIX
  sandbox, so the per-account startup pass (change-site #10) must remain behind the same
  `kReleaseMode && !isMsixInstall` guard. This means Store builds rely on foreground
  scans only, unchanged from today.
- **Android dev vs prod**: WorkManager unique names must incorporate the same
  environment distinction used elsewhere (the flavor/data-dir separation) so dev and
  prod jobs do not share a unique name. The accountId already differs per account; the
  environment token must also be present to avoid dev/prod collision on the same device.
- **iOS**: no implementation in scope; the accountId-keyed naming convention is recorded
  here so a future BGTaskScheduler implementation can adopt one task identifier per
  account consistently.

## References

- ADR-0013 (`docs/adr/0013-per-account-settings-with-inheritance.md`) -- per-account
  settings inheritance model that this ADR extends to the enable flag and frequency.
- ADR-0014 (`docs/adr/0014-windows-background-scanning-task-scheduler.md`) -- the
  single-global-task model this ADR supersedes for the enable/schedule concern; the
  "single task name / most frequent interval wins" Neutral consequence is resolved here.
- ADR-0035 (`docs/adr/0035-production-development-side-by-side.md`) -- dev/prod
  side-by-side; source of `taskNameSuffix`, `logPrefix`, and the `_dev` artifact suffix.
- `mobile-app/lib/core/storage/settings_store.dart` -- global keys (lines 45-46,
  133-154), per-account enable override (lines 383-397), effective resolution (lines
  662-669).
- `mobile-app/lib/core/services/background_mode_service.dart` -- CLI flag parsing
  (lines 14, 20-24).
- `mobile-app/lib/main.dart` -- background-mode entry (lines 53-95), startup
  ensure-task (lines 196-216).
- `mobile-app/lib/core/services/background_scan_windows_worker.dart` -- Windows worker
  loop (lines 63, 102-211), log path (lines 40-54), CSV/XLSX naming (lines 307-316).
- `mobile-app/lib/core/services/windows_task_scheduler_service.dart` -- task name and
  lifecycle (lines 16-306).
- `mobile-app/lib/core/services/powershell_script_generator.dart` -- task arguments
  (line 39).
- `mobile-app/lib/core/services/background_scan_worker.dart` -- Android worker (lines
  21-139), `callbackDispatcher` (lines 239-246).
- `mobile-app/lib/core/services/background_scan_manager.dart` -- WorkManager scheduling
  (lines 55-116).
- `mobile-app/lib/core/storage/database_helper.dart` -- `account_settings` table (lines
  239-248), orphaned `background_scan_schedule` table (lines 252-262), `background_scan_log`
  (lines 290-303).
- `mobile-app/assets/content/help/background_scanning.md` -- user-facing help text.

## Amendment -- Sprint 73 (F235): Doze delivery

The per-account WorkManager task in this ADR is unchanged and remains the scan
engine. WorkManager cannot wake a device in Doze, so each account now also has an
inexact `AlarmManager.setAndAllowWhileIdle` alarm whose only job is to wake the
device and enqueue a one-off WorkManager task for that account. The inexact
variant was chosen over `setExactAndAllowWhileIdle` because it needs no exact-alarm
permission and carries no Google Play policy burden; the cost is a delivery window
of about an hour. Alarms are re-armed after each firing and restored after a
reboot by `BootReceiver`. See `DozeAlarmScheduler.kt` and ARCHITECTURE.md
"Android in Doze".

## Amendment -- Sprint 74 (MV74-2, Harold Q3): cross-isolate exclusion

**What was assumed, and was false.** The F175 `ScanCoordinator` lease was
documented as "the whole guarantee on Android, where every scan shares one
process". One process is true; one Dart ISOLATE is not. `workmanager_android`
creates a new `FlutterEngine` for every background worker, so each background
scan runs in its own isolate with its own copy of the singleton. On Windows the
background scan is a separate process. On BOTH platforms, then, nothing stopped a
background scan and a manual scan from opening two IMAP sessions on one account --
the Sprint 61 per-account session-cap failure.

**Decision (Harold, 2026-09-25, answer to planning question 3: "update/append
current ADR").** Exclusion moves to the one thing both sides can read, the
shared `scan_results` row:

- The scanning isolate refreshes `scan_results.last_heartbeat_at` every 30
  seconds (DB v9).
- Before opening any connection, `BackgroundScanCore.scanAccount` checks for a
  live INTERACTIVE row (manual, demo) on the same account --
  `in_progress` with a heartbeat inside 5 minutes -- and SKIPS the account if
  one exists. The background side yields because the user is the one waiting.
- The manual-scan notice counts a background row only with a fresh heartbeat,
  so a dead scan stops blocking within minutes rather than 30.
- Same code on both platforms (ADR-0042, no exception).

**Two gaps found by the Sprint 74 PR review, CLOSED on Harold's Class-2
decision (2026-09-25, "ensure a scan that fails before connecting updates that
the scan is no longer running").** (1) A manual scan wrote its row only after
connecting -- a window of seconds; its row is now written right after the
lease and BEFORE connecting, and a pre-connect failure closes it as `error`
(`interrupted` on cancel). (2) Re-processing from Scan Results wrote no row;
it now holds a heartbeating `reprocess` claim row for its whole run, deleted
when it ends and never listed in Scan History.

**Remaining accepted limit (SUPERSEDED the same sprint -- see the next
amendment).** The check was still check-then-act with no lock, and a query
failure failed OPEN.

## Amendment -- Sprint 74 Manual Validation (Harold Q4, 2026-09-27): one scan per account, of any type -- a real lock

**Why.** On the Fold8 (0.16.0) four BACKGROUND scans started on one AOL
account inside one minute, and In-progress rows stayed for hours. The
exclusion above only made background scans yield to INTERACTIVE ones; per
account there are three independent WorkManager chains (the periodic task,
the F235 Doze one-off, Test Background Scan -- Harold confirmed he pressed
nothing), and nothing stopped one from starting beside another. Harold: *"Can
only run one at a time. For any type of scan, If one is already running,
don't start a new one. It is a semiphore type problem and scans cannot run
forever."*

**Decision.** A per-account semaphore in the shared database:
`ScanResultStore.claimAccountScan`. In ONE transaction -- sqflite opens it with
`BEGIN IMMEDIATE`, which takes SQLite's write lock, so the UI isolate, the
Android worker isolates and the Windows worker process serialize against each
other (`busy_timeout` 30 s, WAL, `DatabaseHelper.onConfigure`) -- it:
1. reaps this account's dead holders (`in_progress` with a heartbeat older than
   `heartbeatFreshness` (5 min) or started more than `scanTimeout` (30 min)
   ago) to `interrupted` -- this is what "scans cannot run forever" means
   without an app restart;
2. refuses if any `in_progress` row remains for the account, of ANY type;
3. otherwise inserts the new scan's row.
Every scan takes it: manual, demo and background through
`EmailScanProvider.startScan`, re-processing through `claimInteractive`.

**Refusal is not failure.** A refused scan writes no row and throws
`ScanAccountBusyException`; each caller maps it: background -> a skip (like
the early check), manual -> "A scan is already running" (OK only), re-process
-> "saved ... your mailbox was not changed yet. The next scan applies it."

**Fail CLOSED.** A database error while claiming refuses the scan. This
replaces the Sprint 17/60 "continue without persistence" behavior for the
claim step only (a semaphore that admits work when it cannot check is not a
semaphore). Harold can flip this.

**Per account, not global.** The harm is the provider's per-account session
cap, and Doze delivers every account's alarm in one batch, so a global lock
would starve all but one account every interval.

**Heartbeat ownership corrected.** `EmailScanProvider.reset()` no longer stops
the heartbeat: the Manual Scan screen calls it from `didPopNext` -- every time
the user backs out of Results, including mid-scan -- so it made a running scan
look dead, and the lock would then have reaped it and let a second scan in.

**Scope confirmed, and a busy retry added (Harold, 2026-09-28).** The lock
stays PER ACCOUNT. Harold: *"if either of the N account scans finds the DB
busy it waits random number of minutes between 2 and 6 minutes then starts
(won't worry about conflict if they still conflict)"*. So a background scan
whose first attempt finds its account held (early check or claim refused), or
hits SQLite "database is locked", waits a random 2:00-6:00
(`BackgroundScanCore.randomBusyRetryDelay`) and makes exactly ONE more attempt
through the same lock; if that is busy too, its outcome stands. The random
wait also spreads the Doze batch. This REPLACES the Windows-only F98/F101
retry (15 attempts, 1 minute apart) with one rule on both platforms
(ADR-0042). Android caveat: a WorkManager worker has about 10 minutes without
a foreground service, so a 6-minute wait leaves about 4 for the scan.

**What is still not proven by tests**: contention between two real SQLite
connections (two isolates or processes) -- the unit tests run on one
connection. That is Manual Validation on the device. The "Stop the background
scan and start mine" action is F238 (Sprint 75, release blocker for 0.17.0) --
see the next amendment.

## Amendment -- Sprint 75 (F238, Harold Q1 at plan approval, 2026-10-03): a cross-isolate stop request through the row

**Why.** With the lock above, a user who taps Start Live Scan while a
background scan holds the account is told "A scan is already running" with
only OK. The background scan is invisible and cannot be stopped from the UI:
it runs in another isolate (Android WorkManager) or another process (Windows
Task Scheduler), so the F224 cancel (`ScanCoordinator.requestCancel`, a flag
on an in-memory lease) cannot reach it. Harold, Sprint 74 Manual Validation:
*"0.17.0 cannot ship without a fix ... it is the largest bug that we have."*

**Decision (Class-1, approved as Sprint 75 open question 1).** The shared
`scan_results` row, already the liveness and exclusion channel, becomes the
ONLY control channel into a running scan as well:

- DB v11 adds nullable `scan_results.cancel_requested_at` (additive, guarded
  migration; existing rows stay NULL).
- The dialog offers a third action, "Stop the background scan and start
  mine", ONLY when the holder is a `background` scan. A manual, demo or
  `reprocess` holder is the user's own work and keeps OK only.
- The UI writes the request on the holder row by id, guarded on
  `status = 'in_progress'` (`ScanResultStore.requestCancel`). One row, one
  account: it can never stop another account's scan.
- The scanning isolate reads its own row on the EXISTING heartbeat tick
  (`EmailScanProvider._startHeartbeat`, every 30 s) and, when set, calls
  `ScanCoordinator.requestCancel` in ITS OWN isolate. From there the F224 path
  is unchanged: the scan stops at its next check point, its partial counts
  are kept, its `finally` releases the lease and closes the IMAP session, and
  `cancelScan` closes the row `interrupted` with the reason "Stopped so your
  manual scan could start" -- never `error`. The tick never closes the row
  itself: the row closing is what admits the waiting manual scan, so it may
  happen only when the lease and session are really being torn down.
- The manual side shows "Stopping the background scan..." and waits, BOUNDED
  (90 s, polling every 2 s), for the holder row to leave `in_progress` or for
  its heartbeat to go stale -- the same condition `claimAccountScan` reaps on.
  It then starts through the NORMAL path, so the claim still decides. If the
  bound expires, the user is told and nothing starts; the request stays on
  the row and is honored at the scan's next check point, and the claim reaps
  the holder if it is dead.
- Same code on both platforms (ADR-0042): cross-isolate on Android,
  cross-process on Windows. No exception declared.
- The stopped background scan is NOT a completed scan. The scanner swallows
  a cancel (right for a manual scan), so `BackgroundScanCore` checks
  `scanProvider.wasCancelled` and returns a skip with `stopped: true`: no
  export, no "scan complete" notification, and no 2-6 minute busy retry --
  the user is scanning that account by hand.

**Amendment (Sprint 76, F249) -- the check points.** Until 0.17.0 the only
check point was a BATCH boundary. On the Fold (2026-10-04) a background scan
stuck at Found 0 never reached one, so the stop was accepted and ignored; a
test (F248) then showed the same: accepted at the first folder, and the scan
went on to "completed" because empty folders produce no batch. The scanner now
also checks right after the connect, at each folder start, and after the last
folder (`EmailScanner._cancelCheckpoint`), with the same lease check and the
same exit (`ScanCancelledException` -> `cancelScan` -> `finally`). This also
makes the user's Cancel Scan and a timeout's revoked lease take effect at those
points. Still NOT covered: a stop while the connect or one folder's search is
itself blocked -- there is no check point inside a single awaited call; the
F248 diagnostic log on the phone decides whether that case needs a cancel race.

**Why not a second channel.** The F224 token and the MV74-2 heartbeat timer
are reused as-is: no second cancel path, no second timer. A platform channel
(Android) or a named pipe / signal (Windows) would have been two mechanisms
for one behavior, and ADR-0042 asks for one.

**What is still not proven by tests.** Two real connections (the tests run on
one); the scanner's `ScanCancelledException` handler is simulated by calling
`cancelScan()` as it does, and its wiring is pinned by the F224 source gate;
a single IMAP fetch or connect longer than the bound has no batch boundary in
it, so the bound can expire although the request will be honored later; and
the scanner marks the row before its `finally` disconnects, so a sub-second
window exists where the manual claim is granted while the background socket
is still closing (pre-existing F224 ordering, not changed here). Windows
Manual Validation with a background scan really running in ANOTHER PROCESS
covers the first. **Not** Settings > Test Background Scan: on Windows that runs
the worker inside the UI process (one connection, one ScanCoordinator), so it
exercises the same-isolate path only (Sprint 75 review H-2). The Windows
recipe starts the dev exe with `--background-scan --account-id=<account>`
and then starts a live scan on that account while the background process is
still scanning (since F243, below, the app may already be open). The phone
follows in Sprint 76 (Harold Q3).

## Amendment -- Sprint 75 (F243, Harold at Manual Validation, 2026-10-03): Windows background scans run while the app is open

**Before.** BUG-S37-1 (Sprint 38) made every Windows `--background-scan` launch
EXIT when the foreground app was running -- a read-only probe of the UI's
single-instance mutex in `windows/runner/main.cpp` -- because the two
processes then failed with "database is locked" on one SQLite file. F109
(Sprint 44) added the "deferred" record and the two texts explaining it. On
Windows, scheduled scans therefore did not run for as long as the window was
open; Android, whose worker runs in its own isolate with its own connection,
never deferred.

**Decision.** Remove the deferral. The probe stays only to LOG that the UI was
open ("Foreground UI is running; background scan proceeds"); the background
process still never takes the mutex, so the UI can open during a scan.

**Why it is safe now.** The cause is handled where it belongs:
- the database runs in WAL mode with `busy_timeout` 30 s
  (`database_helper.dart`), so a second writer waits instead of failing;
- the per-account claim (Sprint 74 amendments above) decides who scans: a
  background scan of an account a live scan holds is REFUSED and skipped, and
  retried once after 2-6 minutes (`BackgroundScanCore.scanAccount`), which also
  covers a lock that outlasts the busy timeout;
- a background scan that started FIRST is stopped by the user through the F238
  offer above.
Scope is PER ACCOUNT (Harold's Sprint 74 Q4 rule): other accounts keep
scanning. Windows now behaves like Android (ADR-0042; no exception remains).

**Removed with it**: the Settings > Background status line (F109a) and the Scan
History hint (F109b), both of which said background scans pause while the app
is open. The F109c ingest stays: it only converts an old handoff file into
`deferred` rows, and existing rows stay readable.

**What is not proven by tests.** Two real processes writing at once under load
(the native integration script, `scripts/test-background-scan-skip.ps1`,
proves the launch PROCEEDS with the UI open, against a non-existent account so
it touches no mail); the claim's behavior across processes is covered by the
Dart tests on one connection and by Manual Validation.

## Amendment -- Sprint 76 Manual Validation (Harold, 2026-10-05: "q1 1 ... q3 2"): KEEP, and five-minute spacing

**1. The Doze one-off uses KEEP (Q1 = 1).** `DozeScanTrigger.enqueue` used
`ExistingWorkPolicy.REPLACE`, which cancels the existing work even while it is
RUNNING: an alarm firing during a long Doze-started scan killed that scan
mid-fetch, with no outcome line and an `in_progress` row left for the reaper
(both Phase 5.1.1 reviewers confirmed the scenario; F249 part 2). KEEP lets the
running scan finish and drops the new request -- the next alarm re-arms anyway.
APPEND stays rejected (it stacks scans, F175). The F253 new-mail one-off
already used KEEP.

**2. Five-minute spacing, never a skip (Q3 = 2, with Harold's refinement).**
Harold rejected skipping a background scan that falls soon after another:
*"no as when emails arrive is the best possible position - if < 5 minutes can
it delay until 5 minutes before starting the scan"*. `BackgroundScanCore.scanAccount`
now waits until 5 minutes after the account's last COMPLETED scan (any type)
before its first attempt, then scans. The spacing wait and the existing 2-6
minute busy retry share one 6-minute budget (`cappedBusyWait`), so the worst
case is unchanged and an Android worker (about 10 minutes) keeps time to scan.
Shared by both platforms (ADR-0042).

**3. A scan that fetched nothing is a failed scan (Q4).** When every folder
that exists on the account failed to fetch -- no network -- the scan now ends
with `ScanFetchFailedException` instead of "completed, errors=N", so the worker
reports a failure and WorkManager retries it (a notification-triggered run does
not retry; its next notification is the retry). A partial failure still
completes with its errors counted (F174).

## Amendment -- Sprint 77 (F264, Harold at plan approval 2026-10-06: Q11, Q13, Q14): the interval is minutes

**1. Interval model.** The per-account interval is an integer number of MINUTES
carried end to end, from **5 to 5940 minutes (99 hours)**. The fixed
`ScanFrequency` list (15 / 30 / 60 minutes and daily; the Settings list also
offered 120 and 240) is retired. ONE shared model, `lib/core/services/scan_interval.dart`,
owns the range (`kMinIntervalMinutes = 5`, `kMaxIntervalMinutes = 99 * 60`), the
unit-plus-number conversion, the label and the conversion of stored values.
Storage is unchanged: `background_frequency` (per account) holds minutes.

**2. One control on both platforms (Q11).** Settings > Background > "Scan every":
a unit dropdown FIRST (Minutes or Hours), then a 2-digit number box (1-99).
Interval = number x unit. An entry under 5 minutes is flagged inline ("Minimum is
5 minutes, to limit battery use") and is not saved. The floor is one named
constant because the R76-1 battery measurements may move it. It is tied by a test
to `BackgroundScanCore.kMinScanSpacing` (5 minutes): a floor below the spacing
would make every scan wait.

**3. Schedulers take minutes.** `BackgroundScanScheduler.schedule` takes
`intervalMinutes`. Windows emits ONE trigger shape for every interval:
`New-ScheduledTaskTrigger -Once -At <start> -RepetitionInterval (New-TimeSpan
-Minutes <n>) -RepetitionDuration (New-TimeSpan -Days 365)`. Microsoft documents
`RepetitionPattern.Interval` as 1 minute to 31 days, so 5 minutes to 99 hours
(4 days 3 hours) is inside it. The old `-Daily -At 09:00AM` special case is gone;
a daily scan is 1440 minutes. `verifyAndRepairTaskPath` takes the minutes from its
caller and no longer guesses the interval from the trigger's text.

**4. Android: the alarm gets the user's minutes, WorkManager its minimum.** The
Doze alarm (F235) is armed with the UNCLAMPED minutes. WorkManager's documented
minimum repeat interval is 15 minutes, so only the WorkManager safety-net
registration is clamped (`ScanInterval.workManagerMinutes`). Before F264 the
15-minute clamp ran above the alarm call, so a 5-14 minute interval would have
armed the alarm at 15. Android's own limit on while-idle alarms (about one per
nine minutes per app, fewer in lower standby buckets) still applies, and the
Background tab's Android note states the practical result ("expect up to about 45
minutes between scans, even with a shorter interval").

**5. Start-time jitter (Q13: "if > 15 min then random +/- 5 minutes").** For
intervals over 15 minutes only; none at 15 or below. Windows: the trigger starts
5 minutes early (23:55 YESTERDAY) and `-RandomDelay` adds 0 to 10 minutes, which
nets minus 5 to plus 5 around the nominal time (`-RandomDelay` can only delay, so
"either way" needs both parts). **First-run timing (corrected at Sprint 77 Phase
5.1.2)**: the trigger's start is ALWAYS in the past -- midnight today, or 23:55
yesterday with jitter -- so Task Scheduler runs the task at the next repetition
after registration, at most one interval away. The first F264 version used
`-At "11:55PM"`, which is 23:55 TODAY, a future start for most of the day: a task
over 15 minutes did not run until that night. The start is now computed in Dart
(`PowerShellScriptGenerator.startBoundary`) and passed as a literal; a test checks
it is never after the registration time, and a Windows-only test runs the real
`New-ScheduledTaskTrigger` and checks its `StartBoundary` is in the past. Android: `AlarmJitter.offsetMs` adds a uniform
offset within plus or minus 5 minutes each time the alarm is armed, natively,
because every re-arm after a firing and after boot comes through
`DozeAlarmScheduler.schedule`. The two constants are pinned equal by a test.
**Consequence recorded**: the F98 (Sprint 42) anti-collision delay (interval minus
one minute) no longer applies at 15 minutes or less, so two accounts on the same
short interval start together again. The database busy timeout, WAL mode and the
worker's lock retry (F98) remain the protection.

**6. Existing users are converted on upgrade, both platforms (Q11).** A one-time,
sentinel-guarded migration (`BackgroundIntervalMigration`, same shape as the F98
`PerAccountBgMigration`) converts every stored value to the nearest one the
control can express (5-99 minutes, or a whole number of hours; ties go to the
longer interval) and re-registers the schedule of every account whose background
scanning is on. The re-registration also repairs a pre-F264 defect: an account
saved at 120 or 240 minutes had NOTHING scheduled (the Settings gate looked the
value up in the fixed list and returned), and the Windows startup path rescheduled
it every 15 minutes. Startup reconciliation uses the same conversion
(`reconcileAccountInterval`), never a hard-coded 15.

**Windows and Android paths (ADR-0042).** Shared: the model, the control, storage,
the migration. Windows: the trigger shape and repair path above. Android: the
alarm and WorkManager split above. The delivery-timing difference (Windows fires on
the minute; Android as the OS allows) remains the declared exception.
