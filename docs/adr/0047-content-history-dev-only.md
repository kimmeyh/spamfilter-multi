# ADR-0047: Content history -- a dev-only record of the developer's own mail

**Status**: Proposed (Harold accepts before the capture code merges -- Sprint 78 Task 7 DoD)
**Date**: 2026-10-10
**Deciders**: Harold (Chief Architect / Product Owner)
**Sprint**: 78 (R76-4, Issue #476)

## Context

Later heuristic, rule-mining and ML items (F267-F272, research `R76-3`) need a
labeled history of real email: what arrived, what the app decided, and what the
user decided. Today the app keeps a 100-character preview and the outcome of
each scan. It keeps no body text, and it keeps rows per scan, not per email.

Harold gave a Class-1 approval for this on 2026-10-09, for his own four
accounts only. On 2026-10-10 he narrowed it: *"limit to only running in Windows
dev or only dev - no need at this time to run anywhere else as Windows dev can
capture the entire list. on/off button on the Settings> General tab only for
dev."* He also asked that it write only unique emails and decide that from
headers: *"only pull full email if not in DB"*.

The Fold closed test acts on mail every 15 minutes. Harold will run Windows DEV
background scans read-only at 15 or 5 minutes for all four accounts, so the
history sees mail before and after the Fold acts on it. Many repeat sightings
are expected.

## Decision

1. **Dev builds only.** Capture runs only when `AppEnvironment.isDev`
   (`app_environment.dart:29`) is true AND the Settings > General "Content
   history" switch is on. The switch defaults to off and is not shown in a prod
   build. Store (MSIX) and Play (AAB) builds are prod builds, so no customer
   build can capture. A policy test asserts that capture cannot run, and the
   switch is not built, when `APP_ENV` is not `dev`. There is no account
   allow-list: a dev install holds only its developer's accounts.
   **The default environment is `dev`** (`app_environment.dart:20`): a build
   that omits `APP_ENV` is a dev build. The gate is therefore only as safe as
   the release build paths. A policy test pins that every release path (the
   MSIX `windows_build_args` and the `build-with-secrets.ps1` release/AAB path)
   passes `APP_ENV=prod`. A release build without it would be a dev build in
   every other respect too (title suffix, data folder), which the existing
   release self-test catches.
2. **Where it runs.** The check is an environment check in shared code, not a
   platform branch. It runs today on Harold's Windows DEV install. A dev
   Android build behaves the same way.
3. **One capture point.** Capture is called from `EmailScanner.evaluateBatch`
   (`email_scanner.dart:384-470`), before the safe-sender `continue`, so manual
   and background scans and every outcome pass through it.
4. **Unique emails, decided from headers.**
   - Identity: SHA-256 of the RFC 5322 Message-ID plus the account. The
     Message-ID already arrives with the headers every scan fetches (IMAP
     `generic_imap_adapter.dart:2107-2114`, Gmail
     `gmail_api_adapter.dart:1217-1221`). With no Message-ID, the fallback is the
     provider identifier plus the folder.
   - Per batch: compute identities, look them up in one indexed query, and fetch
     a body only for identities not already stored.
   - A repeat sighting writes no new row and fetches nothing. It updates only
     last-seen date and folder, and the scan outcome when it changed.
5. **What is stored** (Harold R3 = 1). Per email: account, identity hash,
   Message-ID, from address and display name, Reply-To, Return-Path domain,
   subject, received date, folder at first sight, last-seen date and folder,
   authentication class (F96), `List-Unsubscribe` presence, scan outcome
   (matched rule, pattern, action), the user's final decision with its date
   (recorded from the Results and Review quick actions; a Review row carries
   no Message-ID, so its decision is matched by the provider id in the
   account),
   scan type and platform, and the plain-text body. When an email has no text
   part, HTML is converted to text. The body is capped at 64 KB. No
   attachments, images or raw HTML.
6. **Body fetch.** A new provider method fetches the content of one message.
   IMAP and Gmail implement it and walk nested multipart. The existing
   `fetchFullBody`, which body rules use, does not change, so rule matching is
   unchanged. Demo and mock adapters implement it as a named no-op. One message
   is fetched at a time (F177/F180 memory limits).
7. **Storage** (R4 = 1). A separate SQLite file, `content_history.db`, beside
   `spam_filter.db` in the app data folder (`AppPaths`), so on Windows DEV:
   `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter_Dev\content_history.db`.
   The main schema and its version do not change. The dev seeder, which copies
   the prod `spam_filter.db` into dev, does not copy this file (prod never has
   one).
8. **Retention** (R5 = 1). Kept until deleted. Settings > General shows the
   switch, the stored count and a "Delete content history" button
   (`ContentHistoryRow`, which builds nothing in a prod build).
9. **Deletion.** "Remove an account" deletes that account's rows. "Delete all
   data" closes the history database and deletes the file. The pre-existing
   gaps in both paths (R7 = 1: `account_folder_cursors`, `background_scan_log`,
   `unmatched_emails`, `auth_rate_limit`) are fixed in the same task, and a
   policy test asserts that every table holding account data is covered by both
   paths.
10. **No export this sprint** (R6). Capture writes straight to the file on the
    PC. A later F267/F268 item adds an export if a tool needs one.
11. **Failure never fails a scan.** Capture runs inside a try/catch that logs
    through `DiagnosticLogger` and continues. A capture failure is visible in
    the log, never in scan results.

## Relation to R76-3

R76-3 Section 6 recommended never storing full body text, URLs with paths,
phone numbers or order numbers, because those were proposed for every user.
Harold chose the body text (R3 = 1) for dev-only use on his own mail. This ADR
overrides that recommendation for dev builds only. The recommendation still
holds for any customer build.

## Before any customer build could capture

A customer build would need, in order: F273 (privacy policy and Play Data
safety rewrite), a fresh Class-1 decision on what is stored, the R76-3 Section 6
"never store" list applied, encryption at rest (SEC-11b), and an export and
deletion path the user controls. Until then the environment gate in item 1 is
the control. Removing it is a Class-1 change.

## Platform primitives (ADR-0042)

- **Concurrent writers.** On Windows the background scan runs as a separate
  process (Task Scheduler). On Android it runs in a WorkManager isolate of the
  same process. Every write is ONE atomic statement: a new email is
  `INSERT OR IGNORE` against the UNIQUE index on `(account_id, identity_hash)`,
  and a repeat sighting is one `UPDATE`. Two writers that both miss the lookup
  cannot both insert: the second insert is ignored and that writer records a
  sighting instead. A blocked writer waits on `busy_timeout` (30 s, as the main
  database). As built, no multi-statement transaction is needed.
- **Deleting an open file.** On Windows a file with an open handle cannot be
  deleted, so "Delete all data" closes the history database before deleting
  the file. On Android an open file can be unlinked, but the same close-first
  order is used on both, so the behavior is identical.
- **SQLite version.** No `ON CONFLICT DO UPDATE` (needs 3.24); select, then
  update or insert, as in ADR-0045.

## Consequences

- Prod builds carry the capture code but can never run it. The cost is code
  size only.
- The history holds readable private mail in plaintext SQLite under the user
  profile, like the main database (SEC-11b on HOLD).
- The history grows without bound until deleted. At a 64 KB cap per body, about
  16,000 emails fit in 1 GB; typical bodies are far smaller.
- Labels are only as good as the scans that see the mail. Mail the Fold deletes
  before any Windows DEV scan sees it is not captured.

## Alternatives rejected

- **Build-time hash list of four addresses in the secrets files** (the original
  R1 recommendation). Superseded by Harold's dev-only decision, which needs no
  secrets key and no per-account gate.
- **A hidden per-account switch in every build.** Makes it a product feature for
  every user.
- **A table in `spam_filter.db`.** Changes the main schema and couples the
  history's size and deletion to the main database (R4 = 1 chose a separate
  file).
- **Fetch every body and deduplicate after.** Thousands of redundant downloads
  per day at a 5-minute interval.
