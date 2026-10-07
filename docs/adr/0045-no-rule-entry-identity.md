# ADR-0045: Identity and refresh semantics of a No Rule entry

**Status**: Accepted
**Date**: 2026-10-06
**Deciders**: Harold (Chief Architect / Product Owner)
**Sprint**: 77 (F245, Issue #463)

## Context

Every background scan evaluates the mailbox again. An IMAP windowed scan
re-fetches from the oldest unaddressed No Rule UID forward on purpose, so a
new rule gets a chance to match the backlog (`email_scanner.dart`, Sprint 38
Round 4). Each re-fetched No Rule email was inserted again. The result on a
real phone was about 115 new `unmatched_emails` rows per AOL scan, one UID
listed ten times in a morning, and the same email written to the background
export file on every scan.

`unmatched_emails` has no account column. An account is known only through
`scan_result_id -> scan_results.account_id`. Two IMAP accounts can hold the
same UID in a folder with the same name, so an identity that ignores the
account would merge two different emails.

## Decision

1. **Identity.** A No Rule entry is one email, identified by
   `(account, provider_identifier_type, provider_identifier_value,
   folder_name)`. The account comes from the row's scan
   (`scan_results.account_id`). There is no new account column (Harold, Q18 =
   2). Because the account is reached through a join, there is no
   cross-account UNIQUE index. A non-unique index
   `idx_unmatched_identity(provider_identifier_type, provider_identifier_value,
   folder_name)` supports the lookup.
2. **One writer.** `UnmatchedEmailStore.upsertUnmatchedEmails` is the only
   code that writes `unmatched_emails`. `addUnmatchedEmail` and
   `addUnmatchedEmailBatch` call it. A source gate
   (`test/policy/f245_single_writer_test.dart`) fails when any other
   `insert('unmatched_emails'` or `INSERT INTO unmatched_emails` appears in
   `lib/`. Prevention is the single helper plus the gate, because the schema
   cannot enforce account-scoped uniqueness without a new column.
3. **Account-scoped match.** The helper matches only inside the row's own
   account, through a join to `scan_results`. A match never crosses accounts.
4. **Refresh, not skip.** A matching row is updated in place. Its id and its
   first-seen time (`created_at`) are kept. `scan_result_id` moves to the
   current scan, and `last_seen_at`, subject, date, availability and
   authentication classification are refreshed. The row id is kept because the
   No Rule Review multi-select is keyed on it. `INSERT OR REPLACE` is not used,
   because it would change the id.
5. **Dismissed comes back (Harold, Q20 = 2).** The refresh resets
   `processed` to 0. A user who dismissed an email with "Remove Current Rule"
   or "Mark as Processed" is deferring it until the next scan: when a later
   scan still finds it with no rule, it returns for a decision. Harold:
   dismissed is often "I do not know, I will have to check".
6. **Retention on last-seen (Harold, Q22 = 1).** The 90-day cleanup cuts on
   `last_seen_at` (`created_at` for a row without one). An email a scan still
   sees never ages out. `created_at` stays the first-seen time.
7. **No Rule Review screen (Harold, Q21 = 2).** The screen lists every
   UNPROCESSED row for each account across scans
   (`UnmatchedEmailStore.getUnprocessedForAccount`). It used to read only the
   latest completed scan. With one row per email there are no duplicates, and
   a row owned by an older scan is still unaddressed.
8. **Background export lists once (Harold, Q19 = 1).** The upsert reports for
   each email whether it was inserted, changed (subject), reappeared (was
   dismissed), or unchanged. The BACKGROUND export omits the unchanged ones
   (`getExcelRows(omitAlreadyListedNoRule: true)`, passed only by
   `BackgroundScanExport.exportIfEnabled`). Manual-scan exports stay complete.
   Actions taken are always exported. A scan whose rows are all omitted still
   writes the `<no records to process>` row.
9. **Counts unchanged (Harold, Q23 = 1).** `scan_results.no_rule_count`, the
   Scan History "No Rule" column, and the Results banner keep their meaning:
   No Rule emails evaluated in that scan.
10. **Migration to DB v12.** Adds `last_seen_at`, back-fills it from
    `created_at`, and dedups existing rows to one per identity within an
    account. The newest row (highest scan id, then row id) survives and keeps
    its own `processed` state, which is the state of the latest sighting. It
    takes the oldest `created_at` and the newest `last_seen_at` of its group,
    and it is already on the newest scan, so the Review screen still finds it.
    The step runs inside sqflite's upgrade transaction, so a failure leaves
    the database at v11.

## Platform primitive (ADR-0042)

The helper is SELECT, then UPDATE or INSERT, inside one transaction. It does
not use `INSERT ... ON CONFLICT DO UPDATE`, which needs SQLite 3.24 or newer.

- **Windows**: `sqflite_common_ffi` bundles a recent SQLite, so either form
  would work.
- **Android**: `sqflite` uses the DEVICE's SQLite, and `minSdk` is 24. A
  3.24 or newer library is not guaranteed on every supported API level
  (unverified: the SQLite version per API level was not confirmed from
  developer.android.com).

The portable form behaves the same on both. `Database.transaction` issues
`BEGIN IMMEDIATE` (sqflite_common `txnBeginTransaction`, shared by the ffi and
Android implementations), which takes the write lock before the SELECT. The
UI isolate and a background worker (another isolate on Android, another
process on Windows) therefore cannot both miss the SELECT and both insert. The
second waits on `busy_timeout`.

The persistence path is shared code on both platforms (`EmailScanProvider`,
used by both background workers and live scans). There is no platform
exception.

## Consequences

- A user who dismissed a No Rule email sees it again after the next scan that
  still finds no rule for it. This is intended (Q20).
- Rows that the retired design duplicated are removed once, at upgrade. They
  cannot be restored. Retention would have deleted them within 90 days, and
  the Review screen never showed them.
- The Rule Test screen samples emails from the last three scans. After the
  upsert a re-found email lives only on the newest scan, so older scans hold
  fewer rows. The sample pool shrinks but does not empty.
- Two processes writing the same email at the same instant are serialized by
  the transaction, not by an index. A future second writer that bypasses the
  helper would re-create the defect without any database error. The source
  gate is the control.
- A moved email (different folder) is a new entry. A merged-folder identity
  was rejected because it would hide a real change of location.

## Alternatives rejected

- **Add an `account_id` column with a UNIQUE index.** Rejected by Harold
  (Q18 = 2): no new column. The account-scoped lookup through the scan
  achieves the same match.
- **Identity without the account.** Rejected: two IMAP accounts can share a
  UID in a same-named folder.
- **Skip an already-listed email.** It would make a still-unaddressed email
  vanish from Review after the next scan, because the screen read only the
  latest scan.
- **Keep `processed` on a refresh.** Rejected by Harold (Q20 = 2).
