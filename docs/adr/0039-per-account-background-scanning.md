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
