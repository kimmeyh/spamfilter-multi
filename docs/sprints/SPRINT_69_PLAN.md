# Sprint 69 Plan

**Status**: STUB -- NOT PLANNED, NOT APPROVED. Scope is not selected until Phase 8.4.
**Branch**: `feature/20260910_Sprint_69` (created at Phase 6.6 from
`feature/20260909_Sprint_68` at `1f2eb8c`)
**Created**: 2026-09-10

## Carry-ins from Sprint 68

**Retrospective Category 13 (minor function updates for the next sprint plan): NONE.** All four
roles said so explicitly. The items below are backlog candidates Harold targeted or filed during
Sprint 68, not Category 13 carry-ins -- the distinction matters because Category 13 items are
committed and these are candidates for the Phase 8.4 slate.

### Targeted at Sprint 69 by Harold (2026-09-09)

**F202. Per-provider folder defaults** (~6-10h, Priority 10)

An overall default plus per-provider overrides for all four folder settings: Safe Senders
Folder, Deleted Rule Folder, Manual Scan Selected Folders, Background Scan Selected Folders.

Harold's ADR-0042 argument is the card's foundation: *"the development team cannot choose or
override for the providers what they deem as the defaults (names of folders and how folders are
used), so it requires an override by provider."* That turns "pick better defaults" into "record
what each provider actually does".

Already settled, so planning does not have to re-open them:

- **Existing accounts: NO migration, NO opt-in.** New users only; Settings is the path for
  everyone else.
- **A missing or empty folder is NOT an error** -- the scan continues.
- Confirmed values recorded as observed truth for AOL, Gmail and Yahoo. iCloud pending Harold.

Two code-level findings the card carries so they are not discovered mid-execution: a MISSING
folder currently routes through `recordFolderFetchError` into `errorCount` (so shipping a
default naming a folder some accounts lack produces a phantom error), and
`initialSelectedFolders` silently outranks the canonical pre-select.

### Also queued

- **F192.** Custom IMAP Server support -- build the host-entry UI (~4-6h, Priority 32). Harold
  planned this for Sprint 69 at the Sprint 68 scope selection.
- **F203.** "Found N, evaluated 0" is unexplainable to the user (~1-2h, Priority 22). Surfaced
  during Sprint 68 Manual Validation.

### Open, externally blocked

- **F199 remnant**: the Partner Center publisher display name. Microsoft's own documentation
  contradicts itself on whether an Individual account can change it, so this is resolved by a
  support ticket rather than by editing. Tracked in `docs/LEGAL_ENTITY.md`.

## Not yet done

Phase 8.4 backlog refinement pass 2 selects the scope. This stub exists because Phase 7.7
requires it, not because scope is decided.
