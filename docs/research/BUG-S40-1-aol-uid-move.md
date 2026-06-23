# BUG-S40-1: AOL/Yahoo silent partial UID MOVE -- root cause and fix

**Date**: 2026-06-03 (Sprint 40 manual testing)
**Account**: `kimmeyharold@aol.com` (AOL IMAP, `imap.aol.com`)
**Symptom**: A live scan reported 482 messages deleted from "Bulk Mail", but a
re-scan minutes later "deleted" 271 of the EXACT SAME messages (identical IMAP
UIDs still present). Repeated scans cleared fewer each time, suggesting the
messages eventually all move given enough re-runs.

---

## Observed evidence

| | Scan 1 (10:15) | Scan 2 (10:26) |
|---|---|---|
| Bulk Mail returned (Step 4) | 579 | 365 |
| Deleted (reported) | 482 | 271 |
| Of scan-1 deletes still present at scan 2 | -- | 271 (100% subset) |
| Truly gone by scan 2 | -- | 211 |

- The 271 survivors carried the **same IMAP UIDs** across scans. An IMAP UID is
  permanent within a mailbox and never reused, so these are the literal same
  messages -- true survivors of a failed move, NOT re-injected copies (which
  would have new UIDs; that is the separate F91 "copy-not-move" case).
- The server returned `OK` for the `UID MOVE`; no exception was raised.

## Root cause (ranked by evidence)

### 1. Primary -- RFC 9738 MESSAGELIMIT partial MOVE, unparsed by enough_mail (STRONG)

AOL/Yahoo implement the IMAP **MESSAGELIMIT extension (RFC 9738)**. Under it:

- `MOVE` / `UID MOVE` are explicitly **not atomic**. When a move exceeds the
  server's per-command message limit, the server moves a **subset**, returns a
  **tagged `OK`** (not `NO`), and attaches a `[MESSAGELIMIT <limit> <lowest
  unprocessed UID>]` response code. The client is expected to repeat the
  command for the remainder.
- The server MAY enforce the cap even against clients that never negotiated the
  extension.

`enough_mail` 2.1.7 does **not** parse the `[MESSAGELIMIT ...]` response code
(verified by grep of `~/AppData/Local/Pub/Cache/.../enough_mail-2.1.7/lib`:
no `MESSAGELIMIT` / `lowestUid` / `UIDONLY` handling). `_copyOrMove` builds a
single `UID MOVE <all-uids> <path>` command and treats a tagged OK as complete.
Our adapter additionally sent **all** delete UIDs in one un-chunked command.

This explains every symptom: OK with a large remainder left behind, same UIDs
remaining, and "fewer remain each rescan / eventually all move."

### 2. Contributing -- low effective per-command cap on the Bulk folder (ANECDOTAL but consistent)

Field reports (Apple Communities "UID COPY sync limit with Yahoo" and forums)
describe Yahoo/AOL silently failing batch moves/copies above ~18-20 messages,
with items disappearing then reappearing on sync. The observed ~211-moved chunk
(< AOL's advertised MESSAGELIMIT of 1000) indicates the effective cap on the
spam/Bulk folder is variable and lower than advertised. Practically: do not
trust the advertised MESSAGELIMIT as a chunk size; pick a small fixed chunk.

### 3. Not the cause here -- command-line length, rate limiting

- Over-long command lines produce a `NO`/error ("Too long argument"), not a
  silent OK -- does not match the symptom (but is an independent reason to
  chunk).
- Rate limiting surfaces as an explicit `NO [LIMIT] ... Rate limit hit` or a
  dropped connection, not a silent partial OK. Still relevant to the retry
  strategy (do not hammer; single sequential connection; inter-command delay).

## Fix implemented

`GenericIMAPAdapter.moveToFolderBatch` -> `_moveFolderChunkedWithRetry`:

1. **Chunk** the UID set into `_moveChunkSize = 50` chunks (well below the
   advertised 1000; balances throughput against the low effective cap).
2. For each chunk: `UID MOVE`, then **`_moveChunkDelay = 250 ms`** pause to stay
   under command-rate limits.
3. **Verify** via `_uidsStillPresent` (a `UID SEARCH` of the chunk's UIDs in the
   source folder). Survivors are carried forward.
4. **Loop** the whole source folder up to `_moveMaxPasses = 6` times, re-moving
   survivors, until none remain. Abort early on a no-progress pass (server
   refusing the UIDs outright).
5. UIDs still present after all passes are recorded as **genuine failures** via
   `partitionByMoveSurvival` (honest CSV / scan summary), not false successes.

This converts the historical "reappears on every scan" cross-scan loop into a
single deterministic, bounded in-scan reconciliation. Applies to delete,
moveToJunk, and safe-sender move (all route through `moveToFolderBatch`).

### Tunable constants (top of `generic_imap_adapter.dart`)

| Constant | Value | Rationale |
|----------|-------|-----------|
| `_moveChunkSize` | 50 | Below AOL effective cap; throughput vs. safety |
| `_moveChunkDelay` | 250 ms | Under AOL/Yahoo command-rate limit |
| `_moveMaxPasses` | 6 | Bound; each pass must make progress or abort |

If live testing shows survivors still remaining after 6 passes, lower
`_moveChunkSize` (e.g. 20) first; only consider COPY+EXPUNGE if MOVE is proven
to hard-refuse (research shows COPY is atomic and hard-fails over the cap, so it
is NOT a reliability win over chunked MOVE).

## MOVE vs COPY+EXPUNGE

Prefer **chunked `UID MOVE` + verify loop**. COPY is atomic and returns a hard
`NO [MESSAGELIMIT]` over the cap ("no messages copied"), so COPY+STORE\Deleted+
EXPUNGE is all-or-nothing and offers no advantage; it would still require
chunking below the cap. UID-mode operations are reported as more reliable on
Yahoo/AOL.

## Future hardening (backlog candidates)

- Parse `[MESSAGELIMIT n lowestUid]` and/or `ENABLE UIDONLY` (would require
  extending or forking `enough_mail`) to drive the chunk loop from the server's
  own reported remainder instead of post-hoc verification.
- Exponential backoff on `NO [LIMIT]` / connection drops within the chunk loop.

## Key sources

- RFC 9738 -- IMAP MESSAGELIMIT (MOVE non-atomic; OK + `[MESSAGELIMIT]`):
  https://www.rfc-editor.org/rfc/rfc9738.html
- RFC 6851 -- IMAP MOVE baseline: https://www.rfc-editor.org/rfc/rfc6851
- Yahoo/AOL IMAP Pagination & Mail Sync (official):
  https://senders.yahooinc.com/static/Yahoo_Aol%20IMAP%20Pagination%20and%20Mail%20Sync-7564bd8d996168f4b38eee1440784515.pdf
- imapsync Yahoo FAQ: https://imapsync.lamiral.info/FAQ.d/FAQ.Yahoo.txt
- Mozilla bug 1727971 (Yahoo `NO [LIMIT]` rate limit):
  https://bugzilla.mozilla.org/show_bug.cgi?id=1727971
- Apple Communities -- Yahoo ~19-message UID COPY cap:
  https://discussions.apple.com/thread/254716993
